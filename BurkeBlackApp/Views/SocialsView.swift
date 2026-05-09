import SwiftUI

struct SocialsView: View {
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
                    Text("Ports")
                        .font(PirateTheme.font(size: 28))
                        .foregroundStyle(PirateTheme.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 16)

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
                                        .background(Color.white.opacity(0.06))
                                        .clipShape(RoundedRectangle(cornerRadius: 18))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18)
                                                .stroke(social.color.opacity(0.35), lineWidth: 1.5)
                                        )

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
            .navigationBarHidden(true)
            .refreshable {
                await viewModel.loadAll()
            }
            .task {
                if viewModel.youtubeVideos.isEmpty {
                    await viewModel.loadAll()
                }
            }
            .onAppear { appLog("Socials: view appeared") }
        }
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
                    .font(PirateTheme.font(size: 14))
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
        }
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
                        .font(PirateTheme.font(size: 12))
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
        }
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
                        .font(PirateTheme.font(size: 12))
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
        }
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
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }
}

#Preview {
    SocialsView()
}
