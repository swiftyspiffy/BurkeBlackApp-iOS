import SwiftUI

private let lateShiftLogins = ["crream", "gassymexican", "burkeblack", "cletusbueford"]

struct LateShiftView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss

    @State private var streamers: [LateShiftStreamer] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("The Late Shift")
                    .font(PirateTheme.font(size: 28))
                    .foregroundStyle(PirateTheme.accentColor)
                    .padding(.top, 8)

                Text("The Late Shift Twitch stream team")
                    .font(PirateTheme.font(size: 15))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, -12)

                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(PirateTheme.accentColor)
                        Text("Gathering the crew...")
                            .font(PirateTheme.font(size: 14))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.red.opacity(0.6))
                        Text("Lost at sea!")
                            .font(PirateTheme.font(size: 18))
                            .foregroundStyle(.white)
                        Text(error)
                            .font(PirateTheme.font(size: 13))
                            .foregroundStyle(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                        Button {
                            Task { await loadStreamers() }
                        } label: {
                            Text("Try Again")
                                .font(PirateTheme.font(size: 16))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 10)
                                .background(PirateTheme.accentColor)
                                .clipShape(Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    ForEach(streamers) { streamer in
                        StreamerCard(streamer: streamer)
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
        .task {
            await loadStreamers()
        }
    }

    private func loadStreamers() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // 1. Get Twitch credentials from backend
            guard let bearerToken = AccountViewModel.getBearerToken() else {
                errorMessage = "Log in with Twitch to view The Late Shift"
                return
            }

            let (twitchToken, clientId) = try await fetchTwitchCredentials(bearerToken: bearerToken)

            // 2. Fetch user data for all streamers
            let loginQuery = lateShiftLogins.map { "login=\($0)" }.joined(separator: "&")
            let usersData: TwitchUsersResponse = try await twitchGet(
                url: "https://api.twitch.tv/helix/users?\(loginQuery)",
                token: twitchToken, clientId: clientId
            )

            // 3. Fetch stream status for all streamers
            let streamQuery = lateShiftLogins.map { "user_login=\($0)" }.joined(separator: "&")
            let streamsData: TwitchStreamsResponse = try await twitchGet(
                url: "https://api.twitch.tv/helix/streams?\(streamQuery)",
                token: twitchToken, clientId: clientId
            )

            // 4. Fetch follower counts per user
            var followerCounts: [String: Int] = [:]
            for user in usersData.data {
                do {
                    let followersData: TwitchFollowersResponse = try await twitchGet(
                        url: "https://api.twitch.tv/helix/channels/followers?broadcaster_id=\(user.id)&first=1",
                        token: twitchToken, clientId: clientId
                    )
                    followerCounts[user.login.lowercased()] = followersData.total
                } catch {
                    appLog("LateShift: failed to fetch followers for \(user.login): \(error)")
                }
            }

            // 5. Build streamer list in display order
            var result: [LateShiftStreamer] = []
            for login in lateShiftLogins {
                guard let user = usersData.data.first(where: { $0.login.lowercased() == login.lowercased() }) else { continue }
                let stream = streamsData.data.first(where: { $0.userLogin.lowercased() == login.lowercased() })
                result.append(LateShiftStreamer(
                    login: user.login,
                    displayName: user.displayName,
                    profileImageUrl: user.profileImageUrl,
                    offlineImageUrl: user.offlineImageUrl,
                    broadcasterId: user.id,
                    followerCount: followerCounts[login.lowercased()] ?? 0,
                    isLive: stream != nil,
                    viewerCount: stream?.viewerCount ?? 0,
                    streamTitle: stream?.title ?? "",
                    gameName: stream?.gameName ?? ""
                ))
            }

            streamers = result
            appLog("LateShift: loaded \(result.count) streamers")
        } catch {
            appLog("LateShift: error: \(error)")
            errorMessage = "\(error.localizedDescription)"
        }
    }

    private func fetchTwitchCredentials(bearerToken: String) async throws -> (String, String) {
        guard let url = URL(string: "https://api.burkeblack.tv/app/twitch-token") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        TwitchAuthService.addPlatformHeaders(&request)

        appLog("LateShift: fetching twitch credentials...")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if http.statusCode == 401 {
            appLog("LateShift: backend returned 401 - token expired")
            throw URLError(.userAuthenticationRequired)
        }

        guard http.statusCode == 200 else {
            appLog("LateShift: backend returned \(http.statusCode)")
            throw URLError(.badServerResponse)
        }

        struct TokenResponse: Codable {
            let success: Bool
            let data: TokenData?
        }
        struct TokenData: Codable {
            let access_token: String
            let client_id: String
        }

        let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
        guard let tokenData = decoded.data else {
            throw URLError(.cannotParseResponse)
        }
        return (tokenData.access_token, tokenData.client_id)
    }

    private func twitchGet<T: Codable>(url urlString: String, token: String, clientId: String) async throws -> T {
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Client-Id")
        appLog("LateShift: GET \(urlString)")
        let (data, resp) = try await URLSession.shared.data(for: request)
        if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
            appLog("LateShift: Twitch API returned \(http.statusCode)")
            let body = String(data: data, encoding: .utf8) ?? ""
            appLog("LateShift: response: \(body.prefix(200))")
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Models

private struct LateShiftStreamer: Identifiable {
    var id: String { login }
    let login: String
    let displayName: String
    let profileImageUrl: String
    let offlineImageUrl: String
    let broadcasterId: String
    let followerCount: Int
    let isLive: Bool
    let viewerCount: Int
    let streamTitle: String
    let gameName: String
}

private struct TwitchUsersResponse: Codable {
    let data: [TwitchUser]
}

private struct TwitchUser: Codable {
    let id: String
    let login: String
    let displayName: String
    let profileImageUrl: String
    let offlineImageUrl: String

    enum CodingKeys: String, CodingKey {
        case id, login
        case displayName = "display_name"
        case profileImageUrl = "profile_image_url"
        case offlineImageUrl = "offline_image_url"
    }
}

private struct TwitchStreamsResponse: Codable {
    let data: [TwitchStream]
}

private struct TwitchStream: Codable {
    let userLogin: String
    let title: String
    let gameName: String
    let viewerCount: Int

    enum CodingKeys: String, CodingKey {
        case title
        case userLogin = "user_login"
        case gameName = "game_name"
        case viewerCount = "viewer_count"
    }
}

private struct TwitchFollowersResponse: Codable {
    let total: Int
}

// MARK: - Streamer Card

private struct StreamerCard: View {
    let streamer: LateShiftStreamer

    var body: some View {
        Link(destination: URL(string: "https://twitch.tv/\(streamer.login)")!) {
            VStack(spacing: 0) {
                // Banner image
                ZStack(alignment: .bottomLeading) {
                    AsyncImage(url: URL(string: streamer.offlineImageUrl)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle().fill(Color.white.opacity(0.05))
                    }
                    .frame(height: 120)
                    .clipped()
                    .overlay(
                        LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                    )

                    // Live badge
                    if streamer.isLive {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(.red)
                                .frame(width: 8, height: 8)
                            Text("LIVE")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.8))
                        .clipShape(Capsule())
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .topTrailing)
                        .frame(maxHeight: .infinity, alignment: .top)
                    }

                    // Profile + name overlay
                    HStack(spacing: 12) {
                        AsyncImage(url: URL(string: streamer.profileImageUrl)) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Circle().fill(Color.white.opacity(0.1))
                        }
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(streamer.isLive ? PirateTheme.accentColor : Color.clear, lineWidth: 2)
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(streamer.displayName)
                                .font(PirateTheme.font(size: 18))
                                .foregroundStyle(.white)
                            HStack(spacing: 4) {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 10))
                                Text(formatCount(streamer.followerCount))
                                    .font(.caption2)
                            }
                            .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .padding(12)
                }

                // Stream info (if live)
                if streamer.isLive {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 10))
                            Text("\(formatCount(streamer.viewerCount)) viewers")
                                .font(.caption)
                            Spacer()
                            Text(streamer.gameName)
                                .font(.caption)
                                .foregroundStyle(PirateTheme.accentColor)
                        }
                        .foregroundStyle(.white.opacity(0.6))

                        Text(streamer.streamTitle)
                            .font(PirateTheme.font(size: 13))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                } else {
                    HStack {
                        Text("Offline")
                            .font(PirateTheme.font(size: 13))
                            .foregroundStyle(.white.opacity(0.3))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.05))
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(streamer.isLive ? PirateTheme.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}
