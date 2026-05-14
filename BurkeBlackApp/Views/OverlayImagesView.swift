import SwiftUI

struct ModeDimension {
    let name: String
    let width: Int
    let height: Int
    let credit: Int
}

struct PositionerData: Identifiable {
    let id = UUID()
    let imageURL: URL?
    let isGif: Bool
    let modes: [ModeDimension]
    let name: String
    let imageId: Int?
    let gifToken: String?
    let bounceCount: Int
}

struct OverlayImagesView: View {
    let token: String
    let username: String
    let userFilter: String
    var onSelect: ((OverlayPick) -> Void)?

    @State private var selectedTab = 0
    @State private var positionerData: PositionerData?
    @State private var positionerResult: OverlayPick?
    @StateObject private var libraryVM: OverlayImagesViewModel
    @StateObject private var klipyVM: KlipyViewModel
    @Environment(\.dismiss) private var dismiss

    init(token: String, username: String, userFilter: String = "all", onSelect: ((OverlayPick) -> Void)? = nil) {
        self.token = token
        self.username = username
        self.userFilter = userFilter
        self.onSelect = onSelect
        _libraryVM = StateObject(wrappedValue: OverlayImagesViewModel(token: token, username: username, userFilter: userFilter))
        _klipyVM = StateObject(wrappedValue: KlipyViewModel(token: token, username: username))
    }

    private func bounceCountForImage(_ image: OverlayImage) -> Int {
        image.modes?.bounce?.count ?? 1
    }

    private func modeDimensions(for image: OverlayImage) -> [ModeDimension] {
        var dims: [ModeDimension] = []
        let cr = image.credits
        if let m = image.modes?.large { dims.append(ModeDimension(name: "large", width: m.width, height: m.height, credit: cr?.large ?? 3)) }
        if let m = image.modes?.medium { dims.append(ModeDimension(name: "medium", width: m.width, height: m.height, credit: cr?.medium ?? 2)) }
        if let m = image.modes?.small { dims.append(ModeDimension(name: "small", width: m.width, height: m.height, credit: cr?.small ?? 1)) }
        if let m = image.modes?.bounce { dims.append(ModeDimension(name: "bounce", width: m.width, height: m.height, credit: cr?.bounce ?? 3)) }
        if dims.isEmpty { dims.append(ModeDimension(name: "medium", width: 300, height: 300, credit: 2)) }
        return dims
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text("Library").tag(0)
                    Text("Klipy").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                ZStack {
                    LibraryTabView(viewModel: libraryVM, onImageTap: { image in
                        positionerData = PositionerData(
                            imageURL: URL(string: image.thumbnailUrl),
                            isGif: image.thumbnailUrl.lowercased().hasSuffix(".gif"),
                            modes: modeDimensions(for: image),
                            name: image.name,
                            imageId: image.id,
                            gifToken: nil,
                            bounceCount: bounceCountForImage(image)
                        )
                    })
                        .opacity(selectedTab == 0 ? 1 : 0)
                        .allowsHitTesting(selectedTab == 0)
                    KlipyTabView(viewModel: klipyVM, onGifTap: { gif in
                        let gifCredits = klipyVM.gifCredits
                        positionerData = PositionerData(
                            imageURL: klipyVM.decryptedURLs[gif.token],
                            isGif: true,
                            modes: [
                                ModeDimension(name: "large", width: 500, height: 500, credit: gifCredits?["large"] ?? 3),
                                ModeDimension(name: "medium", width: 300, height: 300, credit: gifCredits?["medium"] ?? 2),
                                ModeDimension(name: "small", width: 150, height: 150, credit: gifCredits?["small"] ?? 1),
                                ModeDimension(name: "bounce", width: 120, height: 120, credit: gifCredits?["bounce"] ?? 3)
                            ],
                            name: gif.title,
                            imageId: nil,
                            gifToken: gif.token,
                            bounceCount: 3
                        )
                    })
                        .opacity(selectedTab == 1 ? 1 : 0)
                        .allowsHitTesting(selectedTab == 1)
                }
            }
            .navigationTitle("Image / GIF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await klipyVM.loadGifSettings() }
            .fullScreenCover(item: $positionerData) { data in
                OverlayPositionerView(
                    data: data,
                    streamThumbnailURL: libraryVM.streamThumbnailURL,
                    onClose: { positionerData = nil },
                    onDone: { pick in
                        positionerData = nil
                        if let onSelect {
                            onSelect(pick)
                        } else {
                            dismiss()
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Library Tab

private struct LibraryTabView: View {
    @ObservedObject var viewModel: OverlayImagesViewModel
    var onImageTap: ((OverlayImage) -> Void)?

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    GenreChip(name: "All", isSelected: viewModel.selectedCategory == "All") {
                        viewModel.selectedCategory = "All"
                    }
                    ForEach(viewModel.categories) { cat in
                        GenreChip(name: cat.name, isSelected: viewModel.selectedCategory == cat.name) {
                            viewModel.selectedCategory = cat.name
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.images.isEmpty {
                Spacer()
                ContentUnavailableView("No Images", systemImage: "photo", description: Text("No overlay images available."))
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(viewModel.groupedImages, id: \.category.id) { group in
                            Section {
                                LazyVGrid(columns: columns, spacing: 8) {
                                    ForEach(group.images) { image in
                                        ImageCell(image: image) {
                                            onImageTap?(image)
                                        }
                                    }
                                }
                            } header: {
                                Text(group.category.name)
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }
            }
        }
        .task { await viewModel.loadImages() }
    }
}

private struct ImageCell: View {
    let image: OverlayImage
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            if let url = URL(string: image.thumbnailUrl) {
                AnimatedGIFView(url: url)
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Text(image.name)
                .font(.caption2)
                .lineLimit(1)
                .foregroundStyle(.primary)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

// MARK: - Klipy Tab

private struct KlipyTabView: View {
    @ObservedObject var viewModel: KlipyViewModel
    var onGifTap: ((KlipyGifResult) -> Void)?

    private let categoryColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    private let gifColumns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4)
    ]

    private let categoryIcons: [String: String] = [
        "Trending": "flame.fill",
        "Reactions": "face.smiling",
        "Memes": "star.fill",
        "Funny": "theatermasks.fill",
        "Anime": "sparkles",
        "Gaming": "gamecontroller.fill",
        "Love": "heart.fill",
        "Sad": "cloud.rain.fill",
        "Happy": "sun.max.fill",
        "Angry": "bolt.fill",
        "Dance": "figure.dance",
        "Celebrate": "party.popper.fill"
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search Klipy", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .onSubmit {
                        Task { await viewModel.search() }
                    }
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.clearSearch()
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

            if viewModel.isShowingResults {
                ScrollView {
                    LazyVGrid(columns: gifColumns, spacing: 4) {
                        ForEach(viewModel.results) { gif in
                            GifCell(gif: gif, previewURL: viewModel.decryptedURLs[gif.token]) {
                                onGifTap?(gif)
                            }
                            .onAppear {
                                if gif.token == viewModel.results.last?.token {
                                    Task { await viewModel.loadMore() }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    if viewModel.isLoading {
                        ProgressView()
                            .padding()
                    }

                    if viewModel.results.isEmpty && !viewModel.isLoading {
                        ContentUnavailableView("No Results", systemImage: "magnifyingglass",
                            description: Text("Try a different search term."))
                            .padding(.top, 40)
                    }
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: categoryColumns, spacing: 10) {
                        ForEach(KlipyViewModel.defaultCategories, id: \.self) { name in
                            CategoryChip(
                                name: name,
                                icon: categoryIcons[name] ?? "magnifyingglass"
                            ) {
                                viewModel.searchByCategory(name)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                }
            }
        }
    }
}

private struct CategoryChip: View {
    let name: String
    let icon: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(PirateTheme.accentColor)
                Text(name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

private struct GifCell: View {
    let gif: KlipyGifResult
    let previewURL: URL?
    let onTap: () -> Void

    var body: some View {
        Group {
            if let url = previewURL {
                AnimatedGIFView(url: url)
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray6))
                    .frame(height: 100)
                    .overlay(ProgressView())
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

// MARK: - Animated GIF

struct AnimatedGIFView: UIViewRepresentable {
    let url: URL
    var fill: Bool = true

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = fill ? .scaleAspectFill : .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.backgroundColor = .clear
        imageView.isUserInteractionEnabled = false
        imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return imageView
    }

    func updateUIView(_ imageView: UIImageView, context: Context) {
        if context.coordinator.loadedURL == url { return }
        context.coordinator.loadedURL = url
        imageView.image = nil

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let image = UIImage.gifImage(data: data) ?? UIImage(data: data)
                await MainActor.run {
                    imageView.image = image
                }
            } catch {}
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var loadedURL: URL?
    }
}

extension UIImage {
    static func gifImage(data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 1 else { return nil }

        var images: [UIImage] = []
        var duration: Double = 0

        for i in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            images.append(UIImage(cgImage: cgImage))

            if let props = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
               let gifDict = props[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                let frameDuration = gifDict[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double
                    ?? gifDict[kCGImagePropertyGIFDelayTime as String] as? Double
                    ?? 0.1
                duration += frameDuration
            } else {
                duration += 0.1
            }
        }

        guard !images.isEmpty else { return nil }
        return UIImage.animatedImage(with: images, duration: duration)
    }
}

// MARK: - Overlay Positioner (single-page: size picker + stream thumbnail with draggable artifact)

private struct OverlayPositionerView: View {
    let data: PositionerData
    let streamThumbnailURL: URL?
    let onClose: () -> Void
    let onDone: (OverlayPick) -> Void

    @State private var selectedMode: String = ""
    @State private var position: CGPoint = CGPoint(x: 0.5, y: 0.5)
    @State private var bouncePositions: [CGPoint] = []
    @State private var bounceTimer: Timer?

    private let modeLabels: [String: String] = [
        "large": "Large", "medium": "Medium", "small": "Small", "bounce": "Bounce"
    ]

    private var isBounce: Bool { selectedMode == "bounce" }

    private var currentModeDimension: ModeDimension? {
        data.modes.first { $0.name == selectedMode }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        if let url = data.imageURL {
                            AnimatedGIFView(url: url)
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        Text(data.name)
                            .font(.headline)
                        Spacer()
                    }
                    .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(data.modes, id: \.name) { mode in
                                Button {
                                    guard selectedMode != mode.name else { return }
                                    stopBouncing()
                                    selectedMode = mode.name
                                    if mode.name == "bounce" {
                                        startBouncing()
                                    }
                                } label: {
                                    Text(modeLabels[mode.name] ?? mode.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .foregroundStyle(selectedMode == mode.name ? .white : .primary)
                                        .background(selectedMode == mode.name ? PirateTheme.accentColor : Color(.systemGray5))
                                        .clipShape(Capsule())
                                        .overlay(alignment: .topTrailing) {
                                            Text("\(mode.credit)")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(.white)
                                                .frame(minWidth: 18, minHeight: 18)
                                                .background(Circle().fill(Color(.systemGray3)))
                                                .offset(x: 6, y: -8)
                                        }
                                        .padding(.top, 10)
                                        .padding(.trailing, 8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 12)

                streamThumbnailView
                    .padding(.horizontal)

                Text(isBounce ? "Bouncing preview" : "Drag to position the overlay")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                Spacer()
            }
            .navigationTitle("Image Modifying")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onClose() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let pick = OverlayPick(
                            imageId: data.imageId,
                            gifToken: data.gifToken,
                            name: data.name,
                            mode: selectedMode,
                            duration: currentModeDimension.map { $0.name == "bounce" ? 10 : 10 } ?? 10,
                            xPercent: position.x,
                            yPercent: position.y,
                            credit: currentModeDimension?.credit ?? 1
                        )
                        onDone(pick)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            let defaultMode = data.modes.first { $0.name == "small" } ?? data.modes.first
            if let mode = defaultMode {
                selectedMode = mode.name
            }
        }
        .onDisappear {
            stopBouncing()
        }
    }

    private var streamThumbnailView: some View {
        GeometryReader { geo in
            let thumbWidth = geo.size.width
            let thumbHeight = thumbWidth * 9.0 / 16.0
            let artSize = artifactSize(in: thumbWidth, thumbHeight: thumbHeight)

            ZStack {
                AsyncImage(url: streamThumbnailURL) { imgPhase in
                    switch imgPhase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        Color(.systemGray5)
                            .overlay(
                                VStack(spacing: 4) {
                                    Image(systemName: "tv")
                                        .font(.title2)
                                    Text("Stream Preview")
                                        .font(.caption)
                                }
                                .foregroundStyle(.secondary)
                            )
                    }
                }
                .frame(width: thumbWidth, height: thumbHeight)
                .clipped()

                if isBounce {
                    ForEach(0..<bouncePositions.count, id: \.self) { i in
                        overlayArtifact
                            .frame(width: artSize.width, height: artSize.height)
                            .allowsHitTesting(false)
                            .position(
                                x: bouncePositions[i].x * thumbWidth,
                                y: bouncePositions[i].y * thumbHeight
                            )
                    }
                } else {
                    ZStack {
                        overlayArtifact
                            .frame(width: artSize.width, height: artSize.height)
                            .allowsHitTesting(false)

                        Color.clear
                            .frame(width: artSize.width, height: artSize.height)
                            .contentShape(Rectangle())
                    }
                    .position(
                        x: position.x * thumbWidth,
                        y: position.y * thumbHeight
                    )
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let newX = value.location.x / thumbWidth
                                let newY = value.location.y / thumbHeight
                                position = CGPoint(
                                    x: min(max(newX, 0.05), 0.95),
                                    y: min(max(newY, 0.05), 0.95)
                                )
                            }
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .frame(width: thumbWidth, height: thumbHeight)
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
    }

    @ViewBuilder
    private var overlayArtifact: some View {
        if let url = data.imageURL {
            AnimatedGIFView(url: url, fill: false)
        } else {
            Image(systemName: "photo")
                .foregroundStyle(.white)
        }
    }

    private func artifactSize(in thumbWidth: CGFloat, thumbHeight: CGFloat) -> CGSize {
        let fraction: CGFloat
        switch selectedMode {
        case "large": fraction = 0.18
        case "medium": fraction = 0.12
        case "small": fraction = 0.07
        case "bounce": fraction = 0.06
        default: fraction = 0.10
        }
        let s = thumbWidth * fraction
        return CGSize(width: s, height: s)
    }

    private func startBouncing() {
        let count = max(data.bounceCount, 1)
        bouncePositions = (0..<count).map { _ in randomPosition() }

        bounceTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.7)) {
                bouncePositions = (0..<count).map { _ in randomPosition() }
            }
        }
    }

    private func stopBouncing() {
        bounceTimer?.invalidate()
        bounceTimer = nil
        bouncePositions = []
    }

    private func randomPosition() -> CGPoint {
        CGPoint(
            x: Double.random(in: 0.15...0.85),
            y: Double.random(in: 0.15...0.85)
        )
    }
}
