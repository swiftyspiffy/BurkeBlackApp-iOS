import SwiftUI


struct CaptainsDispatchView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    @State private var notifType = "burke_announcement"
    @State private var title = ""
    @State private var message = ""
    @State private var url = ""
    @State private var linkChoice = "none"  // none, twitch, website
    @State private var twitchChoice = "burkeblack"  // burkeblack, custom
    @State private var twitchChannel = ""
    @State private var websiteUrl = ""
    @State private var isSending = false
    @State private var channelConfirmData: TwitchChannelInfo? = nil
    @State private var showChannelSheet = false
    @State private var isCheckingChannel = false
    @State private var showConfirm = false
    @State private var showResult = false
    @State private var resultMessage = ""
    @State private var history: [NotificationHistoryItem] = []
    @State private var isLoadingHistory = true

    private var resolvedUrl: String? {
        switch linkChoice {
        case "twitch":
            let channel = twitchChoice == "burkeblack" ? "burkeblack" : twitchChannel.trimmingCharacters(in: .whitespaces)
            return channel.isEmpty ? nil : "https://twitch.tv/\(channel)"
        case "website":
            let trimmed = websiteUrl.trimmingCharacters(in: .whitespaces)
            return isValidUrl(trimmed) ? trimmed : nil
        default:
            return nil
        }
    }

    private var hasInvalidLink: Bool {
        if linkChoice == "website" && !websiteUrl.trimmingCharacters(in: .whitespaces).isEmpty {
            return !isValidUrl(websiteUrl)
        }
        if linkChoice == "twitch" && twitchChoice == "custom" && twitchChannel.trimmingCharacters(in: .whitespaces).isEmpty {
            return true
        }
        return false
    }

    private func isValidUrl(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: trimmed) else { return false }
        return url.scheme == "https" || url.scheme == "http"
    }

    private let titlePresets = [
        "Word from Captain Burke",
        "Dispatch from the Captain",
        "Message from BurkeBlack",
        "Announcement from The Dirty Skull",
    ]

    private let types = [
        ("burke_announcement", "Burke Announcement"),
        ("special_event", "Special Event"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Captain\u{2019}s Dispatch")
                    .font(PirateTheme.font(size: 28))
                    .foregroundStyle(PirateTheme.accentColor)
                    .padding(.top, 8)

                Text("Send word to all hands on deck")
                    .font(PirateTheme.font(size: 14))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.top, -12)

                // Type picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("Dispatch Type")
                        .font(PirateTheme.font(size: 14))
                        .foregroundStyle(.white.opacity(0.5))
                    Picker("Type", selection: $notifType) {
                        ForEach(types, id: \.0) { value, label in
                            Text(label).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Title presets
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title")
                        .font(PirateTheme.font(size: 14))
                        .foregroundStyle(.white.opacity(0.5))

                    FlowLayout(spacing: 8) {
                        ForEach(titlePresets, id: \.self) { preset in
                            Button {
                                title = preset
                            } label: {
                                Text(preset)
                                    .font(PirateTheme.font(size: 13))
                                    .foregroundStyle(title == preset ? .black : PirateTheme.accentColor)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(title == preset ? PirateTheme.accentColor : PirateTheme.accentColor.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                // Message
                VStack(alignment: .leading, spacing: 6) {
                    Text("Message")
                        .font(PirateTheme.font(size: 14))
                        .foregroundStyle(.white.opacity(0.5))
                    TextEditor(text: $message)
                        .frame(minHeight: 100)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Notification opens (optional)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Notification Opens...")
                        .font(PirateTheme.font(size: 14))
                        .foregroundStyle(.white.opacity(0.5))

                    Picker("Opens", selection: $linkChoice) {
                        Text("Dirty Skull").tag("none")
                        Text("Twitch").tag("twitch")
                        Text("Website").tag("website")
                    }
                    .pickerStyle(.segmented)

                    if linkChoice == "twitch" {
                        VStack(alignment: .leading, spacing: 8) {
                            Picker("Channel", selection: $twitchChoice) {
                                Text("BurkeBlack").tag("burkeblack")
                                Text("Other Channel").tag("custom")
                            }
                            .pickerStyle(.segmented)

                            if twitchChoice == "custom" {
                                TextField("Channel name", text: $twitchChannel)
                                    .textFieldStyle(.roundedBorder)
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                            }
                        }
                    }

                    if linkChoice == "website" {
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("https://...", text: $websiteUrl)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.URL)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                            if !websiteUrl.isEmpty && !isValidUrl(websiteUrl) {
                                Text("Enter a valid URL starting with https://")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }

                // Send button
                Button {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    Task { await handleSendTapped() }
                } label: {
                    HStack {
                        Spacer()
                        if isSending {
                            ProgressView().tint(.black)
                        } else {
                            Text("Send Dispatch")
                                .font(PirateTheme.font(size: 18))
                        }
                        Spacer()
                    }
                    .foregroundStyle(.black)
                    .padding(.vertical, 14)
                    .background(PirateTheme.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || message.trimmingCharacters(in: .whitespaces).isEmpty || isSending || isCheckingChannel || hasInvalidLink)

                // History
                Divider().overlay(PirateTheme.accentColor.opacity(0.2)).padding(.top, 8)

                Text("Recent Dispatches")
                    .font(PirateTheme.font(size: 20))
                    .foregroundStyle(PirateTheme.accentColor.opacity(0.8))

                if isLoadingHistory {
                    HStack { Spacer(); ProgressView().tint(PirateTheme.accentColor); Spacer() }
                } else if history.isEmpty {
                    Text("No dispatches sent yet")
                        .font(PirateTheme.font(size: 14))
                        .foregroundStyle(.white.opacity(0.3))
                } else {
                    ForEach(history) { item in
                        NotificationHistoryRow(item: item)
                    }
                }
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
        .confirmationDialog("Send this dispatch to all pirates?", isPresented: $showConfirm, titleVisibility: .visible) {
            Button("Send Now") { Task { await send() } }
            Button("Cancel", role: .cancel) {}
        }
        .overlay {
            if showChannelSheet, let info = channelConfirmData {
                ZStack {
                    Color.black
                        .ignoresSafeArea()

                    TwitchChannelConfirmView(info: info) { confirmed in
                        withAnimation(.easeOut(duration: 0.2)) {
                            showChannelSheet = false
                        }
                        if confirmed {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showConfirm = true
                            }
                        } else {
                            twitchChannel = ""
                            channelConfirmData = nil
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .transition(.opacity)
            }
        }
        .alert("Dispatch Result", isPresented: $showResult) {
            Button("OK") {}
        } message: {
            Text(resultMessage)
        }
        .onAppear { Task { await loadHistory() } }
    }

    private func handleSendTapped() async {
        // If custom Twitch channel, verify it first
        if linkChoice == "twitch" && twitchChoice == "custom" {
            let channel = twitchChannel.trimmingCharacters(in: .whitespaces)
            guard !channel.isEmpty else { return }
            isCheckingChannel = true
            appLog("CaptainsDispatch: looking up channel \(channel)")
            if let info = await lookupTwitchChannel(channel) {
                isCheckingChannel = false
                channelConfirmData = info
                // Small delay to let state settle before presenting sheet
                try? await Task.sleep(for: .milliseconds(100))
                showChannelSheet = true
            } else {
                isCheckingChannel = false
                resultMessage = "Could not find Twitch channel \"\(channel)\""
                showResult = true
            }
        } else {
            showConfirm = true
        }
    }

    private func lookupTwitchChannel(_ channel: String) async -> TwitchChannelInfo? {
        guard let bearerToken = AccountViewModel.getBearerToken(),
              let twitchCreds = await getTwitchCredentials(bearerToken: bearerToken) else { return nil }

        guard let url = URL(string: "https://api.twitch.tv/helix/users?login=\(channel)") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(twitchCreds.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(twitchCreds.clientId, forHTTPHeaderField: "Client-Id")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }

            struct UsersResponse: Codable {
                let data: [TwitchUser]
            }
            struct TwitchUser: Codable {
                let id: String
                let login: String
                let display_name: String
                let profile_image_url: String
                let created_at: String
            }

            let decoded = try JSONDecoder().decode(UsersResponse.self, from: data)
            guard let user = decoded.data.first else { return nil }

            // Get follower count
            var followerCount = 0
            if let followerUrl = URL(string: "https://api.twitch.tv/helix/channels/followers?broadcaster_id=\(user.id)&first=1") {
                var fReq = URLRequest(url: followerUrl)
                fReq.setValue("Bearer \(twitchCreds.accessToken)", forHTTPHeaderField: "Authorization")
                fReq.setValue(twitchCreds.clientId, forHTTPHeaderField: "Client-Id")
                if let (fData, _) = try? await URLSession.shared.data(for: fReq),
                   let fJson = try? JSONSerialization.jsonObject(with: fData) as? [String: Any] {
                    followerCount = fJson["total"] as? Int ?? 0
                }
            }

            return TwitchChannelInfo(
                login: user.login,
                displayName: user.display_name,
                profileImageUrl: user.profile_image_url,
                followerCount: followerCount,
                createdAt: user.created_at
            )
        } catch {
            appLog("CaptainsDispatch: channel lookup failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func getTwitchCredentials(bearerToken: String) async -> (accessToken: String, clientId: String)? {
        guard let url = URL(string: "https://api.burkeblack.tv/app/twitch-token") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        TwitchAuthService.addPlatformHeaders(&request)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }

            struct TokenResponse: Codable {
                let success: Bool
                let data: TokenData?
            }
            struct TokenData: Codable {
                let access_token: String
                let client_id: String
            }

            let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
            guard let td = decoded.data else { return nil }
            return (td.access_token, td.client_id)
        } catch {
            return nil
        }
    }

    private func send() async {
        isSending = true
        defer { isSending = false }
        appLog("CaptainsDispatch: sending \(notifType)")

        guard let bearerToken = AccountViewModel.getBearerToken(),
              let reqUrl = URL(string: "https://api.burkeblack.tv/app/captain/send-notification") else { return }

        var request = URLRequest(url: reqUrl)
        request.httpMethod = "POST"
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        TwitchAuthService.addPlatformHeaders(&request)

        let body: [String: Any?] = [
            "type": notifType,
            "title": title.trimmingCharacters(in: .whitespaces),
            "message": message.trimmingCharacters(in: .whitespaces),
            "url": resolvedUrl,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0

            if code == 200 {
                if let json = try? JSONDecoder().decode(APISuccessResponse<SendNotificationResult>.self, from: data), let result = json.data {
                    resultMessage = "Sent to \(result.ios_sent + result.android_sent) devices (\(result.ios_sent) iOS, \(result.android_sent) Android)"
                } else {
                    resultMessage = "Dispatch sent!"
                }
                appLog("CaptainsDispatch: sent successfully")
                title = ""
                message = ""
                linkChoice = "none"
                twitchChannel = ""
                websiteUrl = ""
                await loadHistory()
            } else {
                if let json = try? JSONDecoder().decode(APIErrorOrSuccess.self, from: data) {
                    resultMessage = json.error ?? "Failed to send"
                } else {
                    resultMessage = "Server error (\(code))"
                }
                appLog("CaptainsDispatch: send failed \(code)")
            }
            showResult = true
        } catch {
            resultMessage = error.localizedDescription
            showResult = true
        }
    }

    private func loadHistory() async {
        guard let bearerToken = AccountViewModel.getBearerToken(),
              let url = URL(string: "https://api.burkeblack.tv/app/captain/notification-history?limit=20") else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        TwitchAuthService.addPlatformHeaders(&request)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONDecoder().decode(APISuccessResponse<HistoryResponse>.self, from: data), let result = json.data {
                history = result.history
            }
        } catch {
            appLog("CaptainsDispatch: history load failed")
        }
        isLoadingHistory = false
    }
}

// MARK: - Models

struct SendNotificationResult: Codable {
    let ios_sent: Int
    let ios_failed: Int
    let android_sent: Int
    let android_failed: Int
}

struct NotificationHistoryItem: Codable, Identifiable {
    var id: Int { _id }
    let _id: Int
    let notification_type: String
    let title: String
    let message: String
    let url: String?
    let sent_by_username: String?
    let ios_sent: Int
    let ios_failed: Int
    let android_sent: Int
    let android_failed: Int
    let created_at: Int

    enum CodingKeys: String, CodingKey {
        case _id = "id"
        case notification_type, title, message, url
        case sent_by_username, ios_sent, ios_failed, android_sent, android_failed, created_at
    }

    var typeLabel: String {
        switch notification_type {
        case "burke_announcement": return "Announcement"
        case "special_event": return "Special Event"
        case "mod_announcement": return "Mod Announcement"
        case "channel_tidings": return "Tidings"
        case "burkeblack_stream": return "Stream Start"
        case "burke40k_stream": return "40k Stream"
        default: return notification_type
        }
    }

    var timeAgo: String {
        let seconds = Int(Date().timeIntervalSince1970) - created_at
        let minutes = seconds / 60
        let hours = minutes / 60
        let days = hours / 24
        if days > 0 { return "\(days)d ago" }
        if hours > 0 { return "\(hours)h ago" }
        if minutes > 0 { return "\(minutes)m ago" }
        return "just now"
    }
}

struct HistoryResponse: Codable {
    let history: [NotificationHistoryItem]
}

// MARK: - History Row

struct NotificationHistoryRow: View {
    let item: NotificationHistoryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.typeLabel)
                    .font(PirateTheme.font(size: 12))
                    .foregroundStyle(PirateTheme.accentColor.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(PirateTheme.accentColor.opacity(0.1))
                    .clipShape(Capsule())
                Spacer()
                Text(item.timeAgo)
                    .font(PirateTheme.font(size: 11))
                    .foregroundStyle(.white.opacity(0.3))
            }
            Text(item.title)
                .font(PirateTheme.font(size: 15))
                .foregroundStyle(.white)
            HStack(spacing: 12) {
                if let sender = item.sent_by_username {
                    Text("by \(sender)")
                        .font(PirateTheme.font(size: 11))
                        .foregroundStyle(.white.opacity(0.3))
                }
                Text("iOS: \(item.ios_sent)")
                    .font(PirateTheme.font(size: 11))
                    .foregroundStyle(.white.opacity(0.3))
                Text("Android: \(item.android_sent)")
                    .font(PirateTheme.font(size: 11))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
    }
}

// MARK: - Twitch Channel Info

struct TwitchChannelInfo: Identifiable {
    var id: String { login }
    let login: String
    let displayName: String
    let profileImageUrl: String
    let followerCount: Int
    let createdAt: String

    var formattedCreatedAt: String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: createdAt) {
            return date.formatted(date: .long, time: .omitted)
        }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: createdAt) {
            return date.formatted(date: .long, time: .omitted)
        }
        return createdAt
    }
}

// MARK: - Channel Confirmation View

struct TwitchChannelConfirmView: View {
    let info: TwitchChannelInfo
    let onResult: (Bool) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Just checkin\u{2019}, Captain...")
                .font(PirateTheme.font(size: 24))
                .foregroundStyle(PirateTheme.accentColor)
                .padding(.top, 24)

            Text("Is this the correct channel?")
                .font(PirateTheme.font(size: 16))
                .foregroundStyle(.white.opacity(0.6))

            // Channel card
            VStack(spacing: 14) {
                AsyncImage(url: URL(string: info.profileImageUrl)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundStyle(.purple.opacity(0.4))
                }
                .frame(width: 80, height: 80)
                .clipShape(Circle())

                Text(info.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text("twitch.tv/\(info.login)")
                    .font(.caption)
                    .foregroundStyle(.purple)

                HStack(spacing: 24) {
                    VStack(spacing: 2) {
                        Text("\(info.followerCount.formatted())")
                            .font(.headline)
                            .foregroundStyle(PirateTheme.accentColor)
                        Text("Followers")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    VStack(spacing: 2) {
                        Text(info.formattedCreatedAt)
                            .font(.headline)
                            .foregroundStyle(PirateTheme.accentColor)
                        Text("Created")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(PirateTheme.accentColor.opacity(0.2), lineWidth: 1))
            )
            .padding(.horizontal, 20)

            // Buttons
            VStack(spacing: 10) {
                Button {
                    onResult(true)
                } label: {
                    Text("Aye, That Be the One!")
                        .font(PirateTheme.font(size: 18))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(PirateTheme.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    onResult(false)
                } label: {
                    Text("Nay, Wrong Ship")
                        .font(PirateTheme.font(size: 16))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }

    }
}

// MARK: - Flow Layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: ProposedViewSize(width: bounds.width, height: bounds.height), subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
