import SwiftUI
import SafariServices

struct CrewView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var showClipVoting = false
    @State private var showCommunityServers = false
    @State private var safariURL: URL?
    @State private var showStudio = false
    @State private var showFaq = false
    @State private var showEmotes = false
    @State private var showLateShift = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    PiratePageHeader(
                        title: "The Crew",
                        icon: "person.3.fill",
                        subtitle: "Gather, explore, and sail with the community."
                    )

                    // Monthly Twitch Clip Voting
                    CrewActionCard(
                        title: "Monthly Twitch Clip Voting",
                        subtitle: "Vote fer the finest plunder of the month",
                        icon: "trophy.fill",
                        isAssetIcon: false
                    ) {
                        appLog("Crew: opening clip voting")
                        showClipVoting = true
                    }

                    // Community Game Servers
                    CrewActionCard(
                        title: "Community Game Servers",
                        subtitle: "Join yer fellow pirates on the high seas",
                        icon: "gamecontroller.fill",
                        isAssetIcon: false
                    ) {
                        appLog("Crew: opening community servers")
                        showCommunityServers = true
                    }

                    // Captain's Studio
                    CrewActionCard(
                        title: "Captain\u{2019}s Studio",
                        subtitle: "Explore the Captain\u{2019}s creative works",
                        icon: "ic_burke_captain",
                        isAssetIcon: true
                    ) {
                        appLog("Crew: opening studio")
                        showStudio = true
                    }

                    // The Late Shift
                    CrewActionCard(
                        title: "The Late Shift",
                        subtitle: "The Late Shift Twitch stream team",
                        icon: "ic_lateshift",
                        isAssetIcon: true
                    ) {
                        appLog("Crew: opening late shift")
                        showLateShift = true
                    }

                    // Emotes, Bits, Badges & Cheermotes
                    CrewActionCard(
                        title: "Emotes, Bits, Badges & Cheermotes",
                        subtitle: "Browse the Captain\u{2019}s treasure chest of emotes",
                        icon: "ic_burke_emote",
                        isAssetIcon: true
                    ) {
                        appLog("Crew: opening emotes gallery")
                        showEmotes = true
                    }

                    // Information & FAQ
                    CrewActionCard(
                        title: "Information & FAQ",
                        subtitle: "Charts and maps fer the lost sailor",
                        icon: "questionmark.circle.fill",
                        isAssetIcon: false
                    ) {
                        appLog("Crew: opening FAQ")
                        showFaq = true
                    }

                    // Apply to be Moderator
                    CrewActionCard(
                        title: "Apply to be Moderator",
                        subtitle: "Defend The Dirty Skull from scallywags",
                        icon: "twitch_mod_badge",
                        isAssetIcon: true
                    ) {
                        safariURL = URL(string: "https://docs.google.com/forms/d/e/1FAIpQLSfSzrzgJLfLqXXPzVv7ejfUnV_x5abdNHd3tdV3H-Gjl7nqtg/viewform")
                    }
                }
                .frame(maxWidth: 720)
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity)
            }
            .background(PirateScreenBackground())
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showClipVoting) {
                NavigationStack {
                    ClipVotingView()
                }
            }
            .fullScreenCover(isPresented: $showCommunityServers) {
                NavigationStack {
                    CommunityServersView()
                }
            }
            .fullScreenCover(isPresented: $showStudio) {
                NavigationStack {
                    StudioView()
                }
            }
            .fullScreenCover(isPresented: $showLateShift) {
                NavigationStack {
                    LateShiftView()
                }
            }
            .fullScreenCover(isPresented: $showEmotes) {
                NavigationStack {
                    EmotesGalleryView()
                }
            }
            .fullScreenCover(isPresented: $showFaq) {
                NavigationStack {
                    FaqView()
                }
            }
            .sheet(item: $safariURL) { url in
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
    }
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

// MARK: - Action Card

private struct CrewActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let isAssetIcon: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                if isAssetIcon {
                    Image(icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 38, height: 38)
                        .frame(width: 52, height: 52)
                        .background(PirateTheme.iconBgColor.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(PirateTheme.accentColor.opacity(0.16), lineWidth: 1)
                        )
                } else {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(PirateTheme.accentColor)
                        .frame(width: 52, height: 52)
                        .background(PirateTheme.iconBgColor.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(PirateTheme.accentColor.opacity(0.16), lineWidth: 1)
                        )
                }

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(PirateTheme.font(size: 18))
                        .foregroundStyle(PirateTheme.accentColor)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.52))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(PirateTheme.accentColor.opacity(0.72))
                    .font(.caption)
                    .frame(width: 28, height: 28)
                    .background(PirateTheme.accentColor.opacity(0.08))
                    .clipShape(Circle())
            }
            .padding(18)
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .pirateCardSurface()
        }
        .buttonStyle(PiratePressButtonStyle())
    }
}
