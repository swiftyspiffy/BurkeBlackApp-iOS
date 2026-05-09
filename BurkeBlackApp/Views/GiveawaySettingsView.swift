import SwiftUI


struct GiveawaySettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    private func onToggleChanged(_ enabled: Bool) {
        appLog("GiveawaySettings: popups \(enabled ? "enabled" : "disabled")")
    }
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Giveaways")
                    .font(PirateTheme.font(size: 28))
                    .foregroundStyle(PirateTheme.accentColor)
                    .padding(.top, 8)

                Text("Configure how plunder be delivered")
                    .font(PirateTheme.font(size: 15))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, -16)

                // Popup toggle
                HStack(spacing: 14) {
                    Image(systemName: "gift.fill")
                        .font(.title3)
                        .foregroundStyle(settings.giveawayPopupsEnabled ? .pink : .gray)
                        .frame(width: 42, height: 42)
                        .background(settings.giveawayPopupsEnabled ? Color.pink.opacity(0.15) : Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show Giveaway Popups")
                            .font(PirateTheme.font(size: 16))
                            .foregroundStyle(settings.giveawayPopupsEnabled ? .white : .gray)
                        Text("Treasure alerts appear when giveaways start")
                            .font(PirateTheme.font(size: 12))
                            .foregroundStyle(.white.opacity(settings.giveawayPopupsEnabled ? 0.4 : 0.2))
                    }

                    Spacer()

                    Toggle("", isOn: $settings.giveawayPopupsEnabled)
                        .labelsHidden()
                        .tint(PirateTheme.accentColor)
                        .onChange(of: settings.giveawayPopupsEnabled) { _, val in onToggleChanged(val) }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.05))
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
                    .foregroundStyle(PirateTheme.accentColor)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
