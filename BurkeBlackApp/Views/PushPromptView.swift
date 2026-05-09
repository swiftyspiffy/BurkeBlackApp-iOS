import SwiftUI


struct PushPromptView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject var pushService: PushNotificationService

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {} // absorb taps

            // Modal card
            VStack(spacing: 0) {
                // Header with bell icon
                VStack(spacing: 12) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(PirateTheme.accentColor)
                        .shadow(color: PirateTheme.accentColor.opacity(0.4), radius: 12)

                    Text("Ahoy, Sailor!")
                        .font(PirateTheme.font(size: 30))
                        .foregroundStyle(PirateTheme.accentColor)
                }
                .padding(.top, 28)
                .padding(.bottom, 16)

                // Message
                VStack(spacing: 12) {
                    Text("The Captain and his crew would like to send ye dispatches from the ship \u{2014} stream alerts, announcements, special events, and news from The Dirty Skull.")
                        .font(PirateTheme.font(size: 16))
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)

                    Text("Shall we hoist the signal flags? Ye can trim the sails anytime in Rigging → Notifications.")
                        .font(PirateTheme.font(size: 18))
                        .foregroundStyle(PirateTheme.accentColor.opacity(0.9))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

                // Buttons
                VStack(spacing: 10) {
                    // Accept
                    Button {
                        appLog("PushPrompt: user tapped Aye")
                        Task { await pushService.acceptPushNotifications() }
                    } label: {
                        Text("Aye, Keep Me Posted!")
                            .font(PirateTheme.font(size: 20))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(PirateTheme.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Decline
                    Button {
                        appLog("PushPrompt: user tapped Nay")
                        pushService.declinePushNotifications()
                    } label: {
                        Text("Nay, Not Now")
                            .font(PirateTheme.font(size: 16))
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.08, green: 0.1, blue: 0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(PirateTheme.accentColor.opacity(0.3), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.5), radius: 30)
        }
        .transition(.opacity)
    }
}
