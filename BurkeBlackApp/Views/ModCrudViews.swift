import SwiftUI


// MARK: - Generic Helpers

struct ModPostBody: Encodable {
    let dict: [String: String]
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicKey.self)
        for (key, value) in dict {
            try container.encode(value, forKey: DynamicKey(stringValue: key))
        }
    }
}

struct DynamicKey: CodingKey {
    var stringValue: String
    init(stringValue: String) { self.stringValue = stringValue }
    var intValue: Int? { nil }
    init?(intValue: Int) { return nil }
}

// MARK: - Links (Full CRUD)

struct ModLinksView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject var vm: ModPanelViewModel
    @State private var links: [ModLink] = []
    @State private var isLoading = true
    @State private var search = ""
    @State private var showCreate = false
    @State private var editingLink: ModLink?

    private var filtered: [ModLink] {
        search.isEmpty ? links : links.filter {
            $0.customName.localizedCaseInsensitiveContains(search) ||
            $0.longUrl.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        List {
            ForEach(filtered) { link in
                Button {
                    editingLink = link
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("burke.black/\(link.customName)")
                            .font(.headline)
                            .foregroundStyle(PirateTheme.accentColor)
                        Text(link.longUrl)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button("Delete", role: .destructive) {
                        Task { await deleteLink(link.id) }
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Search links")
        .navigationTitle("Links (\(links.count))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showCreate = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreate) {
            NavigationStack {
                ModLinkFormView(vm: vm, mode: .create) { await loadLinks() }
            }
        }
        .sheet(item: $editingLink) { link in
            NavigationStack {
                ModLinkFormView(vm: vm, mode: .edit(link)) { await loadLinks() }
            }
        }
        .task { await loadLinks() }
    }

    func loadLinks() async {
        do {
            let r: ModLinksResponse = try await vm.modGet("/mod/links")
            links = r.links
        } catch {}
        isLoading = false
    }

    func deleteLink(_ id: Int) async {
        do {
            let _: MessageResponse = try await vm.modPost("/mod/links/delete", body: ModPostBody(dict: ["id": "\(id)"]))
            await loadLinks()
        } catch { vm.alertMessage = error.localizedDescription; vm.showAlert = true }
    }
}

struct ModLinkFormView: View {
    @ObservedObject var vm: ModPanelViewModel
    enum Mode: Identifiable {
        case create
        case edit(ModLink)
        var id: String {
            switch self {
            case .create: return "create"
            case .edit(let l): return "edit-\(l.id)"
            }
        }
    }
    let mode: Mode
    let onSave: () async -> Void
    @State private var slug = ""
    @State private var url = ""
    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                if case .create = mode {
                    TextField("Slug (burke.black/...)", text: $slug)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                TextField("Destination URL", text: $url)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            }
            Section {
                Button {
                    Task { await save() }
                } label: {
                    HStack { Spacer(); Text(isCreate ? "Create" : "Save").fontWeight(.semibold); Spacer() }
                }
                .disabled(isSaving || url.isEmpty || (isCreate && slug.isEmpty))
            }
        }
        .navigationTitle(isCreate ? "New Link" : "Edit Link")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .onAppear {
                appLog("ModCrud: view appeared")
            if case .edit(let link) = mode {
                slug = link.customName
                url = link.longUrl
            }
        }
    }

    private var isCreate: Bool { if case .create = mode { return true } else { return false } }

    private func save() async {
        isSaving = true
        do {
            if case .create = mode {
                let _: MessageResponse = try await vm.modPost("/mod/links", body: ModPostBody(dict: ["custom_name": slug, "long_url": url]))
            } else if case .edit(let link) = mode {
                let _: MessageResponse = try await vm.modPost("/mod/links/update", body: ModPostBody(dict: ["id": "\(link.id)", "long_url": url]))
            }
            await onSave()
            dismiss()
        } catch {
            vm.alertMessage = error.localizedDescription; vm.showAlert = true
        }
        isSaving = false
    }
}

struct ModLink: Codable, Identifiable {
    let id: Int
    let customName: String
    let longUrl: String
    enum CodingKeys: String, CodingKey { case id; case customName = "custom_name"; case longUrl = "long_url" }
}
struct ModLinksResponse: Codable { let links: [ModLink] }

// MARK: - Commands (Full CRUD)

struct ModCommandsView: View {
    @ObservedObject var vm: ModPanelViewModel
    @State private var commands: [ModCommand] = []
    @State private var isLoading = true
    @State private var search = ""
    @State private var showCreate = false
    @State private var editingCmd: ModCommand?
    @State private var deletingCmdId: Int?
    @State private var showDeleteConfirm = false

    private var filtered: [ModCommand] {
        search.isEmpty ? commands : commands.filter {
            $0.command.localizedCaseInsensitiveContains(search) ||
            $0.data.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        List {
            ForEach(filtered) { cmd in
                Button { editingCmd = cmd } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(cmd.command).font(.headline).foregroundStyle(PirateTheme.accentColor)
                            Spacer()
                            Text(cmd.tier).font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color(.systemGray5)).clipShape(Capsule())
                            Text("\(cmd.cooldown)s").font(.caption2).foregroundStyle(.secondary)
                        }
                        Text(cmd.data).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button("Delete", role: .destructive) {
                        deletingCmdId = cmd.id
                        showDeleteConfirm = true
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Search commands")
        .navigationTitle("Commands (\(commands.count))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showCreate = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showCreate) {
            NavigationStack { ModCommandFormView(vm: vm, mode: .create) { await loadCmds() } }
        }
        .sheet(item: $editingCmd) { cmd in
            NavigationStack { ModCommandFormView(vm: vm, mode: .edit(cmd)) { await loadCmds() } }
        }
        .task { await loadCmds() }
        .confirmationDialog("Delete this command?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let id = deletingCmdId { Task { await deleteCmd(id) } }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    func loadCmds() async {
        do { let r: ModCommandsResponse = try await vm.modGet("/mod/commands"); commands = r.commands } catch {}
        isLoading = false
    }

    func deleteCmd(_ id: Int) async {
        do { let _: MessageResponse = try await vm.modPost("/mod/commands/delete", body: ModPostBody(dict: ["id": "\(id)"])); await loadCmds() }
        catch { vm.alertMessage = error.localizedDescription; vm.showAlert = true }
    }
}

struct ModCommandFormView: View {
    @ObservedObject var vm: ModPanelViewModel
    enum Mode: Identifiable {
        case create; case edit(ModCommand)
        var id: String { switch self { case .create: return "c"; case .edit(let c): return "e\(c.id)" } }
    }
    let mode: Mode; let onSave: () async -> Void
    @State private var command = "!"; @State private var data = ""; @State private var cooldown = "30"
    @State private var tier = "viewer"; @State private var tags = ""; @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss
    let tiers = ["viewer", "subscriber", "moderator", "disabled"]

    var body: some View {
        Form {
            Section {
                if isCreate { TextField("!command", text: $command).autocorrectionDisabled().textInputAutocapitalization(.never) }
                else { Text(command).foregroundStyle(.secondary) }
            }
            Section("Response") { TextEditor(text: $data).frame(minHeight: 80) }
            Section {
                TextField("Cooldown (seconds)", text: $cooldown).keyboardType(.numberPad)
                Picker("Access Tier", selection: $tier) { ForEach(tiers, id: \.self) { Text($0).tag($0) } }
            }
            Section {
                Button { Task { await save() } } label: {
                    HStack { Spacer(); Text(isCreate ? "Create" : "Save").fontWeight(.semibold); Spacer() }
                }.disabled(isSaving || data.isEmpty)
            }
        }
        .navigationTitle(isCreate ? "New Command" : "Edit Command")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        .onAppear {
            if case .edit(let c) = mode { command = c.command; data = c.data; cooldown = "\(c.cooldown)"; tier = c.tier; tags = c.tags }
        }
    }

    private var isCreate: Bool { if case .create = mode { return true } else { return false } }

    private func save() async {
        isSaving = true
        do {
            let cd = Int(cooldown) ?? 30
            if isCreate {
                let _: MessageResponse = try await vm.modPost("/mod/commands", body: ModPostBody(dict: [
                    "command": command, "data": data, "cooldown": "\(cd)", "tier": tier, "tags": tags
                ]))
            } else if case .edit(let c) = mode {
                let _: MessageResponse = try await vm.modPost("/mod/commands/update", body: ModPostBody(dict: [
                    "id": "\(c.id)", "data": data, "cooldown": "\(cd)", "tier": tier
                ]))
            }
            await onSave(); dismiss()
        } catch { vm.alertMessage = error.localizedDescription; vm.showAlert = true }
        isSaving = false
    }
}

struct ModCommand: Codable, Identifiable { let id: Int; let command, data, tier, tags: String; let cooldown: Int }
struct ModCommandsResponse: Codable { let commands: [ModCommand] }

// MARK: - Timed Messages (Full CRUD)

struct ModTimedMessagesView: View {
    @ObservedObject var vm: ModPanelViewModel
    @State private var messages: [ModTimedMessage] = []
    @State private var isLoading = true
    @State private var showCreate = false
    @State private var editingMsg: ModTimedMessage?

    var body: some View {
        List {
            ForEach(messages) { msg in
                Button { editingMsg = msg } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(msg.name).font(.headline)
                            Spacer()
                            Text("\(msg.interval / 60)m").font(.caption).foregroundStyle(.secondary)
                            if msg.disabled == 1 { Text("OFF").font(.caption2).fontWeight(.bold).foregroundStyle(.red) }
                            if msg.dedicated == 1 { Image(systemName: "pin.fill").font(.caption2).foregroundStyle(.blue) }
                        }
                        Text(msg.message).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button("Delete", role: .destructive) { Task { await deleteMsg(msg.id) } }
                }
            }
        }
        .navigationTitle("Timed Messages")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .primaryAction) { Button { showCreate = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showCreate) { NavigationStack { ModTimedFormView(vm: vm, mode: .create) { await loadMsgs() } } }
        .sheet(item: $editingMsg) { m in NavigationStack { ModTimedFormView(vm: vm, mode: .edit(m)) { await loadMsgs() } } }
        .task { await loadMsgs() }
    }

    func loadMsgs() async {
        do { let r: ModTimedResponse = try await vm.modGet("/mod/timed-messages"); messages = r.messages } catch {}
        isLoading = false
    }

    func deleteMsg(_ id: Int) async {
        do { let _: MessageResponse = try await vm.modPost("/mod/timed-messages/delete", body: ModPostBody(dict: ["id": "\(id)"])); await loadMsgs() }
        catch { vm.alertMessage = error.localizedDescription; vm.showAlert = true }
    }
}

struct ModTimedFormView: View {
    @ObservedObject var vm: ModPanelViewModel
    enum Mode: Identifiable {
        case create; case edit(ModTimedMessage)
        var id: String { switch self { case .create: return "c"; case .edit(let m): return "e\(m.id)" } }
    }
    let mode: Mode; let onSave: () async -> Void
    @State private var name = ""; @State private var message = ""; @State private var interval = "300"
    @State private var dedicated = false; @State private var disabled = false; @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section { TextField("Name (no spaces)", text: $name).autocorrectionDisabled().textInputAutocapitalization(.never) }
            Section("Message") { TextEditor(text: $message).frame(minHeight: 80) }
            Section {
                TextField("Interval (seconds)", text: $interval).keyboardType(.numberPad)
                Toggle("Dedicated", isOn: $dedicated)
                Toggle("Disabled", isOn: $disabled)
            }
            Section {
                Button { Task { await save() } } label: {
                    HStack { Spacer(); Text(isCreate ? "Create" : "Save").fontWeight(.semibold); Spacer() }
                }.disabled(isSaving || name.isEmpty || message.isEmpty)
            }
        }
        .navigationTitle(isCreate ? "New Timed Message" : "Edit Timed Message")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        .onAppear {
            if case .edit(let m) = mode { name = m.name; message = m.message; interval = "\(m.interval)"; dedicated = m.dedicated == 1; disabled = m.disabled == 1 }
        }
    }

    private var isCreate: Bool { if case .create = mode { return true } else { return false } }

    private func save() async {
        isSaving = true
        do {
            let iv = Int(interval) ?? 300
            let body = ModPostBody(dict: ["name": name, "message": message, "interval": "\(iv)", "dedicated": dedicated ? "1" : "0", "disabled": disabled ? "1" : "0"])
            if isCreate {
                let _: MessageResponse = try await vm.modPost("/mod/timed-messages", body: body)
            } else if case .edit(let m) = mode {
                var d = ["id": "\(m.id)", "name": name, "message": message, "interval": "\(iv)", "dedicated": dedicated ? "1" : "0", "disabled": disabled ? "1" : "0"]
                let _: MessageResponse = try await vm.modPost("/mod/timed-messages/update", body: ModPostBody(dict: d))
            }
            await onSave(); dismiss()
        } catch { vm.alertMessage = error.localizedDescription; vm.showAlert = true }
        isSaving = false
    }
}

struct ModTimedMessage: Codable, Identifiable { let id: Int; let name, message: String; let interval, dedicated, disabled: Int }
struct ModTimedResponse: Codable { let messages: [ModTimedMessage] }

// MARK: - Timeout Words (Full CRUD)

struct ModTimeoutWordsView: View {
    @ObservedObject var vm: ModPanelViewModel
    @State private var words: [ModTimeoutWord] = []
    @State private var categories: [String] = []
    @State private var isLoading = true
    @State private var search = ""
    @State private var showCreate = false
    @State private var deletingWordId: Int?
    @State private var showDeleteConfirm = false

    private var filtered: [ModTimeoutWord] {
        search.isEmpty ? words : words.filter { $0.word.localizedCaseInsensitiveContains(search) || $0.category.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        List {
            ForEach(filtered) { w in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(w.word).font(.body)
                        Text(w.category).font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if w.silent == 1 { Image(systemName: "speaker.slash").font(.caption).foregroundStyle(.orange) }
                    if w.partOf == 1 { Image(systemName: "text.magnifyingglass").font(.caption).foregroundStyle(.blue) }
                    Button { Task { await toggleWord(w) } } label: {
                        Circle().fill(w.enabled == 1 ? .green : .red).frame(width: 12)
                    }
                }
                .contentShape(Rectangle())
                .swipeActions(edge: .trailing) {
                    Button("Delete", role: .destructive) {
                        deletingWordId = w.id; showDeleteConfirm = true
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Search words")
        .confirmationDialog("Delete this word?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let id = deletingWordId { Task { await deleteWord(id) } }
            }
            Button("Cancel", role: .cancel) {}
        }
        .navigationTitle("Timeout Words (\(words.count))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .primaryAction) { Button { showCreate = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showCreate) { NavigationStack { ModTimeoutWordFormView(vm: vm, categories: categories) { await loadWords() } } }
        .task { await loadWords() }
    }

    func loadWords() async {
        do {
            let r: ModTOWordsResponse = try await vm.modGet("/mod/timeout-words")
            words = r.words
            categories = r.categories.map { $0.category }
        } catch {}
        isLoading = false
    }

    func toggleWord(_ w: ModTimeoutWord) async {
        do { let _: MessageResponse = try await vm.modPost("/mod/timeout-words/toggle", body: ModPostBody(dict: ["id": "\(w.id)", "enabled": w.enabled == 1 ? "0" : "1"])); await loadWords() }
        catch { vm.alertMessage = error.localizedDescription; vm.showAlert = true }
    }

    func deleteWord(_ id: Int) async {
        do { let _: MessageResponse = try await vm.modPost("/mod/timeout-words/delete", body: ModPostBody(dict: ["id": "\(id)"])); await loadWords() }
        catch { vm.alertMessage = error.localizedDescription; vm.showAlert = true }
    }
}

struct ModTimeoutWordFormView: View {
    @ObservedObject var vm: ModPanelViewModel
    let categories: [String]
    let onSave: () async -> Void
    @State private var word = ""; @State private var category = "other"; @State private var silent = false; @State private var partOf = false
    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                TextField("Word/phrase", text: $word).autocorrectionDisabled().textInputAutocapitalization(.never)
                Picker("Category", selection: $category) {
                    ForEach(categories, id: \.self) { cat in
                        Text(cat.capitalized).tag(cat)
                    }
                }
            }
            Section {
                Toggle("Silent (purge without timeout)", isOn: $silent)
                Toggle("Part-of (substring match)", isOn: $partOf)
            }
            Section {
                Button { Task { await save() } } label: {
                    HStack { Spacer(); Text("Add").fontWeight(.semibold); Spacer() }
                }.disabled(isSaving || word.isEmpty)
            }
        }
        .navigationTitle("New Timeout Word")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
    }

    private func save() async {
        isSaving = true
        do {
            let _: MessageResponse = try await vm.modPost("/mod/timeout-words", body: ModPostBody(dict: [
                "word": word, "category": category, "silent": silent ? "1" : "0", "part_of": partOf ? "1" : "0"
            ]))
            await onSave(); dismiss()
        } catch { vm.alertMessage = error.localizedDescription; vm.showAlert = true }
        isSaving = false
    }
}

struct ModTimeoutWord: Codable, Identifiable { let id: Int; let word, category: String; let silent, partOf, enabled: Int
    enum CodingKeys: String, CodingKey { case id, word, category, silent, enabled; case partOf = "part_of" }
}
struct ModTOWordsResponse: Codable { let words: [ModTimeoutWord]; let categories: [ModTOCategory] }
struct ModTOCategory: Codable { let id: Int; let category: String }

// MARK: - Spoiler Words (Full CRUD)

struct ModSpoilerWordsView: View {
    @ObservedObject var vm: ModPanelViewModel
    @State private var words: [ModSpoilerWord] = []
    @State private var isLoading = true
    @State private var search = ""
    @State private var showCreate = false
    @State private var deletingSpoilerId: Int?
    @State private var showSpoilerDeleteConfirm = false

    private var filtered: [ModSpoilerWord] {
        search.isEmpty ? words : words.filter { $0.word.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        List {
            ForEach(filtered) { w in
                HStack {
                    Text(w.word).font(.body)
                    Spacer()
                    if w.silent == 1 { Image(systemName: "speaker.slash").font(.caption).foregroundStyle(.orange) }
                    if w.partOf == 1 { Image(systemName: "text.magnifyingglass").font(.caption).foregroundStyle(.blue) }
                    Button { Task { await toggleWord(w) } } label: {
                        Circle().fill(w.enabled == 1 ? .green : .red).frame(width: 12)
                    }
                }
                .contentShape(Rectangle())
                .swipeActions(edge: .trailing) {
                    Button("Delete", role: .destructive) {
                        deletingSpoilerId = w.id; showSpoilerDeleteConfirm = true
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Search words")
        .confirmationDialog("Delete this word?", isPresented: $showSpoilerDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let id = deletingSpoilerId { Task { await deleteWord(id) } }
            }
            Button("Cancel", role: .cancel) {}
        }
        .navigationTitle("Spoiler Words (\(words.count))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .primaryAction) { Button { showCreate = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showCreate) { NavigationStack { ModSpoilerWordFormView(vm: vm) { await loadWords() } } }
        .task { await loadWords() }
    }

    func loadWords() async {
        do { let r: ModSpoilerResponse = try await vm.modGet("/mod/spoiler-words"); words = r.words } catch {}
        isLoading = false
    }

    func toggleWord(_ w: ModSpoilerWord) async {
        do { let _: MessageResponse = try await vm.modPost("/mod/spoiler-words/toggle", body: ModPostBody(dict: ["id": "\(w.id)", "enabled": w.enabled == 1 ? "0" : "1"])); await loadWords() }
        catch { vm.alertMessage = error.localizedDescription; vm.showAlert = true }
    }

    func deleteWord(_ id: Int) async {
        do { let _: MessageResponse = try await vm.modPost("/mod/spoiler-words/delete", body: ModPostBody(dict: ["id": "\(id)"])); await loadWords() }
        catch { vm.alertMessage = error.localizedDescription; vm.showAlert = true }
    }
}

struct ModSpoilerWordFormView: View {
    @ObservedObject var vm: ModPanelViewModel
    let onSave: () async -> Void
    @State private var word = ""; @State private var silent = false; @State private var partOf = false
    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section { TextField("Word", text: $word).autocorrectionDisabled().textInputAutocapitalization(.never) }
            Section {
                Toggle("Silent (purge without timeout)", isOn: $silent)
                Toggle("Part-of (substring match)", isOn: $partOf)
            }
            Section {
                Button { Task { await save() } } label: {
                    HStack { Spacer(); Text("Add").fontWeight(.semibold); Spacer() }
                }.disabled(isSaving || word.isEmpty)
            }
        }
        .navigationTitle("New Spoiler Word")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
    }

    private func save() async {
        isSaving = true
        do {
            let _: MessageResponse = try await vm.modPost("/mod/spoiler-words", body: ModPostBody(dict: [
                "word": word, "silent": silent ? "1" : "0", "part_of": partOf ? "1" : "0"
            ]))
            await onSave(); dismiss()
        } catch { vm.alertMessage = error.localizedDescription; vm.showAlert = true }
        isSaving = false
    }
}

struct ModSpoilerWord: Codable, Identifiable { let id: Int; let word: String; let silent, partOf, enabled: Int
    enum CodingKeys: String, CodingKey { case id, word, silent, enabled; case partOf = "part_of" }
}
struct ModSpoilerResponse: Codable { let words: [ModSpoilerWord] }
