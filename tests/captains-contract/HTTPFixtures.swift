import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class CaptainsFixtureProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var recorded: [URLRequest] = []
    static var renewalStatus = 200
    static var privateStatus = 200
    static var renewalSuccess = true

    static var requests: [URLRequest] {
        lock.lock(); defer { lock.unlock() }; return recorded
    }
    static func reset(renewal: Int = 200, status: Int = 200, success: Bool = true) {
        lock.lock(); defer { lock.unlock() }
        recorded = []; renewalStatus = renewal; privateStatus = status; renewalSuccess = success
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock()
        Self.recorded.append(request)
        let path = request.url!.path
        let renewing = path == "/app/auth/renew"
        let isPrivate = request.value(forHTTPHeaderField: "Authorization") != nil
        let status = renewing ? Self.renewalStatus : isPrivate ? Self.privateStatus : 200
        let body: String
        switch path {
        case "/app/auth/renew": body = "{\"success\":\(Self.renewalSuccess),\"data\":{}}"
        case "/captain/api/v1/elections/schedule": body = #"{"start":"2026-10-29T00:00:00Z","end":"2026-11-01T22:00:00Z","now":"2026-10-29T01:00:00Z"}"#
        case "/captain/api/v1/elections/currentWinner": body = "null"
        case "/captain/api/v1/elections/123/tokenBalance": body = #"{"balance":12}"#
        case "/captain/api/v1/elections/vote": body = #"{"result":"success"}"#
        default: body = "[]"
        }
        Self.lock.unlock()
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private func capturedBody(_ request: URLRequest) -> Data {
    if let data = request.httpBody { return data }
    guard let stream = request.httpBodyStream else { return Data() }
    stream.open(); defer { stream.close() }
    var data = Data(), bytes = [UInt8](repeating: 0, count: 1024)
    while stream.hasBytesAvailable {
        let count = stream.read(&bytes, maxLength: bytes.count)
        if count <= 0 { break }
        data.append(contentsOf: bytes.prefix(count))
    }
    return data
}

func httpContracts() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [CaptainsFixtureProtocol.self]
    let session = URLSession(configuration: configuration)
    defer { session.invalidateAndCancel() }
    let api = CaptainsAPI(session: session)
    CaptainsFixtureProtocol.reset()
    _ = try await api.election()
    let details = try await api.details()
    precondition(details.winner == nil)
    precondition(CaptainsFixtureProtocol.requests.count == 6)
    precondition(CaptainsFixtureProtocol.requests.allSatisfy {
        $0.httpMethod == "GET" && $0.value(forHTTPHeaderField: "Authorization") == nil &&
        $0.value(forHTTPHeaderField: "X-Burke-Go-API") == nil && $0.timeoutInterval == 15
    })
    let identity = CaptainSession(token: "synthetic-session", userID: "123")
    CaptainsFixtureProtocol.reset()
    let balance = try await api.balance(identity)
    precondition(balance == 12)
    var requests = CaptainsFixtureProtocol.requests
    precondition(requests.map { $0.url!.path } == ["/app/auth/renew", "/captain/api/v1/elections/123/tokenBalance"])
    precondition(requests[0].httpMethod == "POST" && requests[0].value(forHTTPHeaderField: "X-Burke-Go-API") == "1")
    precondition(requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == "Bearer synthetic-session" && $0.value(forHTTPHeaderField: "X-App-Platform") == "iOS" })

    let vote = CaptainVoteRequest(captain: "captain-one", amount: 2, requestID: UUID().uuidString)
    CaptainsFixtureProtocol.reset()
    let result = try await api.vote(identity, request: vote)
    requests = CaptainsFixtureProtocol.requests
    precondition(result == "success" && requests.count == 2 && requests[1].httpMethod == "POST")
    precondition(requests[1].url!.path == "/captain/api/v1/elections/vote")
    let sentVote = try JSONDecoder().decode(CaptainVoteRequest.self, from: capturedBody(requests[1]))
    precondition(sentVote == vote)

    for status in [401, 403, 500, 503] {
        CaptainsFixtureProtocol.reset(renewal: status)
        do { _ = try await api.vote(identity, request: vote); fatalError("Failed renewal accepted") } catch {}
        precondition(CaptainsFixtureProtocol.requests.count == 1, "Write dispatched despite failed renewal")
    }
    CaptainsFixtureProtocol.reset(success: false)
    do { _ = try await api.balance(identity); fatalError("Unsuccessful renewal accepted") } catch {}
    precondition(CaptainsFixtureProtocol.requests.count == 1)

    CaptainsFixtureProtocol.reset(status: 503)
    do { _ = try await api.vote(identity, request: vote); fatalError("Failed vote accepted") } catch {}
    precondition(CaptainsFixtureProtocol.requests.count == 2, "Write was automatically retried")

    CaptainsFixtureProtocol.reset()
    let invalid = CaptainVoteRequest(captain: "captain-one", amount: 0, requestID: vote.requestID)
    do { _ = try await api.vote(identity, request: invalid); fatalError("Invalid vote accepted") } catch {}
    precondition(CaptainsFixtureProtocol.requests.isEmpty)
    do { _ = try await api.balance(CaptainSession(token: "synthetic", userID: "../unsafe")); fatalError("Invalid identity accepted") } catch {}
    precondition(CaptainsFixtureProtocol.requests.isEmpty)
    print("Captains HTTP decoding, anonymous reads, session renewal, and write contracts passed")
}
