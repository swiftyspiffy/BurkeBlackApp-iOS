import SwiftUI

struct ContentView: View {
    init() {
        let tabFont = PirateTheme.uiFont(size: 11)
        UITabBarItem.appearance().setTitleTextAttributes([.font: tabFont], for: .normal)
        UITabBarItem.appearance().setTitleTextAttributes([.font: tabFont], for: .selected)
    }

    enum Tab: Int {
        case helm, crew, tidings, ports, rigging
    }

    @State private var selectedTab: Tab = .helm
    @StateObject private var streamDeck = StreamDeckViewModel()
    @StateObject private var captains = CaptainsViewModel(api: CaptainsAPI(), store: LocalCaptainsStore(), socket: CaptainsSocket(), popups: .shared)
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var deepLink = DeepLinkManager.shared
    @StateObject private var giveawayWS = GiveawayWebSocketManager.shared
    @ObservedObject private var popups = EventPopupCoordinator.shared
    @ObservedObject private var pushService = PushNotificationService.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                HomeView(viewModel: streamDeck)
                    .tabItem {
                        Label("Helm", systemImage: "house.fill")
                    }
                    .tag(Tab.helm)

                CrewView()
                    .tabItem {
                        Label("Crew", systemImage: "person.3.fill")
                    }
                    .tag(Tab.crew)

                TidingsView(deepLinkArticleId: $deepLink.pendingArticleId)
                    .tabItem {
                        Label("Tidings", systemImage: "scroll.fill")
                    }
                    .tag(Tab.tidings)

                SocialsView(streamDeck: streamDeck)
                    .tabItem {
                        Label("Ports", systemImage: "sailboat.fill")
                    }
                    .tag(Tab.ports)

                RiggingView()
                    .tabItem {
                        Label("Rigging", systemImage: "gearshape.fill")
                    }
                    .tag(Tab.rigging)
            }
            .tint(PirateTheme.accentColor)
            .onChange(of: selectedTab) { _, newTab in
                appLog("ContentView: tab switched to \(newTab)")
            }
            .onAppear {
                captains.setSession(AccountViewModel.captainSession())
                captains.setPopupsEnabled(settings.captainsPopupsEnabled)
                captains.start()
                // Connect WebSocket passively for giveaway events
                appLog("ContentView: appeared, connecting giveaway WS")
                if !giveawayWS.isConnected {
                    giveawayWS.connectPassive()
                }
                // Refresh push notification token on every launch
                Task {
                    await pushService.refreshTokenRegistration()
                }
            }
            .task {
                await AccountViewModel.recoverCaptainIdentity()
                await streamDeck.loadIfNeeded()

                while !Task.isCancelled {
                    do {
                        try await Task.sleep(for: .seconds(60))
                    } catch {
                        break
                    }
                    await streamDeck.refresh()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    captains.setSession(AccountViewModel.captainSession())
                    captains.start()
                    giveawayWS.reconnectIfNeeded()
                    // Refresh push token when returning to foreground
                    Task {
                        await AccountViewModel.recoverCaptainIdentity()
                        await streamDeck.refresh()
                        await pushService.refreshTokenRegistration()
                    }
                } else if phase == .background {
                    captains.stop()
                }
            }

            .onOpenURL { url in
                appLog("DeepLink: received via onOpenURL")
                deepLink.handleURL(url)
            }

            .onChange(of: deepLink.navigateToTidings) { _, shouldNavigate in
                if shouldNavigate {
                    selectedTab = .tidings
                    deepLink.navigateToTidings = false
                }
            }

            .onChange(of: deepLink.navigateToAccount) { _, shouldNavigate in
                if shouldNavigate {
                    selectedTab = .helm
                }
            }

            EventPopupHost()

            if pushService.showPiratePrompt {
                PushPromptView(pushService: pushService)
            }
        }
        .environmentObject(captains)
        .onReceive(NotificationCenter.default.publisher(for: AccountViewModel.sessionDidChange)) { _ in
            captains.setSession(AccountViewModel.captainSession())
        }
        .onChange(of: settings.captainsPopupsEnabled) { _, enabled in
            captains.setPopupsEnabled(enabled)
        }
        .fullScreenCover(isPresented: Binding(
            get: { popups.expanded == .captains },
            set: { if !$0 { popups.minimize(.captains) } }
        )) {
            NavigationStack { CaptainsView() }
                .overlay { EventPopupHost(includeCaptains: false) }
                .environmentObject(captains)
                .tint(PirateTheme.accentColor)
        }
        .preferredColorScheme(.dark)
    }

}

#Preview {
    ContentView()
}
