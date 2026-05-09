import SwiftUI


// MARK: - Model

struct Tiding: Identifiable {
    let id: Int
    let title: String
    let author: String
    let postedAt: Date
    let body: String
    let isVisibleOnIos: Bool
    let isVisibleOnAndroid: Bool
    let isVisibleOnWebsite: Bool

    var timeAgo: String {
        let seconds = Int(Date().timeIntervalSince(postedAt))
        let minutes = seconds / 60
        let hours = minutes / 60
        let days = hours / 24
        let weeks = days / 7

        if weeks > 0 { return "Posted \(weeks) \(weeks == 1 ? "week" : "weeks") ago" }
        if days > 0 { return "Posted \(days) \(days == 1 ? "day" : "days") ago" }
        if hours > 0 { return "Posted \(hours) \(hours == 1 ? "hour" : "hours") ago" }
        if minutes > 0 { return "Posted \(minutes) \(minutes == 1 ? "minute" : "minutes") ago" }
        return "Posted just now"
    }
}

// Shared API row — used by all three endpoints (/news, /mod/news, /mod/news/deleted)
struct APIArticle: Codable {
    let id: Int
    let subject: String
    let body: String
    let created_at: String
    let created_by_username: String
    let is_visible_on_ios: Int?
    let is_visible_on_android: Int?
    let is_visible_on_website: Int?

    func toTiding() -> Tiding {
        Tiding(
            id: id,
            title: subject,
            author: created_by_username,
            postedAt: TidingDateParser.parse(created_at),
            body: body,
            isVisibleOnIos: (is_visible_on_ios ?? 1) == 1,
            isVisibleOnAndroid: (is_visible_on_android ?? 1) == 1,
            isVisibleOnWebsite: (is_visible_on_website ?? 1) == 1
        )
    }
}

enum TidingDateParser {
    static func parse(_ dateStr: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        if let date = formatter.date(from: dateStr) { return date }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: dateStr) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: dateStr) { return date }

        return Date()
    }
}

// MARK: - View

struct TidingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Binding var deepLinkArticleId: Int?
    @State private var tidings: [Tiding] = []
    @State private var selectedTiding: Tiding?
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var canManageNews = false
    @State private var showNewTiding = false
    @State private var editingTiding: Tiding?
    @State private var showDeletedTidings = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header (5-second hold opens Deleted Tidings for mods)
                        HStack(spacing: 10) {
                            Image(systemName: "scroll.fill")
                                .font(.title3)
                                .foregroundStyle(PirateTheme.accentColor)
                            Text("Tidings")
                                .font(PirateTheme.font(size: 28))
                                .foregroundStyle(PirateTheme.accentColor)
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 4)
                        .contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 5.0) {
                            if canManageNews {
                                appLog("Tidings: 5s hold - opening deleted view")
                                showDeletedTidings = true
                            }
                        }

                        Text("News from across the seven seas")
                            .font(PirateTheme.font(size: 14))
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.bottom, 16)

                        if isLoading {
                            HStack {
                                Spacer()
                                VStack(spacing: 12) {
                                    ProgressView().tint(PirateTheme.accentColor)
                                    Text("Fetchin\u{2019} the latest dispatches...")
                                        .font(PirateTheme.font(size: 14))
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                                .padding(.top, 40)
                                Spacer()
                            }
                        } else if loadFailed {
                            HStack {
                                Spacer()
                                VStack(spacing: 12) {
                                    Image(systemName: "wifi.slash")
                                        .font(.system(size: 36))
                                        .foregroundStyle(PirateTheme.accentColor.opacity(0.4))
                                    Text("Couldn\u{2019}t reach the ship\u{2019}s log")
                                        .font(PirateTheme.font(size: 16))
                                        .foregroundStyle(.white.opacity(0.5))
                                    Button {
                                        Task { await loadTidings() }
                                    } label: {
                                        Text("Try Again")
                                            .font(PirateTheme.font(size: 14))
                                            .foregroundStyle(.black)
                                            .padding(.horizontal, 24)
                                            .padding(.vertical, 8)
                                            .background(PirateTheme.accentColor)
                                            .clipShape(Capsule())
                                    }
                                }
                                .padding(.top, 40)
                                Spacer()
                            }
                        } else if tidings.isEmpty {
                            HStack {
                                Spacer()
                                VStack(spacing: 12) {
                                    Image(systemName: "scroll")
                                        .font(.system(size: 36))
                                        .foregroundStyle(PirateTheme.accentColor.opacity(0.3))
                                    Text("No tidings to report, Captain")
                                        .font(PirateTheme.font(size: 16))
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                                .padding(.top, 40)
                                Spacer()
                            }
                        } else {
                            // Articles
                            LazyVStack(spacing: 12) {
                                ForEach(tidings) { tiding in
                                    TidingCard(tiding: tiding, showPlatformBadges: canManageNews) {
                                        appLog("Tidings: opened article: \(tiding.title)")
                                        selectedTiding = tiding
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }

                if canManageNews {
                    Button {
                        showNewTiding = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.black)
                            .frame(width: 56, height: 56)
                            .background(PirateTheme.accentColor)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                    .accessibilityLabel("New Tiding")
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(item: $selectedTiding) { tiding in
                NavigationStack {
                    TidingDetailView(
                        tiding: tiding,
                        canManage: canManageNews,
                        onEdit: { editingTiding = $0 },
                        onDeleted: {
                            // Article was deleted - refresh list
                            Task { await loadTidings() }
                        }
                    )
                }
            }
            .fullScreenCover(isPresented: $showNewTiding) {
                NewTidingView(mode: .create) {
                    Task { await loadTidings() }
                }
            }
            .fullScreenCover(item: $editingTiding) { article in
                NewTidingView(
                    mode: .edit(
                        existing: article,
                        isVisibleOnIos: article.isVisibleOnIos,
                        isVisibleOnAndroid: article.isVisibleOnAndroid,
                        isVisibleOnWebsite: article.isVisibleOnWebsite
                    )
                ) {
                    Task { await loadTidings() }
                }
            }
            .fullScreenCover(isPresented: $showDeletedTidings) {
                DeletedTidingsView()
            }
            .onAppear {
                if tidings.isEmpty {
                    Task { await loadTidings() }
                }
            }
            .refreshable {
                await loadTidings()
            }
            .onChange(of: deepLinkArticleId) { _, newId in
                guard let articleId = newId else { return }
                if let article = tidings.first(where: { $0.id == articleId }) {
                    appLog("Tidings: deep linking to article \(articleId)")
                    selectedTiding = article
                    deepLinkArticleId = nil
                } else if !tidings.isEmpty {
                    Task { await loadTidings() }
                }
            }
        }
    }

    // Tiding is `Identifiable` already so this works as `fullScreenCover(item:)` source
    // (need a fileprivate Identifiable wrapper if we ever want two distinct sheets keyed
    // off the same struct — for now `editingTiding` and `selectedTiding` are independent).

    private func loadTidings() async {
        isLoading = tidings.isEmpty
        loadFailed = false
        appLog("Tidings: loading articles from API")

        // Resolve mod permission first; mods get every article via /mod/news
        let token = AccountViewModel.getBearerToken()
        if let t = token {
            await refreshNewsPermission(token: t)
        } else {
            canManageNews = false
        }

        let urlString: String
        if canManageNews, token != nil {
            urlString = "https://api.burkeblack.tv/app/mod/news"
        } else {
            urlString = "https://api.burkeblack.tv/app/news?platform=ios"
        }
        guard let url = URL(string: urlString) else {
            loadFailed = true
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        if canManageNews, let t = token {
            request.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        }
        TwitchAuthService.addPlatformHeaders(&request)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                appLog("Tidings: API returned \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                loadFailed = tidings.isEmpty
                isLoading = false
                return
            }

            struct NewsResponse: Codable {
                let success: Bool
                let data: NewsData?
            }
            struct NewsData: Codable {
                let articles: [APIArticle]
            }

            let decoded = try JSONDecoder().decode(NewsResponse.self, from: data)
            guard let articles = decoded.data?.articles else {
                loadFailed = tidings.isEmpty
                isLoading = false
                return
            }

            tidings = articles.map { $0.toTiding() }
            appLog("Tidings: loaded \(tidings.count) articles (mod=\(canManageNews))")

            // Check for pending deep link
            if let articleId = deepLinkArticleId {
                if let article = tidings.first(where: { $0.id == articleId }) {
                    appLog("Tidings: deep linking to article \(articleId)")
                    selectedTiding = article
                }
                deepLinkArticleId = nil
            }
        } catch {
            appLog("Tidings: load failed - \(error.localizedDescription)")
            loadFailed = tidings.isEmpty
        }
        isLoading = false
    }

    private func refreshNewsPermission(token: String) async {
        guard let url = URL(string: "https://api.burkeblack.tv/app/mod/permissions") else {
            canManageNews = false
            return
        }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        TwitchAuthService.addPlatformHeaders(&req)
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                canManageNews = false
                return
            }
            struct PermsResp: Codable {
                let success: Bool
                let data: PermsData?
                struct PermsData: Codable { let news: FlexInt? }
            }
            let decoded = try JSONDecoder().decode(PermsResp.self, from: data)
            canManageNews = (decoded.data?.news?.isOne ?? false)
        } catch {
            appLog("Tidings: perms fetch error \(error.localizedDescription)")
            canManageNews = false
        }
    }
}

// MARK: - Tiding Card

private struct TidingCard: View {
    let tiding: Tiding
    let showPlatformBadges: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(tiding.title)
                            .font(PirateTheme.font(size: 17))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if showPlatformBadges {
                            PlatformBadges(tiding: tiding)
                        }
                    }

                    HStack(spacing: 6) {
                        Text(tiding.author)
                            .font(PirateTheme.font(size: 12))
                            .foregroundStyle(PirateTheme.accentColor.opacity(0.7))

                        Text("\u{2022}")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.2))

                        Text(tiding.timeAgo)
                            .font(PirateTheme.font(size: 12))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }

                Spacer(minLength: 12)

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(PirateTheme.accentColor.opacity(0.3))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct PlatformBadges: View {
    let tiding: Tiding

    var body: some View {
        HStack(spacing: 4) {
            badge("iphone", on: tiding.isVisibleOnIos, label: "iOS")
            badge("candybarphone", on: tiding.isVisibleOnAndroid, label: "Android")
            badge("globe", on: tiding.isVisibleOnWebsite, label: "Website")
        }
    }

    private func badge(_ symbol: String, on: Bool, label: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 12))
            .foregroundStyle(on ? PirateTheme.accentColor : .white.opacity(0.18))
            .accessibilityLabel(on ? "\(label) visible" : "\(label) hidden")
    }
}

// MARK: - Detail View

struct TidingDetailView: View {
    let tiding: Tiding
    let canManage: Bool
    let onEdit: (Tiding) -> Void
    let onDeleted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var deleteError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(tiding.title)
                    .font(PirateTheme.font(size: 26))
                    .foregroundStyle(PirateTheme.accentColor)

                HStack(spacing: 6) {
                    Text(tiding.author)
                        .font(PirateTheme.font(size: 14))
                        .foregroundStyle(PirateTheme.accentColor.opacity(0.7))
                    Text("\u{2022}")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.2))
                    Text(tiding.timeAgo)
                        .font(PirateTheme.font(size: 14))
                        .foregroundStyle(.white.opacity(0.4))
                }

                Divider().overlay(PirateTheme.accentColor.opacity(0.2))

                MarkdownBodyView(markdown: tiding.body)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
                    .foregroundStyle(PirateTheme.accentColor)
            }
            if canManage {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        let toEdit = tiding
                        dismiss()
                        // Defer so the dismiss animation kicks in before the new sheet opens
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            onEdit(toEdit)
                        }
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundStyle(PirateTheme.accentColor)
                    }
                    .disabled(isDeleting)
                }
                ToolbarItem(placement: .primaryAction) {
                    if isDeleting {
                        ProgressView().tint(PirateTheme.accentColor)
                    } else {
                        Button {
                            showDeleteConfirm = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(Color(red: 1.0, green: 0.42, blue: 0.42))
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete this tiding?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { Task { await performDelete() } }
        } message: {
            Text("It will be hidden from users immediately. You can restore it later via the Tidings deleted view.")
        }
        .alert("Couldn't delete", isPresented: .init(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK", role: .cancel) { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
    }

    private func performDelete() async {
        guard let token = AccountViewModel.getBearerToken() else {
            deleteError = "Not signed in"
            return
        }
        isDeleting = true
        defer { isDeleting = false }
        guard let url = URL(string: "https://api.burkeblack.tv/app/mod/news/delete") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        TwitchAuthService.addPlatformHeaders(&req)
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["id": tiding.id])
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            struct Resp: Codable { let success: Bool; let error: String? }
            let decoded = try JSONDecoder().decode(Resp.self, from: data)
            if decoded.success {
                appLog("Tidings: deleted \(tiding.id)")
                onDeleted()
                dismiss()
            } else {
                deleteError = decoded.error ?? "Failed to delete"
            }
        } catch {
            appLog("Tidings: delete error \(error.localizedDescription)")
            deleteError = "Couldn't reach the ship's log"
        }
    }
}

// MARK: - Markdown Renderer (internal so NewTidingView preview tab and DeletedTidingsView can reuse)

struct MarkdownBodyView: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(parseLines().enumerated()), id: \.offset) { _, line in
                line
            }
        }
    }

    private func parseLines() -> [AnyView] {
        var views: [AnyView] = []
        let lines = markdown.components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                views.append(AnyView(Spacer().frame(height: 4)))
            } else if trimmed.hasPrefix("### ") {
                let heading = String(trimmed.dropFirst(4))
                views.append(AnyView(
                    Text(heading)
                        .font(PirateTheme.font(size: 18))
                        .foregroundStyle(PirateTheme.accentColor.opacity(0.75))
                        .padding(.top, 4)
                ))
            } else if trimmed.hasPrefix("## ") {
                let heading = String(trimmed.dropFirst(3))
                views.append(AnyView(
                    Text(heading)
                        .font(PirateTheme.font(size: 20))
                        .foregroundStyle(PirateTheme.accentColor.opacity(0.85))
                        .padding(.top, 4)
                ))
            } else if trimmed.hasPrefix("# ") {
                let heading = String(trimmed.dropFirst(2))
                views.append(AnyView(
                    Text(heading)
                        .font(PirateTheme.font(size: 24))
                        .foregroundStyle(PirateTheme.accentColor)
                        .padding(.top, 4)
                ))
            } else if trimmed.hasPrefix("![") {
                if let urlStart = trimmed.range(of: "]("), let urlEnd = trimmed.range(of: ")", range: urlStart.upperBound..<trimmed.endIndex) {
                    let imageUrl = String(trimmed[urlStart.upperBound..<urlEnd.lowerBound])
                    views.append(AnyView(
                        AsyncImage(url: URL(string: imageUrl)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            case .failure:
                                EmptyView()
                            default:
                                ProgressView().tint(PirateTheme.accentColor.opacity(0.5))
                                    .frame(height: 100)
                            }
                        }
                        .padding(.vertical, 4)
                    ))
                }
            } else if trimmed.hasPrefix("- ") {
                let bullet = String(trimmed.dropFirst(2))
                views.append(AnyView(
                    HStack(alignment: .top, spacing: 8) {
                        Text("\u{2022}")
                            .foregroundStyle(PirateTheme.accentColor.opacity(0.5))
                        renderInlineMarkdown(bullet)
                    }
                    .padding(.leading, 8)
                ))
            } else if let match = trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                let number = String(trimmed[trimmed.startIndex..<match.upperBound])
                let content = String(trimmed[match.upperBound...])
                views.append(AnyView(
                    HStack(alignment: .top, spacing: 4) {
                        Text(number)
                            .foregroundStyle(PirateTheme.accentColor.opacity(0.5))
                            .font(.system(size: 15))
                        renderInlineMarkdown(content)
                    }
                    .padding(.leading, 8)
                ))
            } else {
                views.append(AnyView(renderInlineMarkdown(trimmed)))
            }
            i += 1
        }
        return views
    }

    private func renderInlineMarkdown(_ text: String) -> Text {
        if let attributed = try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            var styled = attributed
            styled.foregroundColor = .white.opacity(0.75)
            styled.font = .system(size: 15)
            for run in styled.runs {
                if run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true {
                    styled[run.range].foregroundColor = .white
                    styled[run.range].font = .system(size: 15, weight: .semibold)
                }
                if run.link != nil {
                    styled[run.range].foregroundColor = PirateTheme.accentColor
                    styled[run.range].underlineStyle = .single
                }
            }
            return Text(styled)
        }
        return Text(text)
            .foregroundColor(.white.opacity(0.75))
            .font(.system(size: 15))
    }
}
