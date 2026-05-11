import Foundation
import SwiftUI
import Security
import WidgetKit

@MainActor
class AccountViewModel: ObservableObject {
    @Published var isLoggedIn = false
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var username = ""
    @Published var avatarURL: URL?
    @Published var doubloons = 0
    @Published var soundbyteCredits = 0
    @Published var donations: Double = 0
    @Published var giveawaysEntered = 0
    @Published var giveawaysWon = 0
    @Published var giveawaysDonated = 0
    @Published var eventsDonations: Double = 0
    @Published var totalBits = 0
    @Published var soundbyteSends = 0
    @Published var favSoundbyte: FavSoundbyteData?
    @Published var lastSoundbyte: LastSoundbyteData?
    @Published var soundbytesEnabled = true
    @Published var canSendCaptainNotifications = false
    @Published var followedAt: String?
    @Published var latestSub: LatestSubData?
    @Published var isModerator = false
    @Published var isSubGifter = false
    @Published var isBitsSender = false
    @Published var userRole = "Twitch Viewer"
    @Published var follows = false
    @Published var subscribed = false
    @Published var subTier: String?

    var isDonator: Bool { donations > 0 || eventsDonations > 0 }
    var showModPanel: Bool { isModerator || userRole.lowercased().contains("mod") || userRole.lowercased().contains("staff") }

    private static let tokenKey = "app_bearer_token"
    private static let userDataKey = "app_user_data"
    private static let avatarKey = "app_avatar_url"
    private static let statusKey = "app_user_status"
    private static let forceVerifyKey = "app_force_verify"

    private(set) var bearerToken: String?


    func fetchNotificationPermissions() async {
        guard let token = bearerToken else { return }
        guard let url = URL(string: "https://api.burkeblack.tv/app/notification-permissions") else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        TwitchAuthService.addPlatformHeaders(&request)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }

            struct PermResponse: Codable {
                let success: Bool
                let data: Perms?
            }
            struct Perms: Codable {
                let can_send_burke_announcements: Bool
                let can_send_special_events: Bool
            }

            if let decoded = try? JSONDecoder().decode(PermResponse.self, from: data), let perms = decoded.data {
                canSendCaptainNotifications = perms.can_send_burke_announcements || perms.can_send_special_events
                appLog("Notification permissions: captain=\(canSendCaptainNotifications)")
            }
        } catch {
            appLog("Notification permissions fetch failed: \(error.localizedDescription)")
        }
    }

    static func getBearerToken() -> String? {
        if let token = loadFromKeychain(key: tokenKey) {
            return token
        }
        if let token = UserDefaults.standard.string(forKey: tokenKey) {
            return token
        }
        appLog("getBearerToken: not found in keychain or UserDefaults")
        return nil
    }

    // MARK: - Keychain

    private static func saveToKeychain(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func loadFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    init() {
        restoreSession()
    }

    func loginWithTwitch() async {
        isLoading = true
        defer { isLoading = false }

        let forceVerify = UserDefaults.standard.bool(forKey: Self.forceVerifyKey)
        do {
            let result = try await TwitchAuthService.shared.authenticate(forceVerify: forceVerify)
            bearerToken = result.token
            applyDashboard(result.dashboard)
            if let url = result.avatarUrl ?? result.dashboard.avatarUrl {
                avatarURL = URL(string: url)
                UserDefaults.standard.set(url, forKey: Self.avatarKey)
            }
            saveSession(token: result.token, dashboard: result.dashboard)
            isLoggedIn = true
            UserDefaults.standard.set(false, forKey: Self.forceVerifyKey)
            GiveawayWebSocketManager.shared.connect(token: result.token, username: result.username)
            appLog("Login success: \(result.username)")

            // Reload feature flags with new auth context
            Task { await FeatureFlagService.shared.load() }

            // Register for push notifications
            await PushNotificationService.shared.requestPermissionAndRegister()
            await PushNotificationService.shared.reregisterIfNeeded()
            await PushNotificationService.shared.syncPreferences()

            // Fetch user status and notification permissions in background
            await fetchUserStatus()
            await fetchNotificationPermissions()
        } catch is CancellationError {
            appLog("Login cancelled")
        } catch {
            appLog("Login error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func refreshDashboard() async {
        guard let token = bearerToken else { return }
        appLog("Dashboard refresh started")
        do {
            let dashboard = try await TwitchAuthService.shared.fetchDashboard(token: token)
            applyDashboard(dashboard)
            if let url = dashboard.avatarUrl {
                avatarURL = URL(string: url)
                UserDefaults.standard.set(url, forKey: Self.avatarKey)
            }
            saveSession(token: token, dashboard: dashboard)
            appLog("Account: dashboard refreshed for \(dashboard.username)")

            await fetchUserStatus()
        } catch {
            appLog("Account: dashboard refresh failed, logging out: \(error.localizedDescription)")
            logout()
        }
    }

    func fetchUserStatus() async {
        guard let token = bearerToken else { return }
        appLog("Fetching user status")
        do {
            let status = try await TwitchAuthService.shared.fetchUserStatus(token: token)
            appLog("User status: role=\(status.userRole) follows=\(status.follows) sub=\(status.subscribed)")
            follows = status.follows
            subscribed = status.subscribed
            subTier = status.subTier
            userRole = status.userRole
            isModerator = (status.isModerator ?? false) || UserDefaults.standard.bool(forKey: "app_reviewer_is_mod")
            isSubGifter = status.isSubGifter ?? false
            isBitsSender = status.isBitsSender ?? false
            if let fa = status.followedAt { followedAt = fa }
            if let data = try? JSONEncoder().encode(status) {
                UserDefaults.standard.set(data, forKey: Self.statusKey)
            }
            refreshWidgetFollowMonths()
        } catch {
            appLog("Account: fetchUserStatus error: \(error.localizedDescription)")
            // Non-critical, keep cached values
        }
    }

    private func refreshWidgetFollowMonths() {
        guard let shared = UserDefaults(suiteName: "group.com.swiftyspiffy.BurkeBlackApp") else { return }
        shared.set(followMonths(from: followedAt), forKey: "widget.followMonths")
        WidgetCenter.shared.reloadAllTimelines()
    }

    func reviewerLogin(token: String, username: String, avatarUrl: String? = nil, moderator: Bool = false) async {
        bearerToken = token
        self.username = username
        if let url = avatarUrl {
            self.avatarURL = URL(string: url)
            UserDefaults.standard.set(url, forKey: Self.avatarKey)
        }
        self.isModerator = moderator
        if moderator { self.userRole = "Moderator" }
        isLoggedIn = true
        Self.saveToKeychain(key: Self.tokenKey, value: token)
        UserDefaults.standard.set(moderator, forKey: "app_reviewer_is_mod")
        GiveawayWebSocketManager.shared.connect(token: token, username: username)
        appLog("Reviewer login: \(username) moderator=\(moderator)")

        // Try to fetch dashboard data
        do {
            let dashboard = try await TwitchAuthService.shared.fetchDashboard(token: token)
            applyDashboard(dashboard)
            saveSession(token: token, dashboard: dashboard)
        } catch {
            // Dashboard may fail for reviewer account - that's ok
            appLog("Reviewer dashboard fetch failed: \(error.localizedDescription)")
        }
    }

    func logout() {
        Task { await PushNotificationService.shared.unregisterFromBackend() }
        appLog("User logged out")
        UserDefaults.standard.set(true, forKey: Self.forceVerifyKey)
        UserDefaults.standard.removeObject(forKey: "app_reviewer_is_mod")
        GiveawayWebSocketManager.shared.disconnect()
        isLoggedIn = false
        bearerToken = nil
        username = ""
        avatarURL = nil
        doubloons = 0
        soundbyteCredits = 0
        donations = 0.0
        giveawaysEntered = 0
        giveawaysWon = 0
        giveawaysDonated = 0
        userRole = "Twitch Viewer"
        follows = false
        subscribed = false
        subTier = nil
        isModerator = false
        isSubGifter = false
        isBitsSender = false
        appLog("Account: clearing token from keychain")
        Self.deleteFromKeychain(key: Self.tokenKey)
        UserDefaults.standard.removeObject(forKey: Self.tokenKey) // Clean up legacy
        UserDefaults.standard.removeObject(forKey: Self.userDataKey)
        UserDefaults.standard.removeObject(forKey: Self.avatarKey)
        UserDefaults.standard.removeObject(forKey: Self.statusKey)
        clearWidgetData()

        // Reload feature flags without auth context
        Task { await FeatureFlagService.shared.load() }
    }

    private func applyDashboard(_ dashboard: DashboardData) {
        username = dashboard.username
        doubloons = dashboard.doubloons
        soundbyteCredits = dashboard.soundbyteCredits
        donations = dashboard.donations
        giveawaysEntered = dashboard.giveawaysEntered
        giveawaysWon = dashboard.giveawaysWon
        giveawaysDonated = dashboard.giveawaysDonated
        eventsDonations = dashboard.eventsDonations ?? 0
        totalBits = dashboard.totalBits ?? 0
        soundbyteSends = dashboard.soundbyteSends ?? 0
        favSoundbyte = dashboard.favSoundbyte
        lastSoundbyte = dashboard.lastSoundbyte
        soundbytesEnabled = dashboard.soundbytesEnabled ?? true
        latestSub = dashboard.latestSub
        if let fd = dashboard.followDate {
            followedAt = fd
        }
    }

    private func saveSession(token: String, dashboard: DashboardData) {
        appLog("Account: saving session to keychain")
        Self.saveToKeychain(key: Self.tokenKey, value: token)
        if let data = try? JSONEncoder().encode(dashboard) {
            UserDefaults.standard.set(data, forKey: Self.userDataKey)
        }
        updateWidgetData(dashboard: dashboard)
    }

    private func updateWidgetData(dashboard: DashboardData) {
        guard let shared = UserDefaults(suiteName: "group.com.swiftyspiffy.BurkeBlackApp") else { return }
        shared.set(dashboard.doubloons, forKey: "widget.doubloons")
        shared.set(dashboard.soundbyteCredits, forKey: "widget.soundbyteCredits")
        let followDate = dashboard.followDate ?? followedAt
        shared.set(followMonths(from: followDate), forKey: "widget.followMonths")
        shared.set(dashboard.latestSub?.cumulativeMonths ?? 0, forKey: "widget.subMonths")
        shared.set(true, forKey: "widget.isLoggedIn")
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func clearWidgetData() {
        guard let shared = UserDefaults(suiteName: "group.com.swiftyspiffy.BurkeBlackApp") else { return }
        shared.removeObject(forKey: "widget.doubloons")
        shared.removeObject(forKey: "widget.soundbyteCredits")
        shared.removeObject(forKey: "widget.followMonths")
        shared.removeObject(forKey: "widget.subMonths")
        shared.set(false, forKey: "widget.isLoggedIn")
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func followMonths(from dateString: String?) -> Int {
        guard let dateString else { return 0 }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = iso.date(from: dateString)
        if date == nil {
            iso.formatOptions = [.withInternetDateTime]
            date = iso.date(from: dateString)
        }
        if date == nil {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd HH:mm:ss"
            date = df.date(from: dateString)
        }
        if date == nil {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            date = df.date(from: dateString)
        }
        guard let followDate = date else { return 0 }
        let months = Calendar.current.dateComponents([.month], from: followDate, to: Date()).month ?? 0
        return max(0, months)
    }

    private func restoreSession() {
        appLog("Restoring session")
        guard let token = Self.loadFromKeychain(key: Self.tokenKey) ?? UserDefaults.standard.string(forKey: Self.tokenKey),
              let data = UserDefaults.standard.data(forKey: Self.userDataKey),
              let dashboard = try? JSONDecoder().decode(DashboardData.self, from: data)
        else { return }
        bearerToken = token
        // Migrate token from UserDefaults to Keychain if needed
        if Self.loadFromKeychain(key: Self.tokenKey) == nil {
            Self.saveToKeychain(key: Self.tokenKey, value: token)
            UserDefaults.standard.removeObject(forKey: Self.tokenKey) // Clean up legacy
        }
        appLog("Session restored for \(dashboard.username)")
        Task {
            await PushNotificationService.shared.requestPermissionAndRegister()
            await PushNotificationService.shared.reregisterIfNeeded()
            await fetchNotificationPermissions()
        }
        applyDashboard(dashboard)
        updateWidgetData(dashboard: dashboard)
        if let urlString = UserDefaults.standard.string(forKey: Self.avatarKey) {
            avatarURL = URL(string: urlString)
        }
        if let statusData = UserDefaults.standard.data(forKey: Self.statusKey),
           let status = try? JSONDecoder().decode(UserStatus.self, from: statusData) {
            appLog("User status: role=\(status.userRole) follows=\(status.follows) sub=\(status.subscribed)")
            follows = status.follows
            subscribed = status.subscribed
            subTier = status.subTier
            userRole = status.userRole
            isModerator = (status.isModerator ?? false) || UserDefaults.standard.bool(forKey: "app_reviewer_is_mod")
            isSubGifter = status.isSubGifter ?? false
            isBitsSender = status.isBitsSender ?? false
            if let fa = status.followedAt { followedAt = fa }
        }
        isLoggedIn = true
        GiveawayWebSocketManager.shared.connect(token: token, username: dashboard.username)
    }
}
