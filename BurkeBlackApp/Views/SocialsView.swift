import SwiftUI

struct SocialsView: View {
    @ObservedObject var streamDeck: StreamDeckViewModel
    @ObservedObject private var settings = AppSettings.shared
    @StateObject private var viewModel = SocialsViewModel()

    let socials: [SocialLink] = [
        SocialLink(name: "Twitch", icon: "twitch_icon", isCustomIcon: true, url: "https://twitch.tv/burkeblack", color: .purple),
        SocialLink(name: "Twitter / X", icon: "x_icon", isCustomIcon: true, url: "https://twitter.com/burkeblack", color: .primary),
        SocialLink(name: "YouTube", icon: "play.rectangle.fill", isCustomIcon: false, url: "https://youtube.com/burkeblack", color: .red),
        SocialLink(name: "Instagram", icon: "instagram_icon", isCustomIcon: true, url: "https://instagram.com/burkeblack", color: .pink),
        SocialLink(name: "TikTok", icon: "tiktok_icon", isCustomIcon: true, url: "https://tiktok.com/@burkeblack", color: .primary),
        SocialLink(name: "Discord", icon: "discord_icon", isCustomIcon: true, url: "https://discord.com/channels/90892452679933952/973441118203166780", color: .indigo),
        SocialLink(name: "Website", icon: "globe", isCustomIcon: false, url: "https://burkeblack.tv", color: .green),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    PiratePageHeader(
                        title: "Ports",
                        icon: "sailboat.fill",
                        subtitle: "Watch, follow, and explore the Captain’s channels."
                    )

                    ClassicsFeatureCard(
                        channel: streamDeck.channel(for: .classics)
                            ?? StreamDeckChannel.placeholder(for: .classics),
                        refreshID: streamDeck.fetchedAt
                    )
                    .padding(.horizontal, 16)

                    // YouTube Videos
                    if !viewModel.youtubeVideos.isEmpty {
                        SectionDividerHeader(title: "Latest YouTube Videos")
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 14) {
                                ForEach(viewModel.youtubeVideos) { video in
                                    YouTubeVideoCard(video: video)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    // YouTube Shorts
                    if !viewModel.youtubeShorts.isEmpty {
                        SectionDividerHeader(title: "Latest YouTube Shorts")
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 12) {
                                ForEach(viewModel.youtubeShorts) { short in
                                    YouTubeShortsCard(video: short)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    // TikToks
                    if !viewModel.tiktokVideos.isEmpty {
                        SectionDividerHeader(title: "Latest TikToks")
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 12) {
                                ForEach(viewModel.tiktokVideos) { tiktok in
                                    TikTokCard(video: tiktok)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    // X / Twitter Posts
                    if !viewModel.twitterPosts.isEmpty {
                        SectionDividerHeader(title: "Latest Posts on X")
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 14) {
                                ForEach(viewModel.twitterPosts) { post in
                                    TwitterPostCard(post: post)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    // Follow the Captain
                    SectionDividerHeader(title: "Follow the Captain")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(socials) { social in
                                Link(destination: URL(string: social.url)!) {
                                    VStack(spacing: 8) {
                                        ZStack {
                                            if social.isCustomIcon {
                                                let needsWhite = social.icon == "x_icon" || social.icon == "tiktok_icon"
                                                Image(social.icon)
                                                    .resizable()
                                                    .renderingMode(needsWhite ? .template : .original)
                                                    .scaledToFit()
                                                    .frame(width: 36, height: 36)
                                                    .foregroundStyle(needsWhite ? .white : .primary)
                                            } else {
                                                Image(systemName: social.icon)
                                                    .font(.title)
                                                    .foregroundStyle(social.color)
                                            }
                                        }
                                        .frame(width: 72, height: 72)
                                        .pirateCardSurface(
                                            cornerRadius: 18,
                                            textureIntensity: 0.025
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18)
                                                .stroke(social.color.opacity(0.35), lineWidth: 1.5)
                                        )
                                        .shadow(color: social.color.opacity(0.12), radius: 8, y: 3)

                                        Text(social.name)
                                            .font(PirateTheme.font(size: 13))
                                            .foregroundStyle(.white.opacity(0.6))
                                    }
                                    .frame(width: 80)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    Spacer().frame(height: 16)
                }
            }
            .background(PirateScreenBackground())
            .navigationBarHidden(true)
            .refreshable {
                async let socials: Void = viewModel.loadAll()
                async let streams: Void = streamDeck.refresh()
                _ = await (socials, streams)
            }
            .task {
                if viewModel.youtubeVideos.isEmpty {
                    await viewModel.loadAll()
                }
                await streamDeck.loadIfNeeded()
            }
            .onAppear { appLog("Socials: view appeared") }
        }
    }
}

// MARK: - 24/7 Classics

private struct ClassicsFeatureCard: View {
    let channel: StreamDeckChannel
    let refreshID: String?

    var body: some View {
        VStack(spacing: 0) {
            Link(destination: channelURL) {
                ZStack {
                    if channel.isLive {
                        ClassicsThumbnail(
                            urlString: channel.thumbnailUrl,
                            refreshID: refreshID
                        )
                    } else {
                        ZStack {
                            Color.white.opacity(0.035)
                            RadialGradient(
                                colors: [
                                    PirateTheme.accentColor.opacity(0.18),
                                    .clear,
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 230
                            )
                            ChannelProfileImage(channel: channel, size: 112)
                        }
                    }

                    LinearGradient(
                        colors: [.black.opacity(0.12), .clear, .black.opacity(0.42)],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    HStack(spacing: 6) {
                        Circle()
                            .fill(channel.isLive ? Color.white : Color.gray.opacity(0.7))
                            .frame(width: 8, height: 8)
                        Text(channel.isLive ? "LIVE" : "OFFLINE")
                            .font(.caption)
                            .fontWeight(.black)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(channel.isLive ? Color.red : Color.black.opacity(0.68))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(12)
                }
                .aspectRatio(16 / 9, contentMode: .fit)
            }
            .buttonStyle(.plain)

            HStack(alignment: .top, spacing: 14) {
                ChannelProfileImage(channel: channel, size: 68)

                VStack(alignment: .leading, spacing: 7) {
                    Text("The 24/7 Archive")
                        .font(PirateTheme.font(size: 25))
                        .foregroundStyle(.white)

                    Text("Classic BurkeBlack playthroughs, always on.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.58))
                        .fixedSize(horizontal: false, vertical: true)

                    Link(destination: channelURL) {
                        HStack(spacing: 8) {
                            Image("twitch_icon")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                            Text("Watch on Twitch")
                                .font(PirateTheme.font(size: 17))
                        }
                        .foregroundStyle(PirateTheme.accentColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(PirateTheme.accentColor.opacity(0.11))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(PirateTheme.accentColor.opacity(0.5), lineWidth: 1)
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
        }
        .background(
            ZStack {
                Color.black.opacity(0.7)
                PirateCardTexture()
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(PirateTheme.accentColor.opacity(0.75), lineWidth: 1.25)
        )
    }

    private var channelURL: URL {
        URL(string: channel.twitchUrl)
            ?? URL(string: "https://www.twitch.tv/burkeblack247")!
    }
}

private struct ClassicsThumbnail: View {
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
                        Color.white.opacity(0.04)
                        Image("burkeblack_profile")
                            .resizable()
                            .scaledToFit()
                            .frame(width: min(proxy.size.width, proxy.size.height) * 0.55)
                            .opacity(0.55)
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

// MARK: - Section Divider Header (centered text with lines)

private struct SectionDividerHeader: View {
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            line
            Text(title)
                .font(PirateTheme.font(size: 18))
                .foregroundStyle(PirateTheme.accentColor)
                .layoutPriority(1)
            line
        }
        .padding(.horizontal, 16)
    }

    private var line: some View {
        Rectangle()
            .fill(PirateTheme.accentColor.opacity(0.3))
            .frame(height: 1)
    }
}

// MARK: - YouTube Video Card (Landscape, 260pt, 16:9)

private struct YouTubeVideoCard: View {
    let video: YouTubeItem

    var body: some View {
        Link(destination: URL(string: video.url) ?? URL(string: "https://youtube.com")!) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: URL(string: video.thumbnailUrl)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle().fill(Color.white.opacity(0.1))
                    }
                    .frame(width: 260, height: 146)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    )

                    // Play icon
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(PirateTheme.accentColor)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // View count badge
                    if video.views > 0 {
                        Text(SocialsViewModel.formatViewCount(video.views))
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.7))
                            .clipShape(Capsule())
                            .padding(8)
                    }
                }

                Text(video.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .frame(width: 260, alignment: .leading)

                if !video.uploadedAt.isEmpty {
                    Text(SocialsViewModel.relativeDate(video.uploadedAt))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(width: 260)
            .padding(8)
            .pirateCardSurface(cornerRadius: 14, textureIntensity: 0.025)
        }
        .buttonStyle(PiratePressButtonStyle())
    }
}

// MARK: - YouTube Shorts Card (Portrait, 130pt, 9:16)

private struct YouTubeShortsCard: View {
    let video: YouTubeItem

    var body: some View {
        Link(destination: URL(string: video.url) ?? URL(string: "https://youtube.com")!) {
            ZStack(alignment: .bottom) {
                AsyncImage(url: URL(string: video.thumbnailUrl)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color.white.opacity(0.1))
                }
                .frame(width: 130, height: 231)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                LinearGradient(colors: [.clear, .black.opacity(0.9)], startPoint: .center, endPoint: .bottom)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(PirateTheme.accentColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    if video.views > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 9))
                            Text(SocialsViewModel.formatViewCount(video.views))
                                .font(.caption2)
                        }
                        .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(8)
                .frame(width: 130, alignment: .leading)
            }
            .frame(width: 130, height: 231)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(PirateTheme.accentColor.opacity(0.24), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.28), radius: 7, y: 3)
        }
        .buttonStyle(PiratePressButtonStyle())
    }
}

// MARK: - TikTok Card (Portrait, 150pt, 3:4)

private struct TikTokCard: View {
    let video: TikTokItem

    var body: some View {
        Link(destination: URL(string: video.url) ?? URL(string: "https://tiktok.com")!) {
            ZStack(alignment: .bottom) {
                AsyncImage(url: URL(string: video.coverImageUrl)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color.white.opacity(0.1))
                }
                .frame(width: 150, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                LinearGradient(colors: [.clear, .black.opacity(0.9)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .frame(maxHeight: .infinity, alignment: .bottom)

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(PirateTheme.accentColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if video.duration > 0 {
                    Text(SocialsViewModel.formatDuration(video.duration))
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Capsule())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(8)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        HStack(spacing: 3) {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 9))
                            Text(SocialsViewModel.formatViewCount(video.viewCount))
                                .font(.caption2)
                        }
                        HStack(spacing: 3) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 9))
                            Text(SocialsViewModel.formatViewCount(video.likeCount))
                                .font(.caption2)
                        }
                    }
                    .foregroundStyle(.white.opacity(0.7))
                }
                .padding(8)
                .frame(width: 150, alignment: .leading)
            }
            .frame(width: 150, height: 200)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(PirateTheme.accentColor.opacity(0.24), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.28), radius: 7, y: 3)
        }
        .buttonStyle(PiratePressButtonStyle())
    }
}

// MARK: - Twitter Post Card (280pt)

private struct TwitterPostCard: View {
    let post: TwitterPost

    var body: some View {
        Link(destination: URL(string: post.url) ?? URL(string: "https://x.com")!) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    AsyncImage(url: URL(string: post.authorProfileImageUrl)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle().fill(Color.white.opacity(0.1))
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 1) {
                        Text(post.authorName)
                            .font(PirateTheme.font(size: 14))
                            .foregroundStyle(.white)
                            .fontWeight(.bold)
                        Text("@\(post.authorUsername)")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Spacer()

                    Image("x_icon")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(.white.opacity(0.5))
                }

                Text(post.text)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)

                if let firstMedia = post.mediaUrls.first, !firstMedia.isEmpty {
                    AsyncImage(url: URL(string: firstMedia)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle().fill(Color.white.opacity(0.1))
                    }
                    .frame(width: 248, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                HStack(spacing: 14) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart")
                            .font(.system(size: 11))
                        Text(SocialsViewModel.formatViewCount(post.likeCount))
                            .font(.caption2)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.2.squarepath")
                            .font(.system(size: 11))
                        Text(SocialsViewModel.formatViewCount(post.retweetCount))
                            .font(.caption2)
                    }
                    Spacer()
                    if !post.publishedAt.isEmpty {
                        Text(SocialsViewModel.relativeDate(post.publishedAt))
                            .font(.caption2)
                    }
                }
                .foregroundStyle(.white.opacity(0.5))
            }
            .padding(16)
            .frame(width: 280)
            .pirateCardSurface(cornerRadius: 14, textureIntensity: 0.025)
        }
        .buttonStyle(PiratePressButtonStyle())
    }
}

#Preview {
    SocialsView(streamDeck: StreamDeckViewModel())
}
