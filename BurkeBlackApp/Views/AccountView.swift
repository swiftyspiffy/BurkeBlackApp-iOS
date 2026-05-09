import SwiftUI


struct AccountView: View {
    @ObservedObject private var settings = AppSettings.shared
    @StateObject private var viewModel = AccountViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoggedIn {
                    LoggedInView(viewModel: viewModel)
                } else {
                    LoggedOutView(viewModel: viewModel)
                }
            }
            .onAppear { appLog("Account: view appeared, loggedIn=\(viewModel.isLoggedIn)") }
            .navigationBarHidden(true)
            .alert("Login Failed", isPresented: $viewModel.showError) {
                Button("OK") {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active && viewModel.isLoggedIn {
                    appLog("Account: refreshing dashboard on foreground")
                    Task { await viewModel.refreshDashboard() }
                }
            }
        }
    }
}

struct LoggedOutView: View {
    @ObservedObject var viewModel: AccountViewModel
    @State private var showReviewerLogin = false
    @State private var reviewerUsername = ""
    @State private var reviewerPassword = ""
    @State private var reviewerError = ""
    @State private var showReviewerError = false
    @State private var isReviewerLoading = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "person.circle")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundStyle(.gray.opacity(0.4))
            Text("Sign in to see your stats, giveaways, and send soundbytes!")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                appLog("Account: login with Twitch tapped")
                Task { await viewModel.loginWithTwitch() }
            } label: {
                HStack(spacing: 10) {
                    Image("TwitchLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                    Text("Login with Twitch")
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color(red: 0.57, green: 0.33, blue: 0.86))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 40)
            .disabled(viewModel.isLoading)
            .overlay { if viewModel.isLoading { ProgressView() } }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 5)
                    .onEnded { _ in showReviewerLogin = true }
            )
            Spacer()
            Spacer()
        }
        .alert("Reviewer Access", isPresented: $showReviewerLogin) {
            TextField("Username", text: $reviewerUsername)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            SecureField("Password", text: $reviewerPassword)
            Button("Cancel", role: .cancel) {
                reviewerUsername = ""; reviewerPassword = ""
            }
            Button("Login") {
                Task { await reviewerLogin() }
            }
        } message: {
            Text("Enter reviewer credentials")
        }
        .alert("Error", isPresented: $showReviewerError) {
            Button("OK") {}
        } message: {
            Text(reviewerError)
        }
    }

    private func reviewerLogin() async {
        guard !reviewerUsername.isEmpty, !reviewerPassword.isEmpty else { return }
        isReviewerLoading = true
        defer { isReviewerLoading = false }

        guard let url = URL(string: "https://api.burkeblack.tv/app/auth/reviewer") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        TwitchAuthService.addPlatformHeaders(&request)

        struct ReviewerBody: Encodable { let username: String; let password: String }
        request.httpBody = try? JSONEncoder().encode(ReviewerBody(username: reviewerUsername, password: reviewerPassword))

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return }

            if http.statusCode != 200 {
                if let e = try? JSONDecoder().decode(APIErrorOrSuccess.self, from: data) {
                    reviewerError = e.error ?? "Invalid credentials"
                } else {
                    reviewerError = "Invalid credentials"
                }
                showReviewerError = true
                return
            }

            struct ReviewerResponse: Codable { let token: String; let username: String; let userId: String?; let avatarUrl: String?; let isModerator: Bool?; enum CodingKeys: String, CodingKey { case token, username; case userId = "user_id"; case avatarUrl = "avatar_url"; case isModerator = "is_moderator" } }
            let decoded = try JSONDecoder().decode(APISuccessResponse<ReviewerResponse>.self, from: data)
            guard let result = decoded.data else { return }

            await viewModel.reviewerLogin(token: result.token, username: result.username, avatarUrl: result.avatarUrl, moderator: result.isModerator ?? false)
            reviewerUsername = ""; reviewerPassword = ""
        } catch {
            reviewerError = error.localizedDescription
            showReviewerError = true
        }
    }
}

struct LoggedInView: View {
    @ObservedObject var viewModel: AccountViewModel
    @State private var showGiveaways = false
    @State private var showFeedback = false
    @State private var showSoundbytes = false
    @State private var showModPanel = false
    @State private var showCaptainsDispatch = false
    @State private var showModDispatch = false

    var body: some View {
        List {
            // Profile section with badges on right
            Section {
                HStack(spacing: 14) {
                    AsyncImage(url: viewModel.avatarURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundStyle(.purple.opacity(0.5))
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.username)
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text(viewModel.userRole)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if viewModel.subscribed {
                            Text(viewModel.subTier ?? "Subscriber")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }

                    Spacer()

                    // Badges stacked on right
                    VStack(alignment: .trailing, spacing: 4) {
                        if viewModel.follows {
                            BadgeView(text: "Follower", color: .purple)
                        }
                        if viewModel.subscribed {
                            BadgeView(text: "Subscriber", color: .blue)
                        }
                        if viewModel.isModerator {
                            BadgeView(text: "Moderator", color: .cyan)
                        }
                        if viewModel.isSubGifter {
                            BadgeView(text: "Gifter", color: .pink)
                        }
                        if viewModel.isBitsSender {
                            HStack(spacing: 2) {
                                Image(cheerImageForTotal(viewModel.totalBits))
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 14, height: 14)
                                Text("Bits")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.orange)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.orange.opacity(0.15))
                            .clipShape(Capsule())
                        }
                        if viewModel.isDonator {
                            BadgeView(text: "Donator", color: .green)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            // Captain's Dispatch (Burke only, or swiftyspiffy with debug toggle)
            if !AppSettings.shared.presentationMode && (viewModel.username.lowercased() == "burkeblack" || (viewModel.username.lowercased() == "swiftyspiffy" && AppSettings.shared.debugShowCaptainsDispatch)) {
                Section {
                    Button { appLog("Account: opening captains dispatch")
                        showCaptainsDispatch = true } label: {
                        HStack {
                            Image(systemName: "megaphone.fill")
                                .foregroundStyle(PirateTheme.accentColor)
                            Text("Captain\u{2019}s Dispatch")
                        }
                    }
                }
            }

            // Mod Dispatch (moderators only)
            if viewModel.isModerator && !AppSettings.shared.presentationMode {
                Section {
                    Button { appLog("Account: opening mod dispatch")
                        showModDispatch = true } label: {
                        HStack {
                            Image(systemName: "bell.badge.fill")
                                .foregroundStyle(PirateTheme.accentColor)
                            Text("Crew Dispatch")
                        }
                    }
                }
            }

            // Action buttons
            Section {
                HStack(spacing: 12) {
                    Button { showGiveaways = true } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "gift.fill")
                                .font(.title2)
                                .foregroundStyle(.orange)
                            Text("Giveaways")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button { showSoundbytes = true } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "music.note.list")
                                .font(.title2)
                                .foregroundStyle(PirateTheme.accentColor)
                            Text("Soundbytes")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if viewModel.isModerator && !AppSettings.shared.presentationMode {
                        Button { showModPanel = true } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "shield.fill")
                                    .font(.title2)
                                    .foregroundStyle(.cyan)
                                Text("Mod Panel")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }

            // Stats
            Section("Your Stats") {
                StatRow(label: "Doubloons", value: StatFormatter.integer(viewModel.doubloons))
                NavigationLink {
                    DonationsView(token: viewModel.bearerToken ?? "")
                } label: {
                    StatRow(label: "Donations", value: StatFormatter.currency(viewModel.donations + viewModel.eventsDonations))
                }
                NavigationLink {
                    BitsView(token: viewModel.bearerToken ?? "")
                } label: {
                    StatRow(label: "Bits Cheered", value: StatFormatter.integer(viewModel.totalBits))
                }
                if let followedAt = viewModel.followedAt {
                    StatRow(label: "Following Since", value: formatFollowDate(followedAt))
                }
            }

            if let sub = viewModel.latestSub {
                Section("Subscription") {
                    StatRow(label: "Tier", value: sub.tier)
                    StatRow(label: "Months", value: StatFormatter.integer(sub.cumulativeMonths))
                    if sub.streakMonths > 0 {
                        StatRow(label: "Streak", value: StatFormatter.integer(sub.streakMonths))
                    }
                    if sub.isGift, let gifter = sub.gifter {
                        StatRow(label: "Gifted by", value: gifter)
                    }
                    StatRow(label: "Recent Subscription", value: formatFollowDate(sub.date))
                    if sub.cumulativeMonths > 0 {
                        StatRow(label: "Subscribed Since", value: subscribedSince(months: sub.cumulativeMonths))
                    }
                }
            }

            // Giveaway stats
            Section("Giveaways") {
                StatRow(label: "Entered", value: StatFormatter.integer(viewModel.giveawaysEntered))
                StatRow(label: "Won", value: StatFormatter.integer(viewModel.giveawaysWon))
                StatRow(label: "Donated", value: StatFormatter.integer(viewModel.giveawaysDonated))
            }

            // Soundbyte stats
            Section("Soundbytes") {
                StatRow(label: "Credits", value: StatFormatter.integer(viewModel.soundbyteCredits))
                StatRow(label: "Soundbytes Sent", value: StatFormatter.integer(viewModel.soundbyteSends))
                if let fav = viewModel.favSoundbyte {
                    StatRow(label: "Most Sent", value: "\(fav.name) (\(fav.count)x)")
                }
                if let last = viewModel.lastSoundbyte {
                    StatRow(label: "Last Sent", value: "\(last.name) (\(last.formattedDate))")
                }
            }

            Section {
                Button { showFeedback = true } label: {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundStyle(PirateTheme.accentColor)
                        Text("Send Feedback")
                    }
                }
            }

            Section {
                Button("Sign Out", role: .destructive) { appLog("Account: sign out tapped"); viewModel.logout() }
            }
        }
        .refreshable { await viewModel.refreshDashboard() }
        .fullScreenCover(isPresented: $showGiveaways) {
            NavigationStack {
                GiveawaysHubView(token: viewModel.bearerToken ?? "")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showGiveaways = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showFeedback) {
            NavigationStack {
                FeedbackView(username: viewModel.username, userId: nil)
                    .navigationTitle("Feedback")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showFeedback = false }
                        }
                    }
            }
        }
        .fullScreenCover(isPresented: $showCaptainsDispatch) {
            NavigationStack {
                CaptainsDispatchView()
            }
        }
        .fullScreenCover(isPresented: $showModDispatch) {
            NavigationStack {
                ModDispatchView()
            }
        }
        .fullScreenCover(isPresented: $showModPanel) {
            NavigationStack {
                ModPanelView(token: viewModel.bearerToken ?? "", username: viewModel.username)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showModPanel = false }
                        }
                    }
            }
        }
        .fullScreenCover(isPresented: $showSoundbytes) {
            NavigationStack {
                SoundbytesView(token: viewModel.bearerToken ?? "", onCreditsChanged: { newCredits in
                    viewModel.soundbyteCredits = newCredits
                })
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { showSoundbytes = false }
                    }
                }
            }
        }
    }
}

// MARK: - Components

struct BadgeView: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(color)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

struct GiveawaysHubView: View {
    let token: String
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var isSearching = false

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("Entered").tag(0)
                Text("Won").tag(1)
                Text("Donated").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top)

            if isSearching {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search name or donator...", text: $searchText)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
                .padding(.top, 8)
            }

            // Use ZStack to keep views alive across tab switches
            ZStack {
                GiveawayEntriesView(token: token, searchText: searchText)
                    .opacity(selectedTab == 0 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 0)
                GiveawayWinsView(token: token, searchText: searchText)
                    .opacity(selectedTab == 1 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 1)
                GiveawayDonatedView(token: token, searchText: searchText)
                    .opacity(selectedTab == 2 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 2)
            }
        }
        .navigationTitle("Giveaways")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    withAnimation {
                        isSearching.toggle()
                        if !isSearching { searchText = "" }
                    }
                } label: {
                    Image(systemName: isSearching ? "xmark" : "magnifyingglass")
                }
            }
        }
    }
}

private func cheerImageForTotal(_ bits: Int) -> String {
    if bits >= 10000 { return "cheer_10000" }
    if bits >= 5000 { return "cheer_5000" }
    if bits >= 100 { return "cheer_100" }
    return "cheer_1"
}

private func subscribedSince(months: Int) -> String {
    let calendar = Calendar.current
    guard let date = calendar.date(byAdding: .month, value: -months, to: Date()) else {
        return "\(months) months ago"
    }
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM, yyyy"
    return formatter.string(from: date)
}

private func formatFollowDate(_ dateStr: String) -> String {
    let outputFormatter = DateFormatter()
    outputFormatter.dateFormat = "MMM d, yyyy"

    // Try ISO 8601 with fractional seconds
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = iso.date(from: dateStr) {
        return outputFormatter.string(from: date)
    }
    // Try ISO 8601 without fractional seconds
    iso.formatOptions = [.withInternetDateTime]
    if let date = iso.date(from: dateStr) {
        return outputFormatter.string(from: date)
    }
    // Try datetime format
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd HH:mm:ss"
    if let date = df.date(from: dateStr) {
        return outputFormatter.string(from: date)
    }
    // Try date-only format
    df.dateFormat = "yyyy-MM-dd"
    if let date = df.date(from: dateStr) {
        return outputFormatter.string(from: date)
    }
    return dateStr
}

struct StatRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}

#Preview("Logged Out") { AccountView() }
