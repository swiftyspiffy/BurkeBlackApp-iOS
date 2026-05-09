import Foundation

actor TwitchEmoteService {
    static let shared = TwitchEmoteService()

    private let broadcasterID = "44338537"
    private let backendBaseURL = "https://api.burkeblack.tv/app"

    private var cachedAccessToken: String?
    private var cachedClientId: String?

    private init() {}

    // MARK: - Public API

    func fetchChannelEmotes() async throws -> ChannelEmotesResponse {
        appLog("TwitchEmoteService: fetching channel emotes")
        let url = URL(string: "https://api.twitch.tv/helix/chat/emotes?broadcaster_id=\(broadcasterID)")!
        let data = try await twitchGet(url: url)
        let response = try JSONDecoder().decode(ChannelEmotesResponse.self, from: data)
        appLog("TwitchEmoteService: got \(response.data.count) emotes")
        return response
    }

    func fetchChannelBadges() async throws -> ChannelBadgesResponse {
        appLog("TwitchEmoteService: fetching channel badges")
        let url = URL(string: "https://api.twitch.tv/helix/chat/badges?broadcaster_id=\(broadcasterID)")!
        let data = try await twitchGet(url: url)
        let response = try JSONDecoder().decode(ChannelBadgesResponse.self, from: data)
        appLog("TwitchEmoteService: got \(response.data.count) badge sets")
        return response
    }

    func fetchCheermotes() async throws -> CheermotesResponse {
        appLog("TwitchEmoteService: fetching cheermotes")
        let url = URL(string: "https://api.twitch.tv/helix/bits/cheermotes?broadcaster_id=\(broadcasterID)")!
        let data = try await twitchGet(url: url)
        let response = try JSONDecoder().decode(CheermotesResponse.self, from: data)
        appLog("TwitchEmoteService: got \(response.data.count) cheermote sets")
        return response
    }

    // MARK: - Token Management

    private func getTwitchCredentials() async throws -> (accessToken: String, clientId: String) {
        if let token = cachedAccessToken, let clientId = cachedClientId {
            return (token, clientId)
        }
        return try await refreshTwitchToken()
    }

    private func refreshTwitchToken() async throws -> (accessToken: String, clientId: String) {
        appLog("TwitchEmoteService: requesting Twitch token from backend")

        // Get the app bearer token from keychain
        guard let appToken = await MainActor.run(body: { AccountViewModel.getBearerToken() }) else {
            appLog("TwitchEmoteService: no app bearer token available - user not logged in")
            throw EmoteError.notLoggedIn
        }

        guard let url = URL(string: "\(backendBaseURL)/twitch-token") else {
            throw EmoteError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(appToken)", forHTTPHeaderField: "Authorization")
        TwitchAuthService.addPlatformHeaders(&request)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw EmoteError.networkError("Invalid response")
        }

        if http.statusCode == 401 {
            appLog("TwitchEmoteService: backend returned 401 - token invalid or no refresh token")
            throw EmoteError.notLoggedIn
        }

        guard http.statusCode == 200 else {
            appLog("TwitchEmoteService: backend returned \(http.statusCode)")
            throw EmoteError.networkError("Server error (\(http.statusCode))")
        }

        struct TokenResponse: Codable {
            let success: Bool
            let data: TokenData?
            let error: String?
        }
        struct TokenData: Codable {
            let access_token: String
            let client_id: String
        }

        let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
        guard let tokenData = decoded.data else {
            appLog("TwitchEmoteService: backend error: \(decoded.error ?? "unknown")")
            throw EmoteError.networkError(decoded.error ?? "No token data")
        }

        cachedAccessToken = tokenData.access_token
        cachedClientId = tokenData.client_id
        appLog("TwitchEmoteService: got fresh Twitch access token")
        return (tokenData.access_token, tokenData.client_id)
    }

    // MARK: - Network

    private func twitchGet(url: URL) async throws -> Data {
        let creds = try await getTwitchCredentials()

        var request = URLRequest(url: url)
        request.setValue("Bearer \(creds.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(creds.clientId, forHTTPHeaderField: "Client-Id")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw EmoteError.networkError("Invalid response")
        }

        if http.statusCode == 401 {
            appLog("TwitchEmoteService: Twitch returned 401, refreshing token")
            cachedAccessToken = nil
            cachedClientId = nil
            let newCreds = try await refreshTwitchToken()

            var retry = URLRequest(url: url)
            retry.setValue("Bearer \(newCreds.accessToken)", forHTTPHeaderField: "Authorization")
            retry.setValue(newCreds.clientId, forHTTPHeaderField: "Client-Id")
            let (retryData, retryResp) = try await URLSession.shared.data(for: retry)
            guard let retryHttp = retryResp as? HTTPURLResponse, retryHttp.statusCode == 200 else {
                appLog("TwitchEmoteService: retry also failed")
                throw EmoteError.networkError("Twitch API error after retry")
            }
            return retryData
        }

        guard http.statusCode == 200 else {
            appLog("TwitchEmoteService: Twitch returned \(http.statusCode)")
            throw EmoteError.networkError("Twitch API error (\(http.statusCode))")
        }
        return data
    }
}

// MARK: - Error

enum EmoteError: LocalizedError {
    case networkError(String)
    case notLoggedIn

    var errorDescription: String? {
        switch self {
        case .networkError(let msg): return msg
        case .notLoggedIn: return "Sign in to view emotes"
        }
    }
}

// MARK: - Response Models

struct ChannelEmotesResponse: Codable {
    let data: [TwitchEmote]
    let template: String
}

struct TwitchEmote: Codable {
    let id: String
    let name: String
    let images: TwitchEmoteImages
    let emote_type: String
    let emote_set_id: String
    let format: [String]
    let scale: [String]
    let theme_mode: [String]
}

struct TwitchEmoteImages: Codable {
    let url_1x: String
    let url_2x: String
    let url_4x: String
}

struct ChannelBadgesResponse: Codable {
    let data: [TwitchBadgeSet]
}

struct TwitchBadgeSet: Codable {
    let set_id: String
    let versions: [TwitchBadgeVersion]
}

struct TwitchBadgeVersion: Codable {
    let id: String
    let image_url_1x: String
    let image_url_2x: String
    let image_url_4x: String
    let title: String
    let description: String
}

struct CheermotesResponse: Codable {
    let data: [TwitchCheermote]
}

struct TwitchCheermote: Codable {
    let prefix: String
    let tiers: [CheermoteTier]
    let type: String
}

struct CheermoteTier: Codable {
    let min_bits: Int
    let images: CheermoteImages
}

struct CheermoteImages: Codable {
    let dark: CheermoteTheme
    let light: CheermoteTheme
}

struct CheermoteTheme: Codable {
    let animated: [String: String]
    let `static`: [String: String]

    enum CodingKeys: String, CodingKey {
        case animated
        case `static`
    }
}
