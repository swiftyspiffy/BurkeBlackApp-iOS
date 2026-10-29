import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// Compile the production giveaway manager with isolated app dependencies. These
// fixtures cannot open an authenticated API connection or spend real tokens.
func appLog(_ message: String) {}
@MainActor final class AppSettings {
    static let shared = AppSettings()
    var giveawayPopupsEnabled = true
}
struct DashboardData: Codable { let username: String }
enum TwitchAuthService {
    static func addPlatformHeaders(_ request: inout URLRequest) {}
    static func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        throw URLError(.notConnectedToInternet)
    }
}

@MainActor func giveawayContracts() {
    let manager = GiveawayWebSocketManager.shared
    let popups = EventPopupCoordinator.shared
    manager.handleMessage(#"{"event":"newraffle","name":"Fixture prize","donator":"Fixture"}"#)
    precondition(popups.expanded == .giveaway && !manager.isDismissedToMini)
    popups.present(.captains)
    precondition(manager.isDismissedToMini && manager.activeGiveaway?.name == "Fixture prize")
    manager.handleMessage(#"{"event":"giveawayupdate","totalEntries":"25"}"#)
    precondition(popups.expanded == .captains && manager.activeGiveaway?.totalEntries == "25")
    manager.restoreGiveaway()
    precondition(popups.expanded == .giveaway)
    manager.minimizeGiveaway()
    precondition(popups.expanded == nil && manager.activeGiveaway != nil)
    manager.handleMessage(#"{"event":"rafflewinner","winner":"Fixture winner"}"#)
    precondition(popups.expanded == nil && manager.activeGiveaway?.phase == .winner)
    manager.handleMessage(#"{"event":"newraffle","name":"Second prize","donator":"Fixture"}"#)
    precondition(popups.expanded == .giveaway && manager.activeGiveaway?.name == "Second prize")
    manager.dismissGiveaway()
    precondition(!popups.available.contains(.giveaway) && popups.expanded == nil)
    AppSettings.shared.giveawayPopupsEnabled = false
    manager.handleMessage(#"{"event":"newraffle","name":"Hidden prize"}"#)
    precondition(manager.activeGiveaway == nil && !popups.available.contains(.giveaway))
    AppSettings.shared.giveawayPopupsEnabled = true
    popups.setAvailable(.captains, false)
    print("Production giveaway events, popup priority, minimize/restore, and settings contracts passed")
}
