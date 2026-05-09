import WidgetKit
import SwiftUI
import UIKit

// MARK: - Widget Logger

private func widgetLog(_ message: String) {
    guard let defaults = UserDefaults(suiteName: WidgetData.appGroup) else { return }
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let entry = "[\(fmt.string(from: Date()))] \(message)"
    var logs = defaults.stringArray(forKey: "widget.logs") ?? []
    logs.append(entry)
    if logs.count > 500 { logs = Array(logs.suffix(500)) }
    defaults.set(logs, forKey: "widget.logs")
}

// MARK: - Shared Data

struct WidgetData {
    static let appGroup = "group.com.swiftyspiffy.BurkeBlackApp"

    static func load() -> CrewStats {
        guard let defaults = UserDefaults(suiteName: appGroup) else {
            return .placeholder
        }
        let doubloons = defaults.integer(forKey: "widget.doubloons")
        let soundbyteCredits = defaults.integer(forKey: "widget.soundbyteCredits")
        let followMonths = defaults.integer(forKey: "widget.followMonths")
        let subMonths = defaults.integer(forKey: "widget.subMonths")
        let isLoggedIn = defaults.bool(forKey: "widget.isLoggedIn")
        return CrewStats(
            doubloons: doubloons,
            soundbyteCredits: soundbyteCredits,
            followMonths: followMonths,
            subMonths: subMonths,
            isLoggedIn: isLoggedIn
        )
    }
}

struct CrewStats {
    let doubloons: Int
    let soundbyteCredits: Int
    let followMonths: Int
    let subMonths: Int
    let isLoggedIn: Bool

    static let placeholder = CrewStats(
        doubloons: 1250,
        soundbyteCredits: 3,
        followMonths: 24,
        subMonths: 12,
        isLoggedIn: true
    )
}

// MARK: - Timeline

struct CrewStatsEntry: TimelineEntry {
    let date: Date
    let stats: CrewStats
}

struct CrewStatsProvider: TimelineProvider {
    func placeholder(in context: Context) -> CrewStatsEntry {
        CrewStatsEntry(date: .now, stats: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (CrewStatsEntry) -> Void) {
        let entry = CrewStatsEntry(date: .now, stats: WidgetData.load())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CrewStatsEntry>) -> Void) {
        let stats = WidgetData.load()
        widgetLog("CrewStats: timeline refresh — loggedIn=\(stats.isLoggedIn) doubloons=\(stats.doubloons) soundbytes=\(stats.soundbyteCredits) followMo=\(stats.followMonths) subMo=\(stats.subMonths)")
        let entry = CrewStatsEntry(date: .now, stats: stats)
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Widget View

struct CrewStatsWidgetView: View {
    let entry: CrewStatsEntry

    private let gold = Color(red: 0xCC/255, green: 0x88/255, blue: 0x03/255)
    private let darkBrown = Color(red: 0.1, green: 0.07, blue: 0.04)
    private let medBrown = Color(red: 0.16, green: 0.12, blue: 0.08)

    var body: some View {
        if entry.stats.isLoggedIn {
            statsView
        } else {
            loggedOutView
        }
    }

    private var statsView: some View {
        VStack(spacing: 6) {
            Text("Crew Stats")
                .font(.custom("PirataOne-Regular", size: 16))
                .foregroundStyle(gold)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 6) {
                statCell(icon: "star.circle.fill", label: "Doubloons", value: entry.stats.doubloons.formatted())
                statCell(icon: "speaker.wave.2.fill", label: "Soundbytes", value: entry.stats.soundbyteCredits.formatted())
                statCell(icon: "heart.fill", label: "Follow Mo.", value: entry.stats.followMonths.formatted())
                statCell(icon: "star.fill", label: "Sub Mo.", value: entry.stats.subMonths.formatted())
            }
        }
        .padding(12)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [medBrown, darkBrown],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func statCell(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(gold)
            Text(value)
                .font(.custom("PirataOne-Regular", size: 18))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var loggedOutView: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 28))
                .foregroundStyle(gold)
            Text("Log In")
                .font(.custom("PirataOne-Regular", size: 16))
                .foregroundStyle(gold)
            Text("Open Dirty Skull to\nsee yer stats")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(12)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [medBrown, darkBrown],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Stream Status Data

struct StreamStatusData {
    let isLive: Bool
    let title: String?
    let gameName: String?
    let viewerCount: Int?
    let boxArtImage: UIImage?
    let startedAt: Date?

    static let placeholder = StreamStatusData(isLive: true, title: "Drake is Best Ships \u{1F480} THE NEW DIRTY SKULL APP IS LIVE - !app \u{1F480} !Madrinas \u{1F480} !BootyBoard \u{1F480} !Discord \u{1F480}", gameName: "Sea of Thieves", viewerCount: 2_847, boxArtImage: nil, startedAt: Date().addingTimeInterval(-3 * 3600))
    static let offline = StreamStatusData(isLive: false, title: nil, gameName: nil, viewerCount: nil, boxArtImage: nil, startedAt: nil)

    private static func saveLastLive(_ status: StreamAPIData, boxArtData: Data?) {
        guard let defaults = UserDefaults(suiteName: WidgetData.appGroup) else { return }
        defaults.set(status.title, forKey: "widget.lastLive.title")
        defaults.set(status.game_name, forKey: "widget.lastLive.gameName")
        defaults.set(status.viewer_count ?? 0, forKey: "widget.lastLive.viewerCount")
        defaults.set(status.box_art_url, forKey: "widget.lastLive.boxArtUrl")
        if let artData = boxArtData {
            defaults.set(artData, forKey: "widget.lastLive.boxArtData")
        }
    }

    private static func loadLastLive() -> StreamStatusData {
        guard let defaults = UserDefaults(suiteName: WidgetData.appGroup),
              defaults.string(forKey: "widget.lastLive.title") != nil else {
            widgetLog("StreamStatus: no saved live data, using mock")
            return .placeholder
        }
        let title = defaults.string(forKey: "widget.lastLive.title")
        let game = defaults.string(forKey: "widget.lastLive.gameName")
        let viewers = defaults.integer(forKey: "widget.lastLive.viewerCount")
        var boxArt: UIImage? = nil
        if let artData = defaults.data(forKey: "widget.lastLive.boxArtData") {
            boxArt = UIImage(data: artData)
        }
        return StreamStatusData(
            isLive: true,
            title: title,
            gameName: game,
            viewerCount: viewers > 0 ? viewers : 1234,
            boxArtImage: boxArt,
            startedAt: Date().addingTimeInterval(-3 * 3600)
        )
    }

    static func fetch() async -> StreamStatusData {
        let defaults = UserDefaults(suiteName: WidgetData.appGroup)
        let forceStatus = defaults?.string(forKey: "widget.debug.forceStatus") ?? "none"
        let legacyForceOffline = defaults?.bool(forKey: "widget.debug.forceOffline") ?? false

        if forceStatus == "offline" || legacyForceOffline {
            widgetLog("StreamStatus: force offline enabled, returning offline")
            return .offline
        }
        if forceStatus == "online" {
            widgetLog("StreamStatus: force online enabled, returning last live data")
            var data = loadLastLive()
            if data.boxArtImage == nil {
                let mockArtUrl = URL(string: "https://static-cdn.jtvnw.net/ttv-boxart/490377-144x192.jpg")!
                if let (imgData, _) = try? await URLSession.shared.data(from: mockArtUrl) {
                    data = StreamStatusData(isLive: data.isLive, title: data.title, gameName: data.gameName, viewerCount: data.viewerCount, boxArtImage: UIImage(data: imgData), startedAt: data.startedAt)
                }
            }
            return data
        }

        guard let url = URL(string: "https://api.burkeblack.tv/app/stream-status") else {
            widgetLog("StreamStatus: invalid URL")
            return .offline
        }
        do {
            widgetLog("StreamStatus: fetching from API...")
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                widgetLog("StreamStatus: bad HTTP status \(code)")
                return .offline
            }
            let decoded = try JSONDecoder().decode(StreamAPIResponse.self, from: data)
            guard decoded.success, let status = decoded.data else {
                widgetLog("StreamStatus: API returned success=false or nil data")
                return .offline
            }

            var boxArt: UIImage? = nil
            var boxArtRawData: Data? = nil
            if let artUrlStr = status.box_art_url, let artUrl = URL(string: artUrlStr) {
                if let (imgData, _) = try? await URLSession.shared.data(from: artUrl) {
                    boxArt = UIImage(data: imgData)
                    boxArtRawData = imgData
                    widgetLog("StreamStatus: box art loaded (\(imgData.count) bytes)")
                } else {
                    widgetLog("StreamStatus: box art download failed for \(artUrlStr)")
                }
            }

            var startDate: Date? = nil
            if let started = status.started_at {
                let fmt = ISO8601DateFormatter()
                startDate = fmt.date(from: started)
            }

            if status.is_live {
                saveLastLive(status, boxArtData: boxArtRawData)
            }

            widgetLog("StreamStatus: live=\(status.is_live) game=\(status.game_name ?? "nil") viewers=\(status.viewer_count ?? 0) boxArt=\(boxArt != nil) started=\(status.started_at ?? "nil")")

            return StreamStatusData(
                isLive: status.is_live,
                title: status.title,
                gameName: status.game_name,
                viewerCount: status.viewer_count,
                boxArtImage: boxArt,
                startedAt: startDate
            )
        } catch {
            widgetLog("StreamStatus: fetch error — \(error.localizedDescription)")
            return .offline
        }
    }
}

private struct StreamAPIResponse: Codable {
    let success: Bool
    let data: StreamAPIData?
}

private struct StreamAPIData: Codable {
    let is_live: Bool
    let title: String?
    let game_name: String?
    let viewer_count: Int?
    let box_art_url: String?
    let started_at: String?
}

// MARK: - Stream Status Timeline

struct StreamStatusEntry: TimelineEntry {
    let date: Date
    let stream: StreamStatusData
}

struct StreamStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreamStatusEntry {
        StreamStatusEntry(date: .now, stream: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (StreamStatusEntry) -> Void) {
        Task {
            let stream = await StreamStatusData.fetch()
            completion(StreamStatusEntry(date: .now, stream: stream))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreamStatusEntry>) -> Void) {
        Task {
            widgetLog("StreamStatus: timeline refresh starting")
            let stream = await StreamStatusData.fetch()
            let entry = StreamStatusEntry(date: .now, stream: stream)
            let interval: TimeInterval = stream.isLive ? 15 * 60 : 30 * 60
            widgetLog("StreamStatus: next refresh in \(Int(interval/60)) min")
            let nextUpdate = Date.now.addingTimeInterval(interval)
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
}

// MARK: - Stream Status Small Widget View

struct StreamStatusSmallView: View {
    let entry: StreamStatusEntry

    private let gold = Color(red: 0xCC/255, green: 0x88/255, blue: 0x03/255)
    private let darkBrown = Color(red: 0.1, green: 0.07, blue: 0.04)
    private let medBrown = Color(red: 0.16, green: 0.12, blue: 0.08)

    var body: some View {
        VStack(spacing: 0) {
            if entry.stream.isLive {
                liveView
            } else {
                offlineView
            }
        }
        .padding(12)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [medBrown, darkBrown],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var liveView: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Circle().fill(.red).frame(width: 7, height: 7)
                        Text("LIVE")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(.red)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 10))
                        Text(entry.stream.viewerCount?.formatted() ?? "0")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(gold)
                }

                Spacer()

                Image("burkeblack_profile")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(gold.opacity(0.5), lineWidth: 1))
            }

            Spacer()

            HStack(alignment: .bottom, spacing: 8) {
                if let boxArt = entry.stream.boxArtImage {
                    Image(uiImage: boxArt)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 67)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                if let game = entry.stream.gameName {
                    Text(game)
                        .font(.custom("PirataOne-Regular", size: 20))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var offlineView: some View {
        VStack(spacing: 8) {
            Image("burkeblack_profile")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                .opacity(0.5)

            Text("Stream Offline")
                .font(.custom("PirataOne-Regular", size: 16))
                .foregroundStyle(.white.opacity(0.5))

            if let next = nextStreamDate() {
                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                        Text("Next stream")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(gold.opacity(0.7))
                    Text(next, style: .relative)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(gold.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Stream Status Medium Widget View

struct StreamStatusMediumView: View {
    let entry: StreamStatusEntry

    private let gold = Color(red: 0xCC/255, green: 0x88/255, blue: 0x03/255)
    private let darkBrown = Color(red: 0.1, green: 0.07, blue: 0.04)
    private let medBrown = Color(red: 0.16, green: 0.12, blue: 0.08)

    var body: some View {
        Group {
            if entry.stream.isLive {
                liveView
            } else {
                offlineView
            }
        }
        .padding(14)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [medBrown, darkBrown],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var liveView: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 4) {
                if let boxArt = entry.stream.boxArtImage {
                    Image(uiImage: boxArt)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 106)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                if let game = entry.stream.gameName {
                    Text(game)
                        .font(.custom("PirataOne-Regular", size: 18))
                        .foregroundStyle(gold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 0) {
                    HStack(spacing: 5) {
                        Circle().fill(.red).frame(width: 7, height: 7)
                        Text("LIVE")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(.red)
                    }

                    if let started = entry.stream.startedAt {
                        (Text(" \u{2022} ").foregroundColor(.white.opacity(0.3)) +
                        Text(started, style: .relative).foregroundColor(.white.opacity(0.6)))
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 10))
                        Text(entry.stream.viewerCount?.formatted() ?? "0")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(gold)

                    Spacer().frame(width: 8)

                    Image("burkeblack_profile")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(gold.opacity(0.5), lineWidth: 1))
                }

                Spacer(minLength: 2)

                if let title = entry.stream.title {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .minimumScaleFactor(0.75)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var offlineView: some View {
        HStack(spacing: 16) {
            Image("burkeblack_profile")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .opacity(0.5)

            VStack(alignment: .leading, spacing: 6) {
                Text("Stream Offline")
                    .font(.custom("PirataOne-Regular", size: 18))
                    .foregroundStyle(.white.opacity(0.5))

                if let next = nextStreamDate() {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                        Text("Next stream ")
                            .font(.system(size: 11))
                        + Text(next, style: .relative)
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(gold.opacity(0.7))
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Next Stream Helper

private func nextStreamDate() -> Date? {
    let eastern = TimeZone(identifier: "America/New_York")!
    let cal = Calendar.current
    let now = Date()
    let components = cal.dateComponents(in: eastern, from: now)

    for dayOffset in 0..<8 {
        var check = components
        check.hour = 22; check.minute = 0; check.second = 0
        if dayOffset > 0 || (components.hour ?? 0) >= 22 {
            check.day = (check.day ?? 0) + (dayOffset == 0 ? 1 : dayOffset)
        }
        if let date = cal.date(from: check) {
            let weekday = cal.component(.weekday, from: date)
            if weekday != 1 && date > now { return date }
        }
    }
    return nil
}

// MARK: - Widget Configurations

struct CrewStatsWidget: Widget {
    let kind = "BurkeBlackWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CrewStatsProvider()) { entry in
            CrewStatsWidgetView(entry: entry)
                .widgetURL(URL(string: "burkeblackapp://account"))
        }
        .configurationDisplayName("Crew Stats")
        .description("Yer doubloons, soundbytes, follow months & sub months at a glance.")
        .supportedFamilies([.systemSmall])
    }
}

struct StreamStatusSmallWidget: Widget {
    let kind = "StreamStatusSmall"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreamStatusProvider()) { entry in
            StreamStatusSmallView(entry: entry)
                .widgetURL(URL(string: "https://twitch.tv/burkeblack"))
        }
        .configurationDisplayName("Stream Status")
        .description("Is BurkeBlack live? See at a glance.")
        .supportedFamilies([.systemSmall])
    }
}

struct StreamStatusMediumWidget: Widget {
    let kind = "StreamStatusMedium"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreamStatusProvider()) { entry in
            StreamStatusMediumView(entry: entry)
                .widgetURL(URL(string: "https://twitch.tv/burkeblack"))
        }
        .configurationDisplayName("Stream Status")
        .description("Stream title, game, viewers — all at a glance.")
        .supportedFamilies([.systemMedium])
    }
}

@main
struct BurkeBlackWidgetBundle: WidgetBundle {
    var body: some Widget {
        CrewStatsWidget()
        StreamStatusSmallWidget()
        StreamStatusMediumWidget()
    }
}

// MARK: - Previews

#Preview("Crew Stats", as: .systemSmall) {
    CrewStatsWidget()
} timeline: {
    CrewStatsEntry(date: .now, stats: .placeholder)
}

#Preview("Stream Live", as: .systemSmall) {
    StreamStatusSmallWidget()
} timeline: {
    StreamStatusEntry(date: .now, stream: .placeholder)
}

#Preview("Stream Offline", as: .systemSmall) {
    StreamStatusSmallWidget()
} timeline: {
    StreamStatusEntry(date: .now, stream: .offline)
}

#Preview("Stream Live Medium", as: .systemMedium) {
    StreamStatusMediumWidget()
} timeline: {
    StreamStatusEntry(date: .now, stream: .placeholder)
}

#Preview("Stream Offline Medium", as: .systemMedium) {
    StreamStatusMediumWidget()
} timeline: {
    StreamStatusEntry(date: .now, stream: .offline)
}
