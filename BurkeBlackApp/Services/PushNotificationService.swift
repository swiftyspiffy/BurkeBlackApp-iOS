import Foundation
import UserNotifications
import UIKit

@MainActor
class PushNotificationService: ObservableObject {
    static let shared = PushNotificationService()

    @Published var isRegistered = false
    @Published var permissionStatus: UNAuthorizationStatus = .notDetermined
    @Published var showPiratePrompt = false

    private let backendBaseURL = "https://api.burkeblack.tv/app"
    private var deviceToken: String?
    private let hasAskedKey = "push_has_asked_permission"

    var hasAskedBefore: Bool {
        UserDefaults.standard.bool(forKey: hasAskedKey)
    }

    private init() {}

    // MARK: - Permission & Registration

    /// Call after login. Shows pirate prompt if first time, otherwise registers directly.
    func requestPermissionAndRegister() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        permissionStatus = settings.authorizationStatus

        if settings.authorizationStatus == .authorized {
            // Already authorized, just register
            appLog("Push: already authorized, registering")
            UIApplication.shared.registerForRemoteNotifications()
            return
        }

        if settings.authorizationStatus == .denied {
            appLog("Push: previously denied, skipping")
            return
        }

        if !hasAskedBefore {
            // Show pirate prompt first
            appLog("Push: showing pirate prompt (first time)")
            showPiratePrompt = true
            // Don't proceed - the modal will call acceptPushNotifications() or declinePushNotifications()
        } else {
            appLog("Push: already asked before, skipping")
        }
    }

    /// Called when user taps "Aye!" on the pirate prompt
    func acceptPushNotifications() async {
        UserDefaults.standard.set(true, forKey: hasAskedKey)
        showPiratePrompt = false
        appLog("Push: user accepted pirate prompt, requesting system permission")

        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            appLog("Push: permission \(granted ? "granted" : "denied")")

            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }

            let settings = await center.notificationSettings()
            permissionStatus = settings.authorizationStatus
        } catch {
            appLog("Push: permission request failed: \(error.localizedDescription)")
        }
    }

    /// Called when user taps "Nay" on the pirate prompt
    func declinePushNotifications() {
        UserDefaults.standard.set(true, forKey: hasAskedKey)
        showPiratePrompt = false
        appLog("Push: user declined pirate prompt")
    }

    func checkPermissionStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        permissionStatus = settings.authorizationStatus
    }

    // MARK: - Device Token Handling

    func handleDeviceToken(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02x", $0) }.joined()
        deviceToken = token
        UserDefaults.standard.set(token, forKey: "push_device_token")
        appLog("Push: received device token (\(token.prefix(12))...)")

        Task {
            await registerTokenWithBackend(token)
        }
    }

    func handleRegistrationError(_ error: Error) {
        appLog("Push: registration failed: \(error.localizedDescription)")
    }

    // MARK: - Backend Registration

    private func registerTokenWithBackend(_ token: String) async {
        guard let bearerToken = AccountViewModel.getBearerToken() else {
            appLog("Push: skipping backend registration - not logged in")
            return
        }

        guard let url = URL(string: "\(backendBaseURL)/device-token") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        TwitchAuthService.addPlatformHeaders(&request)

        struct Body: Encodable {
            let platform: String
            let device_token: String
            let environment: String
        }
        request.httpBody = try? JSONEncoder().encode(Body(
            platform: "ios",
            device_token: token,
            environment: APNsEnvironment.current.rawValue
        ))

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if code == 200 {
                isRegistered = true
                appLog("Push: device token registered with backend")
            } else {
                appLog("Push: backend registration failed with status \(code)")
            }
        } catch {
            appLog("Push: backend registration error: \(error.localizedDescription)")
        }
    }

    func unregisterFromBackend() async {
        guard let token = deviceToken ?? UserDefaults.standard.string(forKey: "push_device_token") else { return }
        guard let bearerToken = AccountViewModel.getBearerToken() else { return }
        guard let url = URL(string: "\(backendBaseURL)/device-token") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        TwitchAuthService.addPlatformHeaders(&request)

        struct Body: Encodable { let device_token: String }
        request.httpBody = try? JSONEncoder().encode(Body(device_token: token))

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            appLog("Push: unregister response \(code)")
            isRegistered = false
        } catch {
            appLog("Push: unregister error: \(error.localizedDescription)")
        }
    }

    /// Re-register stored token after login (e.g., if token was received before login)
    func reregisterIfNeeded() async {
        if let token = deviceToken ?? UserDefaults.standard.string(forKey: "push_device_token") {
            await registerTokenWithBackend(token)
        }
    }

    /// Refresh token registration on every app launch to prevent stale tokens
    func refreshTokenRegistration() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        permissionStatus = settings.authorizationStatus

        guard settings.authorizationStatus == .authorized else {
            appLog("Push: refresh skipped - not authorized")
            return
        }

        guard AccountViewModel.getBearerToken() != nil else {
            appLog("Push: refresh skipped - not logged in")
            return
        }

        appLog("Push: refreshing token registration on launch")
        // Ask APNs for the current token (triggers handleDeviceToken delegate if token changed)
        UIApplication.shared.registerForRemoteNotifications()
        // Also re-post the stored token to backend in case it was lost server-side
        if let token = deviceToken ?? UserDefaults.standard.string(forKey: "push_device_token") {
            await registerTokenWithBackend(token)
        }
    }

    // MARK: - Preference Sync

    func syncPreferences() async {
        guard let bearerToken = AccountViewModel.getBearerToken() else { return }
        let settings = AppSettings.shared

        guard let url = URL(string: "\(backendBaseURL)/notification-preferences") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        TwitchAuthService.addPlatformHeaders(&request)

        let burkeSchedule: [String: Any] = [
            "days": Array(settings.burkeStreamDays),
            "from_hour": settings.burkeStreamFromHour,
            "from_min": settings.burkeStreamFromMinute,
            "to_hour": settings.burkeStreamToHour,
            "to_min": settings.burkeStreamToMinute,
            "all_day": settings.burkeStreamAllDay,
        ]

        let burke40kSchedule: [String: Any] = [
            "days": Array(settings.burke40kDays),
            "from_hour": settings.burke40kFromHour,
            "from_min": settings.burke40kFromMinute,
            "to_hour": settings.burke40kToHour,
            "to_min": settings.burke40kToMinute,
            "all_day": settings.burke40kAllDay,
        ]

        let body: [String: Any] = [
            "notif_burkeblack_stream": settings.burkeStreamEnabled ? 1 : 0,
            "notif_burke40k_stream": settings.burke40kEnabled ? 1 : 0,
            "notif_burke_announcements": settings.burkeAnnouncements ? 1 : 0,
            "notif_mod_announcements": settings.modAnnouncements ? 1 : 0,
            "notif_special_events": settings.specialEvents ? 1 : 0,
            "notif_channel_tidings": settings.tidings ? 1 : 0,
            "notif_youtube_videos": settings.youtubeVideos ? 1 : 0,
            "notif_youtube_shorts": settings.youtubeShorts ? 1 : 0,
            "notif_tiktok_videos": settings.tiktokVideos ? 1 : 0,
            "notif_twitter_posts": settings.twitterPosts ? 1 : 0,
            "burke_stream_schedule_json": String(data: try! JSONSerialization.data(withJSONObject: burkeSchedule), encoding: .utf8)!,
            "burke40k_stream_schedule_json": String(data: try! JSONSerialization.data(withJSONObject: burke40kSchedule), encoding: .utf8)!,
            "timezone": TimeZone.current.identifier,
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            appLog("Push: preferences synced (\(code))")
        } catch {
            appLog("Push: preference sync error: \(error.localizedDescription)")
        }
    }
}


// MARK: - Deep Link Manager

@MainActor
class DeepLinkManager: ObservableObject {
    static let shared = DeepLinkManager()

    @Published var pendingArticleId: Int? = nil
    @Published var navigateToTidings = false
    @Published var navigateToAccount = false

    private init() {}

    func handleURL(_ url: URL) {
        guard url.scheme == "burkeblackapp" else { return }

        switch url.host {
        case "tidings":
            navigateToTidings = true
            if let idStr = url.pathComponents.dropFirst().first, let articleId = Int(idStr) {
                appLog("DeepLink: opening tidings article \(articleId)")
                pendingArticleId = articleId
            } else {
                appLog("DeepLink: opening tidings tab")
            }
        case "account":
            appLog("DeepLink: opening Captain's Quarters")
            navigateToAccount = true
        default:
            appLog("DeepLink: unhandled host \(url.host ?? "nil")")
        }
    }
}


// MARK: - APNs Environment

enum APNsEnvironment: String {
    case production
    case sandbox

    /// Determined from the embedded provisioning profile when possible.
    /// `aps-environment = development` means APNs sandbox; otherwise production.
    /// Falls back to the build configuration when the profile cannot be read
    /// (e.g. simulator).
    static var current: APNsEnvironment {
        if let provisioningURL = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
           let data = try? Data(contentsOf: provisioningURL),
           let plistString = String(data: data, encoding: .ascii),
           let start = plistString.range(of: "<plist"),
           let end   = plistString.range(of: "</plist>") {
            let plist = String(plistString[start.lowerBound...end.upperBound])
            if plist.contains("<key>aps-environment</key>\n\t<string>development</string>") {
                return .sandbox
            }
            return .production
        }
        #if DEBUG
        return .sandbox
        #else
        return .production
        #endif
    }
}
