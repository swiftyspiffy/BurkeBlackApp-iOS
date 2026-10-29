import Foundation
#if canImport(Combine)
import Combine
#endif

enum EventPopup: Hashable { case giveaway, captains }

@MainActor
final class EventPopupCoordinator: ObservableObject {
    static let shared = EventPopupCoordinator()
    @Published private(set) var expanded: EventPopup?
    @Published private(set) var available: Set<EventPopup> = []
    @Published private(set) var captainsScreenVisible = false

    func setAvailable(_ kind: EventPopup, _ value: Bool) {
        if value { available.insert(kind) }
        else {
            available.remove(kind)
            minimize(kind)
        }
    }

    // Only new alerts and deliberate user actions present, never tally refreshes.
    func present(_ kind: EventPopup) {
        available.insert(kind)
        if kind == .captains && captainsScreenVisible { return }
        expanded = kind
    }

    func minimize(_ kind: EventPopup) {
        if expanded == kind { expanded = nil }
    }

    func setCaptainsScreenVisible(_ visible: Bool) {
        captainsScreenVisible = visible
        if visible { minimize(.captains) }
    }
}
