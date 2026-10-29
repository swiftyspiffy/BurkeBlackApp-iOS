import SwiftUI

struct EventPopupHost: View {
    @EnvironmentObject private var captains: CaptainsViewModel
    @ObservedObject private var popups = EventPopupCoordinator.shared
    @ObservedObject private var giveaways = GiveawayWebSocketManager.shared
    var includeCaptains = true

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if popups.expanded == .giveaway { GiveawayPopupView(wsManager: giveaways) }
            if includeCaptains && popups.expanded == .captains && !popups.captainsScreenVisible {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    if captains.isActive(at: context.date) {
                        VStack {
                            Spacer()
                            ScrollView {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Label("Captain Election", systemImage: "person.3.sequence.fill").font(.headline)
                                        Spacer()
                                        Button { popups.minimize(.captains) } label: { Image(systemName: "minus.circle.fill").font(.title2) }
                                            .accessibilityLabel("Minimize captain voting")
                                    }
                                    CaptainElectionDeadline()
                                    CaptainWallet()
                                    ForEach(captains.candidates) { captain in CaptainCandidateCard(captain: captain, compact: true) }
                                    CaptainsMessages()
                                    Button("Open Captains") {
                                        popups.minimize(.captains)
                                        captains.showScreen = true
                                    }.buttonStyle(.bordered).frame(maxWidth: .infinity)
                                }.padding(18)
                            }
                            .frame(maxHeight: 570)
                            .background(PirateTheme.cardBgColor)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(PirateTheme.accentColor.opacity(0.6)))
                            .shadow(color: .black.opacity(0.5), radius: 20)
                            .frame(maxWidth: 560)
                            .padding(.horizontal, 16).padding(.bottom, 90)
                        }
                    }
                }
                CaptainVoteConfirmation()
            }

            VStack(alignment: .trailing, spacing: 10) {
                if popups.available.contains(.giveaway) && popups.expanded != .giveaway {
                    restoreButton("Giveaway", icon: "gift.fill") { giveaways.restoreGiveaway() }
                }
                if includeCaptains && !popups.captainsScreenVisible {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        if captains.isActive(at: context.date) && popups.expanded != .captains {
                            restoreButton("Captains", icon: "person.3.sequence.fill") { popups.present(.captains) }
                        }
                    }
                }
            }
            .padding(.trailing, 16).padding(.top, 12)
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
