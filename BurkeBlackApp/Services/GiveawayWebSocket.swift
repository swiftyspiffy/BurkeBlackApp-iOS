import Foundation
import SwiftUI

// MARK: - Giveaway WebSocket Events

struct GiveawayEvent {
    let type: GiveawayEventType
    let name: String?
    let donator: String?
    let totalEntries: String?
    let winner: String?
    let redraw: String?
}

enum GiveawayEventType: String {
    case newGiveaway = "newraffle"
    case giveawayUpdate = "giveawayupdate"
    case newGiveawayWinner = "rafflewinner"
    case giveawayClaim = "raffleclaim"
    case giveawayError = "raffleerror"
    case unknown
}

// MARK: - WebSocket Manager

@MainActor
class GiveawayWebSocketManager: ObservableObject {
    static let shared = GiveawayWebSocketManager()

    @Published var isConnected = false
    @Published var activeGiveaway: ActiveGiveaway?
    @Published var isDismissedToMini = false
    @Published var messageLog: [(Date, String)] = []


    private var webSocketTask: URLSessionWebSocketTask?
    private var isIntentionalDisconnect = false
    private var reconnectTask: Task<Void, Never>?
    private var token: String?
    private var username: String?

    private init() {}

    func connect(token: String, username: String? = nil) {
        self.token = token
        self.username = username
        isIntentionalDisconnect = false
        doConnect()
    }

    func connectPassive() {
        // Connect without auth for passive giveaway event listening
        if webSocketTask == nil || !isConnected {
            isIntentionalDisconnect = false
            doConnect()
            appLog("Giveaway WS: passive connect")
        }
    }

    func reconnectIfNeeded() {
        if !isConnected && !isIntentionalDisconnect {
            appLog("Giveaway WS: reconnecting on resume")
            doConnect()
        }
    }

    func disconnect() {
        isIntentionalDisconnect = true
        reconnectTask?.cancel()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        appLog("Giveaway WS: disconnected")
    }

    private func doConnect() {
        guard let url = URL(string: "wss://socketserver.burkeblack.tv/giveaway") else { return }

        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        isConnected = true
        appLog("Giveaway WS: connected")
        receiveMessage()
        Task { await checkForActiveGiveaway() }
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        self.handleMessage(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self.handleMessage(text)
                        }
                    @unknown default:
                        break
                    }
                    self.receiveMessage()

                case .failure(let error):
                    appLog("Giveaway WS: error \(error.localizedDescription)")
                    self.isConnected = false
                    if !self.isIntentionalDisconnect {
                        self.scheduleReconnect()
                    }
                }
            }
        }
    }

    private func scheduleReconnect() {
        reconnectTask?.cancel()
        reconnectTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            if !isIntentionalDisconnect {
                appLog("Giveaway WS: reconnecting")
                doConnect()
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let eventStr = json["event"] as? String else { return }

        let eventType = GiveawayEventType(rawValue: eventStr) ?? .unknown
        appLog("Giveaway WS: event \(eventStr)")
        messageLog.append((Date(), "\(eventStr): \(text.prefix(200))"))
        if messageLog.count > 50 { messageLog.removeFirst() }

        switch eventType {
        case .newGiveaway:
            guard AppSettings.shared.giveawayPopupsEnabled else { break }
            let name = json["name"] as? String ?? "Giveaway"
            let donator = json["donator"] as? String ?? "Unknown"
            activeGiveaway = ActiveGiveaway(
                name: name,
                donator: donator,
                isEntered: false,
                phase: .entry,
                winner: nil,
                totalEntries: nil,
                timeRemaining: nil,
                countdownStart: nil
            )
            // Try to get the giveaway ID from the DB
            Task { await fetchActiveGiveawayId() }

        case .giveawayUpdate:
            let entries = json["totalEntries"] as? String
            if var g = activeGiveaway { g.totalEntries = entries; activeGiveaway = g }

        case .newGiveawayWinner:
            let winner = json["winner"] as? String
            if var g = activeGiveaway {
                g.phase = .winner; g.winner = winner
                if let e = json["totalEntries"] as? String { g.totalEntries = e }
                activeGiveaway = g
            }

        case .giveawayClaim:
            let winner = json["winner"] as? String
            if var g = activeGiveaway { g.phase = .claimed; g.winner = winner; activeGiveaway = g }

        case .giveawayError:
            activeGiveaway = nil

        case .unknown:
            break
        }
    }

    private func checkForActiveGiveaway() async {
        guard AppSettings.shared.giveawayPopupsEnabled else {
            activeGiveaway = nil
            isDismissedToMini = false
            return
        }
        guard let token = self.token else { return }
        guard let url = URL(string: "https://api.burkeblack.tv/app/giveaway-active") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        TwitchAuthService.addPlatformHeaders(&req)
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataObj = json["data"] as? [String: Any] else { return }

            guard let id = dataObj["id"] as? Int else {
                activeGiveaway = nil
                isDismissedToMini = false
                return
            }

            let state = dataObj["state"] as? String ?? ""
            let name = dataObj["name"] as? String ?? "Giveaway"
            let donator = dataObj["donator"] as? String ?? ""
            let isEntered = dataObj["is_entered"] as? Bool ?? false
            let timeRemaining = dataObj["time_remaining"] as? Int

            // Only show if giveaway is actively running
            // Entry phase: always show (entries are open)
            // Claim/winner: only show if there's time remaining (otherwise it's finished)
            let isActive: Bool
            switch state {
            case "entry":
                isActive = timeRemaining != nil && timeRemaining! > 0
            case "claim", "winner":
                isActive = timeRemaining != nil && timeRemaining! > 0
            default:
                isActive = false
            }

            if isActive {
                let phase: GiveawayPhase = state == "entry" ? .entry : (state == "claim" ? .claimed : .winner)
                var giveaway = ActiveGiveaway(
                    name: name,
                    donator: donator,
                    isEntered: isEntered,
                    phase: phase,
                    winner: nil,
                    totalEntries: nil,
                    timeRemaining: nil,
                    countdownStart: nil
                )
                giveaway.id = id
                if let remaining = timeRemaining, remaining > 0 {
                    giveaway.timeRemaining = remaining
                    giveaway.countdownStart = Date()
                }
                activeGiveaway = giveaway
                appLog("Active giveaway found: \(name) (\(state))")
            } else {
                activeGiveaway = nil
                isDismissedToMini = false
            }
        } catch {
            appLog("Check active giveaway error: \(error)")
        }
    }

    private func fetchActiveGiveawayId() async {
        await checkForActiveGiveaway()
    }

    func enterGiveaway() async {
        guard let token = self.token, let id = activeGiveaway?.id else { return }
        guard let url = URL(string: "https://api.burkeblack.tv/app/giveaway-enter") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        TwitchAuthService.addPlatformHeaders(&req)
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["giveaway_id": id])
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                if var g = activeGiveaway { g.isEntered = true; activeGiveaway = g }
                appLog("Giveaway entered: \(id)")
            } else if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let error = json["error"] as? String {
                appLog("Giveaway enter error: \(error)")
            }
        } catch {
            appLog("Giveaway enter failed: \(error)")
        }
    }

    func leaveGiveaway() async {
        guard let token = self.token, let id = activeGiveaway?.id else { return }
        guard let url = URL(string: "https://api.burkeblack.tv/app/giveaway-leave") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        TwitchAuthService.addPlatformHeaders(&req)
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["giveaway_id": id])
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                if var g = activeGiveaway { g.isEntered = false; activeGiveaway = g }
                appLog("Giveaway left: \(id)")
            }
        } catch {
            appLog("Giveaway leave failed: \(error)")
        }
    }

    func passGiveaway() async {
        guard let token = self.token, let id = activeGiveaway?.id else { return }
        guard let url = URL(string: "https://api.burkeblack.tv/app/giveaway-pass") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        TwitchAuthService.addPlatformHeaders(&req)
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["giveaway_id": id])
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                appLog("Giveaway passed: \(id)")
                activeGiveaway = nil
            }
        } catch {
            appLog("Giveaway pass failed: \(error)")
        }
    }


    func claimGiveaway() async {
        guard let token = self.token, let id = activeGiveaway?.id else { return }
        guard let url = URL(string: "https://api.burkeblack.tv/app/giveaway-claim") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        TwitchAuthService.addPlatformHeaders(&req)
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["giveaway_id": id])
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                appLog("Giveaway claimed: \(id)")
                if var g = activeGiveaway { g.phase = .claimed; activeGiveaway = g }
            }
        } catch {
            appLog("Giveaway claim failed: \(error)")
        }
    }

    func isCurrentUserWinner() -> Bool {
        guard let winner = activeGiveaway?.winner else { return false }
        // Try stored username first, fall back to UserDefaults
        let user = username ?? storedUsername
        guard let user else { return false }
        return winner.caseInsensitiveCompare(user) == .orderedSame
    }

    private var storedUsername: String? {
        guard let data = UserDefaults.standard.data(forKey: "app_user_data"),
              let dashboard = try? JSONDecoder().decode(DashboardData.self, from: data) else { return nil }
        return dashboard.username
    }

    func dismissGiveaway() {
        activeGiveaway = nil
        isDismissedToMini = false
    }

    func minimizeGiveaway() {
        isDismissedToMini = true
    }

    func restoreGiveaway() {
        isDismissedToMini = false
    }
}

// MARK: - Active Giveaway Model

struct ActiveGiveaway {
    var id: Int?
    var name: String
    var donator: String
    var isEntered: Bool
    var phase: GiveawayPhase
    var winner: String?
    var totalEntries: String?
    var timeRemaining: Int?
    var countdownStart: Date?
}

enum GiveawayPhase {
    case entry
    case winner
    case claimed
}
