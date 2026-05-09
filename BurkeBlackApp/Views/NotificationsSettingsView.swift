import SwiftUI
import Combine


// MARK: - Schedule Model

struct StreamSchedule {
    var enabled: Bool = true
    var allTheTime: Bool = true
    var days: Set<Int> = Set(0...6) // 0=Sun, 1=Mon ... 6=Sat
    var fromHour: Int = 9
    var fromMinute: Int = 0
    var toHour: Int = 23
    var toMinute: Int = 0

    var fromDate: Date {
        get { Self.dateFrom(hour: fromHour, minute: fromMinute) }
        set {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            fromHour = comps.hour ?? 9
            fromMinute = comps.minute ?? 0
        }
    }

    var toDate: Date {
        get { Self.dateFrom(hour: toHour, minute: toMinute) }
        set {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            toHour = comps.hour ?? 23
            toMinute = comps.minute ?? 0
        }
    }

    private static func dateFrom(hour: Int, minute: Int) -> Date {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        return Calendar.current.date(from: comps) ?? .now
    }

    static let dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    static let dayShort  = ["S", "M", "T", "W", "T", "F", "S"]
}

// MARK: - Main View

struct NotificationsSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var pushService = PushNotificationService.shared
    @Environment(\.scenePhase) private var scenePhase

    // Bridge StreamSchedule structs to AppSettings
    private var burkeSchedule: Binding<StreamSchedule> {
        Binding(
            get: {
                StreamSchedule(
                    enabled: settings.burkeStreamEnabled,
                    allTheTime: settings.burkeStreamAllDay,
                    days: settings.burkeStreamDays,
                    fromHour: settings.burkeStreamFromHour,
                    fromMinute: settings.burkeStreamFromMinute,
                    toHour: settings.burkeStreamToHour,
                    toMinute: settings.burkeStreamToMinute
                )
            },
            set: { new in
                settings.burkeStreamEnabled = new.enabled
                settings.burkeStreamAllDay = new.allTheTime
                settings.burkeStreamDays = new.days
                settings.burkeStreamFromHour = new.fromHour
                settings.burkeStreamFromMinute = new.fromMinute
                settings.burkeStreamToHour = new.toHour
                settings.burkeStreamToMinute = new.toMinute
            }
        )
    }

    private var burke40kSchedule: Binding<StreamSchedule> {
        Binding(
            get: {
                StreamSchedule(
                    enabled: settings.burke40kEnabled,
                    allTheTime: settings.burke40kAllDay,
                    days: settings.burke40kDays,
                    fromHour: settings.burke40kFromHour,
                    fromMinute: settings.burke40kFromMinute,
                    toHour: settings.burke40kToHour,
                    toMinute: settings.burke40kToMinute
                )
            },
            set: { new in
                settings.burke40kEnabled = new.enabled
                settings.burke40kAllDay = new.allTheTime
                settings.burke40kDays = new.days
                settings.burke40kFromHour = new.fromHour
                settings.burke40kFromMinute = new.fromMinute
                settings.burke40kToHour = new.toHour
                settings.burke40kToMinute = new.toMinute
            }
        )
    }

    private func syncNotifs() {
        Task { await PushNotificationService.shared.syncPreferences() }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                Text("Notifications")
                    .font(PirateTheme.font(size: 28))
                    .foregroundStyle(PirateTheme.accentColor)
                    .padding(.top, 8)

                Text("Choose which signal flags fly from yer mast")
                    .font(PirateTheme.font(size: 15))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, -16)

                // Permission status banner
                if pushService.permissionStatus == .denied {
                    VStack(spacing: 12) {
                        Image(systemName: "bell.slash.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.red.opacity(0.6))
                        Text("Notifications Be Disabled!")
                            .font(PirateTheme.font(size: 18))
                            .foregroundStyle(.white)
                        Text("Ye\'ve silenced the crow\'s nest. Head to yer device settings to let the signals through.")
                            .font(PirateTheme.font(size: 13))
                            .foregroundStyle(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Text("Open Settings")
                                .font(PirateTheme.font(size: 16))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 10)
                                .background(PirateTheme.accentColor)
                                .clipShape(Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.red.opacity(0.08))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.2), lineWidth: 1))
                    )
                } else if pushService.permissionStatus == .notDetermined {
                    VStack(spacing: 12) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(PirateTheme.accentColor.opacity(0.6))
                        Text("Notifications Not Enabled")
                            .font(PirateTheme.font(size: 18))
                            .foregroundStyle(.white)
                        Text("Enable notifications to receive stream alerts, announcements, and more from the Captain.")
                            .font(PirateTheme.font(size: 13))
                            .foregroundStyle(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                        Button {
                            Task { await pushService.acceptPushNotifications() }
                        } label: {
                            Text("Enable Notifications")
                                .font(PirateTheme.font(size: 16))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 10)
                                .background(PirateTheme.accentColor)
                                .clipShape(Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(PirateTheme.accentColor.opacity(0.05))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(PirateTheme.accentColor.opacity(0.2), lineWidth: 1))
                    )
                }

                // All notification sections (disabled when not authorized)
                Group {
                // Stream Start Notifications
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "Stream Lookouts", icon: "eye.fill")

                    StreamNotificationCard(
                        title: "BurkeBlack Stream Start",
                        subtitle: "More reliable than Twitch\u{2019}s crow\u{2019}s nest",
                        icon: "circle.fill",
                        iconColor: .red,
                        schedule: burkeSchedule
                    )

                    StreamNotificationCard(
                        title: "Burke40k Stream Start",
                        subtitle: "The Captain\u{2019}s war table goes live",
                        icon: "table.furniture.fill",
                        iconColor: .brown,
                        schedule: burke40kSchedule
                    )
                }

                // Announcement Notifications
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "Dispatches", icon: "scroll.fill")

                    AssetNotificationCard(
                        title: "Burke Announcements",
                        subtitle: "Word from the Captain himself",
                        assetName: "burkeblack_profile",
                        isEnabled: $settings.burkeAnnouncements
                    )

                    AssetNotificationCard(
                        title: "Moderator Announcements",
                        subtitle: "Orders from the Captain\u{2019}s officers",
                        assetName: "twitch_mod_badge",
                        isEnabled: $settings.modAnnouncements
                    )

                    SimpleNotificationCard(
                        title: "Special Events",
                        subtitle: "One-off voyages, Burkies, TwitchCon & more",
                        icon: "sparkles",
                        iconColor: .yellow,
                        isEnabled: $settings.specialEvents
                    )
                }

                // Tidings
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "Tidings", icon: "newspaper.fill")

                    SimpleNotificationCard(
                        title: "Channel Tidings",
                        subtitle: "News and updates from the ship\u{2019}s log",
                        icon: "scroll.fill",
                        iconColor: .mint,
                        isEnabled: $settings.tidings
                    )
                }

                // Shore Leave Posts
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "Shore Leave Posts", icon: "globe")

                    SimpleNotificationCard(
                        title: "YouTube Videos",
                        subtitle: "New videos from the Captain’s channel",
                        icon: "play.rectangle.fill",
                        iconColor: .red,
                        isEnabled: $settings.youtubeVideos
                    )

                    SimpleNotificationCard(
                        title: "YouTube Shorts",
                        subtitle: "Quick clips from the Captain",
                        icon: "film.stack",
                        iconColor: .red,
                        isEnabled: $settings.youtubeShorts
                    )

                    AssetNotificationCard(
                        title: "TikTok Videos",
                        subtitle: "New TikToks from the Captain",
                        assetName: "tiktok_icon",
                        tintWhite: true,
                        isEnabled: $settings.tiktokVideos
                    )

                    AssetNotificationCard(
                        title: "X Posts",
                        subtitle: "New posts from the Captain on X",
                        assetName: "x_icon",
                        tintWhite: true,
                        isEnabled: $settings.twitterPosts
                    )
                }
                } // end Group
                .opacity(pushService.permissionStatus == .authorized ? 1.0 : 0.4)
                .disabled(pushService.permissionStatus != .authorized)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    appLog("NotificationsSettings: dismissed")
                    dismiss()
                }
                    .foregroundStyle(PirateTheme.accentColor)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            appLog("Notifications: view appeared, permission=\(pushService.permissionStatus)")
            Task { await pushService.checkPermissionStatus() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await pushService.checkPermissionStatus()
                    if pushService.permissionStatus == .authorized {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
            }
        }
        .onChange(of: settings.burkeStreamEnabled) { _, _ in syncNotifs() }
        .onChange(of: settings.burkeStreamAllDay) { _, _ in syncNotifs() }
        .onChange(of: settings.burke40kEnabled) { _, _ in syncNotifs() }
        .onChange(of: settings.burke40kAllDay) { _, _ in syncNotifs() }
        .onChange(of: settings.burkeAnnouncements) { _, _ in syncNotifs() }
        .onChange(of: settings.modAnnouncements) { _, _ in syncNotifs() }
        .onChange(of: settings.specialEvents) { _, _ in syncNotifs() }
        .onChange(of: settings.tidings) { _, _ in syncNotifs() }
        .onChange(of: settings.youtubeVideos) { _, _ in syncNotifs() }
        .onChange(of: settings.youtubeShorts) { _, _ in syncNotifs() }
        .onChange(of: settings.tiktokVideos) { _, _ in syncNotifs() }
        .onChange(of: settings.twitterPosts) { _, _ in syncNotifs() }
    }
}

// MARK: - Section Header

private struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(PirateTheme.accentColor.opacity(0.7))
            Text(title)
                .font(PirateTheme.font(size: 18))
                .foregroundStyle(PirateTheme.accentColor.opacity(0.7))
        }
        .padding(.top, 4)
    }
}

// MARK: - Asset Image Toggle Card

private struct AssetNotificationCard: View {
    let title: String
    let subtitle: String
    let assetName: String
    var tintWhite: Bool = false
    @Binding var isEnabled: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(assetName)
                .resizable()
                .renderingMode(tintWhite ? .template : .original)
                .scaledToFill()
                .frame(width: 42, height: 42)
                .foregroundStyle(tintWhite ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .opacity(isEnabled ? 1.0 : 0.4)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(PirateTheme.font(size: 16))
                    .foregroundStyle(isEnabled ? .white : .gray)
                Text(subtitle)
                    .font(PirateTheme.font(size: 12))
                    .foregroundStyle(.white.opacity(isEnabled ? 0.4 : 0.2))
            }

            Spacer()

            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .tint(PirateTheme.accentColor)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Simple Toggle Card

private struct SimpleNotificationCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    @Binding var isEnabled: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(isEnabled ? iconColor : .gray)
                .frame(width: 42, height: 42)
                .background(isEnabled ? iconColor.opacity(0.15) : Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(PirateTheme.font(size: 16))
                    .foregroundStyle(isEnabled ? .white : .gray)
                Text(subtitle)
                    .font(PirateTheme.font(size: 12))
                    .foregroundStyle(.white.opacity(isEnabled ? 0.4 : 0.2))
            }

            Spacer()

            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .tint(PirateTheme.accentColor)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Stream Notification Card with Schedule

private struct StreamNotificationCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    @Binding var schedule: StreamSchedule

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(schedule.enabled ? iconColor : .gray)
                    .frame(width: 42, height: 42)
                    .background(schedule.enabled ? iconColor.opacity(0.15) : Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(PirateTheme.font(size: 16))
                        .foregroundStyle(schedule.enabled ? .white : .gray)
                    Text(subtitle)
                        .font(PirateTheme.font(size: 12))
                        .foregroundStyle(.white.opacity(schedule.enabled ? 0.4 : 0.2))
                    if schedule.enabled {
                        Text(scheduleDescription)
                            .font(PirateTheme.font(size: 11))
                            .foregroundStyle(PirateTheme.accentColor.opacity(0.6))
                            .padding(.top, 2)
                    }
                }

                Spacer()

                if schedule.enabled {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundStyle(PirateTheme.accentColor.opacity(0.6))
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                    .padding(.trailing, 4)
                }

                Toggle("", isOn: $schedule.enabled)
                    .labelsHidden()
                    .tint(PirateTheme.accentColor)
                    .onChange(of: schedule.enabled) { _, enabled in
                        if !enabled { isExpanded = false }
                    }
            }
            .padding(16)

            // Schedule config
            if schedule.enabled && isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    Divider().overlay(PirateTheme.accentColor.opacity(0.2))

                    // All the time toggle
                    HStack {
                        Text("Alert at all hours")
                            .font(PirateTheme.font(size: 15))
                            .foregroundStyle(.white.opacity(0.8))
                        Spacer()
                        Toggle("", isOn: $schedule.allTheTime)
                            .labelsHidden()
                            .tint(PirateTheme.accentColor)
                    }

                    if !schedule.allTheTime {
                        // Day picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Which days to keep watch")
                                .font(PirateTheme.font(size: 14))
                                .foregroundStyle(.white.opacity(0.5))

                            HStack(spacing: 6) {
                                ForEach(0..<7) { day in
                                    DayButton(
                                        label: StreamSchedule.dayShort[day],
                                        isSelected: schedule.days.contains(day)
                                    ) {
                                        if schedule.days.contains(day) {
                                            if schedule.days.count > 1 {
                                                schedule.days.remove(day)
                                            }
                                        } else {
                                            schedule.days.insert(day)
                                        }
                                    }
                                }
                            }
                        }

                        // Time range
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Watch hours")
                                .font(PirateTheme.font(size: 14))
                                .foregroundStyle(.white.opacity(0.5))

                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("From")
                                        .font(PirateTheme.font(size: 12))
                                        .foregroundStyle(.white.opacity(0.4))
                                    DatePicker("", selection: $schedule.fromDate, displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                        .tint(PirateTheme.accentColor)
                                }

                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundStyle(PirateTheme.accentColor.opacity(0.4))
                                    .padding(.top, 16)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Until")
                                        .font(PirateTheme.font(size: 12))
                                        .foregroundStyle(.white.opacity(0.4))
                                    DatePicker("", selection: $schedule.toDate, displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                        .tint(PirateTheme.accentColor)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var scheduleDescription: String {
        if schedule.allTheTime { return "Alerting at all hours" }
        let dayNames = schedule.days.sorted().map { StreamSchedule.dayLabels[$0] }
        let from = formatTime(hour: schedule.fromHour, minute: schedule.fromMinute)
        let to = formatTime(hour: schedule.toHour, minute: schedule.toMinute)
        if schedule.days.count == 7 {
            return "Every day, \(from) \u{2013} \(to)"
        }
        return "\(dayNames.joined(separator: ", ")), \(from) \u{2013} \(to)"
    }

    private func formatTime(hour: Int, minute: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let period = hour < 12 ? "AM" : "PM"
        if minute == 0 { return "\(h) \(period)" }
        return String(format: "%d:%02d %@", h, minute, period)
    }
}

// MARK: - Disabled Notification Card

private struct DisabledNotificationCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.gray.opacity(0.4))
                .frame(width: 42, height: 42)
                .background(Color.gray.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(PirateTheme.font(size: 16))
                    .foregroundStyle(.gray.opacity(0.5))
                Text(subtitle)
                    .font(PirateTheme.font(size: 12))
                    .foregroundStyle(.white.opacity(0.15))
            }

            Spacer()

            Toggle("", isOn: .constant(false))
                .labelsHidden()
                .disabled(true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.03))
        )
    }
}

// MARK: - Day Button

private struct DayButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(PirateTheme.font(size: 14))
                .foregroundStyle(isSelected ? .black : .white.opacity(0.4))
                .frame(width: 38, height: 38)
                .background(isSelected ? PirateTheme.accentColor : Color.white.opacity(0.08))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
