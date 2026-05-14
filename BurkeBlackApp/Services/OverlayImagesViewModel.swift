import Foundation
import SwiftUI

@MainActor
class OverlayImagesViewModel: ObservableObject {
    let token: String
    let username: String
    let userFilter: String

    @Published var categories: [OverlayCategory] = []
    @Published var images: [OverlayImage] = []
    @Published var selectedCategory = "All"
    @Published var isLoading = false

    @Published var selectedImage: OverlayImage?
    @Published var showModePicker = false
    @Published var selectedMode: String = "medium"
    @Published var overlayPosition: CGPoint = CGPoint(x: 0.5, y: 0.5)
    @Published var isSending = false
    @Published var sendResult: String?
    @Published var showSendResult = false
    @Published var sendError: String?
    @Published var showSendError = false

    var streamThumbnailURL: URL? {
        let ts = Int(Date().timeIntervalSince1970)
        return URL(string: "https://static-cdn.jtvnw.net/previews-ttv/live_user_burkeblack-640x360.jpg?_=\(ts)")
    }

    init(token: String, username: String, userFilter: String = "all") {
        self.token = token
        self.username = username
        self.userFilter = userFilter
    }

    func loadImages() async {
        guard images.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        appLog("OverlayImages: loading with filter=\(userFilter)")
        do {
            let data = try await TwitchAuthService.shared.fetchOverlayImages(token: token, filter: userFilter)
            categories = data.categories
            images = data.images
            appLog("OverlayImages: loaded \(images.count) images in \(categories.count) categories")
        } catch {
            appLog("OverlayImages: load failed - \(error.localizedDescription)")
        }
    }

    var filteredImages: [OverlayImage] {
        if selectedCategory == "All" { return images }
        guard let cat = categories.first(where: { $0.name == selectedCategory }) else { return images }
        return images.filter { $0.categoryId == cat.id }
    }

    struct ImageGroup: Identifiable {
        let category: OverlayCategory
        let images: [OverlayImage]
        var id: Int { category.id }
    }

    var groupedImages: [ImageGroup] {
        let filtered = filteredImages
        var groups: [ImageGroup] = []
        for cat in categories {
            let catImages = filtered.filter { $0.categoryId == cat.id }
            if !catImages.isEmpty {
                groups.append(ImageGroup(category: cat, images: catImages))
            }
        }
        return groups
    }

    var availableModes: [String] {
        guard let img = selectedImage else { return ["medium"] }
        return modesForImage(img)
    }

    func modesForImage(_ img: OverlayImage) -> [String] {
        var modes: [String] = []
        if img.modes?.large != nil { modes.append("large") }
        if img.modes?.medium != nil { modes.append("medium") }
        if img.modes?.small != nil { modes.append("small") }
        if img.modes?.bounce != nil { modes.append("bounce") }
        if modes.isEmpty { modes.append("medium") }
        return modes
    }

    func selectImage(_ image: OverlayImage) {
        selectedImage = image
        let modes = availableModes
        selectedMode = modes.contains("medium") ? "medium" : modes.first ?? "medium"
        overlayPosition = CGPoint(x: 0.5, y: 0.5)
        showModePicker = true
        appLog("OverlayImages: selected '\(image.name)'")
    }

    func triggerOverlay() async {
        guard let image = selectedImage else { return }
        isSending = true
        defer { isSending = false }

        let duration: Double
        switch selectedMode {
        case "large": duration = image.modes?.large?.duration ?? 10
        case "small": duration = image.modes?.small?.duration ?? 10
        case "bounce": duration = image.modes?.bounce?.duration ?? 10
        default: duration = image.modes?.medium?.duration ?? 10
        }

        appLog("OverlayImages: triggering image=\(image.id) mode=\(selectedMode)")
        do {
            let body = OverlayTriggerBody(
                imageId: image.id,
                gifToken: nil,
                mode: selectedMode,
                duration: duration,
                username: username,
                source: "app_ios",
                xPercent: overlayPosition.x,
                yPercent: overlayPosition.y
            )
            let result = try await TwitchAuthService.shared.triggerOverlay(token: token, body: body)
            sendResult = result.message
            showSendResult = true
            showModePicker = false
            appLog("OverlayImages: trigger success - \(result.message)")
        } catch {
            appLog("OverlayImages: trigger failed - \(error.localizedDescription)")
            sendError = error.localizedDescription
            showSendError = true
        }
    }
}
