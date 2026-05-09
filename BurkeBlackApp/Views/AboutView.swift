import SwiftUI
import SafariServices

struct AppAboutView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var showFeedback = false
    @State private var showPrivacyPolicy = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // App info card
                VStack(spacing: 12) {
                    Image("swiftyspiffy_profile")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())

                    Text("The Dirty Skull")
                        .font(PirateTheme.font(size: 28))
                        .foregroundStyle(PirateTheme.accentColor)

                    Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))

                    Text("The official companion app for BurkeBlack\u{2019}s Twitch community. Stay up to date with streams, view your stats, and connect across all platforms.")
                        .font(PirateTheme.font(size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AnyShapeStyle(PirateTheme.cardGradient))
                )

                // Ship's Engineer section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ship\u{2019}s Engineer")
                        .font(PirateTheme.font(size: 18))
                        .foregroundStyle(PirateTheme.accentColor.opacity(0.7))

                    VStack(spacing: 12) {
                        HStack {
                            Text("Built by")
                                .font(PirateTheme.font(size: 15))
                                .foregroundStyle(.white.opacity(0.4))
                            Spacer()
                            Text("swiftyspiffy")
                                .font(PirateTheme.font(size: 15))
                                .foregroundStyle(PirateTheme.accentColor)
                        }

                        Divider().overlay(PirateTheme.accentColor.opacity(0.2))

                        HStack(spacing: 24) {
                            Spacer()
                            Link(destination: URL(string: "https://twitch.tv/swiftyspiffy")!) {
                                VStack(spacing: 6) {
                                    Image("twitch_icon")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 36, height: 36)
                                    Text("Twitch")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                            }
                            Link(destination: URL(string: "https://twitter.com/swiftyspiffy")!) {
                                VStack(spacing: 6) {
                                    Image("x_icon")
                                        .resizable()
                                        .renderingMode(.template)
                                        .scaledToFit()
                                        .frame(width: 36, height: 36)
                                        .foregroundStyle(.white)
                                    Text("Twitter / X")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                            }
                            Link(destination: URL(string: "https://github.com/swiftyspiffy")!) {
                                VStack(spacing: 6) {
                                    Image("github_icon")
                                        .resizable()
                                        .renderingMode(.template)
                                        .scaledToFit()
                                        .frame(width: 36, height: 36)
                                        .foregroundStyle(.white)
                                    Text("GitHub")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(AnyShapeStyle(PirateTheme.cardGradient))
                    )
                }

                // Open Source
                VStack(alignment: .leading, spacing: 12) {
                    Text("Open Source")
                        .font(PirateTheme.font(size: 18))
                        .foregroundStyle(PirateTheme.accentColor.opacity(0.7))

                    VStack(spacing: 0) {
                        Link(destination: URL(string: "https://github.com/swiftyspiffy/BurkeBlackApp-iOS")!) {
                            HStack(spacing: 14) {
                                Image(systemName: "apple.logo")
                                    .font(.title3)
                                    .foregroundStyle(.white)
                                    .frame(width: 42, height: 42)
                                    .background(Color.gray.opacity(0.3))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("iOS App")
                                        .font(PirateTheme.font(size: 15))
                                        .foregroundStyle(.white)
                                    Text("Swift \u{2022} SwiftUI \u{2022} WidgetKit")
                                        .font(PirateTheme.font(size: 11))
                                        .foregroundStyle(.white.opacity(0.4))
                                }

                                Spacer()

                                Image("github_icon")
                                    .resizable()
                                    .renderingMode(.template)
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            .padding(16)
                        }

                        Divider().overlay(PirateTheme.accentColor.opacity(0.2)).padding(.horizontal, 16)

                        Link(destination: URL(string: "https://github.com/swiftyspiffy/BurkeBlackApp-Android")!) {
                            HStack(spacing: 14) {
                                Image(systemName: "apps.iphone")
                                    .font(.title3)
                                    .foregroundStyle(Color.green)
                                    .frame(width: 42, height: 42)
                                    .background(Color.green.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Android App")
                                        .font(PirateTheme.font(size: 15))
                                        .foregroundStyle(.white)
                                    Text("Kotlin \u{2022} Jetpack Compose")
                                        .font(PirateTheme.font(size: 11))
                                        .foregroundStyle(.white.opacity(0.4))
                                }

                                Spacer()

                                Image("github_icon")
                                    .resizable()
                                    .renderingMode(.template)
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            .padding(16)
                        }
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(AnyShapeStyle(PirateTheme.cardGradient))
                    )
                }

                // Action rows
                VStack(spacing: 12) {
                    AboutActionRow(
                        icon: "envelope.fill",
                        iconBg: .orange.opacity(0.3),
                        title: "Send Feedback",
                        subtitle: "Report a bug or share yer thoughts"
                    ) {
                        appLog("About: opening feedback")
                        showFeedback = true
                    }

                    AboutActionRow(
                        icon: "lock.shield.fill",
                        iconBg: .green.opacity(0.3),
                        title: "Privacy Policy",
                        subtitle: "The ship\u{2019}s articles & terms"
                    ) {
                        appLog("About: opening privacy policy")
                        showPrivacyPolicy = true
                    }

                    #if targetEnvironment(simulator) || DEBUG
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Below Deck")
                            .font(PirateTheme.font(size: 18))
                            .foregroundStyle(PirateTheme.accentColor.opacity(0.7))

                        NavigationLink {
                            GiveawayTestView()
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "gearshape.2")
                                    .font(.title3)
                                    .foregroundStyle(PirateTheme.accentColor)
                                    .frame(width: 42, height: 42)
                                    .background(PirateTheme.iconBgColor)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Advanced")
                                        .font(PirateTheme.font(size: 16))
                                        .foregroundStyle(.white)
                                    Text("Debug tools & diagnostics")
                                        .font(PirateTheme.font(size: 12))
                                        .foregroundStyle(.white.opacity(0.4))
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(PirateTheme.accentColor.opacity(0.5))
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(AnyShapeStyle(PirateTheme.cardGradient))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    #endif
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPrivacyPolicy) {
            AboutSafariView(url: URL(string: "https://burkeblack.tv/app/privacy/")!)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showFeedback) {
            NavigationStack {
                FeedbackView(username: nil, userId: nil)
                    .navigationTitle("Feedback")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showFeedback = false }
                        }
                    }
            }
        }
    }
}

// MARK: - Action Row

private struct AboutActionRow: View {
    let icon: String
    let iconBg: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(PirateTheme.accentColor)
                    .frame(width: 42, height: 42)
                    .background(iconBg)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(PirateTheme.font(size: 16))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(PirateTheme.font(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(PirateTheme.accentColor.opacity(0.5))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(AnyShapeStyle(PirateTheme.cardGradient))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct AboutSafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        AppAboutView()
    }
}
