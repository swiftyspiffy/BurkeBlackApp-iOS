import Foundation
import SwiftUI
import CryptoKit
import CommonCrypto

@MainActor
class KlipyViewModel: ObservableObject {
    let token: String
    let username: String

    @Published var searchText = ""
    @Published var results: [KlipyGifResult] = []
    @Published var decryptedURLs: [String: URL] = [:]
    @Published var isLoading = false
    @Published var hasMore = true
    @Published var isShowingResults = false

    @Published var selectedGif: KlipyGifResult?
    @Published var showModePicker = false
    @Published var selectedMode: String = "medium"
    @Published var overlayPosition: CGPoint = CGPoint(x: 0.5, y: 0.5)
    @Published var isSending = false
    @Published var sendResult: String?
    @Published var showSendResult = false
    @Published var sendError: String?
    @Published var showSendError = false

    private var currentPage = 1
    private let perPage = 20
    private var decryptKey: String?
    private var decryptKeyExpiry: Date?

    var streamThumbnailURL: URL? {
        let ts = Int(Date().timeIntervalSince1970)
        return URL(string: "https://static-cdn.jtvnw.net/previews-ttv/live_user_burkeblack-640x360.jpg?_=\(ts)")
    }

    static let defaultCategories = [
        "Trending", "Reactions", "Memes", "Funny",
        "Anime", "Gaming", "Love", "Sad",
        "Happy", "Angry", "Dance", "Celebrate"
    ]

    init(token: String, username: String) {
        self.token = token
        self.username = username
    }

    func searchByCategory(_ name: String) {
        searchText = name
        Task { await search() }
    }

    func search() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            clearSearch()
            return
        }

        currentPage = 1
        results = []
        decryptedURLs = [:]
        hasMore = true
        isShowingResults = true

        await loadPage(query: query, page: 1)
    }

    func loadMore() async {
        guard !isLoading, hasMore else { return }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        await loadPage(query: query, page: currentPage + 1)
    }

    func clearSearch() {
        searchText = ""
        results = []
        decryptedURLs = [:]
        isShowingResults = false
        currentPage = 1
        hasMore = true
    }

    private func loadPage(query: String, page: Int) async {
        isLoading = true
        defer { isLoading = false }

        appLog("Klipy: searching '\(query)' page=\(page)")
        do {
            try await ensureDecryptKey()

            let data = try await TwitchAuthService.shared.searchGifs(
                token: token, query: query, page: page, perPage: perPage
            )

            for gif in data.results {
                if let url = decryptURL(gif.encryptedPreviewUrl) {
                    decryptedURLs[gif.token] = url
                }
            }

            if page == 1 {
                results = data.results
            } else {
                results.append(contentsOf: data.results)
            }
            currentPage = data.page
            hasMore = data.hasNext
            appLog("Klipy: got \(data.results.count) results, hasMore=\(data.hasNext)")
        } catch {
            appLog("Klipy: search failed - \(error.localizedDescription)")
        }
    }

    private func ensureDecryptKey() async throws {
        if let key = decryptKey, let expiry = decryptKeyExpiry, Date() < expiry {
            return
        }

        appLog("Klipy: fetching decrypt key")
        let data = try await TwitchAuthService.shared.fetchGifDecryptKey(token: token)
        decryptKey = data.gifDecryptKey
        decryptKeyExpiry = Date(timeIntervalSince1970: TimeInterval(data.expiresAt))
        appLog("Klipy: decrypt key obtained, expires \(decryptKeyExpiry!)")
    }

    func decryptURL(_ encrypted: String) -> URL? {
        guard let key = decryptKey else { return nil }
        guard let raw = Data(base64Encoded: encrypted), raw.count > 16 else { return nil }

        let iv = raw.prefix(16)
        let ciphertext = raw.dropFirst(16)
        let keyHash = SHA256.hash(data: Data(key.utf8))
        let keyBytes = Array(keyHash)

        let decryptedBufferSize = ciphertext.count + kCCBlockSizeAES128
        var decrypted = Data(count: decryptedBufferSize)
        var decryptedLength = 0

        let status = keyBytes.withUnsafeBufferPointer { keyPtr in
            iv.withUnsafeBytes { ivPtr in
                ciphertext.withUnsafeBytes { dataPtr in
                    decrypted.withUnsafeMutableBytes { outPtr in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyPtr.baseAddress, keyBytes.count,
                            ivPtr.baseAddress,
                            dataPtr.baseAddress, ciphertext.count,
                            outPtr.baseAddress, decryptedBufferSize,
                            &decryptedLength
                        )
                    }
                }
            }
        }

        guard status == kCCSuccess else {
            appLog("Klipy: decrypt failed with status \(status)")
            return nil
        }

        guard let urlString = String(data: decrypted.prefix(decryptedLength), encoding: .utf8) else {
            return nil
        }
        return URL(string: urlString)
    }

    func selectGif(_ gif: KlipyGifResult) {
        selectedGif = gif
        selectedMode = "medium"
        overlayPosition = CGPoint(x: 0.5, y: 0.5)
        showModePicker = true
        appLog("Klipy: selected gif '\(gif.title)'")
    }

    func triggerOverlay() async {
        guard let gif = selectedGif else { return }
        isSending = true
        defer { isSending = false }

        appLog("Klipy: triggering gif mode=\(selectedMode)")
        do {
            let body = OverlayTriggerBody(
                imageId: nil,
                gifToken: gif.token,
                mode: selectedMode,
                duration: 10,
                username: username,
                source: "app_ios",
                xPercent: overlayPosition.x,
                yPercent: overlayPosition.y
            )
            let result = try await TwitchAuthService.shared.triggerOverlay(token: token, body: body)
            sendResult = result.message
            showSendResult = true
            showModePicker = false
            appLog("Klipy: trigger success - \(result.message)")
        } catch {
            appLog("Klipy: trigger failed - \(error.localizedDescription)")
            sendError = error.localizedDescription
            showSendError = true
        }
    }
}
