import SwiftUI


// MARK: - Models

struct EmoteItem: Identifiable {
    let id = UUID()
    let name: String
    let url: String
}

struct EmoteSection: Identifiable {
    let id = UUID()
    let title: String
    let items: [EmoteItem]
}

struct GalleryCategory: Identifiable {
    let id = UUID()
    let title: String
    let sections: [EmoteSection]
}

// MARK: - Main View

struct EmotesGalleryView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    @State private var loadState: LoadState = .loading
    @State private var viewerItems: [EmoteItem] = []
    @State private var viewerIndex: Int = 0
    @State private var showViewer = false

    enum LoadState {
        case loading
        case loaded([GalleryCategory])
        case failed
        case notLoggedIn
    }

    var body: some View {
        Group {
            switch loadState {
            case .loading:
                loadingView
            case .loaded(let categories):
                loadedView(categories)
            case .failed:
                failedView
            case .notLoggedIn:
                notLoggedInView
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
                    .foregroundStyle(PirateTheme.accentColor)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            appLog("EmotesGallery: view appeared")
            loadData()
        }
        .fullScreenCover(isPresented: $showViewer) {
            EmoteViewerOverlay(items: viewerItems, currentIndex: $viewerIndex, isPresented: $showViewer)
        }
    }

    func openViewer(items: [EmoteItem], startingAt item: EmoteItem) {
        viewerItems = items
        viewerIndex = items.firstIndex(where: { $0.id == item.id }) ?? 0
        showViewer = true
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .tint(PirateTheme.accentColor)
            Text("Loadin\u{2019} the treasure chest...")
                .font(PirateTheme.font(size: 16))
                .foregroundStyle(.white.opacity(0.5))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Failed

    private var failedView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundStyle(PirateTheme.accentColor.opacity(0.4))
            Text("No Wind in the Sails")
                .font(PirateTheme.font(size: 24))
                .foregroundStyle(PirateTheme.accentColor)
            Text("An internet connection be required to load emotes, badges, and cheermotes.")
                .font(PirateTheme.font(size: 14))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                appLog("EmotesGallery: retrying load")
                loadState = .loading
                loadData()
            } label: {
                Text("Try Again")
                    .font(PirateTheme.font(size: 16))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 10)
                    .background(PirateTheme.accentColor)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Not Logged In

    private var notLoggedInView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(PirateTheme.accentColor.opacity(0.4))
            Text("Crew Members Only")
                .font(PirateTheme.font(size: 24))
                .foregroundStyle(PirateTheme.accentColor)
            Text("Sign in with Twitch to browse emotes, badges, and cheermotes.")
                .font(PirateTheme.font(size: 14))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Loaded

    private func loadedView(_ categories: [GalleryCategory]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("Emotes, Bits, Badges & Cheermotes")
                    .font(PirateTheme.font(size: 26))
                    .foregroundStyle(PirateTheme.accentColor)
                    .padding(.top, 8)

                ForEach(categories) { category in
                    VStack(alignment: .leading, spacing: 16) {
                        Text(category.title)
                            .font(PirateTheme.font(size: 20))
                            .foregroundStyle(PirateTheme.accentColor.opacity(0.8))

                        ForEach(category.sections) { section in
                            GallerySectionView(section: section) { item in
                                openViewer(items: section.items, startingAt: item)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Data Loading

    private func loadData() {
        Task {
            do {
                let service = TwitchEmoteService.shared

                async let emotesResult = service.fetchChannelEmotes()
                async let badgesResult = service.fetchChannelBadges()
                async let cheermotesResult = service.fetchCheermotes()

                let emotes = try await emotesResult
                let badges = try await badgesResult
                let cheermotes = try await cheermotesResult

                appLog("EmotesGallery: loaded \(emotes.data.count) emotes, \(badges.data.count) badge sets, \(cheermotes.data.count) cheermotes")
                let categories = buildCategories(emotes: emotes, badges: badges, cheermotes: cheermotes)
                await MainActor.run { loadState = .loaded(categories) }
            } catch EmoteError.notLoggedIn {
                appLog("EmotesGallery: user not logged in")
                await MainActor.run { loadState = .notLoggedIn }
            } catch {
                appLog("EmotesGallery: load failed - \(error.localizedDescription)")
                await MainActor.run { loadState = .failed }
            }
        }
    }

    private func buildCategories(emotes: ChannelEmotesResponse, badges: ChannelBadgesResponse, cheermotes: CheermotesResponse) -> [GalleryCategory] {
        let template = emotes.template

        // Group emotes by type
        var subEmotes: [TwitchEmote] = []
        var bitsEmotes: [TwitchEmote] = []
        var followerEmotes: [TwitchEmote] = []

        for emote in emotes.data {
            switch emote.emote_type {
            case "subscriptions": subEmotes.append(emote)
            case "bitstier": bitsEmotes.append(emote)
            case "follower": followerEmotes.append(emote)
            default: break
            }
        }

        // Sub emotes: group by emote_set_id to determine tiers
        // Twitch sub tiers: set with most emotes is usually T1, then T2, T3
        let subSets = Dictionary(grouping: subEmotes, by: { $0.emote_set_id })
        let sortedSets = subSets.sorted { $0.value.count > $1.value.count }

        var emoteSections: [EmoteSection] = []
        let tierNames = ["Tier 1", "Tier 2", "Tier 3"]
        for (i, (_, setEmotes)) in sortedSets.enumerated() {
            let tierName = i < tierNames.count ? tierNames[i] : "Tier \(i + 1)"
            let items = setEmotes.sorted(by: { $0.name < $1.name }).map { emote in
                let format = emote.format.contains("animated") ? "animated" : "static"
                let url = template
                    .replacingOccurrences(of: "{{id}}", with: emote.id)
                    .replacingOccurrences(of: "{{format}}", with: format)
                    .replacingOccurrences(of: "{{theme_mode}}", with: "dark")
                    .replacingOccurrences(of: "{{scale}}", with: "3.0")
                return EmoteItem(name: emote.name, url: url)
            }
            emoteSections.append(EmoteSection(title: "\(tierName) (\(items.count))", items: items))
        }

        // Bits tier emotes
        if !bitsEmotes.isEmpty {
            let items = bitsEmotes.sorted(by: { $0.name < $1.name }).map { emote in
                let format = emote.format.contains("animated") ? "animated" : "static"
                let url = template
                    .replacingOccurrences(of: "{{id}}", with: emote.id)
                    .replacingOccurrences(of: "{{format}}", with: format)
                    .replacingOccurrences(of: "{{theme_mode}}", with: "dark")
                    .replacingOccurrences(of: "{{scale}}", with: "3.0")
                return EmoteItem(name: emote.name, url: url)
            }
            emoteSections.append(EmoteSection(title: "Bits Tier (\(items.count))", items: items))
        }

        // Follower emotes
        if !followerEmotes.isEmpty {
            let items = followerEmotes.sorted(by: { $0.name < $1.name }).map { emote in
                let format = emote.format.contains("animated") ? "animated" : "static"
                let url = template
                    .replacingOccurrences(of: "{{id}}", with: emote.id)
                    .replacingOccurrences(of: "{{format}}", with: format)
                    .replacingOccurrences(of: "{{theme_mode}}", with: "dark")
                    .replacingOccurrences(of: "{{scale}}", with: "3.0")
                return EmoteItem(name: emote.name, url: url)
            }
            emoteSections.append(EmoteSection(title: "Follower (\(items.count))", items: items))
        }

        let emoteCategory = GalleryCategory(title: "Emotes", sections: emoteSections)

        // Badges
        var badgeSections: [EmoteSection] = []
        for badgeSet in badges.data {
            let title: String
            switch badgeSet.set_id {
            case "subscriber": title = "Subscriber"
            case "bits": title = "Cheer"
            default: title = badgeSet.set_id.capitalized
            }

            let items = badgeSet.versions.map { version in
                EmoteItem(name: version.title, url: version.image_url_4x)
            }
            badgeSections.append(EmoteSection(title: "\(title) (\(items.count))", items: items))
        }
        let badgeCategory = GalleryCategory(title: "Badges", sections: badgeSections)

        // Cheermotes - only show channel custom and the default "Cheer"
        var cheermoteSections: [EmoteSection] = []
        for cheermote in cheermotes.data {
            if cheermote.type != "channel_custom" && cheermote.prefix != "Cheer" { continue }

            let items = cheermote.tiers.map { tier in
                let url = tier.images.dark.animated["4"] ?? tier.images.dark.static["4"] ?? ""
                return EmoteItem(name: "\(cheermote.prefix) \(tier.min_bits)", url: url)
            }
            cheermoteSections.append(EmoteSection(title: "\(cheermote.prefix) (\(items.count))", items: items))
        }
        let cheermoteCategory = GalleryCategory(title: "Cheermotes", sections: cheermoteSections)

        return [emoteCategory, badgeCategory, cheermoteCategory]
    }
}

// MARK: - Gallery Section

private struct GallerySectionView: View {
    let section: EmoteSection
    let onTap: (EmoteItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.title)
                .font(PirateTheme.font(size: 15))
                .foregroundStyle(.white.opacity(0.5))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(section.items) { item in
                        EmoteItemView(item: item) {
                            onTap(item)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Emote Item

private struct EmoteItemView: View {
    let item: EmoteItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                AsyncImage(url: URL(string: item.url)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .tint(PirateTheme.accentColor.opacity(0.5))
                            .frame(width: 64, height: 64)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                    case .failure:
                        Image(systemName: "photo")
                            .foregroundStyle(.gray.opacity(0.3))
                            .frame(width: 64, height: 64)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 74, height: 74)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Text(item.name)
                    .font(PirateTheme.font(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(1)
                    .frame(width: 74)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Full Screen Emote Viewer

private struct EmoteViewerOverlay: View {
    let items: [EmoteItem]
    @Binding var currentIndex: Int
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    VStack(spacing: 24) {
                        AsyncImage(url: URL(string: item.url)) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .tint(PirateTheme.accentColor)
                                    .frame(width: 200, height: 200)
                            case .success(let image):
                                image
                                    .resizable()
                                    .interpolation(.none)
                                    .scaledToFit()
                                    .frame(maxWidth: 200, maxHeight: 200)
                            case .failure:
                                Image(systemName: "photo")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.gray.opacity(0.3))
                                    .frame(width: 200, height: 200)
                            @unknown default:
                                EmptyView()
                            }
                        }

                        Text(item.name)
                            .font(PirateTheme.font(size: 22))
                            .foregroundStyle(PirateTheme.accentColor)

                        Text("\(index + 1) of \(items.count)")
                            .font(PirateTheme.font(size: 14))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))

            // Close button on top
            VStack {
                HStack {
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .padding(16)
                }
                Spacer()
            }
        }
    }
}
