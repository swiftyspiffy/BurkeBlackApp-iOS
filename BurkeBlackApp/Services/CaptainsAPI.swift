import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

protocol CaptainsDataSource {
    func election() async throws -> CaptainElection
    func details() async throws -> CaptainDetails
    func renew(_ identity: CaptainSession) async throws
    func balance(_ identity: CaptainSession) async throws -> Int
    func vote(_ identity: CaptainSession, request: CaptainVoteRequest) async throws -> String
}

// A separate transport: Captains responses are bare JSON, and the app API's
// host-based renewal cannot renew requests sent to the overlays host.
final class CaptainsAPI: CaptainsDataSource {
    private let session: URLSession
    private let baseURL: URL

    init(session: URLSession? = nil, baseURL: URL = CaptainsContract.baseURL.appendingPathComponent("api/v1/")) {
        self.session = session ?? URLSession(configuration: .ephemeral, delegate: NoCaptainsRedirects(), delegateQueue: nil)
        self.baseURL = baseURL
    }

    func election() async throws -> CaptainElection {
        async let candidates: [Captain] = read("elections/results")
        async let schedule: CaptainSchedule = read("elections/schedule")
        return try await CaptainElection(candidates: candidates, schedule: schedule)
    }

    func details() async throws -> CaptainDetails {
        async let crew: [Captain] = read("captains/all")
        async let winner: Captain? = read("elections/currentWinner")
        async let current: [CaptainRanking] = read("elections/leaderboard/current")
        async let lifetime: [CaptainRanking] = read("elections/leaderboard/past")
        return try await CaptainDetails(crew: crew, winner: winner, current: current, lifetime: lifetime)
    }

    func renew(_ identity: CaptainSession) async throws {
        guard identity.hasUserID else { throw CaptainsError.authenticationRequired }
        var request = URLRequest(url: URL(string: "https://api.burkeblack.tv/app/auth/renew")!)
        request.httpMethod = "POST"
        request.setValue("1", forHTTPHeaderField: "X-Burke-Go-API")
        request.setValue("Bearer \(identity.token)", forHTTPHeaderField: "Authorization")
        let data = try await send(request)
        struct Renewal: Decodable { let success: Bool }
        guard try JSONDecoder().decode(Renewal.self, from: data).success else { throw CaptainsError.authenticationRequired }
    }

    func balance(_ identity: CaptainSession) async throws -> Int {
        try await renew(identity)
        struct Balance: Decodable { let balance: CaptainCount }
        let value: Balance = try await read("elections/\(identity.userID)/tokenBalance", identity: identity)
        return value.balance.value
    }

    func vote(_ identity: CaptainSession, request: CaptainVoteRequest) async throws -> String {
        guard request.isValid else { throw CaptainsError.invalidRequest }
        try await renew(identity)
        var call = URLRequest(url: baseURL.appendingPathComponent("elections/vote"))
        call.httpMethod = "POST"
        call.setValue("Bearer \(identity.token)", forHTTPHeaderField: "Authorization")
        call.setValue("application/json", forHTTPHeaderField: "Content-Type")
        call.httpBody = try JSONEncoder().encode(request)
        struct Result: Decodable { let result: String }
        return try JSONDecoder().decode(Result.self, from: await send(call)).result
    }

    private func read<T: Decodable>(_ path: String, identity: CaptainSession? = nil) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        if let identity { request.setValue("Bearer \(identity.token)", forHTTPHeaderField: "Authorization") }
        return try JSONDecoder().decode(T.self, from: await send(request))
    }

    private func send(_ original: URLRequest) async throws -> Data {
        var request = original
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("iOS", forHTTPHeaderField: "X-App-Platform")
        #if canImport(UIKit)
        request.setValue(UIDevice.current.systemVersion, forHTTPHeaderField: "X-App-Platform-Version")
        #endif
        request.setValue(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?", forHTTPHeaderField: "X-App-Version")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw CaptainsError.unavailable }
        if http.statusCode == 401 || http.statusCode == 403 { throw CaptainsError.authenticationRequired }
        guard (200..<300).contains(http.statusCode) else { throw CaptainsError.unavailable }
        return data
    }
}

private final class NoCaptainsRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
