import SwiftUI


struct NotificationChannelsDebugView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var serverPrefs: [String: Any]? = nil
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        List {
            // Local settings
            Section("Local Settings") {
                ChannelRow(name: "BurkeBlack Stream", enabled: settings.burkeStreamEnabled, details: burkeStreamDetails)
                ChannelRow(name: "Burke40k Stream", enabled: settings.burke40kEnabled, details: burke40kStreamDetails)
                ChannelRow(name: "Burke Announcements", enabled: settings.burkeAnnouncements)
                ChannelRow(name: "Mod Announcements", enabled: settings.modAnnouncements)
                ChannelRow(name: "Special Events", enabled: settings.specialEvents)
                ChannelRow(name: "Channel Tidings", enabled: settings.tidings)
                ChannelRow(name: "YouTube Videos", enabled: settings.youtubeVideos)
                ChannelRow(name: "YouTube Shorts", enabled: settings.youtubeShorts)
                ChannelRow(name: "Twitter Posts", enabled: settings.twitterPosts, note: "Disabled (not wired)")
            }

            // Server-side settings
            Section("Server Settings") {
                if isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else if let error {
                    Text(error).foregroundStyle(.red).font(.caption)
                } else if let prefs = serverPrefs {
                    ServerRow(key: "burkeblack_stream", prefs: prefs)
                    ServerRow(key: "burke40k_stream", prefs: prefs)
                    ServerRow(key: "burke_announcements", prefs: prefs)
                    ServerRow(key: "mod_announcements", prefs: prefs)
                    ServerRow(key: "special_events", prefs: prefs)
                    ServerRow(key: "channel_tidings", prefs: prefs)
                    ServerRow(key: "youtube_videos", prefs: prefs)
                    ServerRow(key: "youtube_shorts", prefs: prefs)
                    ServerRow(key: "twitter_posts", prefs: prefs)

                    if let tz = prefs["timezone"] as? String {
                        HStack {
                            Text("Timezone")
                            Spacer()
                            Text(tz).foregroundStyle(.secondary).font(.caption)
                        }
                    }

                    if let schedule = prefs["burke_stream_schedule_json"] as? String, !schedule.isEmpty {
                        DisclosureGroup("Burke Stream Schedule") {
                            Text(formatJson(schedule))
                                .font(.caption2)
                                .monospaced()
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let schedule = prefs["burke40k_stream_schedule_json"] as? String, !schedule.isEmpty {
                        DisclosureGroup("Burke40k Stream Schedule") {
                            Text(formatJson(schedule))
                                .font(.caption2)
                                .monospaced()
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text("No server preferences found").foregroundStyle(.secondary)
                }
            }

            Section("Info") {
                HStack {
                    Text("Device Timezone")
                    Spacer()
                    Text(TimeZone.current.identifier).foregroundStyle(.secondary).font(.caption)
                }
                HStack {
                    Text("Last Sync")
                    Spacer()
                    Text(isLoading ? "..." : (error != nil ? "Failed" : "Just now"))
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task {
                        await PushNotificationService.shared.syncPreferences()
                        await fetchServerPrefs()
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Sync & Refresh")
                    }
                }
            }
        }
        .navigationTitle("Notification Channels")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { appLog("NotifChannelsDebug: loading server prefs")
                Task { await fetchServerPrefs() } }
    }

    private var burkeStreamDetails: String? {
        if !settings.burkeStreamEnabled { return nil }
        if settings.burkeStreamAllDay { return "All day, every day" }
        let days = settings.burkeStreamDays.sorted().map { StreamSchedule.dayLabels[$0] }.joined(separator: ", ")
        let from = formatTime(settings.burkeStreamFromHour, settings.burkeStreamFromMinute)
        let to = formatTime(settings.burkeStreamToHour, settings.burkeStreamToMinute)
        return "\(days), \(from)-\(to)"
    }

    private var burke40kStreamDetails: String? {
        if !settings.burke40kEnabled { return nil }
        if settings.burke40kAllDay { return "All day, every day" }
        let days = settings.burke40kDays.sorted().map { StreamSchedule.dayLabels[$0] }.joined(separator: ", ")
        let from = formatTime(settings.burke40kFromHour, settings.burke40kFromMinute)
        let to = formatTime(settings.burke40kToHour, settings.burke40kToMinute)
        return "\(days), \(from)-\(to)"
    }

    private func formatTime(_ hour: Int, _ minute: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let period = hour < 12 ? "AM" : "PM"
        if minute == 0 { return "\(h) \(period)" }
        return String(format: "%d:%02d %@", h, minute, period)
    }

    private func formatJson(_ json: String) -> String {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: .prettyPrinted),
              let str = String(data: pretty, encoding: .utf8) else { return json }
        return str
    }

    private func fetchServerPrefs() async {
        isLoading = true
        error = nil

        guard let bearerToken = AccountViewModel.getBearerToken(),
              let url = URL(string: "https://api.burkeblack.tv/app/notification-preferences") else {
            error = "Not logged in"
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        TwitchAuthService.addPlatformHeaders(&request)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                error = "Server returned \((response as? HTTPURLResponse)?.statusCode ?? 0)"
                isLoading = false
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let prefs = json["data"] as? [String: Any] {
                serverPrefs = prefs
            } else {
                error = "Invalid response format"
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Row Components

private struct ChannelRow: View {
    let name: String
    let enabled: Bool
    var details: String? = nil
    var note: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(enabled ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(name)
                Spacer()
                Text(enabled ? "Enabled" : "Disabled")
                    .foregroundStyle(enabled ? .green : .red)
                    .font(.caption)
            }
            if let details {
                Text(details)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let note {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }
}

private struct ServerRow: View {
    let key: String
    let prefs: [String: Any]

    var body: some View {
        let fullKey = "notif_\(key)"
        let value = prefs[fullKey]
        let enabled: Bool = {
            if let intVal = value as? Int { return intVal == 1 }
            if let strVal = value as? String { return strVal == "1" }
            return false
        }()

        HStack {
            Circle()
                .fill(enabled ? .green : .red)
                .frame(width: 8, height: 8)
            Text(key.replacingOccurrences(of: "_", with: " ").capitalized)
            Spacer()
            if value == nil {
                Text("Not set").foregroundStyle(.orange).font(.caption)
            } else {
                Text(enabled ? "Enabled" : "Disabled")
                    .foregroundStyle(enabled ? .green : .red)
                    .font(.caption)
            }
        }
    }
}
