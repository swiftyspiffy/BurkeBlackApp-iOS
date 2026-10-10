import Foundation

func appLog(_ message: String) {}

final class FixtureProtocol: URLProtocol {
    static let lock = NSLock()
    static var requests: [URLRequest] = []
    static var responseStatus = 200
    static var renewalStatus = 200
    static var body = #"{"success":true,"data":{}}"#

    static func reset(body: String = #"{"success":true,"data":{}}"#, status: Int = 200, renewal: Int = 200) {
        lock.lock(); defer { lock.unlock() }
        requests = []; self.body = body; responseStatus = status; renewalStatus = renewal
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock()
        Self.requests.append(request)
        let renewal = request.url!.path == "/app/auth/renew"
        let status = renewal ? Self.renewalStatus : Self.responseStatus
        let data = (renewal ? "{}" : Self.body).data(using: .utf8)!
        Self.lock.unlock()
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status,
            httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

func requestBody(_ request: URLRequest) -> Data {
    if let body = request.httpBody { return body }
    guard let stream = request.httpBodyStream else { return Data() }
    stream.open(); defer { stream.close() }
    var result = Data(), buffer = [UInt8](repeating: 0, count: 1024)
    while stream.hasBytesAvailable {
        let count = stream.read(&buffer, maxLength: buffer.count)
        if count <= 0 { break }
        result.append(contentsOf: buffer.prefix(count))
    }
    return result
}

func checkContracts() async throws {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [FixtureProtocol.self]
    let session = URLSession(configuration: config)
    defer { session.invalidateAndCancel() }
    let api = APIService(session: session, goAPIEnabled: true)

    // Exercise the actual public APIService path, which previously bypassed routing.
    FixtureProtocol.reset(body: #"{"success":true,"data":{"fetched_at":"2026-01-01T00:00:00Z","is_stale":false,"channels":[{"key":"main","login":"fixture","display_name":"Fixture","twitch_url":"https://www.twitch.tv/fixture","is_live":true}]}}"#)
    let deck = try await api.fetchStreamDeck()
    precondition(deck.channels.first?.isLive == true)
    precondition(FixtureProtocol.requests.count == 1)
    precondition(FixtureProtocol.requests[0].value(forHTTPHeaderField: "X-Burke-Go-API") == "1")

    FixtureProtocol.reset(body: #"{"success":true,"data":{"items":[],"total":0,"limit":10,"offset":0}}"#)
    _ = try await api.fetchYouTubeVideos()
    _ = try await api.fetchYouTubeShorts()
    _ = try await api.fetchTikTokVideos()
    _ = try await api.fetchTwitterPosts()
    precondition(FixtureProtocol.requests.count == 4)
    precondition(FixtureProtocol.requests.allSatisfy { $0.value(forHTTPHeaderField: "X-Burke-Go-API") == "1" })

    // The widget uses the same anonymous transport: no session renewal is required.
    FixtureProtocol.reset()
    _ = try await AppAPIClient.data(for: URLRequest(url: URL(string: "https://api.burkeblack.tv/app/stream-status")!), session: session, goAPIEnabled: true)
    precondition(FixtureProtocol.requests.count == 1)
    precondition(FixtureProtocol.requests[0].value(forHTTPHeaderField: "X-Burke-Go-API") == "1")

    for method in ["GET", "POST", "PUT", "DELETE"] {
        FixtureProtocol.reset()
        var request = URLRequest(url: URL(string: "https://api.burkeblack.tv/app/device-token?fixture=1")!)
        request.httpMethod = method
        request.setValue("Bearer synthetic-session", forHTTPHeaderField: "Authorization")
        request.setValue("iOS", forHTTPHeaderField: "X-App-Platform")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = method == "GET" ? Data() : Data(#"{"device_token":"synthetic"}"#.utf8)
        if method != "GET" { request.httpBody = body }
        _ = try await AppAPIClient.data(for: request, session: session, goAPIEnabled: true)
        let seen = FixtureProtocol.requests
        precondition(seen.count == 2 && seen[0].url!.path == "/app/auth/renew")
        precondition(seen[0].httpMethod == "POST" && seen[0].url!.query == nil)
        precondition(seen[0].value(forHTTPHeaderField: "X-App-Platform") == "iOS")
        precondition(seen[1].httpMethod == method && seen[1].url == request.url)
        precondition(requestBody(seen[1]) == body)
        precondition(seen.allSatisfy { $0.value(forHTTPHeaderField: "X-Burke-Go-API") == "1" })
    }

    var authenticated = URLRequest(url: URL(string: "https://api.burkeblack.tv/app/twitch-token")!)
    authenticated.setValue("Bearer synthetic-session", forHTTPHeaderField: "Authorization")
    FixtureProtocol.reset()
    _ = try await AppAPIClient.data(for: authenticated, session: session, goAPIEnabled: true)
    precondition(FixtureProtocol.requests.map(\.httpMethod) == ["POST", "POST"])
    for status in [401, 500, 503] {
        FixtureProtocol.reset(renewal: status)
        let (_, response) = try await AppAPIClient.data(for: authenticated, session: session, goAPIEnabled: true)
        precondition((response as? HTTPURLResponse)?.statusCode == status)
        precondition(FixtureProtocol.requests.count == 1, "Failed renewal must not replay a write or fall back")
    }
    for (url, enabled) in [("https://api.burkeblack.tv/app/twitch-token", false), ("https://api.twitch.tv/helix/users", true)] {
        FixtureProtocol.reset()
        var request = URLRequest(url: URL(string: url)!)
        request.setValue("Bearer synthetic-session", forHTTPHeaderField: "Authorization")
        _ = try await AppAPIClient.data(for: request, session: session, goAPIEnabled: enabled)
        precondition(FixtureProtocol.requests.count == 1)
        precondition(FixtureProtocol.requests[0].httpMethod == "GET")
        precondition(FixtureProtocol.requests[0].value(forHTTPHeaderField: "X-Burke-Go-API") == nil)
    }
    FixtureProtocol.reset(status: 502)
    do { _ = try await api.fetchStreamDeck(); fatalError("HTTP failure accepted") }
    catch APIError.httpError(502) {}
    print("Public app requests, widget transport, renewal failures, and write preservation passed")
}

Task {
    do { try await checkContracts(); exit(0) }
    catch { print("API contract failed: \(error)"); exit(1) }
}
dispatchMain()
