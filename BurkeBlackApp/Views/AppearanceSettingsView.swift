import SwiftUI

struct AppearanceSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Appearance")
                    .font(PirateTheme.font(size: 28))
                    .foregroundStyle(PirateTheme.accentColor)
                    .padding(.top, 8)

                Text("Customize the look of yer ship")
                    .font(PirateTheme.font(size: 15))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, -16)

                HStack(spacing: 14) {
                    Image(systemName: "paintbrush.fill")
                        .font(.title3)
                        .foregroundStyle(settings.pirateThemeEnabled ? PirateTheme.accentColor : .gray)
                        .frame(width: 42, height: 42)
                        .background(settings.pirateThemeEnabled ? PirateTheme.accentColor.opacity(0.15) : Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pirate Theme")
                            .font(PirateTheme.font(size: 16))
                            .foregroundStyle(settings.pirateThemeEnabled ? .white : .gray)
                        Text("Gold accents, pirate fonts & styled cards")
                            .font(PirateTheme.font(size: 12))
                            .foregroundStyle(.white.opacity(settings.pirateThemeEnabled ? 0.4 : 0.2))
                    }

                    Spacer()

                    Toggle("", isOn: $settings.pirateThemeEnabled)
                        .labelsHidden()
                        .tint(PirateTheme.accentColor)
                        .onChange(of: settings.pirateThemeEnabled) { _, newValue in
                            appLog("Appearance: pirate theme toggled to \(newValue)")
                        }
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
        .onAppear { appLog("Appearance: view appeared") }
    }
}

#Preview {
    NavigationStack {
        AppearanceSettingsView()
    }
}
