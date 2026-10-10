import Foundation

// Shared by the app and widget so every app-API request uses the same protocol.
enum AppAPIClient {
    static func data(
        for original: URLRequest,
        session: URLSession = .shared,
        goAPIEnabled: Bool = MobileSessionContract.enabled
    ) async throws -> (Data, URLResponse) {
        guard MobileSessionContract.usesGoAPI(original.url, enabled: goAPIEnabled) else {
            return try await session.data(for: original)
        }
        var request = original
        request.setValue("1", forHTTPHeaderField: "X-Burke-Go-API")
        if let authorization = request.value(forHTTPHeaderField: "Authorization"), !authorization.isEmpty,
           request.url?.path != "/app/auth/renew" {
            var renewal = URLRequest(url: URL(string: "https://api.burkeblack.tv/app/auth/renew")!)
            renewal.httpMethod = "POST"
            renewal.setValue(authorization, forHTTPHeaderField: "Authorization")
            renewal.setValue("1", forHTTPHeaderField: "X-Burke-Go-API")
            for field in ["X-App-Platform", "X-App-Platform-Version", "X-App-Version"] {
                renewal.setValue(request.value(forHTTPHeaderField: field), forHTTPHeaderField: field)
            }
            let result = try await session.data(for: renewal)
            guard let response = result.1 as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
                return result
            }
        }
        if request.url?.path == "/app/twitch-token" { request.httpMethod = "POST" }
        return try await session.data(for: request)
    }
}
