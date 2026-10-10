import Foundation

actor APIService {
    static let shared = APIService()

    private let baseURL = "https://api.burkeblack.tv/app"
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private let session: URLSession
    private let goAPIEnabled: Bool

    init(session: URLSession = .shared, goAPIEnabled: Bool = MobileSessionContract.enabled) {
        self.session = session
        self.goAPIEnabled = goAPIEnabled
    }

    func fetchYouTubeVideos(limit: Int = 10) async throws -> YouTubeResponse {
        appLog("APIService: fetching youtube videos")
        return try await request("/socials/youtube-videos?limit=\(limit)")
    }

    func fetchYouTubeShorts(limit: Int = 10) async throws -> YouTubeResponse {
        appLog("APIService: fetching youtube shorts")
        return try await request("/socials/youtube-shorts?limit=\(limit)")
    }

    func fetchTikTokVideos(limit: Int = 10) async throws -> TikTokResponse {
        appLog("APIService: fetching tiktok videos")
        return try await request("/socials/tiktok-videos?limit=\(limit)")
    }

    func fetchTwitterPosts(limit: Int = 10) async throws -> TwitterResponse {
        appLog("APIService: fetching twitter posts")
        return try await request("/socials/twitter-posts?limit=\(limit)")
    }

    func fetchStreamDeck() async throws -> StreamDeckData {
        appLog("APIService: fetching stream deck")
        return try await request("/stream-deck")
    }

    private func request<T: Codable>(_ path: String) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        let (data, response) = try await AppAPIClient.data(
            for: URLRequest(url: url), session: session, goAPIEnabled: goAPIEnabled
        )

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            appLog("API: \(path) failed with status \(httpResponse.statusCode)")
            throw APIError.httpError(httpResponse.statusCode)
        }

        let apiResponse: APIResponse<T>
        do {
            apiResponse = try decoder.decode(APIResponse<T>.self, from: data)
        } catch {
            appLog("API: \(path) decode error: \(error)")
            throw error
        }

        guard apiResponse.success, let responseData = apiResponse.data else {
            throw APIError.apiError(apiResponse.error ?? "Unknown error")
        }

        appLog("API: \(path) succeeded")
        return responseData
    }
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "Server error (\(code))"
        case .apiError(let message):
            return message
        }
    }
}
