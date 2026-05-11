import SwiftUI
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in
            PushNotificationService.shared.handleDeviceToken(deviceToken)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Task { @MainActor in
            PushNotificationService.shared.handleRegistrationError(error)
        }
    }

    // Show notifications even when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        appLog("Push: received notification in foreground")
        return [.banner, .sound]
    }

    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        let content = response.notification.request.content

        // Body fallback chain: notification.body -> data["body"] -> data["message"] -> ""
        let body = !content.body.isEmpty ? content.body
            : (userInfo["body"] as? String)
            ?? (userInfo["message"] as? String)
            ?? ""
        appLog("Push: notification body resolved: \(body.prefix(50))")

        let urlValue = userInfo["url"]
        let urlString = (urlValue as? String) ?? ""
        let notifType = (userInfo["type"] as? String) ?? ""
        appLog("Push: notification tapped, url=\(urlString), type=\(notifType)")

        if !urlString.isEmpty, let url = URL(string: urlString) {
            appLog("Push: opening URL: \(urlString)")
            await MainActor.run {
                if url.scheme == "burkeblackapp" {
                    appLog("Push: routing to DeepLinkManager")
                    DeepLinkManager.shared.handleURL(url)
                } else {
                    UIApplication.shared.open(url)
                }
            }
        } else {
            appLog("Push: notification tapped (no URL in payload)")
        }
    }
}

@main
struct BurkeBlackAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appOpacity: Double = 0

    var body: some Scene {
        WindowGroup {
            ContentView()
                .opacity(appOpacity)
                .onAppear {
                    appLog("App launched")
                    AppSettings.shared.migrateIfNeeded()
                    AppSettings.shared.migrateV2IfNeeded()
                    Task { await FeatureFlagService.shared.load() }
                    withAnimation(.easeIn(duration: 0.8)) {
                        appOpacity = 1
                    }
                }
        }
    }
}
