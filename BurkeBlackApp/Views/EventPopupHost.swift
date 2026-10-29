import SwiftUI

struct EventPopupHost: View {
    @EnvironmentObject private var captains: CaptainsViewModel
    @ObservedObject private var popups = EventPopupCoordinator.shared
    @ObservedObject private var giveaways = GiveawayWebSocketManager.shared
    var includeCaptains = true

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if popups.expanded == .giveaway { GiveawayPopupView(wsManager: giveaways) }

            VStack(alignment: .trailing, spacing: 10) {
                if popups.available.contains(.giveaway) && popups.expanded != .giveaway {
                    restoreButton("Giveaway", icon: "gift.fill") { giveaways.restoreGiveaway() }
                }
            }
            .padding(.trailing, 16).padding(.top, 12)

            if includeCaptains && !popups.captainsScreenVisible {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    if captains.isActive(at: context.date) && popups.expanded != .captains {
                        DraggableCaptainButton { popups.present(.captains) }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }

    private func restoreButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(.caption.weight(.semibold))
                .foregroundStyle(.black).padding(.horizontal, 14).padding(.vertical, 10)
                .background(PirateTheme.accentColor).clipShape(Capsule())
                .shadow(color: .black.opacity(0.3), radius: 4)
        }.accessibilityLabel("Expand \(title)")
    }
}

private struct DraggableCaptainButton: View {
    let action: () -> Void
    @AppStorage("settings.captains.bubble.x") private var savedX = 1.0
    @AppStorage("settings.captains.bubble.y") private var savedY = 1.0
    @GestureState private var translation = CGSize.zero
    private let diameter: CGFloat = 60

    var body: some View {
        GeometryReader { geometry in
            let inset = diameter / 2 + 12
            let left = geometry.safeAreaInsets.leading + inset
            let right = max(left, geometry.size.width - geometry.safeAreaInsets.trailing - inset)
            let top = geometry.safeAreaInsets.top + inset
            // Leave room for the app's bottom navigation and the home indicator.
            let bottom = max(top, geometry.size.height - geometry.safeAreaInsets.bottom - inset - 72)
            let base = CGPoint(x: left + (right - left) * savedX, y: top + (bottom - top) * savedY)

            Button(action: action) {
                Image("ic_burke_captain")
                    .resizable().scaledToFit().padding(6)
                    .frame(width: diameter, height: diameter)
                    .background(PirateTheme.cardBgColor)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(PirateTheme.accentColor, lineWidth: 2))
                    .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open Captains")
            .accessibilityHint("Drag to move this button out of the way.")
            .accessibilityIdentifier("captains.restore")
            .accessibilityAction(named: "Move to top left") { savedX = 0; savedY = 0 }
            .accessibilityAction(named: "Move to top right") { savedX = 1; savedY = 0 }
            .accessibilityAction(named: "Move to bottom left") { savedX = 0; savedY = 1 }
            .accessibilityAction(named: "Move to bottom right") { savedX = 1; savedY = 1 }
            .highPriorityGesture(
                DragGesture(minimumDistance: 8, coordinateSpace: .named("captainBubble"))
                    .updating($translation) { value, state, _ in state = value.translation }
                    .onEnded { value in
                        savedX = right > left ? min(1, max(0, (base.x + value.translation.width - left) / (right - left))) : 0
                        savedY = bottom > top ? min(1, max(0, (base.y + value.translation.height - top) / (bottom - top))) : 0
                    }
            )
            .position(x: min(right, max(left, base.x + translation.width)),
                      y: min(bottom, max(top, base.y + translation.height)))
        }
        .coordinateSpace(name: "captainBubble")
    }
}
