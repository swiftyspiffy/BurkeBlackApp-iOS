import SwiftUI
import AVFoundation


// MARK: - Soundbyte Library

struct ModSoundbyteLibraryView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject var vm: ModPanelViewModel
    @State private var soundbytes: [ModSoundbyte] = []
    @State private var genres: [SoundbyteGenre] = []
    @State private var isLoading = true
    @State private var search = ""
    @State private var editingSB: ModSoundbyte?
    @State private var deletingSB: ModSoundbyte?
    @State private var showDeleteConfirm = false
    @State private var player: AVPlayer?
    @State private var playingId: Int?

    private var filtered: [ModSoundbyte] {
        search.isEmpty ? soundbytes : soundbytes.filter {
            $0.audioName.localizedCaseInsensitiveContains(search) ||
            $0.uploadedBy.localizedCaseInsensitiveContains(search) ||
            $0.genre.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        List {
            ForEach(filtered) { sb in
                Button { editingSB = sb } label: {
                    HStack {
                        Button {
                            playSoundbyte(sb)
                        } label: {
                            Image(systemName: playingId == sb.id ? "stop.circle.fill" : "play.circle.fill")
                                .font(.title2)
                                .foregroundStyle(playingId == sb.id ? .red : PirateTheme.accentColor)
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(sb.audioName).font(.headline).foregroundStyle(.primary)
                            HStack(spacing: 8) {
                                Text(sb.genre).font(.caption2).foregroundStyle(.secondary)
                                Text("by \(sb.uploadedBy)").font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                        Text("\(sb.creditCost)").font(.caption2).fontWeight(.bold)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .foregroundStyle(PirateTheme.accentColor).background(PirateTheme.accentColor.opacity(0.15)).clipShape(Capsule())
                        Circle().fill(approvalColor(sb.approved)).frame(width: 10)
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button("Delete", role: .destructive) {
                        deletingSB = sb; showDeleteConfirm = true
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Search soundbytes")
        .navigationTitle("Library (\(soundbytes.count))")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .overlay { if isLoading { ProgressView() } }
        .onDisappear { player?.pause(); player = nil }
        .confirmationDialog("Delete soundbyte?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let sb = deletingSB {
                    Task { await deleteSB(sb.id) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let sb = deletingSB {
                Text("\(sb.audioName) will be permanently removed.")
            }
        }
        .sheet(item: $editingSB) { sb in
            NavigationStack {
                ModSoundbyteEditView(vm: vm, soundbyte: sb, genres: genres) { await load() }
            }
        }
    }

    func load() async {
        do {
            let r: ModSBLibraryResponse = try await vm.modGet("/mod/soundbyte-library")
            soundbytes = r.soundbytes
            genres = r.genres
        } catch {}
        isLoading = false
    }

    func playSoundbyte(_ sb: ModSoundbyte) {
        if playingId == sb.id {
            player?.pause(); player = nil; playingId = nil
            return
        }
        player?.pause()
        guard let loc = sb.audioLocation, let url = URL(string: loc) else { return }
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        playingId = sb.id
        player?.play()
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [self] _ in
            playingId = nil
        }
    }

    func deleteSB(_ id: Int) async {
        do {
            let _: MessageResponse = try await vm.modPost("/mod/soundbyte-library/update", body: ModPostBody(dict: [
                "id": "\(id)", "name": "", "genre": "", "approved": "-1", "horror_night": "0", "credit_cost": "1"
            ]))
            await load()
        } catch { vm.alertMessage = error.localizedDescription; vm.showAlert = true }
    }

    func approvalColor(_ approved: Int) -> Color {
        switch approved {
        case 1: return .green
        case 2: return .blue
        case 0: return .red
        default: return .gray
        }
    }
}

struct ModSoundbyteEditView: View {
    @ObservedObject var vm: ModPanelViewModel
    let soundbyte: ModSoundbyte
    let genres: [SoundbyteGenre]
    let onSave: () async -> Void
    @State private var name: String = ""
    @State private var genre: String = ""
    @State private var approved: Int = 1
    @State private var horrorNight: Bool = false
    @State private var creditCost: String = "1"
    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss

    let approvalOptions = [(1, "Approved"), (0, "Denied"), (2, "Mod-only")]

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                Picker("Genre", selection: $genre) {
                    ForEach(genres) { g in Text(g.genre).tag(g.genre) }
                }
                Picker("Status", selection: $approved) {
                    ForEach(approvalOptions, id: \.0) { Text($0.1).tag($0.0) }
                }
                TextField("Credit Cost", text: $creditCost).keyboardType(.numberPad)
                Toggle("Horror Night", isOn: $horrorNight)
            }

            Section("Info") {
                StatRow(label: "ID", value: "\(soundbyte.id)")
                StatRow(label: "Uploaded by", value: soundbyte.uploadedBy)
            }

            Section {
                Button { Task { await save() } } label: {
                    HStack { Spacer(); Text("Save").fontWeight(.semibold); Spacer() }
                }.disabled(isSaving || name.isEmpty)
            }
        }
        .navigationTitle("Edit Soundbyte")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        .onAppear {
                appLog("ModSoundbytes: view appeared")
            name = soundbyte.audioName
            genre = soundbyte.genre
            approved = soundbyte.approved
            horrorNight = soundbyte.horrorNight == 1
            creditCost = "\(soundbyte.creditCost)"
        }
    }

    func save() async {
        isSaving = true
        do {
            let _: MessageResponse = try await vm.modPost("/mod/soundbyte-library/update", body: ModPostBody(dict: [
                "id": "\(soundbyte.id)", "name": name, "genre": genre,
                "approved": "\(approved)", "horror_night": horrorNight ? "1" : "0",
                "credit_cost": creditCost
            ]))
            await onSave(); dismiss()
        } catch { vm.alertMessage = error.localizedDescription; vm.showAlert = true }
        isSaving = false
    }
}

struct ModSoundbyte: Codable, Identifiable {
    let id: Int
    let audioName: String
    let uploadedBy: String
    let genre: String
    let approved: Int
    let horrorNight: Int
    let creditCost: Int
    let modOnly: Int
    let audioLocation: String?
    enum CodingKeys: String, CodingKey {
        case id, genre, approved
        case audioName = "audio_name"
        case uploadedBy = "uploaded_by"
        case horrorNight = "horror_night"
        case creditCost = "credit_cost"
        case modOnly = "mod_only"
        case audioLocation = "audio_location"
    }
}

struct ModSBLibraryResponse: Codable {
    let soundbytes: [ModSoundbyte]
    let genres: [SoundbyteGenre]
}

// MARK: - Soundbyte Credits

struct ModSBCreditsView: View {
    @ObservedObject var vm: ModPanelViewModel
    @State private var credits: [ModSBCredit] = []
    @State private var isLoading = true
    @State private var search = ""
    @State private var showModify = false
    @State private var editingCredit: ModSBCredit?
    @State private var deletingCreditId: Int?
    @State private var showDeleteConfirm = false

    private var filtered: [ModSBCredit] {
        search.isEmpty ? credits : credits.filter {
            $0.userId.localizedCaseInsensitiveContains(search) ||
            ($0.username ?? "").localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        List {
            ForEach(filtered) { c in
                Button { editingCredit = c } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.username ?? c.userId).font(.body).foregroundStyle(.primary)
                            if c.username != nil {
                                Text("ID: \(c.userId)").font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                        Text(StatFormatter.integer(c.creditCount)).fontWeight(.semibold).foregroundStyle(PirateTheme.accentColor)
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button("Delete", role: .destructive) {
                        deletingCreditId = c.id; showDeleteConfirm = true
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Search by user ID")
        .navigationTitle("Credits (\(credits.count))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showModify = true } label: { Image(systemName: "plus.forwardslash.minus") }
            }
        }
        .task { await load() }
        .overlay { if isLoading { ProgressView() } }
        .sheet(isPresented: $showModify) {
            NavigationStack {
                ModSBCreditsModifyView(vm: vm) { await load() }
            }
        }
        .sheet(item: $editingCredit) { c in
            NavigationStack {
                ModSBCreditsModifyView(vm: vm, prefillUserId: c.userId, prefillAmount: "\(c.creditCount)") { await load() }
            }
        }
        .confirmationDialog("Delete credits?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let id = deletingCreditId, let c = credits.first(where: { $0.id == id }) {
                    Task { await deleteCredits(c.userId) }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    func deleteCredits(_ userId: String) async {
        if let c = credits.first(where: { $0.userId == userId }) {
            do {
                let _: MessageResponse = try await vm.modPost("/mod/soundbyte-credits/modify", body: ModPostBody(dict: [
                    "user_id": userId, "amount": "\(c.creditCount)", "direction": "deduct"
                ]))
                await load()
            } catch { vm.alertMessage = error.localizedDescription; vm.showAlert = true }
        }
    }

    func load() async {
        do {
            let r: ModSBCreditsResponse = try await vm.modGet("/mod/soundbyte-credits-list")
            credits = r.credits
        } catch {}
        isLoading = false
    }

}

struct ModSBCreditsModifyView: View {
    @ObservedObject var vm: ModPanelViewModel
    var prefillUserId: String = ""
    var prefillAmount: String = ""
    let onSave: () async -> Void
    @State private var userId = ""
    @State private var amount = ""
    @State private var direction = "add"
    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                TextField("User ID", text: $userId).keyboardType(.numberPad)
                TextField("Amount", text: $amount).keyboardType(.numberPad)
                Picker("Action", selection: $direction) {
                    Text("Add").tag("add")
                    Text("Deduct").tag("deduct")
                }.pickerStyle(.segmented)
            }
            Section {
                Button { Task { await save() } } label: {
                    HStack { Spacer(); Text(direction == "add" ? "Add Credits" : "Deduct Credits").fontWeight(.semibold); Spacer() }
                }.disabled(isSaving || userId.isEmpty || amount.isEmpty)
            }
        }
        .navigationTitle("Modify Credits")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        .onAppear {
            if !prefillUserId.isEmpty { userId = prefillUserId }
        }
    }

    func save() async {
        isSaving = true
        do {
            let _: MessageResponse = try await vm.modPost("/mod/soundbyte-credits/modify", body: ModPostBody(dict: [
                "user_id": userId, "amount": amount, "direction": direction
            ]))
            await onSave(); dismiss()
        } catch { vm.alertMessage = error.localizedDescription; vm.showAlert = true }
        isSaving = false
    }
}

struct ModSBCredit: Codable, Identifiable {
    var id: Int
    let userId: String
    let creditCount: Int
    let username: String?
    enum CodingKeys: String, CodingKey {
        case id, username
        case userId = "user_id"
        case creditCount = "credit_count"
    }
}

struct ModSBCreditsResponse: Codable { let credits: [ModSBCredit]; let total: Int? }

// MARK: - Soundbyte History (Full / Mod View)

struct ModSBHistoryView: View {
    @ObservedObject var vm: ModPanelViewModel
    @State private var history: [ModSBHistoryItem] = []
    @State private var isLoading = true
    @State private var search = ""

    private var filtered: [ModSBHistoryItem] {
        search.isEmpty ? history : history.filter {
            $0.username.localizedCaseInsensitiveContains(search) ||
            ($0.audioName ?? "").localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        List {
            ForEach(filtered) { item in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.audioName ?? "ID: \(item.sbId)").font(.headline)
                        Spacer()
                        Text(item.platform).font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color(.systemGray5)).clipShape(Capsule())
                    }
                    HStack {
                        Label(item.username, systemImage: "person").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        if item.announce == 1 {
                            Image(systemName: "megaphone.fill").font(.caption2).foregroundStyle(PirateTheme.accentColor)
                        }
                        Text(formatTimestamp(item.timestamp)).font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Search history")
        .navigationTitle("History (\(history.count))")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .overlay { if isLoading { ProgressView() } }
    }

    func load() async {
        do {
            let r: ModSBHistoryResponse = try await vm.modGet("/mod/soundbyte-full-history")
            history = r.history
        } catch {}
        isLoading = false
    }

    func formatTimestamp(_ ts: String) -> String {
        if let epoch = Int(ts) {
            return Date(timeIntervalSince1970: TimeInterval(epoch)).formatted(date: .abbreviated, time: .shortened)
        }
        return ts
    }
}

struct ModSBHistoryItem: Codable, Identifiable {
    let _id = UUID()
    var id: UUID { _id }
    let sbId: Int
    let userId: String
    let username: String
    let announce: Int
    let platform: String
    let timestamp: String
    let audioName: String?

    enum CodingKeys: String, CodingKey {
        case sbId = "sb_id"
        case userId = "user_id"
        case username, announce, platform, timestamp
        case audioName = "audio_name"
    }
}

struct ModSBHistoryResponse: Codable { let history: [ModSBHistoryItem] }
