import Foundation
import SwiftUI

@MainActor
class SocialsViewModel: ObservableObject {
    @Published var youtubeVideos: [YouTubeItem] = []
    @Published var youtubeShorts: [YouTubeItem] = []
    @Published var tiktokVideos: [TikTokItem] = []
    @Published var twitterPosts: [TwitterPost] = []
    @Published var isLoading = false

    func loadAll() async {
        isLoading = true
        defer { isLoading = false }

        async let vids = APIService.shared.fetchYouTubeVideos(limit: 10)
        async let shorts = APIService.shared.fetchYouTubeShorts(limit: 10)
        async let tiktoks = APIService.shared.fetchTikTokVideos(limit: 10)
        async let tweets = APIService.shared.fetchTwitterPosts(limit: 10)

        do { youtubeVideos = try await vids.items; appLog("Socials: loaded \(youtubeVideos.count) youtube videos") } catch { appLog("Socials: youtube videos error: \(error)") }
        do { youtubeShorts = try await shorts.items; appLog("Socials: loaded \(youtubeShorts.count) youtube shorts") } catch { appLog("Socials: youtube shorts error: \(error)") }
        do { tiktokVideos = try await tiktoks.items; appLog("Socials: loaded \(tiktokVideos.count) tiktok videos") } catch { appLog("Socials: tiktok error: \(error)") }
        do { twitterPosts = try await tweets.items; appLog("Socials: loaded \(twitterPosts.count) twitter posts") } catch { appLog("Socials: twitter error: \(error)") }
    }

    // MARK: - Formatters

    static func formatViewCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }

    static func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private static let inputDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    static func relativeDate(_ dateString: String) -> String {
        guard let date = inputDateFormatter.date(from: dateString) else { return "" }
        let now = Date()
        let interval = now.timeIntervalSince(date)

        if interval < 0 { return "Just now" }

        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)

        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        if days < 14 { return "\(days)d ago" }

        let weeks = days / 7
        if weeks < 8 { return "\(weeks)w ago" }

        let months = days / 30
        if months < 12 { return "\(months)mo ago" }

        let years = days / 365
        return "\(years)y ago"
    }
}
