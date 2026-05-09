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
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var deepLink = DeepLinkManager.shared
    @StateObject private var giveawayWS = GiveawayWebSocketManager.shared
    @ObservedObject private var pushService = PushNotificationService.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                HomeView()
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

                SocialsView()
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
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    giveawayWS.reconnectIfNeeded()
                    // Refresh push token when returning to foreground
                    Task {
                        await pushService.refreshTokenRegistration()
                    }
                }
            }

            .onOpenURL { url in
                appLog("DeepLink: received via onOpenURL \(url.absoluteString)")
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

            // Giveaway popup overlay
            GiveawayPopupView(wsManager: giveawayWS)

            // Push notification prompt
            if pushService.showPiratePrompt {
                PushPromptView(pushService: pushService)
            }

            // Mini giveaway restore button
            if giveawayWS.activeGiveaway != nil && giveawayWS.isDismissedToMini {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                giveawayWS.restoreGiveaway()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "gift.fill")
                                    .font(.caption)
                                Text("Giveaway")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(PirateTheme.accentColor)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.3), radius: 4)
                        }
                        .padding(.trailing, 16)
                    }
                    Spacer()
                }
                .padding(.top, 60)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

}

#Preview {
    ContentView()
}
