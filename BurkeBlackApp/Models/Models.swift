import Foundation
import SwiftUI

// MARK: - Stream Info
struct StreamInfo: Codable, Identifiable {
    let id: String
    let title: String
    let game: String
    let viewerCount: Int
    let startedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, game
        case viewerCount = "viewer_count"
        case startedAt = "started_at"
    }
}

// MARK: - Announcements
struct Announcement: Codable, Identifiable {
    let id: String
    let title: String
    let body: String
    let date: Date
}

// MARK: - Channel Stats
struct ChannelStats: Codable {
    let followers: Int
    let subscribers: Int

    var formattedFollowers: String {
        formatNumber(followers)
    }

    var formattedSubscribers: String {
        formatNumber(subscribers)
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 {
            return String(format: "%.1fM", Double(n) / 1_000_000)
        } else if n >= 1_000 {
            return String(format: "%.1fK", Double(n) / 1_000)
        }
        return "\(n)"
    }
}

// MARK: - Schedule
struct ScheduleItem: Codable, Identifiable {
    let id: String
    let title: String
    let startTime: Date
    let endTime: Date?
    let game: String?

    enum CodingKeys: String, CodingKey {
        case id, title, game
        case startTime = "start_time"
        case endTime = "end_time"
    }
}

// MARK: - Social Links
struct SocialLink: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let isCustomIcon: Bool
    let url: String
    let color: Color
}

// MARK: - API Response Wrapper
struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let error: String?
}

// MARK: - Home Data
struct HomeData: Codable {
    let isLive: Bool
    let stream: StreamInfo?
    let announcements: [Announcement]
    let stats: ChannelStats?

    enum CodingKeys: String, CodingKey {
        case isLive = "is_live"
        case stream, announcements, stats
    }
}

// MARK: - Profile Data
struct ProfileData: Codable {
    let displayName: String
    let bio: String?
    let avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case bio
        case avatarURL = "avatar_url"
    }
}

// MARK: - User Account Data
struct UserAccountData: Codable {
    let displayName: String
    let avatarURL: String?
    let followDate: String?
    let subTier: String?
    let subStreak: String?
    let watchTime: String?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case followDate = "follow_date"
        case subTier = "sub_tier"
        case subStreak = "sub_streak"
        case watchTime = "watch_time"
    }
}

// MARK: - Clip Voting

struct ClipVotingConfig: Codable {
    let votingMode: String
    let multiType: String?
    let voteCount: Int
    let clipCount: Int
    let showViewCounts: Bool
    let showPoints: Bool
    let showVoteCounts: Bool

    enum CodingKeys: String, CodingKey {
        case votingMode = "voting_mode"
        case multiType = "multi_type"
        case voteCount = "vote_count"
        case clipCount = "clip_count"
        case showViewCounts = "show_view_counts"
        case showPoints = "show_points"
        case showVoteCounts = "show_vote_counts"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        votingMode = try container.decode(String.self, forKey: .votingMode)
        multiType = try container.decodeIfPresent(String.self, forKey: .multiType)
        voteCount = try container.decodeIfPresent(Int.self, forKey: .voteCount) ?? 1
        clipCount = try container.decodeIfPresent(Int.self, forKey: .clipCount) ?? 10
        showViewCounts = try container.decodeIfPresent(Bool.self, forKey: .showViewCounts) ?? false
        showPoints = try container.decodeIfPresent(Bool.self, forKey: .showPoints) ?? false
        showVoteCounts = try container.decodeIfPresent(Bool.self, forKey: .showVoteCounts) ?? false
    }
}

struct ClipVotingResponse: Codable {
    let month: String
    let periodStart: String
    let periodEnd: String
    let clips: [VotingClip]
    let totalVoters: Int
    let authenticated: Bool
    let userHasVoted: Bool
    let config: ClipVotingConfig

    enum CodingKeys: String, CodingKey {
        case month, clips, config, authenticated
        case periodStart = "period_start"
        case periodEnd = "period_end"
        case totalVoters = "total_voters"
        case userHasVoted = "user_has_voted"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        month = try container.decode(String.self, forKey: .month)
        periodStart = try container.decode(String.self, forKey: .periodStart)
        periodEnd = try container.decode(String.self, forKey: .periodEnd)
        clips = try container.decode([VotingClip].self, forKey: .clips)
        totalVoters = try container.decodeIfPresent(Int.self, forKey: .totalVoters) ?? 0
        authenticated = try container.decodeIfPresent(Bool.self, forKey: .authenticated) ?? false
        userHasVoted = try container.decodeIfPresent(Bool.self, forKey: .userHasVoted) ?? false
        config = try container.decode(ClipVotingConfig.self, forKey: .config)
    }
}

struct VotingClip: Codable, Identifiable {
    var id: String { clipId }
    let clipId: String
    let title: String
    let clipUrl: String
    let embedUrl: String?
    let thumbnailUrl: String
    let creatorName: String
    let viewCount: Int
    let duration: Float
    let createdAt: String?
    let totalPoints: Int
    let voteCount: Int
    let userRank: Int?

    enum CodingKeys: String, CodingKey {
        case title, duration
        case clipId = "clip_id"
        case clipUrl = "clip_url"
        case embedUrl = "embed_url"
        case thumbnailUrl = "thumbnail_url"
        case creatorName = "creator_name"
        case viewCount = "view_count"
        case createdAt = "created_at"
        case totalPoints = "total_points"
        case voteCount = "vote_count"
        case userRank = "user_rank"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        clipId = try container.decode(String.self, forKey: .clipId)
        title = try container.decode(String.self, forKey: .title)
        clipUrl = try container.decode(String.self, forKey: .clipUrl)
        embedUrl = try container.decodeIfPresent(String.self, forKey: .embedUrl)
        thumbnailUrl = try container.decode(String.self, forKey: .thumbnailUrl)
        creatorName = try container.decode(String.self, forKey: .creatorName)
        viewCount = try container.decodeIfPresent(Int.self, forKey: .viewCount) ?? 0
        duration = try container.decodeIfPresent(Float.self, forKey: .duration) ?? 0
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        totalPoints = try container.decodeIfPresent(Int.self, forKey: .totalPoints) ?? 0
        voteCount = try container.decodeIfPresent(Int.self, forKey: .voteCount) ?? 0
        userRank = try container.decodeIfPresent(Int.self, forKey: .userRank)
    }
}

struct ClipVoteBody: Encodable {
    let rankings: [String]
}

struct ClipVoteResponse: Codable {
    let month: String
    let message: String
}

// MARK: - Community Servers

struct CommunityServersResponse: Codable {
    let servers: [CommunityServer]
    let authenticated: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        servers = try container.decode([CommunityServer].self, forKey: .servers)
        authenticated = try container.decodeIfPresent(Bool.self, forKey: .authenticated) ?? false
    }
}

struct CommunityServer: Codable, Identifiable {
    let id: Int
    let serverName: String
    let gameName: String
    let bannerUrl: String?
    let requireSub: Bool
    let requireFollow: Bool
    let requireAllowlist: Bool
    let info: String?
    let hasAccess: Bool
    let ipAddress: String?
    let password: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, info, password
        case serverName = "server_name"
        case gameName = "game_name"
        case bannerUrl = "banner_url"
        case requireSub = "require_sub"
        case requireFollow = "require_follow"
        case requireAllowlist = "require_allowlist"
        case hasAccess = "has_access"
        case ipAddress = "ip_address"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        serverName = try container.decode(String.self, forKey: .serverName)
        gameName = try container.decode(String.self, forKey: .gameName)
        bannerUrl = try container.decodeIfPresent(String.self, forKey: .bannerUrl)
        requireSub = try container.decodeIfPresent(Bool.self, forKey: .requireSub) ?? false
        requireFollow = try container.decodeIfPresent(Bool.self, forKey: .requireFollow) ?? false
        requireAllowlist = try container.decodeIfPresent(Bool.self, forKey: .requireAllowlist) ?? false
        info = try container.decodeIfPresent(String.self, forKey: .info)
        hasAccess = try container.decodeIfPresent(Bool.self, forKey: .hasAccess) ?? false
        ipAddress = try container.decodeIfPresent(String.self, forKey: .ipAddress)
        password = try container.decodeIfPresent(String.self, forKey: .password)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
    }
}

// MARK: - YouTube

struct YouTubeItem: Codable, Identifiable {
    var id: String { videoId }
    let videoId: String
    let title: String
    let thumbnailUrl: String
    let views: Int
    let type: String
    let url: String
    let uploadedAt: String

    enum CodingKeys: String, CodingKey {
        case title, views, type, url
        case videoId = "video_id"
        case thumbnailUrl = "thumbnail_url"
        case uploadedAt = "uploaded_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        videoId = try container.decode(String.self, forKey: .videoId)
        title = try container.decode(String.self, forKey: .title)
        thumbnailUrl = try container.decode(String.self, forKey: .thumbnailUrl)
        views = try container.decodeIfPresent(Int.self, forKey: .views) ?? 0
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
        url = try container.decode(String.self, forKey: .url)
        uploadedAt = try container.decodeIfPresent(String.self, forKey: .uploadedAt) ?? ""
    }
}

struct YouTubeResponse: Codable {
    let items: [YouTubeItem]
    let total: Int
    let limit: Int
    let offset: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decodeIfPresent([YouTubeItem].self, forKey: .items) ?? []
        total = try container.decodeIfPresent(Int.self, forKey: .total) ?? 0
        limit = try container.decodeIfPresent(Int.self, forKey: .limit) ?? 10
        offset = try container.decodeIfPresent(Int.self, forKey: .offset) ?? 0
    }
}

// MARK: - TikTok

struct TikTokItem: Codable, Identifiable {
    var id: String { videoId }
    let videoId: String
    let title: String
    let description: String
    let url: String
    let coverImageUrl: String
    let duration: Int
    let likeCount: Int
    let commentCount: Int
    let shareCount: Int
    let viewCount: Int
    let publishedAt: String

    enum CodingKeys: String, CodingKey {
        case title, description, url, duration
        case videoId = "video_id"
        case coverImageUrl = "cover_image_url"
        case likeCount = "like_count"
        case commentCount = "comment_count"
        case shareCount = "share_count"
        case viewCount = "view_count"
        case publishedAt = "published_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        videoId = try container.decode(String.self, forKey: .videoId)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        url = try container.decode(String.self, forKey: .url)
        coverImageUrl = try container.decodeIfPresent(String.self, forKey: .coverImageUrl) ?? ""
        duration = try container.decodeIfPresent(Int.self, forKey: .duration) ?? 0
        likeCount = try container.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
        commentCount = try container.decodeIfPresent(Int.self, forKey: .commentCount) ?? 0
        shareCount = try container.decodeIfPresent(Int.self, forKey: .shareCount) ?? 0
        viewCount = try container.decodeIfPresent(Int.self, forKey: .viewCount) ?? 0
        publishedAt = try container.decodeIfPresent(String.self, forKey: .publishedAt) ?? ""
    }
}

struct TikTokResponse: Codable {
    let items: [TikTokItem]
    let total: Int
    let limit: Int
    let offset: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decodeIfPresent([TikTokItem].self, forKey: .items) ?? []
        total = try container.decodeIfPresent(Int.self, forKey: .total) ?? 0
        limit = try container.decodeIfPresent(Int.self, forKey: .limit) ?? 20
        offset = try container.decodeIfPresent(Int.self, forKey: .offset) ?? 0
    }
}

// MARK: - Twitter / X

struct TwitterPost: Codable, Identifiable {
    var id: String { tweetId }
    let tweetId: String
    let authorUsername: String
    let authorName: String
    let authorProfileImageUrl: String
    let text: String
    let url: String
    let likeCount: Int
    let retweetCount: Int
    let replyCount: Int
    let quoteCount: Int
    let mediaUrls: [String]
    let isRetweet: Bool
    let isReply: Bool
    let isQuote: Bool
    let publishedAt: String

    enum CodingKeys: String, CodingKey {
        case text, url
        case tweetId = "tweet_id"
        case authorUsername = "author_username"
        case authorName = "author_name"
        case authorProfileImageUrl = "author_profile_image_url"
        case likeCount = "like_count"
        case retweetCount = "retweet_count"
        case replyCount = "reply_count"
        case quoteCount = "quote_count"
        case mediaUrls = "media_urls"
        case isRetweet = "is_retweet"
        case isReply = "is_reply"
        case isQuote = "is_quote"
        case publishedAt = "published_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tweetId = try container.decode(String.self, forKey: .tweetId)
        authorUsername = try container.decodeIfPresent(String.self, forKey: .authorUsername) ?? ""
        authorName = try container.decodeIfPresent(String.self, forKey: .authorName) ?? ""
        authorProfileImageUrl = try container.decodeIfPresent(String.self, forKey: .authorProfileImageUrl) ?? ""
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        url = try container.decodeIfPresent(String.self, forKey: .url) ?? ""
        likeCount = try container.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
        retweetCount = try container.decodeIfPresent(Int.self, forKey: .retweetCount) ?? 0
        replyCount = try container.decodeIfPresent(Int.self, forKey: .replyCount) ?? 0
        quoteCount = try container.decodeIfPresent(Int.self, forKey: .quoteCount) ?? 0
        mediaUrls = try container.decodeIfPresent([String].self, forKey: .mediaUrls) ?? []
        isRetweet = try container.decodeIfPresent(Bool.self, forKey: .isRetweet) ?? false
        isReply = try container.decodeIfPresent(Bool.self, forKey: .isReply) ?? false
        isQuote = try container.decodeIfPresent(Bool.self, forKey: .isQuote) ?? false
        publishedAt = try container.decodeIfPresent(String.self, forKey: .publishedAt) ?? ""
    }
}

struct TwitterResponse: Codable {
    let items: [TwitterPost]
    let total: Int
    let limit: Int
    let offset: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decodeIfPresent([TwitterPost].self, forKey: .items) ?? []
        total = try container.decodeIfPresent(Int.self, forKey: .total) ?? 0
        limit = try container.decodeIfPresent(Int.self, forKey: .limit) ?? 20
        offset = try container.decodeIfPresent(Int.self, forKey: .offset) ?? 0
    }
}

// MARK: - Overlay Images

struct OverlayCategory: Codable, Identifiable {
    let id: Int
    let name: String
}

struct OverlayImageMode: Codable {
    let width: Int
    let height: Int
    let duration: Double
    let count: Int?
}

struct OverlayImageModes: Codable {
    let large: OverlayImageMode?
    let medium: OverlayImageMode?
    let small: OverlayImageMode?
    let bounce: OverlayImageMode?
}

struct OverlayImageCredits: Codable {
    let large: Int?
    let medium: Int?
    let small: Int?
    let bounce: Int?
    let bounceMulti: Int?

    enum CodingKeys: String, CodingKey {
        case large, medium, small, bounce
        case bounceMulti = "bounce_multi"
    }
}

struct OverlayImage: Codable, Identifiable {
    let id: Int
    let name: String
    let categoryId: Int
    let thumbnailUrl: String
    let allowAll: Bool?
    let allowFollowers: Bool?
    let allowSubs: Bool?
    let allowMods: Bool?
    let modes: OverlayImageModes?
    let credits: OverlayImageCredits?

    enum CodingKeys: String, CodingKey {
        case id, name, modes, credits
        case categoryId = "category_id"
        case thumbnailUrl = "thumbnail_url"
        case allowAll = "allow_all"
        case allowFollowers = "allow_followers"
        case allowSubs = "allow_subs"
        case allowMods = "allow_mods"
    }
}

struct OverlayImagesData: Codable {
    let categories: [OverlayCategory]
    let images: [OverlayImage]
}

struct KlipyGifResult: Codable, Identifiable {
    let token: String
    let title: String
    let encryptedGifUrl: String
    let encryptedPreviewUrl: String
    let previewWidth: Int
    let previewHeight: Int

    var id: String { token }

    enum CodingKeys: String, CodingKey {
        case token, title
        case encryptedGifUrl = "encrypted_gif_url"
        case encryptedPreviewUrl = "encrypted_preview_url"
        case previewWidth = "preview_width"
        case previewHeight = "preview_height"
    }
}

struct KlipySearchData: Codable {
    let results: [KlipyGifResult]
    let hasNext: Bool
    let page: Int

    enum CodingKeys: String, CodingKey {
        case results, page
        case hasNext = "has_next"
    }
}

struct GifDecryptKeyData: Codable {
    let gifDecryptKey: String
    let expiresAt: Int

    enum CodingKeys: String, CodingKey {
        case gifDecryptKey = "gif_decrypt_key"
        case expiresAt = "expires_at"
    }
}

struct GifSettingsData: Codable {
    let enabled: Bool
    let credits: [String: Int]
}

struct OverlayTriggerBody: Encodable {
    let imageId: Int?
    let gifToken: String?
    let mode: String
    let duration: Double
    let username: String
    let source: String
    let xPercent: Double
    let yPercent: Double
    let test: Bool?

    enum CodingKeys: String, CodingKey {
        case mode, duration, username, source, test
        case imageId = "image_id"
        case gifToken = "gif_token"
        case xPercent = "x_percent"
        case yPercent = "y_percent"
    }
}

struct OverlayTriggerData: Codable {
    let message: String
    let creditsRemaining: Int

    enum CodingKeys: String, CodingKey {
        case message
        case creditsRemaining = "credits_remaining"
    }
}
