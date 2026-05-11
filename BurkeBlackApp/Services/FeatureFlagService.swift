import Foundation

@MainActor
class FeatureFlagService: ObservableObject {
    static let shared = FeatureFlagService()

    @Published private(set) var flags: [String: Bool] = [:]
    @Published private(set) var loaded = false

    private let baseURL = "https://api.burkeblack.tv/app"

    private init() {}

    func load() async {
        guard let url = URL(string: "\(baseURL)/feature-flags") else { return }

        var request = URLRequest(url: url)
        if let token = AccountViewModel.getBearerToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        TwitchAuthService.addPlatformHeaders(&request)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                appLog("FeatureFlags: fetch failed (status \((response as? HTTPURLResponse)?.statusCode ?? 0))")
                return
            }

            let decoded = try JSONDecoder().decode(FeatureFlagResponse.self, from: data)
            if decoded.success, let flagData = decoded.data {
                flags = flagData.flags
                loaded = true
                appLog("FeatureFlags: loaded \(flags.count) flags")
            }
        } catch {
            appLog("FeatureFlags: fetch error: \(error.localizedDescription)")
        }
    }

    func isEnabled(_ key: String) -> Bool {
        flags[key] ?? false
    }
}

private struct FeatureFlagResponse: Codable {
    let success: Bool
    let data: FeatureFlagData?
}

private struct FeatureFlagData: Codable {
    let flags: [String: Bool]
}
