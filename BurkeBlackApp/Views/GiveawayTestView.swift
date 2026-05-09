import SwiftUI
import WidgetKit

struct GiveawayTestView: View {
    @ObservedObject var wsManager = GiveawayWebSocketManager.shared
    @ObservedObject var pushService = PushNotificationService.shared
    @ObservedObject var appSettings = AppSettings.shared
    @State private var showGiveawayControls = false
    @State private var authCheckResult: String?
    @State private var isCheckingAuth = false
    @State private var forceStreamStatus: String = {
        UserDefaults(suiteName: "group.com.swiftyspiffy.BurkeBlackApp")?.string(forKey: "widget.debug.forceStatus") ?? "none"
    }()

    private var permissionStatusLabel: String {
        switch pushService.permissionStatus {
        case .authorized: return "Authorized"
        case .denied: return "Denied"
        case .notDetermined: return "Not Determined"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        @unknown default: return "Unknown"
        }
    }

    private var storedToken: String? {
        AccountViewModel.getBearerToken()
    }

    private var storedUsername: String? {
        guard let data = UserDefaults.standard.data(forKey: "app_user_data"),
              let dashboard = try? JSONDecoder().decode(DashboardData.self, from: data) else { return nil }
        return dashboard.username
    }

    var body: some View {
        List {
            // Authentication Section
            Section("Authentication") {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(storedToken != nil ? "Authenticated" : "Not Authenticated")
                        .foregroundStyle(storedToken != nil ? .green : .red)
                        .fontWeight(.medium)
                }

                if let username = storedUsername {
                    HStack {
                        Text("Username")
                        Spacer()
                        Text(username).foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Text("Token")
                    Spacer()
                    if let token = storedToken {
                        Text(String(token.prefix(12)) + "...")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                            .monospaced()
                    } else {
                        Text("None").foregroundStyle(.secondary)
                    }
                }

                Button {
                    Task { await checkAuth() }
                } label: {
                    HStack {
                        if isCheckingAuth {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "checkmark.shield")
                        }
                        Text("Check Authentication")
                    }
                }
                .disabled(storedToken == nil || isCheckingAuth)

                if let result = authCheckResult {
                    Text(result)
                        .font(.caption)
                        .foregroundStyle(result.contains("Valid") ? .green : .red)
                        .padding(.vertical, 4)
                }
            }

            // Notifications Section
            Section("Notifications") {
                HStack {
                    Text("Enabled")
                    Spacer()
                    Text(pushService.permissionStatus == .authorized ? "Yes" : "No")
                        .foregroundStyle(pushService.permissionStatus == .authorized ? .green : .red)
                        .fontWeight(.medium)
                }

                HStack {
                    Text("System Status")
                    Spacer()
                    Text(permissionStatusLabel)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Registered with Backend")
                    Spacer()
                    Text(pushService.isRegistered ? "Yes" : "No")
                        .foregroundStyle(pushService.isRegistered ? .green : .secondary)
                }

                HStack {
                    Text("Device Token")
                    Spacer()
                    if let token = UserDefaults.standard.string(forKey: "push_device_token") {
                        Text(String(token.prefix(16)) + "...")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                            .monospaced()
                    } else {
                        Text("None").foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Text("Has Been Asked")
                    Spacer()
                    Text(pushService.hasAskedBefore ? "Yes" : "No")
                        .foregroundStyle(.secondary)
                }

                NavigationLink {
                    NotificationChannelsDebugView()
                } label: {
                    HStack {
                        Image(systemName: "bell.badge")
                        Text("Notification Channels")
                    }
                }
            }

            // WebSocket Section
            Section("WebSocket") {
                HStack {
                    Text("Connection")
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(wsManager.isConnected ? .green : .red)
                            .frame(width: 8, height: 8)
                        Text(wsManager.isConnected ? "Connected" : "Disconnected")
                            .foregroundStyle(wsManager.isConnected ? .green : .red)
                    }
                }

                HStack {
                    Text("Active Giveaway")
                    Spacer()
                    Text(wsManager.activeGiveaway != nil ? "Yes" : "No")
                        .foregroundStyle(wsManager.activeGiveaway != nil ? .green : .secondary)
                }

                if let g = wsManager.activeGiveaway {
                    HStack {
                        Text("Phase")
                        Spacer()
                        Text("\(String(describing: g.phase))")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Entered")
                        Spacer()
                        Text(g.isEntered ? "Yes" : "No")
                            .foregroundStyle(g.isEntered ? .green : .secondary)
                    }
                    if let winner = g.winner {
                        HStack {
                            Text("Winner")
                            Spacer()
                            Text(winner).foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("Is Current User Winner")
                            Spacer()
                            Text(wsManager.isCurrentUserWinner() ? "Yes" : "No")
                                .foregroundStyle(wsManager.isCurrentUserWinner() ? .green : .secondary)
                        }
                    }
                }

                Button {
                    if wsManager.isConnected {
                        wsManager.disconnect()
                    } else {
                        wsManager.reconnectIfNeeded()
                    }
                } label: {
                    HStack {
                        Image(systemName: wsManager.isConnected ? "wifi.slash" : "wifi")
                        Text(wsManager.isConnected ? "Disconnect" : "Reconnect")
                    }
                }

                // Recent messages
                if !wsManager.messageLog.isEmpty {
                    DisclosureGroup("Recent Messages (\(wsManager.messageLog.count))") {
                        ForEach(wsManager.messageLog.reversed(), id: \.0) { entry in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.0, style: .time)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Text(entry.1)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }

            // UI
            Section("UI") {
                Toggle(isOn: $appSettings.presentationMode) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Presentation Mode")
                        Text("Hides Dispatch, Mod Panel for screenshots")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // UI Debug
            if storedUsername?.lowercased() == "swiftyspiffy" {
                Section("UI Debug") {
                    Toggle(isOn: $appSettings.debugShowCaptainsDispatch) {
                        Text("Show Captain\u{2019}s Dispatch")
                    }
                }
            }

            // Widget Debug
            Section("Widget Debug") {
                Picker(selection: $forceStreamStatus) {
                    Text("Default").tag("none")
                    Text("Force Online").tag("online")
                    Text("Force Offline").tag("offline")
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Force Stream Status")
                        Text("Override widget stream state for testing")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: forceStreamStatus) { _, newValue in
                    let defaults = UserDefaults(suiteName: "group.com.swiftyspiffy.BurkeBlackApp")
                    defaults?.set(newValue, forKey: "widget.debug.forceStatus")
                    defaults?.removeObject(forKey: "widget.debug.forceOffline")
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }

            // Debug Logs
            Section("Logs") {
                NavigationLink {
                    DebugLogsView()
                } label: {
                    Label("Debug Logs", systemImage: "doc.text.magnifyingglass")
                }
                NavigationLink {
                    WidgetLogsView()
                } label: {
                    Label("Widget Logs", systemImage: "square.text.square")
                }
            }

            // Giveaway Simulation (collapsed)
            #if targetEnvironment(simulator) || DEBUG
            Section {
                DisclosureGroup("Giveaway Simulation", isExpanded: $showGiveawayControls) {
                    Group {
                        Button("New Giveaway") {
                            wsManager.activeGiveaway = ActiveGiveaway(
                                name: "Sea of Thieves DLC",
                                donator: "BurkeBlack",
                                isEntered: false,
                                phase: .entry,
                                winner: nil,
                                totalEntries: nil
                            )
                            wsManager.activeGiveaway?.id = 999
                            wsManager.isDismissedToMini = false
                        }

                        Button("New Giveaway (with entries)") {
                            wsManager.activeGiveaway = ActiveGiveaway(
                                name: "Steam Gift Card $50",
                                donator: "swiftyspiffy",
                                isEntered: false,
                                phase: .entry,
                                winner: nil,
                                totalEntries: "47"
                            )
                            wsManager.activeGiveaway?.id = 999
                            wsManager.isDismissedToMini = false
                        }

                        Button("Already Entered") {
                            wsManager.activeGiveaway = ActiveGiveaway(
                                name: "Skull & Bones Game Key",
                                donator: "NinjaDrop0ut",
                                isEntered: true,
                                phase: .entry,
                                winner: nil,
                                totalEntries: "123"
                            )
                            wsManager.activeGiveaway?.id = 999
                            wsManager.isDismissedToMini = false
                        }

                        Button("Set Timer 10s") {
                            if var g = wsManager.activeGiveaway { g.timeRemaining = 10; g.countdownStart = Date(); wsManager.activeGiveaway = g }
                        }

                        Button("Toggle Entered") {
                            if var g = wsManager.activeGiveaway { g.isEntered.toggle(); wsManager.activeGiveaway = g }
                        }

                        Button("Winner Drawn (me)") {
                            if var g = wsManager.activeGiveaway {
                                g.phase = .winner
                                g.winner = storedUsername ?? "swiftyspiffy"
                                g.totalEntries = "89"
                                wsManager.activeGiveaway = g
                            }
                        }

                        Button("Winner Drawn (other)") {
                            if var g = wsManager.activeGiveaway {
                                g.phase = .winner
                                g.winner = "BurkeBlack"
                                g.totalEntries = "156"
                                wsManager.activeGiveaway = g
                            }
                        }

                        Button("Prize Claimed") {
                            if var g = wsManager.activeGiveaway { g.phase = .claimed; wsManager.activeGiveaway = g }
                        }

                        Button("Dismiss Giveaway", role: .destructive) {
                            wsManager.dismissGiveaway()
                        }
                    }
                }
            }
            #endif
        }
        .onAppear { appLog("Advanced: view appeared") }
        .navigationTitle("Advanced")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func checkAuth() async {
        guard let token = storedToken else { return }
        isCheckingAuth = true
        authCheckResult = nil
        do {
            let status = try await TwitchAuthService.shared.fetchUserStatus(token: token)
            authCheckResult = "Valid \u{2714} Role: \(status.userRole), Mod: \(status.isModerator ?? false), Follows: \(status.follows), Sub: \(status.subscribed)"
        } catch {
            authCheckResult = "Invalid \u{2718} \(error.localizedDescription)"
        }
        isCheckingAuth = false
    }
}
