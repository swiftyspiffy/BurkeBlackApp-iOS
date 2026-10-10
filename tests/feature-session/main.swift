import Foundation

func appLog(_ message: String) {}

// A session in the app's credential provider with no legacy UserDefaults token.
@MainActor enum AccountViewModel {
    static func getBearerToken() -> String? { "synthetic-keychain-session" }
}

@MainActor final class TwitchAuthService {
    static let shared = TwitchAuthService()
    var clipTokens: [String?] = []
    var serverTokens: [String?] = []
    var voteTokens: [String] = []
    func fetchClips(token: String?) async throws -> ClipVotingResponse {
        clipTokens.append(token)
        return try JSONDecoder().decode(ClipVotingResponse.self, from: Data(#"{"month":"2026-01","period_start":"2026-01-01","period_end":"2026-01-31","clips":[],"total_voters":0,"authenticated":true,"user_has_voted":false,"config":{"voting_mode":"single","vote_count":1}}"#.utf8))
    }
    func fetchCommunityServers(token: String?) async throws -> CommunityServersResponse {
        serverTokens.append(token)
        return try JSONDecoder().decode(CommunityServersResponse.self, from: Data(#"{"servers":[],"authenticated":true}"#.utf8))
    }
    func submitClipVote(token: String, rankings: [String]) async throws -> ClipVoteResponse {
        voteTokens.append(token)
        precondition(rankings == ["synthetic-clip"])
        return ClipVoteResponse(month: "2026-01", message: "Recorded")
    }
}

Task { @MainActor in
    precondition(UserDefaults.standard.string(forKey: "app_bearer_token") == nil)
    let clips = ClipVotingViewModel()
    let servers = CommunityServersViewModel()
    await clips.fetchClips()
    await servers.fetchServers()
    clips.selections = ["synthetic-clip"]
    await clips.submitVote()
    let api = TwitchAuthService.shared
    precondition(!api.clipTokens.isEmpty && api.clipTokens.allSatisfy { $0 == "synthetic-keychain-session" })
    precondition(!api.serverTokens.isEmpty && api.serverTokens.allSatisfy { $0 == "synthetic-keychain-session" })
    precondition(api.voteTokens == ["synthetic-keychain-session"] && clips.submitSuccess)
    print("Clip reads, voting, and community access use the current credential provider")
    exit(0)
}
dispatchMain()
