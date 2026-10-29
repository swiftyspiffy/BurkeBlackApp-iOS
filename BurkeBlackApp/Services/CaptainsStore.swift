import Foundation

@MainActor
protocol CaptainsStore {
    func lastElection() -> String?
    func markElection(_ key: String)
    func pendingVote(userID: String) throws -> CaptainVoteRequest?
    func savePending(_ vote: CaptainVoteRequest?, userID: String) throws
}

// Vote receipts contain no credentials. Atomic files survive app termination;
// an unreadable receipt blocks new spending rather than silently replacing it.
@MainActor
final class LocalCaptainsStore: CaptainsStore {
    private let directory: URL
    private let defaults: UserDefaults

    init(directory: URL? = nil, defaults: UserDefaults = .standard) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CaptainsVotes", isDirectory: true)
        self.defaults = defaults
    }

    func lastElection() -> String? { defaults.string(forKey: "settings.captains.lastElection") }
    func markElection(_ key: String) { defaults.set(key, forKey: "settings.captains.lastElection") }

    private func url(_ userID: String) throws -> URL {
        guard CaptainSession(token: "", userID: userID).hasUserID else { throw CaptainsError.storage }
        return directory.appendingPathComponent("\(userID).json")
    }

    func pendingVote(userID: String) throws -> CaptainVoteRequest? {
        let file = try url(userID)
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        let vote = try JSONDecoder().decode(CaptainVoteRequest.self, from: Data(contentsOf: file))
        guard vote.isValid else { throw CaptainsError.storage }
        return vote
    }

    func savePending(_ vote: CaptainVoteRequest?, userID: String) throws {
        let file = try url(userID)
        if let vote {
            guard vote.isValid else { throw CaptainsError.storage }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(vote).write(to: file, options: .atomic)
        } else if FileManager.default.fileExists(atPath: file.path) {
            try FileManager.default.removeItem(at: file)
        }
    }
}
