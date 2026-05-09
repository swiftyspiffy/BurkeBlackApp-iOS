import SwiftUI


struct ScrollsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var showStudio = false
    @State private var showFaq = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Studio - top half
                Button { showStudio = true } label: {
                    ZStack {
                        Image("bg_studio")
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()

                        // Darken + fade overlay
                        LinearGradient(
                            colors: [.black.opacity(0.5), .black.opacity(0.3), .black.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )

                        Text("Captain\u{2019}s Studio")
                            .font(PirateTheme.font(size: 34))
                            .foregroundStyle(PirateTheme.accentColor)
                            .shadow(color: .black.opacity(0.8), radius: 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.plain)

                // FAQ - bottom half
                Button { showFaq = true } label: {
                    ZStack {
                        Image("bg_faq")
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()

                        // Darken + fade overlay
                        LinearGradient(
                            colors: [.black.opacity(0.35), .black.opacity(0.15), .black.opacity(0.35)],
                            startPoint: .top,
                            endPoint: .bottom
                        )

                        Text("Information & FAQ")
                            .font(PirateTheme.font(size: 34))
                            .foregroundStyle(PirateTheme.accentColor)
                            .shadow(color: .black.opacity(0.8), radius: 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.plain)
            }
            .onAppear { appLog("Scrolls: view appeared") }
            .ignoresSafeArea()
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showStudio) {
                NavigationStack {
                    StudioView()
                }
            }
            .fullScreenCover(isPresented: $showFaq) {
                NavigationStack {
                    FaqView()
                }
            }
        }
    }
}
