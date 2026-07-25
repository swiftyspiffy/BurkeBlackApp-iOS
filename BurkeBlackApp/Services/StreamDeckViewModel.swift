import Foundation

enum StreamChannelKey: String, Codable, CaseIterable {
    case main
    case burke40k
    case classics
}

struct StreamDeckChannel: Codable, Identifiable, Equatable {
    let key: StreamChannelKey
    let login: String
    let displayName: String
    let twitchUrl: String
    let isLive: Bool
    let title: String?
    let gameName: String?
    let viewerCount: Int?
    let thumbnailUrl: String?
    let profileImageUrl: String?
    let startedAt: String?

    var id: StreamChannelKey { key }

    var cardName: String {
        switch key {
        case .main: "BurkeBlack"
        case .burke40k: "Burke40k"
        case .classics: "24/7 Classics"
        }
    }

    var heroTitle: String {
        switch key {
        case .main, .burke40k:
            if let title, !title.isEmpty {
                return title
            }
            return "\(displayName) is live"
        case .classics:
            return "Classic BurkeBlack"
        }
    }

    var watchButtonTitle: String {
        switch key {
        case .main: "Watch BurkeBlack"
        case .burke40k: "Watch Burke40k"
        case .classics: "Watch 24/7 Classics"
        }
    }

    enum CodingKeys: String, CodingKey {
        case key, login, title
        case displayName = "display_name"
        case twitchUrl = "twitch_url"
        case isLive = "is_live"
        case gameName = "game_name"
        case viewerCount = "viewer_count"
        case thumbnailUrl = "thumbnail_url"
        case profileImageUrl = "profile_image_url"
        case startedAt = "started_at"
    }

    static func placeholder(for key: StreamChannelKey) -> StreamDeckChannel {
        let login: String
        let displayName: String

        switch key {
        case .main:
            login = "burkeblack"
            displayName = "BurkeBlack"
        case .burke40k:
            login = "burke40k"
            displayName = "Burke40k"
        case .classics:
            login = "burkeblack247"
            displayName = "BurkeBlack247"
        }

        return StreamDeckChannel(
            key: key,
            login: login,
            displayName: displayName,
            twitchUrl: "https://www.twitch.tv/\(login)",
            isLive: false,
            title: nil,
            gameName: nil,
            viewerCount: nil,
            thumbnailUrl: nil,
            profileImageUrl: nil,
            startedAt: nil
        )
    }
}

struct StreamDeckData: Codable {
    let fetchedAt: String
    let isStale: Bool
    let channels: [StreamDeckChannel]

    enum CodingKeys: String, CodingKey {
        case fetchedAt = "fetched_at"
        case isStale = "is_stale"
        case channels
    }
}

@MainActor
final class StreamDeckViewModel: ObservableObject {
    @Published private(set) var channels = StreamChannelKey.allCases.map {
        StreamDeckChannel.placeholder(for: $0)
    }
    @Published private(set) var isLoading = false
    @Published private(set) var isStale = false
    @Published private(set) var fetchedAt: String?
    @Published private(set) var error: String?
    @Published var selectedKey: StreamChannelKey?

    var selectedChannel: StreamDeckChannel {
        if let selectedKey, let selected = channel(for: selectedKey) {
            return selected
        }
        return channel(for: .main) ?? StreamDeckChannel.placeholder(for: .main)
    }

    var allChannelsOffline: Bool {
        !channels.contains(where: \.isLive)
    }

    func channel(for key: StreamChannelKey) -> StreamDeckChannel? {
        channels.first(where: { $0.key == key })
    }

    func select(_ channel: StreamDeckChannel) {
        selectedKey = channel.key
    }

    func loadIfNeeded() async {
        guard fetchedAt == nil else { return }
        await refresh()
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let data = try await APIService.shared.fetchStreamDeck()
            let channelsByKey = Dictionary(uniqueKeysWithValues: data.channels.map { ($0.key, $0) })

            channels = StreamChannelKey.allCases.map {
                channelsByKey[$0] ?? StreamDeckChannel.placeholder(for: $0)
            }
            fetchedAt = data.fetchedAt
            isStale = data.isStale
            error = nil

            if selectedKey == nil {
                selectedKey = StreamChannelKey.allCases.first(where: {
                    channelsByKey[$0]?.isLive == true
                }) ?? .main
            }

            appLog("StreamDeck: loaded \(channels.filter(\.isLive).count) live channels")
        } catch {
            self.error = error.localizedDescription
            appLog("StreamDeck: load failed - \(error.localizedDescription)")
        }
    }
}
