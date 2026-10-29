import Foundation
#if canImport(Combine)
import Combine
#endif

@MainActor
final class CaptainsViewModel: ObservableObject {
    @Published private(set) var candidates: [Captain] = []
    @Published private(set) var schedule: CaptainSchedule?
    @Published private(set) var crew: [Captain] = []
    @Published private(set) var winner: Captain?
    @Published private(set) var currentRanking: [CaptainRanking] = []
    @Published private(set) var lifetimeRanking: [CaptainRanking] = []
    @Published private(set) var balance: Int?
    @Published private(set) var session: CaptainSession?
    @Published private(set) var authRequired = false
    @Published private(set) var loading = false
    @Published private(set) var detailsLoaded = false
    @Published private(set) var connected = false
    @Published private(set) var error: String?
    @Published private(set) var detailsError: String?
    @Published private(set) var balanceError: String?
    @Published private(set) var storageError: String?
    @Published private(set) var notice: String?
    @Published private(set) var pending: CaptainVoteRequest?
    @Published private(set) var pendingLoaded = true
    @Published private(set) var sending = false
    @Published private(set) var serverOffset: TimeInterval = 0
    @Published var selectedID: String?
    @Published var amount = "1"
    @Published var confirmationOpen = false

    let popups: EventPopupCoordinator
    private let api: CaptainsDataSource
    private let store: CaptainsStore
    private let socket: CaptainsSocketSource
    private let clock: () -> Date
    private var generation = 0
    private var identityGeneration = 0
    private var foreground = false
    private var screenVisible = false
    private var popupsEnabled = true
    private var refreshTask: Task<Void, Never>?
    private var socketTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    private var refreshQueued = false
    private var lastRefresh = Date.distantPast

    init(api: CaptainsDataSource, store: CaptainsStore, socket: CaptainsSocketSource,
         popups: EventPopupCoordinator, clock: @escaping () -> Date = Date.init) {
        self.api = api; self.store = store; self.socket = socket
        self.popups = popups; self.clock = clock
    }

    var selected: Captain? { candidates.first { $0.id == selectedID } }
    var validAmount: Int? {
        guard !amount.isEmpty, amount.allSatisfy({ $0.isASCII && $0.isNumber }),
              let value = Int(amount), (1...CaptainsContract.maximumVotes).contains(value), value <= (balance ?? 0) else { return nil }
        return value
    }
    func remaining(at now: Date) -> TimeInterval { schedule?.end.timeIntervalSince(now.addingTimeInterval(serverOffset)) ?? 0 }
    func isActive(at now: Date) -> Bool {
        guard let schedule else { return false }
        return !candidates.isEmpty && now.addingTimeInterval(serverOffset) >= schedule.start && remaining(at: now) > 0
    }

    func start() {
        guard !foreground else { return }
        foreground = true
        refresh(); connect()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 1_000_000_000) } catch { break }
                guard let self else { break }
                let expired = self.schedule != nil && self.remaining(at: self.clock()) <= 0
                if expired { self.popups.setAvailable(.captains, false) }
                let elapsed = self.clock().timeIntervalSince(self.lastRefresh)
                if (expired && elapsed >= 5) || (elapsed >= 30 && (self.screenVisible || self.popups.expanded == .captains || !self.connected)) {
                    self.refresh()
                }
            }
        }
    }

    func stop() {
        foreground = false
        generation += 1
        refreshTask?.cancel(); refreshTask = nil
        socketTask?.cancel(); pollTask?.cancel(); debounceTask?.cancel(); debounceTask = nil
        refreshQueued = false; loading = false; connected = false
        // A dispatched vote continues; its receipt is already durable.
    }

    func setSession(_ identity: CaptainSession?) {
        guard identity != session else { return }
        generation += 1
        identityGeneration += 1
        refreshTask?.cancel(); refreshTask = nil
        socketTask?.cancel(); debounceTask?.cancel(); debounceTask = nil
        refreshQueued = false
        session = identity; balance = nil; balanceError = nil; notice = nil
        authRequired = identity != nil && identity?.hasUserID != true
        selectedID = nil; amount = "1"; confirmationOpen = false
        restorePending()
        if foreground { refresh(); connect() }
    }

    private func restorePending() {
        pending = nil; storageError = nil; pendingLoaded = false
        guard let session, session.hasUserID else { pendingLoaded = true; return }
        do { pending = try store.pendingVote(userID: session.userID); pendingLoaded = true }
        catch { storageError = "Couldn’t read your previous vote. Try Refresh before spending more tokens." }
    }

    func setPopupsEnabled(_ enabled: Bool) {
        popupsEnabled = enabled
        if !enabled { popups.minimize(.captains) } else { considerPopup() }
    }

    func setScreenVisible(_ visible: Bool) {
        screenVisible = visible
        popups.setCaptainsScreenVisible(visible)
        if visible { refresh() }
    }

    func retry() {
        if !pendingLoaded { restorePending() }
        if authRequired, session?.hasUserID == true { authRequired = false; if foreground { connect() } }
        refresh()
    }

    func refresh() {
        guard foreground else { return }
        if refreshTask != nil { refreshQueued = true; return }
        loading = true
        let owner = generation
        refreshTask = Task { [weak self] in
            guard let self else { return }
            repeat {
                self.refreshQueued = false
                await self.refreshData(owner: owner)
            } while self.refreshQueued && self.foreground && owner == self.generation && !Task.isCancelled
            if owner == self.generation { self.refreshTask = nil }
        }
    }

    private func refreshData(owner: Int) async {
        loading = true; lastRefresh = clock()
        let identity = session
        let loadDetails = screenVisible
        // Independent reads: a failed wallet or ranking must not hide the election.
        async let electionRead: Void = refreshElection(owner: owner)
        async let balanceRead: Void = refreshBalance(identity: identity, owner: owner)
        async let detailsRead: Void = refreshDetails(enabled: loadDetails, owner: owner)
        _ = await (electionRead, balanceRead, detailsRead)
        if owner == generation { loading = false }
    }

    private func refreshElection(owner: Int) async {
        do {
            let election = try await api.election()
            guard owner == generation, foreground, !Task.isCancelled else { return }
            let oldKey = schedule?.key
            candidates = election.candidates.sorted { ($0.rank ?? 0, $0.order ?? 0) < ($1.rank ?? 0, $1.order ?? 0) }
            schedule = election.schedule
            serverOffset = election.schedule.now.timeIntervalSince(clock())
            error = nil
            if oldKey != nil && oldKey != schedule?.key && pending == nil {
                selectedID = nil; confirmationOpen = false; amount = "1"
            }
            popups.setAvailable(.captains, isActive(at: clock()))
            considerPopup()
        } catch is CancellationError {} catch {
            if owner == generation { self.error = "Couldn’t refresh the election. Try Refresh." }
        }
    }

    private func refreshBalance(identity: CaptainSession?, owner: Int) async {
        guard let identity, identity.hasUserID, !authRequired else { return }
        do {
            let value = try await api.balance(identity)
            guard owner == generation, !authRequired, !Task.isCancelled else { return }
            balance = value; balanceError = nil
        } catch is CancellationError {} catch CaptainsError.authenticationRequired {
            if owner == generation { requireAuthentication() }
        } catch {
            if owner == generation { balance = nil; balanceError = "Couldn’t load your tokens. Try Refresh." }
        }
    }

    private func refreshDetails(enabled: Bool, owner: Int) async {
        guard enabled else { return }
        do {
            let value = try await api.details()
            guard owner == generation, !Task.isCancelled else { return }
            crew = value.crew.sorted { ($0.order ?? 0) < ($1.order ?? 0) }
            winner = value.winner; currentRanking = value.current; lifetimeRanking = value.lifetime
            detailsLoaded = true; detailsError = nil
        } catch is CancellationError {} catch {
            if owner == generation { detailsError = "Couldn’t refresh the crew and rankings. Try Refresh." }
        }
    }

    private func considerPopup() {
        guard foreground, popupsEnabled, isActive(at: clock()), let key = schedule?.key, store.lastElection() != key else { return }
        store.markElection(key)
        popups.present(.captains)
    }

    private func requireAuthentication() {
        let reconnect = !authRequired
        authRequired = true; balance = nil
        balanceError = "Sign in with Twitch to use your voting tokens."
        if reconnect && foreground { connect() }
    }

    private func connect() {
        socketTask?.cancel()
        connected = false
        let owner = generation
        socketTask = Task { [weak self] in
            guard let self else { return }
            var delay: UInt64 = 2_000_000_000
            while !Task.isCancelled && self.foreground && owner == self.generation {
                do {
                    var identity = self.session.flatMap { $0.hasUserID && !self.authRequired ? $0 : nil }
                    if let verified = identity {
                        do { try await self.api.renew(verified) }
                        catch CaptainsError.authenticationRequired { self.requireAuthentication(); return }
                    }
                    guard owner == self.generation, !Task.isCancelled else { return }
                    if self.authRequired { identity = nil }
                    var first = true
                    for try await event in self.socket.events(session: identity) {
                        guard owner == self.generation, !Task.isCancelled else { return }
                        self.connected = true; delay = 2_000_000_000
                        if first || event == .refresh { self.scheduleRefresh() }
                        first = false
                    }
                } catch is CancellationError { return } catch { /* Poll until the socket recovers. */ }
                guard owner == self.generation, !Task.isCancelled else { return }
                self.connected = false
                do { try await Task.sleep(nanoseconds: delay) } catch { return }
                delay = min(delay * 2, 30_000_000_000)
            }
        }
    }

    private func scheduleRefresh() {
        guard debounceTask == nil else { return }
        debounceTask = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 300_000_000) } catch { return }
            self?.debounceTask = nil; self?.refresh()
        }
    }

    func choose(_ captain: Captain) {
        guard !sending, pending == nil, candidates.contains(where: { $0.id == captain.id }) else { return }
        if selectedID != captain.id { amount = "1" }
        selectedID = captain.id; confirmationOpen = true; notice = nil
    }

    func submitVote() async {
        guard !sending, pendingLoaded, !authRequired, let identity = session, identity.hasUserID else { return }
        let request: CaptainVoteRequest
        if let pending { request = pending }
        else {
            guard isActive(at: clock()), let selected, let value = validAmount else { return }
            request = CaptainVoteRequest(captain: selected.id, amount: value, requestID: UUID().uuidString)
        }
        let owner = identityGeneration
        sending = true; notice = nil
        defer { sending = false; if foreground { refresh() } }
        do {
            try store.savePending(request, userID: identity.userID)
            pending = request; storageError = nil
            let result = try await api.vote(identity, request: request)
            guard result == "success" || result == "insufficient_tokens" else { throw CaptainsError.unavailable }
            // Complete the original user's receipt even if they signed out mid-flight.
            try store.savePending(nil, userID: identity.userID)
            guard owner == identityGeneration else { return }
            pending = nil; confirmationOpen = false; selectedID = nil; amount = "1"
            notice = result == "success" ? "\(request.amount) \(request.amount == 1 ? "vote" : "votes") cast!"
                : "Your balance or the election changed. Refresh and choose again."
        } catch CaptainsError.authenticationRequired {
            if owner == identityGeneration { requireAuthentication() }
        } catch {
            if owner == identityGeneration {
                notice = pending != nil ? "Vote status unconfirmed. Use Check vote to safely recover this request."
                    : "Couldn’t save your vote request. Nothing was sent. Try again."
            }
        }
    }
}
