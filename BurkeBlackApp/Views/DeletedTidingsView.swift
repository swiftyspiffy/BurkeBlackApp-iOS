import SwiftUI

struct DeletedTidingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var articles: [Tiding] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var restoringIds: Set<Int> = []
    @State private var snackbarMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                Group {
                    if isLoading && articles.isEmpty {
                        ProgressView().tint(PirateTheme.accentColor)
                    } else if let err = errorMessage, articles.isEmpty {
                        VStack(spacing: 12) {
                            Text(err)
                                .foregroundStyle(.white.opacity(0.6))
                            Button("Try Again") { Task { await load() } }
                                .foregroundStyle(.black)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 8)
                                .background(PirateTheme.accentColor)
                                .clipShape(Capsule())
                        }
                    } else if articles.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "trash.slash")
                                .font(.system(size: 36))
                                .foregroundStyle(.white.opacity(0.2))
                            Text("Nothing in the bilge.")
                                .font(PirateTheme.font(size: 16))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(articles) { article in
                                    DeletedTidingCard(
                                        tiding: article,
                                        isRestoring: restoringIds.contains(article.id),
                                        onRestore: { Task { await restore(article) } }
                                    )
                                }
                            }
                            .padding(16)
                        }
                    }
                }

                if let msg = snackbarMessage {
                    VStack {
                        Spacer()
                        Text(msg)
                            .font(.subheadline)
                            .padding(12)
                            .background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.white)
                            .padding(.bottom, 24)
                            .padding(.horizontal, 16)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    if snackbarMessage == msg { snackbarMessage = nil }
                                }
                            }
                    }
                }
            }
            .navigationTitle("Deleted Tidings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(PirateTheme.accentColor)
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        guard let token = AccountViewModel.getBearerToken() else {
            errorMessage = "Not signed in"
            isLoading = false
            return
        }
        isLoading = true
        errorMessage = nil
        guard let url = URL(string: "https://api.burkeblack.tv/app/mod/news/deleted") else {
            errorMessage = "Bad URL"
            isLoading = false
            return
        }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        TwitchAuthService.addPlatformHeaders(&req)
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            struct Resp: Codable {
                let success: Bool
                let error: String?
                let data: ArticlesData?
                struct ArticlesData: Codable { let articles: [APIArticle] }
            }
            let decoded = try JSONDecoder().decode(Resp.self, from: data)
            if decoded.success, let list = decoded.data?.articles {
                articles = list.map { $0.toTiding() }
            } else {
                errorMessage = decoded.error ?? "Failed to load"
            }
        } catch {
            errorMessage = "Couldn't reach the ship's log"
            appLog("DeletedTidings: load error \(error.localizedDescription)")
        }
        isLoading = false
    }

    private func restore(_ article: Tiding) async {
        guard !restoringIds.contains(article.id) else { return }
        guard let token = AccountViewModel.getBearerToken() else {
            snackbarMessage = "Not signed in"
            return
        }
        restoringIds.insert(article.id)
        defer { restoringIds.remove(article.id) }

        guard let url = URL(string: "https://api.burkeblack.tv/app/mod/news/restore") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        TwitchAuthService.addPlatformHeaders(&req)
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["id": article.id])
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            struct Resp: Codable { let success: Bool; let error: String? }
            let decoded = try JSONDecoder().decode(Resp.self, from: data)
            if decoded.success {
                articles.removeAll { $0.id == article.id }
                appLog("DeletedTidings: restored \(article.id)")
            } else {
                snackbarMessage = decoded.error ?? "Failed to restore"
            }
        } catch {
            appLog("DeletedTidings: restore error \(error.localizedDescription)")
            snackbarMessage = "Couldn't reach the ship's log"
        }
    }
}

// MARK: - Card

private struct DeletedTidingCard: View {
    let tiding: Tiding
    let isRestoring: Bool
    let onRestore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tiding.title)
                .font(PirateTheme.font(size: 18))
                .foregroundStyle(PirateTheme.accentColor)
                .lineLimit(2)

            HStack(spacing: 6) {
                Text(tiding.author)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                Text("\u{2022}")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.3))
                Text(tiding.timeAgo)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }

            let preview = TidingPreview.shorten(tiding.body)
            if !preview.isEmpty {
                Text(preview)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(2)
            }

            HStack {
                Spacer()
                Button {
                    onRestore()
                } label: {
                    HStack(spacing: 6) {
                        if isRestoring {
                            ProgressView().tint(.black)
                        } else {
                            Image(systemName: "arrow.uturn.backward")
                            Text("Restore").fontWeight(.semibold)
                        }
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(PirateTheme.accentColor)
                    .clipShape(Capsule())
                }
                .disabled(isRestoring)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14).fill(AnyShapeStyle(PirateTheme.cardGradient))
        )
    }
}

enum TidingPreview {
    static func shorten(_ body: String) -> String {
        var s = body
        s = s.replacingOccurrences(of: #"#+\s"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\*\*(.+?)\*\*"#, with: "$1", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\[(.+?)\]\(.+?\)"#, with: "$1", options: .regularExpression)
        s = s.replacingOccurrences(of: #"!\[.*?\]\(.*?\)"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "\n", with: " ")
        let trimmed = String(s.prefix(120))
        return s.count > 120 ? trimmed + "..." : trimmed
    }
}
