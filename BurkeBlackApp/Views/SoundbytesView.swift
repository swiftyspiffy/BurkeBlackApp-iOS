import SwiftUI
import AVFoundation

@MainActor
class SoundbytesViewModel: ObservableObject {
    let token: String
    var onCreditsChanged: ((Int) -> Void)?

    @Published var soundbytes: [Soundbyte] = []
    @Published var genres: [SoundbyteGenre] = []
    @Published var credits = 0
    @Published var searchText = ""
    @Published var selectedGenre = "All"
    @Published var isLoading = false
    @Published var hasMore = true
    @Published var sendResult: String?
    @Published var showSendResult = false
    @Published var sendError: String?
    @Published var showSendError = false
    @Published var soundbytesDisabled = false

    private var total = 0
    private var currentOffset = 0
    private let pageSize = 20
    private var player: AVPlayer?

    init(token: String, onCreditsChanged: ((Int) -> Void)? = nil) {
        self.token = token
        self.onCreditsChanged = onCreditsChanged
    }

    func initialLoad() async {
        appLog("Soundbytes browser opened")
        async let genresTask: () = loadGenres()
        async let creditsTask: () = loadCredits()
        async let soundbytesTask: () = searchSoundbytes()
        async let enabledTask: () = checkEnabled()
        _ = await (genresTask, creditsTask, soundbytesTask, enabledTask)
    }

    func searchSoundbytes() async {
        currentOffset = 0
        soundbytes = []
        hasMore = true
        await loadMore()
    }

    func loadMore() async {
        guard !isLoading, hasMore else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await TwitchAuthService.shared.fetchSoundbytes(
                token: token,
                offset: currentOffset,
                amount: pageSize,
                searchTerm: searchText,
                genre: selectedGenre
            )
            soundbytes.append(contentsOf: response.soundbytes)
            total = response.total
            currentOffset += response.soundbytes.count
            hasMore = currentOffset < total
            if currentOffset == response.soundbytes.count {
                appLog("Soundbytes: loaded \(total) total, showing \(response.soundbytes.count)")
            }
        } catch {
            appLog("Soundbytes: load more failed - \(error.localizedDescription)")
        }
    }

    func checkEnabled() async {
        guard let url = URL(string: "https://api.burkeblack.tv/app/soundbytes-status") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            struct StatusResp: Codable { let success: Bool; let data: EnabledData? }
            struct EnabledData: Codable { let enabled: Bool }
            if let resp = try? JSONDecoder().decode(StatusResp.self, from: data),
               let d = resp.data {
                soundbytesDisabled = !d.enabled
            }
        } catch {}
    }

    func loadGenres() async {
        do {
            genres = try await TwitchAuthService.shared.fetchSoundbyteGenres(token: token)
        } catch {}
    }

    func loadCredits() async {
        do {
            credits = try await TwitchAuthService.shared.fetchSoundbyteCredits(token: token)
        } catch {}
    }

    func send(soundbyteId: Int, announce: Bool) async {
        do {
            let result = try await TwitchAuthService.shared.sendSoundbyte(
                token: token, soundbyteId: soundbyteId, announce: announce
            )
            credits = result.creditsRemaining
            onCreditsChanged?(credits)
            appLog("Soundbyte sent: \(result.soundbyteName), credits remaining: \(credits)")
            sendResult = "Sent \(result.soundbyteName)!"
            showSendResult = true
        } catch {
            appLog("Soundbyte send error: \(error.localizedDescription)")
            sendError = error.localizedDescription
            showSendError = true
        }
    }

    @Published var currentlyPlayingId: Int?

    func preview(soundbyte: Soundbyte) {
        player?.pause()
        player = nil

        guard let url = URL(string: soundbyte.location) else { return }

        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        currentlyPlayingId = soundbyte.id
        player?.play()

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            self?.currentlyPlayingId = nil
        }
    }

    func stopPreview() {
        player?.pause()
        player = nil
        currentlyPlayingId = nil
    }
}

// MARK: - Embeddable Content View

struct SoundbytesContentView: View {
    @ObservedObject var viewModel: SoundbytesViewModel
    var onSelect: ((SoundbytePick) -> Void)?
    @State private var showHistory = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    showHistory = true
                } label: {
                    Label("History", systemImage: "clock.arrow.circlepath")
                        .font(.caption)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search name or author...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                        Task { await viewModel.searchSoundbytes() }
                    } label: {
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

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    GenreChip(name: "All", isSelected: viewModel.selectedGenre == "All") {
                        viewModel.selectedGenre = "All"
                        Task { await viewModel.searchSoundbytes() }
                    }
                    ForEach(viewModel.genres) { genre in
                        GenreChip(name: genre.genre, isSelected: viewModel.selectedGenre == genre.genre) {
                            viewModel.selectedGenre = genre.genre
                            Task { await viewModel.searchSoundbytes() }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            List {
                ForEach(viewModel.soundbytes) { sb in
                    SoundbyteRow(soundbyte: sb, viewModel: viewModel, onSelect: onSelect)
                        .onAppear {
                            if sb.id == viewModel.soundbytes.last?.id {
                                Task { await viewModel.loadMore() }
                            }
                        }
                }

                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                }

                if viewModel.soundbytes.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView("No Soundbytes", systemImage: "music.note",
                        description: Text("Try a different search or genre."))
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
        }
        .onSubmit {
            appLog("Soundbytes: search submitted - \(viewModel.searchText)")
            Task { await viewModel.searchSoundbytes() }
        }
        .task {
            await viewModel.initialLoad()
        }
        .onDisappear {
            viewModel.stopPreview()
        }
        .sheet(isPresented: $showHistory) {
            NavigationStack {
                SoundbyteHistoryView(token: viewModel.token)
                    .navigationTitle("Send History")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showHistory = false }
                        }
                    }
            }
        }
        .alert("Sent!", isPresented: $viewModel.showSendResult) {
            Button("OK") {}
        } message: {
            Text(viewModel.sendResult ?? "")
        }
        .alert("Error", isPresented: $viewModel.showSendError) {
            Button("OK") {}
        } message: {
            Text(viewModel.sendError ?? "")
        }
    }
}

// MARK: - Standalone Wrapper

struct SoundbytesView: View {
    @StateObject private var viewModel: SoundbytesViewModel

    init(token: String, onCreditsChanged: ((Int) -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: SoundbytesViewModel(token: token, onCreditsChanged: onCreditsChanged))
    }

    var body: some View {
        SoundbytesContentView(viewModel: viewModel)
            .navigationTitle("Soundbytes")
            .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Soundbyte Row

struct SoundbyteRow: View {
    let soundbyte: Soundbyte
    @ObservedObject var viewModel: SoundbytesViewModel
    var onSelect: ((SoundbytePick) -> Void)?
    @State private var showSendConfirm = false

    private var isPlaying: Bool {
        viewModel.currentlyPlayingId == soundbyte.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(soundbyte.name)
                        .font(.headline)
                    Text(soundbyte.genre)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if soundbyte.creditCost > 0 {
                    Text("\(soundbyte.creditCost)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .foregroundStyle(PirateTheme.accentColor)
                        .background(PirateTheme.accentColor.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 12) {
                Button {
                    if isPlaying {
                        viewModel.stopPreview()
                    } else {
                        viewModel.preview(soundbyte: soundbyte)
                    }
                } label: {
                    Label(isPlaying ? "Stop" : "Listen", systemImage: isPlaying ? "stop.fill" : "play.fill")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)

                Button {
                    showSendConfirm = true
                } label: {
                    Label("Select", systemImage: "checkmark.circle")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                .tint(PirateTheme.accentColor)

                Spacer()
            }
        }
        .padding(.vertical, 4)
        .confirmationDialog("Select \(soundbyte.name)", isPresented: $showSendConfirm, titleVisibility: .visible) {
            Button("Announce in Chat") {
                if let onSelect {
                    onSelect(SoundbytePick(soundbyteId: soundbyte.id, name: soundbyte.name, announce: true))
                } else {
                    Task { await viewModel.send(soundbyteId: soundbyte.id, announce: true) }
                }
            }
            Button("Send Quietly") {
                if let onSelect {
                    onSelect(SoundbytePick(soundbyteId: soundbyte.id, name: soundbyte.name, announce: false))
                } else {
                    Task { await viewModel.send(soundbyteId: soundbyte.id, announce: false) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Cost: \(soundbyte.creditCost) credit(s). You have \(viewModel.credits).")
        }
    }
}

// MARK: - Genre Chip

struct GenreChip: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(isSelected ? .white : .primary)
                .background(isSelected ? PirateTheme.accentColor : Color(.systemGray5))
                .clipShape(Capsule())
        }
    }
}

// MARK: - History

struct SoundbyteHistoryView: View {
    let token: String
    @State private var history: [SoundbyteHistoryItem] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if history.isEmpty {
                ContentUnavailableView("No History", systemImage: "clock", description: Text("You haven't sent any soundbytes yet."))
            } else {
                List(history) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .font(.headline)
                            Text(item.formattedDate)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        if item.announced {
                            Image(systemName: "megaphone.fill")
                                .font(.caption)
                                .foregroundStyle(PirateTheme.accentColor)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .task {
            do {
                history = try await TwitchAuthService.shared.fetchSoundbyteHistory(token: token)
            } catch {}
            isLoading = false
        }
    }
}
