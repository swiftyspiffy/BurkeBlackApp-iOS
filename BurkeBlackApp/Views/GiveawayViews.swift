import SwiftUI

// MARK: - Entries List

struct GiveawayEntriesView: View {
    let token: String
    var searchText: String = ""
    @State private var entries: [GiveawayEntry] = []
    @State private var isLoading = true
    @State private var error: String?

    private var filteredEntries: [GiveawayEntry] {
        if searchText.isEmpty { return entries }
        let q = searchText.lowercased()
        return entries.filter { $0.name.lowercased().contains(q) || $0.donator.lowercased().contains(q) }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let error {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if filteredEntries.isEmpty {
                ContentUnavailableView("No Entries", systemImage: "ticket", description: Text(searchText.isEmpty ? "You haven't entered any giveaways yet." : "No matching giveaways."))
            } else {
                List(filteredEntries) { entry in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.name)
                            .font(.headline)
                        HStack {
                            Label(entry.donator, systemImage: "gift")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(entry.formattedDate)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Giveaways Entered")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadEntries()
        }
    }

    private func loadEntries() async {
        guard entries.isEmpty else { isLoading = false; return }
        appLog("Loading giveaway entries")
        do {
            entries = try await TwitchAuthService.shared.fetchGiveawayEntries(token: token)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Wins List

struct GiveawayWinsView: View {
    let token: String
    var searchText: String = ""
    @State private var wins: [GiveawayWin] = []
    @State private var isLoading = true
    @State private var error: String?

    private var filteredWins: [GiveawayWin] {
        if searchText.isEmpty { return wins }
        let q = searchText.lowercased()
        return wins.filter { $0.name.lowercased().contains(q) || $0.donator.lowercased().contains(q) }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let error {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if filteredWins.isEmpty {
                ContentUnavailableView("No Wins", systemImage: "trophy", description: Text(searchText.isEmpty ? "You haven't won any giveaways yet." : "No matching giveaways."))
            } else {
                List(filteredWins) { win in
                    NavigationLink {
                        GiveawayPrizeView(win: win)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(win.name)
                                .font(.headline)
                            Label("Donated by \(win.donator)", systemImage: "gift")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Giveaways Won")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadWins()
        }
    }

    private func loadWins() async {
        guard wins.isEmpty else { isLoading = false; return }
        do {
            wins = try await TwitchAuthService.shared.fetchGiveawayWins(token: token)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Prize Detail

struct GiveawayPrizeView: View {
    let win: GiveawayWin
    @State private var copied = false

    var body: some View {
        List {
            Section("Giveaway") {
                LabeledContent("Name", value: win.name)
                LabeledContent("Donated by", value: win.donator)
            }

            Section("Prize") {
                HStack {
                    Text(win.prize)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                    Spacer()
                    Button {
                        UIPasteboard.general.string = win.prize
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copied = false
                        }
                    } label: {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .foregroundStyle(copied ? .green : .purple)
                    }
                }
            }
        }
        .navigationTitle("Prize")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Donated List

struct GiveawayDonatedView: View {
    let token: String
    var searchText: String = ""
    @State private var donated: [GiveawayDonated] = []
    @State private var isLoading = true
    @State private var error: String?

    private var filteredDonated: [GiveawayDonated] {
        if searchText.isEmpty { return donated }
        let q = searchText.lowercased()
        return donated.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let error {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if filteredDonated.isEmpty {
                ContentUnavailableView("No Donations", systemImage: "heart", description: Text(searchText.isEmpty ? "You haven't donated any giveaways yet." : "No matching giveaways."))
            } else {
                List(filteredDonated) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.name)
                            .font(.headline)
                        HStack {
                            Text(item.state.capitalized)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(stateColor(item.state).opacity(0.15))
                                .foregroundStyle(stateColor(item.state))
                                .clipShape(Capsule())
                            Spacer()
                            Text(item.formattedDate)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Giveaways Donated")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDonated()
        }
    }

    private func loadDonated() async {
        guard donated.isEmpty else { isLoading = false; return }
        do {
            donated = try await TwitchAuthService.shared.fetchGiveawayDonated(token: token)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func stateColor(_ state: String) -> Color {
        switch state.lowercased() {
        case "claimed": return .green
        case "open", "active": return .blue
        case "closed", "ended": return .secondary
        default: return .orange
        }
    }
}

#Preview {
    NavigationStack {
        GiveawayPrizeView(win: GiveawayWin(name: "Test Giveaway", donator: "BurkeBlack", prize: "XXXX-YYYY-ZZZZ"))
    }
}
