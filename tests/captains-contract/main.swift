import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try JSONDecoder().decode(type, from: Data(json.utf8))
}

let captainJSON = #"{"id":"captain-one","name":"Cap","title":"The Captain","portrait":"portrait-one","order":1,"rank":1,"votes":"7"}"#
let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)

@MainActor final class MemoryStore: CaptainsStore {
    var last: String?
    var receipts: [String: CaptainVoteRequest] = [:]
    var failRead = false
    var failWrite = false
    var failClear = false
    func lastElection() -> String? { last }
    func markElection(_ key: String) { last = key }
    func pendingVote(userID: String) throws -> CaptainVoteRequest? {
        if failRead { throw CaptainsError.storage }
        return receipts[userID]
    }
    func savePending(_ vote: CaptainVoteRequest?, userID: String) throws {
        if failWrite || (vote == nil && failClear) { throw CaptainsError.storage }
        receipts[userID] = vote
    }
}

struct SilentSocket: CaptainsSocketSource {
    func events(session: CaptainSession?) -> AsyncThrowingStream<CaptainSocketEvent, Error> {
        AsyncThrowingStream { _ in }
    }
}

@MainActor final class FixtureAPI: CaptainsDataSource {
    var electionValue = CaptainElection(candidates: [try! decode(Captain.self, captainJSON)],
        schedule: CaptainSchedule(start: fixedNow.addingTimeInterval(-60), end: fixedNow.addingTimeInterval(3600), now: fixedNow))
    var balanceValue = 10
    var electionError = false
    var detailsError = false
    var balanceAuthError = false
    var voteResult = "success"
    var lostResponse = false
    var voteCalls: [CaptainVoteRequest] = []
    var votedUsers: [String] = []
    var voteGate: CheckedContinuation<Void, Never>?
    var holdVote = false
    var holdBalance = false
    var balanceGate: CheckedContinuation<Void, Never>?
    func election() async throws -> CaptainElection {
        if electionError { throw CaptainsError.unavailable }
        return electionValue
    }
    func details() async throws -> CaptainDetails {
        if detailsError { throw CaptainsError.unavailable }
        return CaptainDetails(crew: electionValue.candidates, winner: nil, current: [], lifetime: [])
    }
    func renew(_ identity: CaptainSession) async throws {}
    func balance(_ identity: CaptainSession) async throws -> Int {
        let value = balanceValue
        if holdBalance { await withCheckedContinuation { balanceGate = $0 } }
        if balanceAuthError { throw CaptainsError.authenticationRequired }
        return value
    }
    func vote(_ identity: CaptainSession, request: CaptainVoteRequest) async throws -> String {
        voteCalls.append(request); votedUsers.append(identity.userID)
        if holdVote { await withCheckedContinuation { voteGate = $0 } }
        if lostResponse { throw URLError(.networkConnectionLost) }
        return voteResult
    }
}

@MainActor func settle(_ condition: () -> Bool) async {
    for _ in 0..<1000 {
        if condition() { return }
        try? await Task.sleep(nanoseconds: 1_000_000)
    }
    fatalError("Timed out waiting for fixture state")
}

@MainActor func makeModel(_ api: FixtureAPI, _ store: MemoryStore, _ coordinator: EventPopupCoordinator? = nil) -> CaptainsViewModel {
    CaptainsViewModel(api: api, store: store, socket: SilentSocket(), popups: coordinator ?? EventPopupCoordinator(), clock: { fixedNow })
}

@MainActor func stateContracts() async throws {
    let api = FixtureAPI(), store = MemoryStore(), coordinator = EventPopupCoordinator()
    var model = makeModel(api, store, coordinator)
    model.setSession(CaptainSession(token: "test-token", userID: "123"))
    model.start()
    await settle { !model.loading && model.balance == 10 }
    precondition(model.candidates.count == 1 && coordinator.expanded == .captains)
    precondition(model.remaining(at: fixedNow) == 3600 && model.isActive(at: fixedNow))
    coordinator.minimize(.captains)
    model.refresh()
    await settle { !model.loading }
    precondition(coordinator.expanded == nil, "Tally refresh reopened an alert")
    model.stop()
    let restart = makeModel(api, store)
    restart.start()
    await settle { !restart.loading }
    precondition(restart.popups.expanded == nil, "Restart reopened a seen election")
    restart.stop()
    model.start()
    await settle { !model.loading }
    coordinator.present(.captains)
    coordinator.present(.giveaway)
    precondition(coordinator.expanded == .giveaway && coordinator.available.contains(.captains))
    coordinator.present(.captains)
    precondition(coordinator.expanded == .captains && coordinator.available.contains(.giveaway))
    model.setScreenVisible(true)
    precondition(coordinator.expanded == .captains, "The full Captains UI is the expanded election")
    coordinator.present(.captains)
    precondition(coordinator.expanded == .captains, "A repeated alert changed full-screen presentation")
    coordinator.present(.giveaway)
    precondition(coordinator.expanded == .giveaway)
    model.setScreenVisible(false)
    coordinator.present(.captains)
    coordinator.setAvailable(.captains, false)
    precondition(coordinator.expanded == .captains, "Crew browsing closed when the election ended")
    coordinator.present(.giveaway)
    model.setPopupsEnabled(false)
    api.electionValue = CaptainElection(candidates: api.electionValue.candidates,
        schedule: CaptainSchedule(start: fixedNow.addingTimeInterval(-30), end: fixedNow.addingTimeInterval(7200), now: fixedNow.addingTimeInterval(300)))
    model.refresh()
    await settle { !model.loading }
    precondition(coordinator.expanded == .giveaway && model.serverOffset == 300)
    model.setPopupsEnabled(true)
    precondition(coordinator.expanded == .captains)
    precondition(model.remaining(at: fixedNow) == 6900)
    model.setPopupsEnabled(false)
    precondition(coordinator.expanded == nil && coordinator.available.contains(.captains))

    let captain = model.candidates[0]
    model.choose(captain)
    for invalid in ["", "0", "-1", "1.5", "11", "1000001", "999999999999999999999999", "１２", "1e2"] {
        model.amount = invalid
        precondition(model.validAmount == nil)
    }
    model.amount = "2"
    api.lostResponse = true
    await model.submitVote()
    precondition(model.pending?.amount == 2 && store.receipts["123"] == model.pending && api.voteCalls.count == 1)
    let receipt = model.pending!
    model.stop()
    let recovered = makeModel(api, store)
    recovered.setSession(CaptainSession(token: "new-test-token", userID: "123"))
    precondition(recovered.pending == receipt)
    // Recover even after the original election has closed.
    api.electionValue = CaptainElection(candidates: [], schedule: CaptainSchedule(start: fixedNow.addingTimeInterval(-7200), end: fixedNow.addingTimeInterval(-1), now: fixedNow))
    api.lostResponse = false
    await recovered.submitVote()
    precondition(api.voteCalls.last == receipt && recovered.pending == nil && store.receipts["123"] == nil)

    model = makeModel(api, store)
    model.setSession(CaptainSession(token: "test-token", userID: "123"))
    model.start()
    api.electionValue = CaptainElection(candidates: [captain], schedule: CaptainSchedule(start: fixedNow.addingTimeInterval(-60), end: fixedNow.addingTimeInterval(3600), now: fixedNow))
    model.refresh(); await settle { !model.loading && !model.candidates.isEmpty }
    model.choose(captain); model.amount = "1"
    store.failWrite = true
    let callsBefore = api.voteCalls.count
    await model.submitVote()
    precondition(api.voteCalls.count == callsBefore && model.pending == nil)
    store.failWrite = false
    api.voteResult = "insufficient_tokens"
    await model.submitVote()
    precondition(model.pending == nil && model.notice?.contains("balance or the election changed") == true)
    api.voteResult = "unknown"
    model.choose(captain); await model.submitVote()
    precondition(model.pending != nil, "Unknown results must remain recoverable")
    api.voteResult = "success"; store.failClear = true
    await model.submitVote()
    precondition(model.pending != nil, "Failed receipt cleanup must remain recoverable")
    store.failClear = false
    await model.submitVote()
    precondition(model.pending == nil)

    // One dispatched request stays locked through double taps and account changes.
    api.holdVote = true
    model.choose(captain)
    let first = Task { await model.submitVote() }
    await settle { api.voteGate != nil }
    let count = api.voteCalls.count
    await model.submitVote()
    precondition(api.voteCalls.count == count)
    model.setSession(CaptainSession(token: "other-token", userID: "456"))
    precondition(model.pending == nil && model.balance == nil)
    await model.submitVote()
    precondition(api.voteCalls.count == count)
    api.voteGate?.resume(); api.voteGate = nil
    await first.value
    precondition(model.notice == nil && store.receipts["123"] == nil && api.votedUsers.last == "123")
    api.holdVote = false
    model.stop()

    // Backgrounding does not discard a confirmed receipt or its result.
    let background = makeModel(api, MemoryStore())
    background.setSession(CaptainSession(token: "token", userID: "123"))
    background.start(); await settle { !background.loading }
    background.choose(captain)
    api.holdVote = true
    let backgroundVote = Task { await background.submitVote() }
    await settle { api.voteGate != nil }
    background.stop()
    api.voteGate?.resume(); api.voteGate = nil
    await backgroundVote.value
    precondition(background.pending == nil && background.notice?.contains("cast!") == true)
    api.holdVote = false
    let callsAfterBackground = api.voteCalls.count

    store.failRead = true
    let blocked = makeModel(api, store)
    blocked.setSession(CaptainSession(token: "token", userID: "123"))
    precondition(!blocked.pendingLoaded && blocked.storageError != nil)
    await blocked.submitVote()
    precondition(api.voteCalls.count == callsAfterBackground)
    store.failRead = false
    blocked.retry()
    precondition(blocked.pendingLoaded)

    // Expired authentication leaves public election data visible.
    api.balanceAuthError = true
    blocked.start()
    await settle { blocked.authRequired && !blocked.loading }
    precondition(blocked.balance == nil && !blocked.candidates.isEmpty)
    blocked.stop()
    api.balanceAuthError = false

    // A late wallet response from the previous account cannot populate the new one.
    api.holdBalance = true
    let stale = makeModel(api, MemoryStore())
    stale.setSession(CaptainSession(token: "one", userID: "123")); stale.start()
    await settle { api.balanceGate != nil }
    stale.setSession(nil)
    api.balanceGate?.resume(); api.balanceGate = nil
    await settle { !stale.loading }
    precondition(stale.balance == nil && stale.session == nil)
    stale.stop()
    api.holdBalance = false

    // Public election data survives independent crew/wallet failures.
    let partial = makeModel(api, MemoryStore())
    api.detailsError = true
    partial.setScreenVisible(true)
    partial.start(); await settle { !partial.loading }
    precondition(!partial.candidates.isEmpty && partial.detailsError != nil)
    api.electionError = true
    partial.refresh(); await settle { !partial.loading }
    precondition(!partial.candidates.isEmpty && partial.error != nil)
    partial.stop()
    api.detailsError = false; api.electionError = false
    print("Captains presentation, clock, validation, recovery, storage, and identity contracts passed")
}

func modelContracts() throws {
    let captain = try decode(Captain.self, captainJSON)
    precondition(captain.voteCount == 7 && captain.portraitURL?.path == "/captain/api/v1/assets/portrait-one")
    let numeric = try decode(CaptainCount.self, "5")
    let noWinner = try decode(Captain?.self, "null")
    precondition(numeric.value == 5 && noWinner == nil)
    for invalid in ["-1", "\"-1\"", "1.5", "null", "\"broken\""] {
        do { _ = try decode(CaptainCount.self, invalid); fatalError("Invalid count accepted") } catch {}
    }
    let schedule = try decode(CaptainSchedule.self, #"{"start":"2026-10-29T00:00:00Z","end":"2026-11-01T22:00:00.000Z","now":"2026-10-29T01:00:00Z"}"#)
    precondition(schedule.end > schedule.start)
    do { _ = try decode(CaptainSchedule.self, #"{"start":"2026-10-29T00:00:00Z","end":"invalid","now":"2026-10-29T01:00:00Z"}"#); fatalError("Invalid date accepted") } catch {}
    func packet(_ type: String, version: Int = 1, channel: String = "44338537") -> Data {
        Data("{\"version\":\(version),\"channel_id\":\"\(channel)\",\"type\":\"\(type)\"}".utf8)
    }
    precondition(CaptainsSocketProtocol.event(packet("kraken.captain.vote_change")) == .refresh)
    precondition(CaptainsSocketProtocol.event(packet("kraken.captain.ping")) == .connected)
    precondition(CaptainsSocketProtocol.event(packet("kraken.captain.vote_change", version: 2)) == nil)
    precondition(CaptainsSocketProtocol.event(packet("kraken.captain.vote_change", channel: "40876073")) == nil)
    precondition(CaptainsSocketProtocol.event(packet("newraffle")) == nil)
    precondition(CaptainsSocketProtocol.event(Data("broken".utf8)) == nil)
    let anonymous = try JSONSerialization.jsonObject(with: CaptainsSocketProtocol.identity(nil)) as! [String: Any]
    precondition(anonymous["token"] == nil)
    let identified = try JSONSerialization.jsonObject(with: CaptainsSocketProtocol.identity(CaptainSession(token: "synthetic", userID: "123"))) as! [String: Any]
    precondition(identified["token"] as? String == "synthetic")
    print("Captains JSON and socket protocol contracts passed")
}

@MainActor func diskContracts() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = LocalCaptainsStore(directory: directory)
    let request = CaptainVoteRequest(captain: "cap", amount: 1, requestID: UUID().uuidString)
    try store.savePending(request, userID: "123")
    let restored = try LocalCaptainsStore(directory: directory).pendingVote(userID: "123")
    let otherUser = try store.pendingVote(userID: "456")
    precondition(restored == request && otherUser == nil)
    do { _ = try store.pendingVote(userID: "../unsafe"); fatalError("Invalid identity accepted") } catch {}
    try Data("invalid".utf8).write(to: directory.appendingPathComponent("123.json"))
    do { _ = try store.pendingVote(userID: "123"); fatalError("Corrupt receipt ignored") } catch {}
    try store.savePending(nil, userID: "123")
    let cleared = try store.pendingVote(userID: "123")
    precondition(cleared == nil)
    print("Captains atomic receipt persistence contracts passed")
}

Task { @MainActor in
    do {
        try modelContracts()
        try await httpContracts()
        try diskContracts()
        giveawayContracts()
        try await stateContracts()
        exit(0)
    } catch { print("Captains contract failed: \(error)"); exit(1) }
}
dispatchMain()
