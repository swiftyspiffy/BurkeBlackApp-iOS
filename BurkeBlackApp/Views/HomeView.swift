import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: StreamDeckViewModel
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var deepLink = DeepLinkManager.shared
    @State private var showAccount = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    HelmHeader(isLoading: viewModel.isLoading)

                    HStack(spacing: 10) {
                        ForEach(viewModel.channels) { channel in
                            ChannelSelectorCard(
                                channel: channel,
                                isSelected: viewModel.selectedChannel.key == channel.key
                            ) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.select(channel)
                                }
                            }
                        }
                    }

                    StreamHeroCard(
                        channel: viewModel.selectedChannel,
                        allChannelsOffline: viewModel.allChannelsOffline,
                        refreshID: viewModel.fetchedAt
                    )

                    if viewModel.isStale {
                        StatusNotice(
                            icon: "clock.arrow.circlepath",
                            text: "Showing the latest saved Twitch status."
                        )
                    } else if viewModel.error != nil, viewModel.fetchedAt == nil {
                        StatusNotice(
                            icon: "wifi.exclamationmark",
                            text: "Twitch status is temporarily unavailable."
                        )
                    }

                    Button { showAccount = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "person.bust")
                            Text("Captain's Quarters")
                                .font(PirateTheme.font(size: 19))
                        }
                        .foregroundStyle(PirateTheme.accentColor)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(PirateTheme.accentColor.opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(PirateTheme.accentColor.opacity(0.55), lineWidth: 1)
                        )
                    }
                    .padding(.bottom, 18)
                }
                .frame(maxWidth: 720)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
            }
            .background(HelmBackground())
            .navigationBarHidden(true)
            .refreshable {
                await viewModel.refresh()
            }
            .fullScreenCover(isPresented: $showAccount) {
                NavigationStack {
                    AccountView()
                        .navigationTitle("Captain's Quarters")
                        .navigationBarTitleDisplayMode(.inline)
                        .navigationBarHidden(false)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { showAccount = false }
                            }
                        }
                }
            }
            .onChange(of: deepLink.navigateToAccount) { _, shouldNavigate in
                if shouldNavigate {
                    showAccount = true
                    deepLink.navigateToAccount = false
                }
            }
            .task {
                await viewModel.loadIfNeeded()
            }
            .onAppear {
                appLog("Helm: view appeared")
            }
        }
    }
}

private struct HelmHeader: View {
    let isLoading: Bool

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 12) {
                headerLine
                Text("Helm")
                    .font(PirateTheme.font(size: 38))
                    .foregroundStyle(.white)
                headerLine
                    .scaleEffect(x: -1)
            }

            HStack(spacing: 7) {
                Rectangle()
                    .fill(PirateTheme.accentColor.opacity(0.45))
                    .frame(width: 50, height: 1)
                Image(systemName: "house.fill")
                    .font(.caption)
                    .foregroundStyle(PirateTheme.accentColor)
                Rectangle()
                    .fill(PirateTheme.accentColor.opacity(0.45))
                    .frame(width: 50, height: 1)
            }
            .overlay(alignment: .trailing) {
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(PirateTheme.accentColor)
                        .offset(x: 34)
                }
            }
        }
        .padding(.top, 18)
    }

    private var headerLine: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, PirateTheme.accentColor.opacity(0.7)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(maxWidth: 72, maxHeight: 1)
    }
}

private struct ChannelSelectorCard: View {
    let channel: StreamDeckChannel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 9) {
                ChannelProfileImage(channel: channel, size: 58)

                Text(channel.cardName)
                    .font(PirateTheme.font(size: 18))
                    .foregroundStyle(isSelected ? PirateTheme.accentColor : .white.opacity(0.78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                HStack(spacing: 6) {
                    Circle()
                        .fill(channel.isLive ? Color.red : Color.gray.opacity(0.65))
                        .frame(width: 9, height: 9)
                    Text(channel.isLive ? "Live" : "Offline")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(channel.isLive ? .white : .white.opacity(0.55))
                }

                if channel.key == .main, !channel.isLive {
                    MainStreamCountdownLabel(compact: true)
                        .frame(height: 15)
                } else {
                    Color.clear.frame(height: 15)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 166)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isSelected ? 0.09 : 0.055),
                                    Color.white.opacity(0.025),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    PirateCardTexture(intensity: isSelected ? 0.1 : 0.06)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected
                            ? PirateTheme.accentColor
                            : Color.white.opacity(0.22),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(
                color: isSelected ? PirateTheme.accentColor.opacity(0.22) : .clear,
                radius: 10
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(channel.cardName), \(channel.isLive ? "live" : "offline")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct ChannelProfileImage: View {
    let channel: StreamDeckChannel
    let size: CGFloat

    var body: some View {
        Group {
            if let profileImageUrl = channel.profileImageUrl,
               let url = URL(string: profileImageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        fallbackImage
                    }
                }
            } else {
                fallbackImage
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(PirateTheme.accentColor.opacity(0.7), lineWidth: 1)
        )
        .accessibilityHidden(true)
    }

    private var fallbackImage: some View {
        Image("burkeblack_profile")
            .resizable()
            .scaledToFill()
    }
}

private struct StreamHeroCard: View {
    let channel: StreamDeckChannel
    let allChannelsOffline: Bool
    let refreshID: String?

    var body: some View {
        VStack(spacing: 0) {
            if channel.isLive {
                livePreview
                liveDetails
            } else {
                offlineDetails
            }
        }
        .background(
            ZStack {
                Color.black.opacity(0.74)
                PirateCardTexture()
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(PirateTheme.accentColor.opacity(0.85), lineWidth: 1.5)
        )
        .shadow(color: PirateTheme.accentColor.opacity(0.12), radius: 14)
    }

    private var livePreview: some View {
        Link(destination: channelURL) {
            ZStack {
                StreamThumbnail(
                    urlString: channel.thumbnailUrl,
                    refreshID: refreshID
                )

                LinearGradient(
                    colors: [.black.opacity(0.12), .clear, .black.opacity(0.35)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Image(systemName: "play.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 76, height: 76)
                    .background(.black.opacity(0.68))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(PirateTheme.accentColor, lineWidth: 2)
                    )

                if let gameName = channel.gameName, !gameName.isEmpty {
                    MetadataBadge(
                        icon: "gamecontroller.fill",
                        text: gameName
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(12)
                }

                if let viewerCount = channel.viewerCount {
                    MetadataBadge(
                        icon: "eye.fill",
                        text: "\(StatFormatter.integer(viewerCount)) viewers"
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(12)
                }
            }
            .aspectRatio(16 / 9, contentMode: .fit)
        }
        .buttonStyle(.plain)
    }

    private var liveDetails: some View {
        VStack(spacing: 13) {
            Text(channel.heroTitle)
                .font(PirateTheme.font(size: 29))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            if channel.key == .classics {
                Text("Classic BurkeBlack playthroughs, always on.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.58))
                    .multilineTextAlignment(.center)
            }

            Link(destination: channelURL) {
                WatchButtonLabel(title: channel.watchButtonTitle, enabled: true)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
    }

    private var offlineDetails: some View {
        VStack(spacing: 15) {
            ChannelProfileImage(channel: channel, size: 126)
                .shadow(color: PirateTheme.accentColor.opacity(0.24), radius: 20)

            Text(offlineTitle)
                .font(PirateTheme.font(size: 31))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            if channel.key == .main {
                MainStreamCountdownLabel(compact: false)
            } else {
                Text("This channel is currently offline.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
            }

            WatchButtonLabel(title: "Currently Offline", enabled: false)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 30)
        .background(
            RadialGradient(
                colors: [
                    PirateTheme.accentColor.opacity(0.13),
                    Color.black.opacity(0.18),
                ],
                center: .top,
                startRadius: 10,
                endRadius: 330
            )
        )
    }

    private var offlineTitle: String {
        if allChannelsOffline, channel.key == .main {
            return "All Channels Offline"
        }
        return "\(channel.cardName) is Offline"
    }

    private var channelURL: URL {
        URL(string: channel.twitchUrl)
            ?? URL(string: "https://www.twitch.tv/\(channel.login)")!
    }
}

private struct StreamThumbnail: View {
    let urlString: String?
    let refreshID: String?

    var body: some View {
        GeometryReader { proxy in
            AsyncImage(url: refreshedURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    ZStack {
                        Color.white.opacity(0.05)
                        Image("burkeblack_profile")
                            .resizable()
                            .scaledToFit()
                            .frame(width: min(proxy.size.width, proxy.size.height) * 0.5)
                            .opacity(0.5)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
    }

    private var refreshedURL: URL? {
        guard let urlString,
              var components = URLComponents(string: urlString)
        else {
            return nil
        }

        if let refreshID {
            var queryItems = components.queryItems ?? []
            queryItems.append(URLQueryItem(name: "refresh", value: refreshID))
            components.queryItems = queryItems
        }
        return components.url
    }
}

private struct MetadataBadge: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(.black.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct WatchButtonLabel: View {
    let title: String
    let enabled: Bool

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: enabled ? "play.fill" : "moon.fill")
            Text(title)
                .font(PirateTheme.font(size: 19))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(enabled ? .black : .white.opacity(0.42))
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(
            enabled
                ? PirateTheme.accentColor
                : Color.white.opacity(0.07)
        )
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(
                    enabled
                        ? PirateTheme.accentColor
                        : Color.white.opacity(0.12),
                    lineWidth: 1
                )
        )
        .accessibilityLabel(title)
    }
}

private struct StatusNotice: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption)
            .foregroundStyle(.white.opacity(0.48))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.045))
            .clipShape(Capsule())
    }
}

private struct HelmBackground: View {
    var body: some View {
        ZStack {
            Color.black
            RadialGradient(
                colors: [
                    PirateTheme.accentColor.opacity(0.08),
                    .clear,
                ],
                center: .top,
                startRadius: 20,
                endRadius: 520
            )
        }
        .ignoresSafeArea()
    }
}

struct MainStreamCountdownLabel: View {
    let compact: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: compact ? 30 : 1)) { context in
            if let text = MainStreamSchedule.countdownText(
                from: context.date,
                includesSeconds: !compact
            ) {
                Text(compact ? "Next in \(text)" : "The next voyage begins in \(text).")
                    .font(compact ? .caption2 : .subheadline)
                    .foregroundStyle(.white.opacity(compact ? 0.42 : 0.58))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }
}

enum MainStreamSchedule {
    private static let eastern = TimeZone(identifier: "America/New_York")!

    static func nextStream(after now: Date) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = eastern
        let today = calendar.startOfDay(for: now)

        for dayOffset in 0..<8 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today),
                  calendar.component(.weekday, from: day) != 1,
                  let stream = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: day),
                  stream > now
            else {
                continue
            }
            return stream
        }
        return nil
    }

    static func countdownText(from now: Date, includesSeconds: Bool) -> String? {
        guard let nextStream = nextStream(after: now) else { return nil }
        let remaining = max(0, Int(nextStream.timeIntervalSince(now)))
        let hours = remaining / 3_600
        let minutes = (remaining % 3_600) / 60
        let seconds = remaining % 60

        if includesSeconds {
            return String(format: "%dh %02dm %02ds", hours, minutes, seconds)
        }
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        }
        return String(format: "%dm", minutes)
    }
}

#Preview {
    HomeView(viewModel: StreamDeckViewModel())
}
