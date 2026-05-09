import SwiftUI


@MainActor
class ModPanelViewModel: ObservableObject {
    let token: String
    @Published var perms: ModPermissions?
    @Published var soundbytesEnabled = true
    @Published var enforcementsEnabled = true
    @Published var isLoading = true
    @Published var alertMessage = ""
    @Published var showAlert = false

    init(token: String) {
        self.token = token
    }

    func load() async {
        appLog("Mod panel loading permissions")
        do {
            let p: ModPermissionsResponse = try await modGet("/mod/permissions")
            perms = p.toPermissions()
        } catch {
            alertMessage = "Permissions: \(error.localizedDescription)"
            showAlert = true
        }
        do {
            let s: ModSettingsResponse = try await modGet("/mod/settings")
            soundbytesEnabled = s.soundbytesEnabled
            enforcementsEnabled = s.enforcePunishments
        } catch {
            // Settings may fail if no access - that's ok
        }
        isLoading = false
    }

    func toggleSoundbytes() async {
        appLog("Mod: toggling soundbytes")
        do {
            let r: ToggleSBResponse = try await modPost("/mod/toggle-soundbytes")
            soundbytesEnabled = r.soundbytesEnabled
        } catch { showError(error) }
    }

    func toggleEnforcements() async {
        appLog("Mod: toggling enforcements")
        do {
            let r: ToggleCEResponse = try await modPost("/mod/toggle-enforcements")
            enforcementsEnabled = r.enforcePunishments
        } catch { showError(error) }
    }

    func restartBot() async {
        appLog("Mod: restarting bot")
        do {
            let _: MessageResponse = try await modPost("/mod/restart-bot")
            alertMessage = "Restart command sent!"
            showAlert = true
        } catch { showError(error) }
    }

    func sendAlertBurke(message: String) async {
        appLog("Mod: sending alert to Burke")
        do {
            let body = ["message": message]
            let r: MessageResponse = try await modPost("/mod/alert-burke", body: body)
            alertMessage = r.message
            showAlert = true
        } catch { showError(error) }
    }

    private func showError(_ error: Error) {
        alertMessage = error.localizedDescription
        showAlert = true
    }

    func modGet<T: Codable>(_ path: String) async throws -> T {
        guard let url = URL(string: "https://api.burkeblack.tv/app\(path)") else { throw AuthError.invalidURL }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        TwitchAuthService.addPlatformHeaders(&req)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            if let e = try? JSONDecoder().decode(APIErrorOrSuccess.self, from: data) {
                throw AuthError.apiError(e.error ?? "Error")
            }
            throw AuthError.dashboardFailed
        }
        let decoded = try JSONDecoder().decode(APISuccessResponse<T>.self, from: data)
        guard let result = decoded.data else { throw AuthError.dashboardFailed }
        return result
    }

    func modPost<T: Codable>(_ path: String, body: Encodable? = nil) async throws -> T {
        guard let url = URL(string: "https://api.burkeblack.tv/app\(path)") else { throw AuthError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        TwitchAuthService.addPlatformHeaders(&req)
        if let body { req.httpBody = try JSONEncoder().encode(body) }
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            if let e = try? JSONDecoder().decode(APIErrorOrSuccess.self, from: data) {
                throw AuthError.apiError(e.error ?? "Error")
            }
            throw AuthError.dashboardFailed
        }
        let decoded = try JSONDecoder().decode(APISuccessResponse<T>.self, from: data)
        guard let result = decoded.data else { throw AuthError.dashboardFailed }
        return result
    }
}

// MARK: - Models

struct ModPermissionsResponse: Codable {
    let admin: FlexInt
    let commands, chat, timeout, spoiler, timed, links, giveaways, audio, settings: FlexInt

    func toPermissions() -> ModPermissions {
        ModPermissions(
            admin: admin.isOne, commands: commands.isOne, chat: chat.isOne,
            timeout: timeout.isOne, spoiler: spoiler.isOne,
            timed: timed.isOne, links: links.isOne,
            giveaways: giveaways.isOne, audio: audio.isOne,
            settings: settings.isOne
        )
    }
}

// Handles PHP returning either "1" (string) or 1 (int)
struct FlexInt: Codable {
    let value: Int
    var isOne: Bool { value == 1 }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let i = try? container.decode(Int.self) {
            value = i
        } else if let s = try? container.decode(String.self) {
            value = Int(s) ?? 0
        } else {
            value = 0
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

struct ModPermissions {
    let admin, commands, chat, timeout, spoiler, timed, links, giveaways, audio, settings: Bool
}

struct ModSettingsResponse: Codable {
    let soundbytesEnabled: Bool
    let enforcePunishments: Bool
    enum CodingKeys: String, CodingKey {
        case soundbytesEnabled = "soundbytes_enabled"
        case enforcePunishments = "enforce_punishments"
    }
}

struct ToggleSBResponse: Codable {
    let soundbytesEnabled: Bool
    enum CodingKeys: String, CodingKey { case soundbytesEnabled = "soundbytes_enabled" }
}

struct ToggleCEResponse: Codable {
    let enforcePunishments: Bool
    enum CodingKeys: String, CodingKey { case enforcePunishments = "enforce_punishments" }
}

struct MessageResponse: Codable { let message: String }

// MARK: - Main View

struct ModPanelView: View {
    @ObservedObject private var settings = AppSettings.shared
    let token: String
    let username: String
    @StateObject private var vm: ModPanelViewModel
    @State private var showRestartConfirm = false
    @State private var showAlertBurke = false
    @State private var alertBurkeMessage = ""
    @State private var isSendingAlert = false

    init(token: String, username: String) {
        self.token = token
        self.username = username
        _vm = StateObject(wrappedValue: ModPanelViewModel(token: token))
    }

    var body: some View {
        Group {
            if vm.isLoading {
                ProgressView()
            } else if vm.perms == nil {
                ContentUnavailableView("Access Denied", systemImage: "lock.shield", description: Text("You don't have moderator permissions."))
            } else {
                List {
                    // Quick actions
                    if let perms = vm.perms {
                        Section {
                            HStack(spacing: 10) {
                                if perms.admin {
                                    Button { showRestartConfirm = true } label: {
                                        ModActionButton(
                                            icon: "arrow.trianglehead.counterclockwise",
                                            title: "Restart\nBot",
                                            color: .red
                                        )
                                    }
                                }

                                if perms.settings {
                                    Button { Task { await vm.toggleSoundbytes() } } label: {
                                        ModActionButton(
                                            icon: vm.soundbytesEnabled ? "speaker.slash.fill" : "speaker.fill",
                                            title: vm.soundbytesEnabled ? "Disable\nSoundbytes" : "Enable\nSoundbytes",
                                            color: vm.soundbytesEnabled ? .orange : .green
                                        )
                                    }

                                    Button { Task { await vm.toggleEnforcements() } } label: {
                                        ModActionButton(
                                            icon: vm.enforcementsEnabled ? "shield.slash" : "shield.fill",
                                            title: vm.enforcementsEnabled ? "Disable\nEnforcements" : "Enable\nEnforcements",
                                            color: vm.enforcementsEnabled ? .yellow : .green
                                        )
                                    }
                                }

                                Button { showAlertBurke = true } label: {
                                    ModActionButton(
                                        icon: "exclamationmark.triangle.fill",
                                        title: "Alert\nBurke",
                                        color: .orange
                                    )
                                }
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }

                        if perms.chat || perms.timeout || perms.spoiler {
                            Section("Moderator Tools") {
                                ModRow(icon: "person.badge.shield.checkmark", title: "Viewer Lookup", color: .cyan, destination: ModViewerLookupView(token: token))
                                if perms.links {
                                    ModRow(icon: "link", title: "Shorten Links", color: .cyan, destination: ModLinksView(vm: vm))
                                }
                            }
                        }

                        if perms.commands || perms.timed || perms.timeout || perms.spoiler {
                            Section("Chat") {
                                if perms.commands {
                                    ModRow(icon: "text.bubble", title: "Commands", color: PirateTheme.accentColor, destination: ModCommandsView(vm: vm))
                                }
                                if perms.timed {
                                    ModRow(icon: "clock.arrow.circlepath", title: "Timed Messages", color: PirateTheme.accentColor, destination: ModTimedMessagesView(vm: vm))
                                }
                                if perms.timeout {
                                    ModRow(icon: "exclamationmark.bubble", title: "Timeout Words", color: PirateTheme.accentColor, destination: ModTimeoutWordsView(vm: vm))
                                }
                                if perms.spoiler {
                                    ModRow(icon: "eye.slash", title: "Spoiler Words", color: PirateTheme.accentColor, destination: ModSpoilerWordsView(vm: vm))
                                }
                            }
                        }

                        if perms.giveaways {
                            Section("Giveaways") {
                                ModRow(icon: "tray.full", title: "Submissions", color: .orange, destination: ModGiveawaySubmissionsView(vm: vm))
                                ModRow(icon: "plus.circle", title: "Add Giveaway", color: .orange, destination: ModAddGiveawayView(vm: vm))
                                ModRow(icon: "eye", title: "Unhide Submission", color: .orange, destination: ModUnhideGiveawaysView(vm: vm))
                                ModRow(icon: "clock", title: "Giveaway History", color: .orange, destination: ModGiveawayHistoryView(vm: vm))
                                ModRow(icon: "trophy", title: "View Wins", color: .orange, destination: ModViewWinsView(vm: vm))
                            }
                        }

                        if perms.audio {
                            Section("Soundbytes") {
                                ModRow(icon: "music.note.list", title: "Library", color: .purple, destination: ModSoundbyteLibraryView(vm: vm))
                                ModRow(icon: "creditcard", title: "Credits", color: .purple, destination: ModSBCreditsView(vm: vm))
                                ModRow(icon: "clock.arrow.circlepath", title: "History", color: .purple, destination: ModSBHistoryView(vm: vm))
                            }

                            Section("Notifications") {
                                ModRow(icon: "bell.badge", title: "Send Announcement", color: .orange, destination: ModSendNotificationView(token: token))
                                ModRow(icon: "clock", title: "Notification History", color: .orange, destination: ModNotificationHistoryView(token: token))
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Mod Panel")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load() }
        .confirmationDialog("Restart Bot?", isPresented: $showRestartConfirm, titleVisibility: .visible) {
            Button("Restart", role: .destructive) { Task { await vm.restartBot() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will restart the bot. Are you sure?")
        }
        .alert("", isPresented: $vm.showAlert) {
            Button("OK") {}
        } message: {
            Text(vm.alertMessage)
        }
        .sheet(isPresented: $showAlertBurke) {
            NavigationStack {
                Form {
                    Section {
                        HStack {
                            Text("Username")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(username)
                        }
                    }
                    Section {
                        TextField("Message", text: $alertBurkeMessage, axis: .vertical)
                            .lineLimit(3...5)
                    }
                }
                .navigationTitle("Alert Burke")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showAlertBurke = false
                            alertBurkeMessage = ""
                        }
                        .disabled(isSendingAlert)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Send") {
                            Task {
                                isSendingAlert = true
                                await vm.sendAlertBurke(message: alertBurkeMessage)
                                isSendingAlert = false
                                showAlertBurke = false
                                alertBurkeMessage = ""
                            }
                        }
                        .disabled(alertBurkeMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSendingAlert)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

// MARK: - Components

struct ModActionButton: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct ModRow<Destination: View>: View {
    let icon: String
    let title: String
    let color: Color
    let destination: Destination

    var body: some View {
        NavigationLink {
            destination
        } label: {
            Label {
                Text(title)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 24)
            }
        }
    }
}

struct ModComingSoonView: View {
    let title: String
    var body: some View {
        ContentUnavailableView("Coming Soon", systemImage: "hammer", description: Text("This feature is under development."))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Viewer Lookup

struct ModViewerLookupView: View {
    let token: String
    @State private var username = ""
    @State private var result: ViewerLookupResult?
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Username", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Button("Lookup") {
                    Task { await lookup() }
                }
                .buttonStyle(.borderedProminent)
                .tint(PirateTheme.accentColor)
                .disabled(username.isEmpty || isLoading)
            }
            .padding()

            if isLoading {
                ProgressView().padding()
            } else if let error {
                Text(error).foregroundStyle(.red).padding()
            } else if let r = result {
                List {
                    if let t = r.twitch {
                        Section("Twitch") {
                            HStack {
                                AsyncImage(url: URL(string: t.profileImageUrl ?? "")) { img in
                                    img.resizable().scaledToFill()
                                } placeholder: {
                                    Image(systemName: "person.circle.fill").resizable().foregroundStyle(.gray)
                                }
                                .frame(width: 40, height: 40).clipShape(Circle())
                                VStack(alignment: .leading) {
                                    Text(t.displayName).fontWeight(.semibold)
                                    Text("ID: \(t.id)").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            if let type = t.type, !type.isEmpty {
                                StatRow(label: "Type", value: type)
                            }
                            if let created = t.createdAt {
                                StatRow(label: "Created", value: String(created.prefix(10)))
                            }
                        }
                    }
                    Section("Stats") {
                        StatRow(label: "Doubloons", value: StatFormatter.integer(r.doubloons))
                        StatRow(label: "Soundbyte Credits", value: StatFormatter.integer(r.soundbyteCredits))
                    }
                    if !r.giveawayWins.isEmpty {
                        Section("Giveaway Wins (\(r.giveawayWins.count))") {
                            ForEach(r.giveawayWins.indices, id: \.self) { i in
                                VStack(alignment: .leading) {
                                    Text(r.giveawayWins[i].name).font(.headline)
                                    Text("From: \(r.giveawayWins[i].donator)").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            Spacer()
        }
        .navigationTitle("Viewer Lookup")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func lookup() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        guard let url = URL(string: "https://api.burkeblack.tv/app/mod/viewer-lookup?viewer=\(username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? username)") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let decoded = try JSONDecoder().decode(APISuccessResponse<ViewerLookupResult>.self, from: data)
            result = decoded.data
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct ViewerLookupResult: Codable {
    let viewer: String
    let twitch: TwitchUserInfo?
    let doubloons: Int
    let soundbyteCredits: Int
    let giveawayWins: [GiveawayWinInfo]
    enum CodingKeys: String, CodingKey {
        case viewer, twitch, doubloons
        case soundbyteCredits = "soundbyte_credits"
        case giveawayWins = "giveaway_wins"
    }
}

struct TwitchUserInfo: Codable {
    let id: String
    let displayName: String
    let createdAt: String?
    let type: String?
    let profileImageUrl: String?
    enum CodingKeys: String, CodingKey {
        case id, type
        case displayName = "display_name"
        case createdAt = "created_at"
        case profileImageUrl = "profile_image_url"
    }
}

struct GiveawayWinInfo: Codable {
    let name: String
    let donator: String
    let prize: String
}
