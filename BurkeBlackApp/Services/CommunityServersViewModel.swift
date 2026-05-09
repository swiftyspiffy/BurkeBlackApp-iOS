import Foundation

@MainActor
class CommunityServersViewModel: ObservableObject {
    @Published var servers: [CommunityServer] = []
    @Published var isLoading = false
    @Published var error: String?

    private var token: String? {
        UserDefaults.standard.string(forKey: "app_bearer_token")
    }

    init() {
        Task { await fetchServers() }
    }

    func fetchServers() async {
        isLoading = true
        error = nil
        do {
            let response = try await TwitchAuthService.shared.fetchCommunityServers(token: token)
            servers = response.servers
            appLog("Servers: loaded \(servers.count) community servers")
        } catch {
            self.error = "Could not reach the server"
            appLog("Servers error: \(error.localizedDescription)")
        }
        isLoading = false
    }
}
