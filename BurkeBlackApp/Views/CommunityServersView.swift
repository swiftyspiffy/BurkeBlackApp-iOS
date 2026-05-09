import SwiftUI


struct CommunityServersView: View {
    @ObservedObject private var settings = AppSettings.shared
    @StateObject private var viewModel: CommunityServersViewModel
    @Environment(\.dismiss) private var dismiss

    init() {
        _viewModel = StateObject(wrappedValue: CommunityServersViewModel())
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.servers.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error, viewModel.servers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(PirateTheme.accentColor)
                    Text("Shipwrecked!")
                        .font(PirateTheme.font(size: 24))
                        .foregroundStyle(PirateTheme.accentColor)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Try Again") { Task { await viewModel.fetchServers() } }
                        .buttonStyle(.borderedProminent)
                        .tint(PirateTheme.accentColor)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.servers.isEmpty {
                VStack(spacing: 12) {
                    Text("\u{2693}")
                        .font(.system(size: 48))
                    Text("All Ports Are Quiet")
                        .font(PirateTheme.font(size: 24))
                        .foregroundStyle(PirateTheme.accentColor)
                    Text("No community servers are sailin' the seas right now. Check back later, matey!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                serverList
            }
        }
        .onAppear { appLog("CommunityServers: appeared") }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Text("\u{2693}")
                        .font(.body)
                    Text("Community Game Servers")
                        .font(PirateTheme.font(size: 18))
                        .foregroundStyle(PirateTheme.accentColor)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") { dismiss() }
            }
        }
    }

    private var serverList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.servers) { server in
                    NavigationLink {
                        ServerDetailView(
                            server: server,
                            isRefreshing: viewModel.isLoading,
                            onRefresh: { Task { await viewModel.fetchServers() } }
                        )
                    } label: {
                        ServerCardView(server: server)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .refreshable { await viewModel.fetchServers() }
    }
}

// MARK: - Server Card

private struct ServerCardView: View {
    let server: CommunityServer

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Full-bleed banner
            if let bannerUrl = server.bannerUrl, let url = URL(string: bannerUrl) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color.gray.opacity(0.15))
                }
                .frame(height: 200)
                .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 200)
            }

            // Gradient fade overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.3), .black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 200)

            // Left edge fade
            LinearGradient(
                colors: [.black.opacity(0.4), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 200)
            .opacity(0.3)

            // Text overlay
            VStack(alignment: .leading, spacing: 6) {
                // Game badge top-right
                HStack {
                    Spacer()
                    Text(server.gameName)
                        .font(PirateTheme.font(size: 12))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                Spacer()

                Text(server.serverName)
                    .font(PirateTheme.font(size: 20))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 4)

                HStack(spacing: 6) {
                    if server.requireSub {
                        RequirementBadge(label: "Sub", color: .purple)
                    }
                    if server.requireFollow {
                        RequirementBadge(label: "Follow", color: .blue)
                    }
                    if server.requireAllowlist {
                        RequirementBadge(label: "Allowlist", color: .orange)
                    }
                    if server.hasAccess {
                        RequirementBadge(label: "\u{2714} Access", color: .green)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Lock overlay for no-access servers
            if !server.hasAccess {
                ZStack {
                    Color.black.opacity(0.45)
                    Image(systemName: "lock.fill")
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .frame(height: 200)
            }
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 14))

    }
}

private struct RequirementBadge: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}


// MARK: - Server Detail

struct ServerDetailView: View {
    let server: CommunityServer
    let isRefreshing: Bool
    let onRefresh: () -> Void

    var body: some View {
        List {
            // Banner
            if let bannerUrl = server.bannerUrl, let url = URL(string: bannerUrl) {
                Section {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle().fill(Color.gray.opacity(0.2))
                    }
                    .frame(height: 200)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .listRowInsets(EdgeInsets())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }

            // Header
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(server.serverName)
                            .font(PirateTheme.font(size: 26))
                            .foregroundStyle(PirateTheme.accentColor)
                        Spacer()
                        Text(server.gameName)
                            .font(PirateTheme.font(size: 14))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    if let created = formattedDate(server.createdAt) {
                        Text("Est. \(created)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    // Requirement badges
                    HStack(spacing: 8) {
                        if server.requireSub {
                            DetailBadge(label: "Subscriber Required", color: .purple)
                        }
                        if server.requireFollow {
                            DetailBadge(label: "Follower Required", color: .blue)
                        }
                        if server.requireAllowlist {
                            DetailBadge(label: "Allowlist Required", color: .orange)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            // Server info
            if let info = server.info, !info.isEmpty {
                Section {
                    Text("Ship's Log")
                        .font(PirateTheme.font(size: 18))
                        .foregroundStyle(PirateTheme.accentColor)

                    Text(info)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                }
            }

            // Access section
            Section {
                if server.hasAccess {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                            Text("Ye Have Access, Pirate!")
                                .font(PirateTheme.font(size: 18))
                                .foregroundStyle(.green)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.green.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        if let ip = server.ipAddress {
                            CopyableFieldView(label: "Server Address", value: ip)
                        }

                        if let password = server.password {
                            CopyableFieldView(label: "Password", value: password)
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .font(.largeTitle)
                            .foregroundStyle(PirateTheme.accentColor.opacity(0.4))
                        Text("Access Denied")
                            .font(PirateTheme.font(size: 22))
                            .foregroundStyle(PirateTheme.accentColor.opacity(0.6))
                        Text("Ye haven't earned yer sea legs yet, pirate! Meet the requirements above to board this vessel.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { onRefresh() }
    }

    private func formattedDate(_ dateStr: String?) -> String? {
        guard let dateStr else { return nil }
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let date = df.date(from: dateStr) else { return nil }
        let out = DateFormatter()
        out.dateFormat = "MMMM d, yyyy"
        return out.string(from: date)
    }
}

private struct DetailBadge: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct CopyableFieldView: View {
    let label: String
    let value: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.tertiary)

            HStack {
                Text(value)
                    .font(PirateTheme.font(size: 18))
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    UIPasteboard.general.string = value
                    withAnimation { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { copied = false }
                    }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .foregroundStyle(copied ? .green : PirateTheme.accentColor)
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
