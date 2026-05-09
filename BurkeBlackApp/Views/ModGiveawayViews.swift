import SwiftUI


// MARK: - Submissions

struct ModGiveawaySubmissionsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject var vm: ModPanelViewModel
    @State private var submissions: [GiveawaySubmission] = []
    @State private var isLoading = true
    @State private var search = ""
    @State private var selectedSub: GiveawaySubmission?
    @State private var showSendConfirm = false
    @State private var sendFormSub: GiveawaySubmission?

    private var filtered: [GiveawaySubmission] {
        search.isEmpty ? submissions : submissions.filter {
            $0.giveawayName.localizedCaseInsensitiveContains(search) ||
            $0.realUser.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        List {
            ForEach(filtered) { sub in
                Button {
                    selectedSub = sub
                    showSendConfirm = true
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(sub.giveawayName).font(.headline).foregroundStyle(.primary)
                            Spacer()
                            Text(sub.giveawayType).font(.caption2)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color(.systemGray5)).clipShape(Capsule())
                        }
                        HStack {
                            Label(sub.realUser, systemImage: "person")
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text(sub.date).font(.caption2).foregroundStyle(.tertiary)
                        }
                        if !sub.giveawayExtra.isEmpty {
                            Text(sub.giveawayExtra).font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(.vertical, 2)
                .swipeActions(edge: .trailing) {
                    Button("Hide", role: .destructive) {
                        appLog("ModGiveaway: hiding submission \(sub.id)")
                        Task { await hideSub(sub.id) }
                    }
                }
            }
            if filtered.isEmpty && !isLoading {
                ContentUnavailableView("No Submissions", systemImage: "tray", description: Text("No pending giveaway submissions."))
            }
        }
        .searchable(text: $search, prompt: "Search submissions")
        .navigationTitle("Submissions (\(submissions.count))")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
        .overlay { if isLoading { ProgressView() } }
        .confirmationDialog("Send to Kraken?", isPresented: $showSendConfirm, titleVisibility: .visible) {
            Button("Review & Send") {
                let sub = selectedSub
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    sendFormSub = sub
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let sub = selectedSub {
                Text("\(sub.giveawayName) from \(sub.realUser)")
            }
        }
        .fullScreenCover(item: $sendFormSub) { sub in
            NavigationStack {
                SendToKrakenFormView(vm: vm, submission: sub) {
                    await load()
                }
            }
        }
    }

    func load() async {
        do {
            let r: SubmissionsResponse = try await vm.modGet("/mod/giveaway-submissions")
            submissions = r.submissions
            appLog("ModGiveaway: loaded \(r.submissions.count) submissions")
        } catch {
            appLog("ModGiveaway: load submissions failed - \(error.localizedDescription)")
        }
        isLoading = false
    }

    func hideSub(_ id: Int) async {
        do {
            let _: MessageResponse = try await vm.modPost("/mod/giveaway-submissions/hide", body: ModPostBody(dict: ["id": "\(id)"]))
            await load()
        } catch { vm.alertMessage = error.localizedDescription; vm.showAlert = true }
    }
}

struct GiveawaySubmission: Codable, Identifiable {
    let id: Int
    let realUser: String
    let date: String
    let suggestedUser: String
    let giveawayName: String
    let giveawayType: String
    let giveawayData: String
    let giveawayExtra: String
    let hidden: Int

    enum CodingKeys: String, CodingKey {
        case id, date, hidden
        case realUser = "real_user"
        case suggestedUser = "suggested_user"
        case giveawayName = "giveaway_name"
        case giveawayType = "giveaway_type"
        case giveawayData = "giveaway_data"
        case giveawayExtra = "giveaway_extra"
    }
}

struct SubmissionsResponse: Codable { let submissions: [GiveawaySubmission] }

// MARK: - Add Giveaway

struct ModAddGiveawayView: View {
    @ObservedObject var vm: ModPanelViewModel
    @State private var mode = 0 // 0=single, 1=bulk
    @State private var name = ""
    @State private var donator = ""
    @State private var type = "code"
    @State private var singleKey = ""
    @State private var bulkKeys = ""
    @State private var extra = ""
    @State private var isSaving = false
    @State private var showSuccess = false
    @State private var successMessage = ""

    let types = ["code", "steam_trade", "steam_code", "steam_gift", "discord", "epicgames_code", "humblebundle", "logitech", "origin", "gog", "uplay", "soundbyte", "other"]

    var body: some View {
        Form {
            Picker("", selection: $mode) {
                Text("Single Key").tag(0)
                Text("Bulk Import").tag(1)
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)

            Section {
                TextField("Giveaway Name", text: $name)
                TextField("Donator", text: $donator)
                Picker("Type", selection: $type) {
                    ForEach(types, id: \.self) { Text($0).tag($0) }
                }
            }

            if mode == 0 {
                Section("Key / Code") {
                    TextField("Enter key or code", text: $singleKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            } else {
                Section("Keys (one per line)") {
                    TextEditor(text: $bulkKeys)
                        .frame(minHeight: 120)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }

            Section {
                TextField("Extra info (optional)", text: $extra)
            }

            Section {
                Button {
                    Task { await submit() }
                } label: {
                    HStack {
                        Spacer()
                        if isSaving { ProgressView() }
                        else { Text("Submit").fontWeight(.semibold) }
                        Spacer()
                    }
                }
                .disabled(isSaving || name.isEmpty || donator.isEmpty || (mode == 0 && singleKey.isEmpty) || (mode == 1 && bulkKeys.isEmpty))
            }
        }
        .navigationTitle("Add Giveaway")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Success", isPresented: $showSuccess) {
            Button("OK") { clearForm() }
        } message: {
            Text(successMessage)
        }
    }

    private func submit() async {
        isSaving = true
        defer { isSaving = false }

        var keys: [String]
        if mode == 0 {
            keys = [singleKey]
        } else {
            keys = bulkKeys
                .components(separatedBy: .newlines)
                .flatMap { $0.components(separatedBy: ",") }
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count >= 3 }
        }

        struct AddBody: Encodable {
            let name: String
            let donator: String
            let type: String
            let keys: [String]
            let extra: String
        }

        do {
            let r: AddGiveawayResponse = try await vm.modPost("/mod/giveaway-submissions/add", body: AddBody(name: name, donator: donator, type: type, keys: keys, extra: extra))
            successMessage = r.message
            showSuccess = true
        } catch {
            vm.alertMessage = error.localizedDescription; vm.showAlert = true
        }
    }

    private func clearForm() {
        singleKey = ""; bulkKeys = ""; name = ""; donator = ""; extra = ""
    }
}

struct SendToKrakenFormView: View {
    @ObservedObject var vm: ModPanelViewModel
    let submission: GiveawaySubmission
    let onDone: () async -> Void
    @State private var name: String = ""
    @State private var donator: String = ""
    @State private var type: String = "code"
    @State private var key: String = ""
    @State private var extra: String = ""
    @State private var filter: String = "none"
    @State private var filterAmount: String = "0"
    @State private var entryDuration: String = "120"
    @State private var claimDuration: String = "300"
    @State private var isSending = false
    @Environment(\.dismiss) private var dismiss

    let types = ["code", "steam_trade", "steam_code", "steam_gift", "discord", "epicgames_code", "humblebundle", "logitech", "origin", "gog", "uplay", "soundbyte", "other"]
    let filters = ["none", "subscriber", "follower"]

    var body: some View {
        Form {
            Section("Giveaway Details") {
                TextField("Name", text: $name)
                TextField("Donator", text: $donator)
                Picker("Type", selection: $type) {
                    ForEach(types, id: \.self) { Text($0).tag($0) }
                }
            }
            Section("Prize") {
                TextField("Key / Code", text: $key)
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                TextField("Extra info", text: $extra)
            }
            Section("Filters") {
                Picker("Filter", selection: $filter) {
                    ForEach(filters, id: \.self) { Text($0.capitalized).tag($0) }
                }
                if filter != "none" {
                    TextField("Filter amount (months)", text: $filterAmount).keyboardType(.numberPad)
                }
            }
            Section("Timing") {
                TextField("Entry duration (seconds)", text: $entryDuration).keyboardType(.numberPad)
                TextField("Claim duration (seconds)", text: $claimDuration).keyboardType(.numberPad)
            }
            Section {
                Button {
                    Task { await send() }
                } label: {
                    HStack {
                        Spacer()
                        if isSending { ProgressView() }
                        else {
                            Image(systemName: "paperplane.fill")
                            Text("Send to Kraken").fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(isSending || name.isEmpty || key.isEmpty)
            }
        }
        .navigationTitle("Send to Kraken")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        }
        .onAppear {
            name = submission.giveawayName
            donator = submission.realUser
            type = submission.giveawayType
            key = submission.giveawayData
            extra = submission.giveawayExtra
        }
    }

    private func send() async {
        isSending = true
        do {
            let body = ModPostBody(dict: [
                "name": name,
                "donator": donator,
                "type": type,
                "prize": key,
                "filter": filter,
                "filter_amount": filterAmount,
                "entry_duration": entryDuration,
                "claim_duration": claimDuration,
                "submission_id": "\(submission.id)",
            ])
            let r: SendToKrakenResponse = try await vm.modPost("/mod/giveaway-send", body: body)
            appLog("ModGiveaway: sent to kraken - \(name) from \(donator)")
            vm.alertMessage = r.message
            vm.showAlert = true
            await onDone()
            dismiss()
        } catch {
            appLog("ModGiveaway: send to kraken failed - \(error.localizedDescription)")
            vm.alertMessage = error.localizedDescription; vm.showAlert = true
        }
        isSending = false
    }
}

struct SendToKrakenResponse: Codable { let message: String }

struct AddGiveawayResponse: Codable { let message: String; let count: Int }

// MARK: - Unhide Submissions

struct ModUnhideGiveawaysView: View {
    @ObservedObject var vm: ModPanelViewModel
    @State private var submissions: [GiveawaySubmission] = []
    @State private var isLoading = true

    var body: some View {
        List {
            ForEach(submissions) { sub in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(sub.giveawayName).font(.headline)
                        Text(sub.realUser).font(.caption).foregroundStyle(.secondary)
                        Text(sub.date).font(.caption2).foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Button("Unhide") {
                        Task { await unhide(sub.id) }
                    }
                    .buttonStyle(.bordered)
                    .tint(PirateTheme.accentColor)
                }
            }
            if submissions.isEmpty && !isLoading {
                ContentUnavailableView("No Hidden Submissions", systemImage: "eye.slash", description: Text("All submissions are visible."))
            }
        }
        .navigationTitle("Hidden (\(submissions.count))")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .overlay { if isLoading { ProgressView() } }
    }

    func load() async {
        do {
            let r: SubmissionsResponse = try await vm.modGet("/mod/giveaway-hidden")
            submissions = r.submissions
        } catch {}
        isLoading = false
    }

    func unhide(_ id: Int) async {
        do {
            let _: MessageResponse = try await vm.modPost("/mod/giveaway-submissions/unhide", body: ModPostBody(dict: ["id": "\(id)"]))
            await load()
        } catch { vm.alertMessage = error.localizedDescription; vm.showAlert = true }
    }
}

// MARK: - Giveaway History

struct ModGiveawayHistoryView: View {
    @ObservedObject var vm: ModPanelViewModel
    @State private var giveaways: [GiveawayHistoryItem] = []
    @State private var isLoading = true
    @State private var search = ""
    @State private var revealedPrizes: [Int: Bool] = [:]

    private var filtered: [GiveawayHistoryItem] {
        search.isEmpty ? giveaways : giveaways.filter {
            $0.name.localizedCaseInsensitiveContains(search) ||
            $0.donator.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        List {
            ForEach(filtered) { g in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(g.name).font(.headline)
                        Spacer()
                        Text(g.state).font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .foregroundStyle(stateColor(g.state))
                            .background(stateColor(g.state).opacity(0.15))
                            .clipShape(Capsule())
                    }
                    HStack {
                        Label(g.donator, systemImage: "gift").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Label(g.author, systemImage: "person").font(.caption).foregroundStyle(.tertiary)
                    }
                    if !g.winnerUserid.isEmpty {
                        Text("Winner: \(g.winnerUserid)").font(.caption2).foregroundStyle(.secondary)
                    }
                    if revealedPrizes[g.id] == true {
                        Text(g.prize).font(.caption).foregroundStyle(PirateTheme.accentColor).textSelection(.enabled)
                    } else if !g.prize.isEmpty {
                        Button("Reveal Prize") {
                            revealedPrizes[g.id] = true
                        }
                        .font(.caption)
                        .tint(PirateTheme.accentColor)
                    }
                    Text(formatTimestamp(g.timestamp)).font(.caption2).foregroundStyle(.tertiary)
                }
                .padding(.vertical, 2)
            }
        }
        .searchable(text: $search, prompt: "Search giveaways")
        .navigationTitle("History (\(giveaways.count))")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .overlay { if isLoading { ProgressView() } }
    }

    func load() async {
        do {
            let r: GiveawayHistoryResponse = try await vm.modGet("/mod/giveaway-history")
            giveaways = r.giveaways
        } catch {}
        isLoading = false
    }

    func stateColor(_ state: String) -> Color {
        switch state.lowercased() {
        case "claimed": return .green
        case "open", "active": return .blue
        case "ended", "closed": return .secondary
        default: return .orange
        }
    }

    func formatTimestamp(_ ts: Int) -> String {
        Date(timeIntervalSince1970: TimeInterval(ts)).formatted(date: .abbreviated, time: .shortened)
    }
}

struct GiveawayHistoryItem: Codable, Identifiable {
    let id: Int
    let timestamp: Int
    let author: String
    let name: String
    let donator: String
    let prize: String
    let state: String
    let winnerUserid: String
    let filter: String
    let filterValue: String

    enum CodingKeys: String, CodingKey {
        case id, timestamp, author, name, donator, prize, state, filter
        case winnerUserid = "winner_userid"
        case filterValue = "filter_value"
    }
}

struct GiveawayHistoryResponse: Codable { let giveaways: [GiveawayHistoryItem] }

// MARK: - View Wins

struct ModViewWinsView: View {
    @ObservedObject var vm: ModPanelViewModel
    @State private var username = ""
    @State private var wins: [GiveawayWinDetail] = []
    @State private var isLoading = false
    @State private var hasSearched = false
    @State private var error: String?
    @State private var revealedPrizes: [String: Bool] = [:]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Username", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit { Task { await search() } }
                Button("Search") { Task { await search() } }
                    .buttonStyle(.borderedProminent)
                    .tint(PirateTheme.accentColor)
                    .disabled(username.count < 3 || isLoading)
            }
            .padding()

            if isLoading {
                ProgressView().padding()
            } else if let error {
                Text(error).foregroundStyle(.red).padding()
            } else if hasSearched && wins.isEmpty {
                ContentUnavailableView("No Wins", systemImage: "trophy", description: Text("\(username) has no giveaway wins."))
            } else {
                List(wins) { win in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(win.name).font(.headline)
                        Label(win.donator, systemImage: "gift").font(.caption).foregroundStyle(.secondary)
                        if revealedPrizes[win.id] == true {
                            Text(win.prize)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(PirateTheme.accentColor)
                                .textSelection(.enabled)
                        } else {
                            Button("Reveal Prize") {
                                revealedPrizes[win.id] = true
                            }
                            .font(.caption)
                            .tint(PirateTheme.accentColor)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            Spacer()
        }
        .navigationTitle("View Wins")
        .navigationBarTitleDisplayMode(.inline)
    }

    func search() async {
        isLoading = true; error = nil; hasSearched = true
        defer { isLoading = false }
        do {
            let r: ViewWinsResponse = try await vm.modGet("/mod/giveaway-wins?viewer=\(username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? username)")
            wins = r.wins
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct GiveawayWinDetail: Codable, Identifiable {
    var id: String { "\(name)-\(donator)" }
    let name: String
    let donator: String
    let prize: String
}

struct ViewWinsResponse: Codable { let wins: [GiveawayWinDetail] }
