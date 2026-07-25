import SwiftUI

struct RiggingView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var showNotifications = false
    @State private var showGiveaways = false
    @State private var showAppearance = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    PiratePageHeader(
                        title: "Rigging",
                        icon: "gearshape.2.fill",
                        subtitle: "Tune the app to suit your voyage."
                    )

                    RiggingRow(
                        title: "Notifications",
                        subtitle: "Signal flags & stream lookouts",
                        icon: "bell.fill",
                        iconBackground: .orange.opacity(0.3)
                    ) {
                        appLog("Rigging: opening notifications settings")
                        showNotifications = true
                    }

                    RiggingRow(
                        title: "Giveaways",
                        subtitle: "Plunder & treasure settings",
                        icon: "gift.fill",
                        iconBackground: .pink.opacity(0.3)
                    ) {
                        appLog("Rigging: opening giveaway settings")
                        showGiveaways = true
                    }

                    RiggingRow(
                        title: "Appearance",
                        subtitle: "Theme & visual settings",
                        icon: "paintbrush.fill",
                        iconBackground: .purple.opacity(0.3)
                    ) {
                        appLog("Rigging: opening appearance settings")
                        showAppearance = true
                    }

                    NavigationLink {
                        AppAboutView()
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "info.circle.fill")
                                .font(.title2)
                                .foregroundStyle(PirateTheme.accentColor)
                                .frame(width: 52, height: 52)
                                .background(Color.blue.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(PirateTheme.accentColor.opacity(0.16), lineWidth: 1)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text("About")
                                    .font(PirateTheme.font(size: 18))
                                    .foregroundStyle(PirateTheme.accentColor)
                                Text("App info & developer details")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.52))
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundStyle(PirateTheme.accentColor.opacity(0.72))
                                .font(.caption)
                                .frame(width: 28, height: 28)
                                .background(PirateTheme.accentColor.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .padding(18)
                        .contentShape(RoundedRectangle(cornerRadius: 16))
                        .pirateCardSurface()
                    }
                    .buttonStyle(PiratePressButtonStyle())
                }
                .frame(maxWidth: 720)
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity)
            }
            .background(PirateScreenBackground())
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showGiveaways) {
                NavigationStack {
                    GiveawaySettingsView()
                }
            }
            .fullScreenCover(isPresented: $showNotifications) {
                NavigationStack {
                    NotificationsSettingsView()
                }
            }
            .fullScreenCover(isPresented: $showAppearance) {
                NavigationStack {
                    AppearanceSettingsView()
                }
            }
        }
    }
}

private struct RiggingRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconBackground: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(PirateTheme.accentColor)
                    .frame(width: 52, height: 52)
                    .background(iconBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(PirateTheme.accentColor.opacity(0.16), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(PirateTheme.font(size: 18))
                        .foregroundStyle(PirateTheme.accentColor)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.52))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(PirateTheme.accentColor.opacity(0.72))
                    .font(.caption)
                    .frame(width: 28, height: 28)
                    .background(PirateTheme.accentColor.opacity(0.08))
                    .clipShape(Circle())
            }
            .padding(18)
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .pirateCardSurface()
        }
        .buttonStyle(PiratePressButtonStyle())
    }
}
