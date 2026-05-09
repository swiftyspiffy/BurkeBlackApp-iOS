import AuthenticationServices
import Foundation

class TwitchAuthService {
    static let shared = TwitchAuthService()

    private let clientID = "jovw06nlsgfkmify8c6emwsvwo54fe"
    private let redirectURI = "https://api.burkeblack.tv/app/auth/callback"
    private let callbackScheme = "burkeblackapp"
    private let scopes = "user:read:email user:read:follows user:read:subscriptions"
    private let backendBaseURL = "https://api.burkeblack.tv/app"

    static func addPlatformHeaders(_ request: inout URLRequest) {
        request.setValue("iOS", forHTTPHeaderField: "X-App-Platform")
        request.setValue(UIDevice.current.systemVersion, forHTTPHeaderField: "X-App-Platform-Version")
        request.setValue(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?", forHTTPHeaderField: "X-App-Version")
    }

    private init() {}

    @MainActor
    func authenticate(forceVerify: Bool = false) async throws -> AuthResult {
        appLog("Starting Twitch OAuth (forceVerify=\(forceVerify))")
        let authResult = try await startOAuthFlow(forceVerify: forceVerify)
        let dashboard = try await fetchDashboard(token: authResult.token)

        return AuthResult(
            token: authResult.token,
            userId: authResult.userId,
            username: authResult.username,
            avatarUrl: authResult.avatarUrl,
            dashboard: dashboard
        )
    }

    @MainActor
    private func startOAuthFlow(forceVerify: Bool) async throws -> OAuthCallbackData {
        var components = URLComponents(string: "https://id.twitch.tv/oauth2/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes),
        ]
        if forceVerify {
            components.queryItems?.append(URLQueryItem(name: "force_verify", value: "true"))
        }

        let authURL = components.url!

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error {
                    if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: CancellationError())
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }

                guard let callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
                else {
                    continuation.resume(throwing: AuthError.noData)
                    return
                }

                let params = components.queryItems ?? []
                func param(_ name: String) -> String? {
                    params.first(where: { $0.name == name })?.value
                }

                if let errorMsg = param("error") {
                    continuation.resume(throwing: AuthError.apiError(errorMsg))
                    return
                }

                guard let token = param("token"),
                      let userId = param("user_id"),
                      let username = param("username")
                else {
                    continuation.resume(throwing: AuthError.noData)
                    return
                }

                appLog("Auth: OAuth callback received token for \(username)")
                continuation.resume(returning: OAuthCallbackData(
                    token: token,
                    userId: userId,
                    username: username,
                    avatarUrl: param("avatar_url")
                ))
            }

            session.presentationContextProvider = PresentationContextProvider.shared
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }

    func fetchDashboard(token: String) async throws -> DashboardData {
        appLog("Fetching dashboard")
        guard let url = URL(string: "\(backendBaseURL)/dashboard") else {
            throw AuthError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        TwitchAuthService.addPlatformHeaders(&request)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            appLog("Auth: fetchDashboard failed with status \(code)")
            throw AuthError.dashboardFailed
        }

        let decoded = try JSONDecoder().decode(APISuccessResponse<DashboardData>.self, from: data)
        guard decoded.success, let dashboard = decoded.data else {
            throw AuthError.dashboardFailed
        }
        return dashboard
    }
}

// MARK: - Presentation Context
class PresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = PresentationContextProvider()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first
        else {
            return ASPresentationAnchor()
        }
        return window
    }
}

// MARK: - Locale-Aware Formatting
enum StatFormatter {
    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = Locale.current.groupingSeparator
        f.decimalSeparator = Locale.current.decimalSeparator
        return f
    }()

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        return f
    }()

    static func integer(_ value: Int) -> String {
        numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func currency(_ value: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: value)) ?? String(format: "$%.2f", value)
    }
}

// MARK: - Models
struct OAuthCallbackData {
    let token: String
    let userId: String
    let username: String
    let avatarUrl: String?
}

struct AuthResult {
    let token: String
    let userId: String
    let username: String
    let avatarUrl: String?
    let dashboard: DashboardData
}

struct DashboardData: Codable {
    let userId: String
    let username: String
    let doubloons: Int
    let soundbyteCredits: Int
    let donations: Double
    let eventsDonations: Double?
    let totalBits: Int?
    let followDate: String?
    let latestSub: LatestSubData?
    let giveawaysEntered: Int
    let giveawaysWon: Int
    let giveawaysDonated: Int
    let avatarUrl: String?
    let soundbyteSends: Int?
    let favSoundbyte: FavSoundbyteData?
    let lastSoundbyte: LastSoundbyteData?
    let soundbytesEnabled: Bool?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username, doubloons, donations
        case soundbyteCredits = "soundbyte_credits"
        case eventsDonations = "events_donations"
        case totalBits = "total_bits"
        case followDate = "follow_date"
        case latestSub = "latest_sub"
        case giveawaysEntered = "giveaways_entered"
        case giveawaysWon = "giveaways_won"
        case giveawaysDonated = "giveaways_donated"
        case avatarUrl = "avatar_url"
        case soundbyteSends = "soundbyte_sends"
        case favSoundbyte = "fav_soundbyte"
        case lastSoundbyte = "last_soundbyte"
        case soundbytesEnabled = "soundbytes_enabled"
    }
}

struct FavSoundbyteData: Codable {
    let name: String
    let count: Int
}

struct LastSoundbyteData: Codable {
    let name: String
    let date: Int

    var formattedDate: String {
        Date(timeIntervalSince1970: TimeInterval(date))
            .formatted(date: .abbreviated, time: .omitted)
    }
}

struct LatestSubData: Codable {
    let tier: String
    let cumulativeMonths: Int
    let streakMonths: Int
    let isGift: Bool
    let gifter: String?
    let message: String?
    let date: String

    enum CodingKeys: String, CodingKey {
        case tier, message, date, gifter
        case cumulativeMonths = "cumulative_months"
        case streakMonths = "streak_months"
        case isGift = "is_gift"
    }
}

struct APISuccessResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
}

struct StreamStatusResponse: Codable {
    let isLive: Bool
    let title: String?
    let gameName: String?
    let viewerCount: Int?

    enum CodingKeys: String, CodingKey {
        case isLive = "is_live"
        case title
        case gameName = "game_name"
        case viewerCount = "viewer_count"
    }
}

struct APIErrorOrSuccess: Codable {
    let success: Bool
    let error: String?
}

enum AuthError: LocalizedError {
    case noData
    case invalidURL
    case exchangeFailed
    case dashboardFailed
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .noData: return "No authorization data received."
        case .invalidURL: return "Invalid server URL."
        case .exchangeFailed: return "Failed to verify login with server."
        case .dashboardFailed: return "Failed to load your data."
        case .apiError(let message): return message
        }
    }
}

// MARK: - Stream Status

struct StreamStatus {
    let isLive: Bool
    let title: String?
    let gameName: String?
    let viewerCount: Int?
}

struct TwitchStreamResponse: Codable {
    let data: [TwitchStreamData]
}

struct TwitchStreamData: Codable {
    let title: String
    let gameName: String
    let viewerCount: Int

    enum CodingKeys: String, CodingKey {
        case title
        case gameName = "game_name"
        case viewerCount = "viewer_count"
    }
}

// MARK: - Soundbyte Browser

struct Soundbyte: Codable, Identifiable {
    let id: Int
    let name: String
    let location: String
    let uploadedBy: String
    let genre: String
    let horror: Int
    let creditCost: Int
    let plays: Int
    let lastPlayedBy: String?

    enum CodingKeys: String, CodingKey {
        case id, name, location, genre, horror, plays
        case uploadedBy = "uploaded_by"
        case creditCost = "credit_cost"
        case lastPlayedBy = "last_played_by"
    }
}

struct SoundbytesResponse: Codable {
    let soundbytes: [Soundbyte]
    let total: Int
    let offset: Int
    let amount: Int
}

struct SoundbyteSendResponse: Codable {
    let message: String
    let soundbyteName: String
    let creditsRemaining: Int

    enum CodingKeys: String, CodingKey {
        case message
        case soundbyteName = "soundbyte_name"
        case creditsRemaining = "credits_remaining"
    }
}

struct SoundbyteHistoryItem: Codable, Identifiable {
    let _id = UUID()
    var id: UUID { _id }
    let soundbyteId: Int
    let name: String
    let announced: Bool
    let date: Int

    enum CodingKeys: String, CodingKey {
        case soundbyteId = "soundbyte_id"
        case name, announced, date
    }


    var formattedDate: String {
        Date(timeIntervalSince1970: TimeInterval(date))
            .formatted(date: .abbreviated, time: .shortened)
    }
}

struct SoundbyteHistoryResponse: Codable {
    let history: [SoundbyteHistoryItem]
}

struct SoundbyteGenre: Codable, Identifiable, Hashable {
    let id: Int
    let genre: String
}

struct SoundbyteGenresResponse: Codable {
    let genres: [SoundbyteGenre]
}

struct SoundbyteCreditsResponse: Codable {
    let soundbyteCredits: Int

    enum CodingKeys: String, CodingKey {
        case soundbyteCredits = "soundbyte_credits"
    }
}

// MARK: - Bits Detail

struct BitCheer: Codable, Identifiable {
    let _id = UUID()
    var id: UUID { _id }
    let bits: Int
    let message: String
    let date: String

    enum CodingKeys: String, CodingKey {
        case bits, message, date
    }

    var formattedDate: String {
        // Try ISO format first, then timestamp
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = formatter.date(from: date) {
            return d.formatted(date: .abbreviated, time: .shortened)
        }
        // Try simple date format
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let d = df.date(from: date) {
            return d.formatted(date: .abbreviated, time: .shortened)
        }
        return date
    }
}

struct BitsResponse: Codable {
    let bits: [BitCheer]
}

// MARK: - Donations

struct Donation: Codable, Identifiable {
    var id: String { "\(amount)-\(date)" }
    let amount: Double
    let currency: String
    let message: String
    let date: String

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.uppercased()
        return formatter.string(from: NSNumber(value: amount)) ?? String(format: "$%.2f", amount)
    }

    var formattedDate: String {
        // createdAt is stored as string like "2024-01-15" or epoch
        if let epoch = Double(date) {
            let d = Date(timeIntervalSince1970: epoch)
            return d.formatted(date: .abbreviated, time: .omitted)
        }
        return date
    }
}

struct DonationsResponse: Codable {
    let donations: [Donation]
}

// MARK: - User Status

struct UserStatus: Codable {
    let follows: Bool
    let subscribed: Bool
    let subTier: String?
    let userRole: String
    let isModerator: Bool?
    let isSubGifter: Bool?
    let isBitsSender: Bool?
    let followedAt: String?

    enum CodingKeys: String, CodingKey {
        case follows, subscribed
        case subTier = "sub_tier"
        case userRole = "user_role"
        case isModerator = "is_moderator"
        case isSubGifter = "is_sub_gifter"
        case isBitsSender = "is_bits_sender"
        case followedAt = "followed_at"
    }
}

// MARK: - Giveaway Models

struct GiveawayEntry: Codable, Identifiable {
    var id: String { "\(name)-\(date)" }
    let name: String
    let donator: String
    let giveawayState: String
    let entryState: String
    let date: Int

    enum CodingKeys: String, CodingKey {
        case name, donator, date
        case giveawayState = "giveaway_state"
        case entryState = "entry_state"
    }

    var formattedDate: String {
        let d = Date(timeIntervalSince1970: TimeInterval(date))
        return d.formatted(date: .abbreviated, time: .omitted)
    }
}

struct GiveawayWin: Codable, Identifiable {
    var id: String { "\(name)-\(donator)" }
    let name: String
    let donator: String
    let prize: String
}

struct GiveawayDonated: Codable, Identifiable {
    var id: String { "\(name)-\(date)" }
    let name: String
    let state: String
    let winnerUserid: String
    let date: Int

    enum CodingKeys: String, CodingKey {
        case name, state, date
        case winnerUserid = "winner_userid"
    }

    var formattedDate: String {
        let d = Date(timeIntervalSince1970: TimeInterval(date))
        return d.formatted(date: .abbreviated, time: .omitted)
    }
}

struct GiveawayEntriesResponse: Codable {
    let giveawayEntries: [GiveawayEntry]

    enum CodingKeys: String, CodingKey {
        case giveawayEntries = "giveaway_entries"
    }
}

struct GiveawayWinsResponse: Codable {
    let giveawayWins: [GiveawayWin]

    enum CodingKeys: String, CodingKey {
        case giveawayWins = "giveaway_wins"
    }
}

struct GiveawayDonatedResponse: Codable {
    let giveawayDonated: [GiveawayDonated]

    enum CodingKeys: String, CodingKey {
        case giveawayDonated = "giveaway_donated"
    }
}

// MARK: - Giveaway API

extension TwitchAuthService {
    func fetchGiveawayEntries(token: String) async throws -> [GiveawayEntry] {
        let response: GiveawayEntriesResponse = try await authenticatedGet("/giveaway-entries", token: token)
        return response.giveawayEntries
    }

    func fetchGiveawayWins(token: String) async throws -> [GiveawayWin] {
        let response: GiveawayWinsResponse = try await authenticatedGet("/giveaway-wins", token: token)
        return response.giveawayWins
    }

    func fetchGiveawayDonated(token: String) async throws -> [GiveawayDonated] {
        let response: GiveawayDonatedResponse = try await authenticatedGet("/giveaway-donated", token: token)
        return response.giveawayDonated
    }




    func fetchSoundbytes(token: String, offset: Int, amount: Int, searchTerm: String, genre: String) async throws -> SoundbytesResponse {
        var path = "/soundbytes?offset=\(offset)&amount=\(amount)"
        if !searchTerm.isEmpty {
            path += "&search_term=\(searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchTerm)"
        }
        if !genre.isEmpty && genre != "All" {
            path += "&genre=\(genre.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? genre)"
        }
        return try await authenticatedGet(path, token: token)
    }

    func fetchSoundbyteGenres(token: String) async throws -> [SoundbyteGenre] {
        let response: SoundbyteGenresResponse = try await authenticatedGet("/soundbyte-genres", token: token)
        return response.genres
    }

    func fetchSoundbyteCredits(token: String) async throws -> Int {
        let response: SoundbyteCreditsResponse = try await authenticatedGet("/soundbyte-credits", token: token)
        return response.soundbyteCredits
    }

    func sendSoundbyte(token: String, soundbyteId: Int, announce: Bool) async throws -> SoundbyteSendResponse {
        appLog("Sending soundbyte \(soundbyteId) announce=\(announce)")
        guard let url = URL(string: "\(backendBaseURL)/soundbyte-send") else {
            throw AuthError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        TwitchAuthService.addPlatformHeaders(&request)

        struct SendBody: Encodable {
            let soundbyte_id: Int
            let announce: Int
        }
        request.httpBody = try JSONEncoder().encode(SendBody(soundbyte_id: soundbyteId, announce: announce ? 1 : 0))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.dashboardFailed
        }

        if httpResponse.statusCode != 200 {
            if let errorResp = try? JSONDecoder().decode(APIErrorOrSuccess.self, from: data) {
                throw AuthError.apiError(errorResp.error ?? "Failed to send soundbyte")
            }
            throw AuthError.apiError("Server error (\(httpResponse.statusCode))")
        }

        let decoded = try JSONDecoder().decode(APISuccessResponse<SoundbyteSendResponse>.self, from: data)
        guard let result = decoded.data else {
            throw AuthError.apiError("Invalid response")
        }
        return result
    }

    func fetchSoundbyteHistory(token: String) async throws -> [SoundbyteHistoryItem] {
        let response: SoundbyteHistoryResponse = try await authenticatedGet("/soundbyte-history", token: token)
        return response.history
    }

    func fetchBits(token: String) async throws -> [BitCheer] {
        let response: BitsResponse = try await authenticatedGet("/bits", token: token)
        return response.bits
    }

    func fetchDonations(token: String) async throws -> [Donation] {
        let response: DonationsResponse = try await authenticatedGet("/donations", token: token)
        return response.donations
    }


    func fetchStreamStatus() async -> StreamStatus {
        appLog("Checking stream status")
        // Check stream status via backend
        guard let statusURL = URL(string: "\(backendBaseURL)/stream-status") else {
            return StreamStatus(isLive: false, title: nil, gameName: nil, viewerCount: nil)
        }

        do {
            var statusReq = URLRequest(url: statusURL)
            TwitchAuthService.addPlatformHeaders(&statusReq)
            let (data, response) = try await URLSession.shared.data(for: statusReq)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return StreamStatus(isLive: false, title: nil, gameName: nil, viewerCount: nil)
            }
            let decoded = try JSONDecoder().decode(APISuccessResponse<StreamStatusResponse>.self, from: data)
            guard let status = decoded.data else {
                return StreamStatus(isLive: false, title: nil, gameName: nil, viewerCount: nil)
            }
            return StreamStatus(isLive: status.isLive, title: status.title, gameName: status.gameName, viewerCount: status.viewerCount)
        } catch {
            appLog("Auth: fetchStreamStatus error: \(error.localizedDescription)")
            return StreamStatus(isLive: false, title: nil, gameName: nil, viewerCount: nil)
        }
    }

    func fetchUserStatus(token: String) async throws -> UserStatus {
        appLog("Fetching user status from API")
        return try await authenticatedGet("/user-status", token: token)
    }

    // MARK: - Clip Voting

    func fetchClips(token: String?) async throws -> ClipVotingResponse {
        appLog("Fetching clips")
        if let token, !token.isEmpty {
            return try await authenticatedGet("/clips", token: token)
        }
        return try await unauthenticatedGet("/clips")
    }

    func submitClipVote(token: String, rankings: [String]) async throws -> ClipVoteResponse {
        appLog("Submitting clip vote with \(rankings.count) selections")
        return try await authenticatedPost("/clips/vote", token: token, body: ClipVoteBody(rankings: rankings))
    }

    // MARK: - Community Servers

    func fetchCommunityServers(token: String?) async throws -> CommunityServersResponse {
        appLog("Fetching community servers")
        if let token, !token.isEmpty {
            return try await authenticatedGet("/community-servers", token: token)
        }
        return try await unauthenticatedGet("/community-servers")
    }

    // MARK: - Generic Helpers

    private func authenticatedGet<T: Codable>(_ path: String, token: String) async throws -> T {
        guard let url = URL(string: "\(backendBaseURL)\(path)") else {
            throw AuthError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        TwitchAuthService.addPlatformHeaders(&request)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            appLog("Auth: GET \(path) failed with status \(code)")
            throw AuthError.dashboardFailed
        }

        let decoded = try JSONDecoder().decode(APISuccessResponse<T>.self, from: data)
        guard decoded.success, let result = decoded.data else {
            throw AuthError.dashboardFailed
        }
        return result
    }

    private func unauthenticatedGet<T: Codable>(_ path: String) async throws -> T {
        guard let url = URL(string: "\(backendBaseURL)\(path)") else {
            throw AuthError.invalidURL
        }

        var request = URLRequest(url: url)
        TwitchAuthService.addPlatformHeaders(&request)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            appLog("Auth: GET \(path) (unauth) failed with status \(code)")
            throw AuthError.dashboardFailed
        }

        let decoded = try JSONDecoder().decode(APISuccessResponse<T>.self, from: data)
        guard decoded.success, let result = decoded.data else {
            throw AuthError.dashboardFailed
        }
        return result
    }

    private func authenticatedPost<T: Codable, B: Encodable>(_ path: String, token: String, body: B) async throws -> T {
        guard let url = URL(string: "\(backendBaseURL)\(path)") else {
            throw AuthError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        TwitchAuthService.addPlatformHeaders(&request)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            appLog("Auth: POST \(path) failed with status \(code)")
            if let data = try? JSONDecoder().decode(APIErrorOrSuccess.self, from: (data)) {
                throw AuthError.apiError(data.error ?? "Request failed")
            }
            throw AuthError.dashboardFailed
        }

        let decoded = try JSONDecoder().decode(APISuccessResponse<T>.self, from: data)
        guard decoded.success, let result = decoded.data else {
            throw AuthError.dashboardFailed
        }
        return result
    }
}
