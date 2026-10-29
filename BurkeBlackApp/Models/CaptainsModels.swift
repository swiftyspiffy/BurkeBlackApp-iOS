import Foundation

enum CaptainsContract {
    static let channelID = "44338537"
    static let baseURL = URL(string: "https://overlays.burkeblack.tv/captain/")!
    static let maximumVotes = 1_000_000

    static func date(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}

// Results use strings for counts; balances and leaderboards use JSON numbers.
struct CaptainCount: Codable, Equatable {
    let value: Int
    init(_ value: Int) { self.value = value }
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let number = (try? container.decode(Int.self)) ?? (try? container.decode(String.self)).flatMap(Int.init)
        guard let number, number >= 0 else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid captain count")
        }
        value = number
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

struct Captain: Decodable, Identifiable, Equatable {
    let id: String
    let name: String
    let title: String?
    let lore: String?
    let portrait: String?
    let order: Int?
    let rank: Int?
    let votes: CaptainCount?

    var voteCount: Int { votes?.value ?? 0 }
    var portraitURL: URL? {
        guard let portrait, !portrait.isEmpty,
              portrait.range(of: "^[a-zA-Z0-9-]+$", options: .regularExpression) != nil else { return nil }
        return CaptainsContract.baseURL.appendingPathComponent("api/v1/assets/\(portrait)")
    }
}

struct CaptainSchedule: Decodable, Equatable {
    let start: Date
    let end: Date
    let now: Date
    var key: String { "\(CaptainsContract.channelID):\(start.timeIntervalSince1970)" }

    init(start: Date, end: Date, now: Date) {
        self.start = start; self.end = end; self.now = now
    }

    private enum CodingKeys: String, CodingKey { case start, end, now }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func date(_ key: CodingKeys) throws -> Date {
            let value = try container.decode(String.self, forKey: key)
            guard let date = CaptainsContract.date(value) else {
                throw DecodingError.dataCorruptedError(forKey: key, in: container, debugDescription: "Invalid election date")
            }
            return date
        }
        start = try date(.start); end = try date(.end); now = try date(.now)
        guard end > start else {
            throw DecodingError.dataCorruptedError(forKey: .end, in: container, debugDescription: "Invalid election interval")
        }
    }
}

struct CaptainRanking: Decodable, Identifiable {
    let id: String
    let name: String?
    let votes: CaptainCount
    let rank: Int?
}

struct CaptainSession: Equatable {
    let token: String
    let userID: String
    var hasUserID: Bool { !userID.isEmpty && userID.allSatisfy { $0.isASCII && $0.isNumber } }
}

struct CaptainVoteRequest: Codable, Equatable {
    let captain: String
    let amount: Int
    let requestID: String
    enum CodingKeys: String, CodingKey {
        case captain, amount
        case requestID = "request_id"
    }
    var isValid: Bool {
        !captain.isEmpty && (1...CaptainsContract.maximumVotes).contains(amount) &&
        requestID.range(of: "^[a-zA-Z0-9-]{16,64}$", options: .regularExpression) != nil
    }
}

struct CaptainElection {
    let candidates: [Captain]
    let schedule: CaptainSchedule
}

struct CaptainDetails {
    let crew: [Captain]
    let winner: Captain?
    let current: [CaptainRanking]
    let lifetime: [CaptainRanking]
}

enum CaptainsError: Error { case authenticationRequired, unavailable, invalidRequest, storage }
