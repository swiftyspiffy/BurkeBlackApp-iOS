import SwiftUI

struct CaptainsView: View {
    @EnvironmentObject private var model: CaptainsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var section = 0
    @State private var allTime = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PiratePageHeader(title: "Captains", icon: "person.3.sequence.fill", subtitle: "Choose who leads the crew.")
                CaptainWallet()
                Picker("Captain sections", selection: $section) {
                    Text("Vote").tag(0)
                    Text("The Crew").tag(1)
                    Text("Rankings").tag(2)
                }
                .pickerStyle(.segmented)
                CaptainsMessages()

                if section == 0 {
                    CaptainElectionDeadline()
                    if model.candidates.isEmpty {
                        CaptainsEmpty(loading: model.loading, text: "The next election is being prepared.")
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 290), spacing: 14)], spacing: 14) {
                        ForEach(model.candidates) { captain in CaptainCandidateCard(captain: captain) }
                    }
                    if let winner = model.winner {
                        HStack(spacing: 16) {
                            CaptainPortrait(captain: winner).frame(width: 86, height: 100)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("CURRENT CAPTAIN").font(.caption).foregroundStyle(PirateTheme.accentColor)
                                Text(winner.name).font(PirateTheme.font(size: 27))
                                Text(winner.title ?? "").foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(16).pirateCardSurface()
                    } else if model.detailsLoaded {
                        Text("A new crew. The first captain is yours to choose.").foregroundStyle(.secondary)
                    }
                    CaptainTokenRules()
                } else if section == 1 {
                    if model.crew.isEmpty {
                        CaptainsEmpty(loading: !model.detailsLoaded && model.detailsError == nil, text: "The crew is unavailable right now.")
                    } else {
                        TabView {
                            ForEach(model.crew) { captain in
                                ScrollView {
                                    VStack(spacing: 18) {
                                        CaptainPortrait(captain: captain).frame(height: 260)
                                        Text(captain.name).font(PirateTheme.font(size: 34))
                                        Text(captain.title ?? "").font(.headline).foregroundStyle(PirateTheme.accentColor)
                                        Text(captain.lore ?? "").font(.body).multilineTextAlignment(.center)
                                        Button {
                                            section = 0
                                            model.choose(captain)
                                        } label: {
                                            Label(model.candidates.contains(where: { $0.id == captain.id }) ? "Vote for this captain" : "Not in this election", systemImage: "checkmark.seal")
                                                .frame(maxWidth: .infinity)
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .disabled(!model.candidates.contains(where: { $0.id == captain.id }) || model.sending || model.pending != nil)
                                    }
                                    .padding(20).padding(.bottom, 30)
                                }
                                .pirateCardSurface()
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .always))
                        .frame(height: 650)
                    }
                } else {
                    Picker("Ranking period", selection: $allTime) {
                        Text("This election").tag(false)
                        Text("All time").tag(true)
                    }.pickerStyle(.segmented)
                    Text("The crew behind the captains").font(PirateTheme.font(size: 26))
                    Text("Top voters · tokens spent, not tokens earned").font(.subheadline).foregroundStyle(.secondary)
                    let rows = allTime ? model.lifetimeRanking : model.currentRanking
                    if rows.isEmpty {
                        CaptainsEmpty(loading: !model.detailsLoaded && model.detailsError == nil, text: "No votes cast yet. Make the first one count.")
                    }
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        HStack(spacing: 16) {
                            Text("\(row.rank ?? index + 1)").font(.title2).foregroundStyle(PirateTheme.accentColor)
                            Text(row.name ?? "Crew member").font(.headline)
                            Spacer()
                            Text(StatFormatter.integer(row.votes.value)).monospacedDigit()
                        }
                        .padding(18).pirateCardSurface()
                    }
                }
                HStack {
                    Label(model.connected ? "Live updates" : "Updates reconnecting", systemImage: model.connected ? "wifi" : "wifi.exclamationmark")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Refresh") { model.retry() }.disabled(model.loading)
                }
            }
            .frame(maxWidth: 1040)
            .padding(16).padding(.bottom, 24)
            .frame(maxWidth: .infinity)
        }
        .background(PirateScreenBackground())
        .navigationTitle("Captains")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        .refreshable { model.retry() }
        .onAppear { model.setScreenVisible(true) }
        .onDisappear { model.setScreenVisible(false) }
        .overlay { CaptainVoteConfirmation() }
    }
}

struct CaptainPortrait: View {
    let captain: Captain
    var body: some View {
        AsyncImage(url: captain.portraitURL) { phase in
            if let image = phase.image { image.resizable().scaledToFit() }
            else { Image("burkeblack_profile").resizable().scaledToFit().opacity(0.55) }
        }
        .background(RadialGradient(colors: [PirateTheme.accentColor.opacity(0.14), .clear], center: .center, startRadius: 0, endRadius: 200))
        .accessibilityHidden(true)
    }
}

struct CaptainWallet: View {
    @EnvironmentObject private var model: CaptainsViewModel
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "circle.hexagongrid.fill").font(.largeTitle).foregroundStyle(PirateTheme.accentColor)
            VStack(alignment: .leading, spacing: 3) {
                Text(model.balance.map(StatFormatter.integer) ?? "—").font(PirateTheme.font(size: 32)).monospacedDigit()
                Text("VOTING TOKENS").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if model.session == nil || model.authRequired { CaptainsSignInButton() }
        }
        .padding(18).pirateCardSurface()
    }
}

struct CaptainsSignInButton: View {
    @State private var showSignIn = false
    var body: some View {
        Button("Sign in with Twitch") { showSignIn = true }
            .buttonStyle(.bordered)
            .sheet(isPresented: $showSignIn) {
                NavigationStack {
                    AccountView(onAuthenticated: { showSignIn = false })
                        .navigationBarHidden(false)
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showSignIn = false } } }
                }
            }
    }
}

struct CaptainsMessages: View {
    @EnvironmentObject private var model: CaptainsViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array([model.error, model.detailsError, model.balanceError, model.storageError, model.notice].compactMap { $0 }.enumerated()), id: \.offset) { _, message in
                Text(message).font(.subheadline).foregroundStyle(.secondary)
            }
            if let pending = model.pending {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your last \(pending.amount)-token vote needs confirmation.").font(.subheadline)
                    Button(model.sending ? "Checking…" : "Check vote") { Task { await model.submitVote() } }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.sending || model.authRequired || !model.pendingLoaded)
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(PirateTheme.accentColor.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

struct CaptainElectionDeadline: View {
    @EnvironmentObject private var model: CaptainsViewModel
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 5) {
                if let schedule = model.schedule {
                    Text("Closes \(Self.deadline(schedule.end))").font(.headline)
                    let remaining = max(0, Int(model.remaining(at: context.date)))
                    Text(model.isActive(at: context.date) ? "\(remaining / 3600)h \((remaining % 3600) / 60)m \(remaining % 60)s remaining" : "Voting is closed")
                        .font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
                } else { Text("Weekly captain election").foregroundStyle(.secondary) }
            }
        }
    }
    private static func deadline(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        formatter.dateFormat = "EEE, MMM d · h:mm a z"
        return formatter.string(from: date)
    }
}

struct CaptainCandidateCard: View {
    @EnvironmentObject private var model: CaptainsViewModel
    let captain: Captain
    var compact = false
    var body: some View {
        Button { model.choose(captain) } label: {
            HStack(spacing: 14) {
                Text("\(captain.rank ?? 0)").font(.title2).foregroundStyle(PirateTheme.accentColor)
                CaptainPortrait(captain: captain).frame(width: compact ? 48 : 74, height: compact ? 62 : 90)
                VStack(alignment: .leading, spacing: 5) {
                    Text(captain.name).font(PirateTheme.font(size: compact ? 20 : 25)).foregroundStyle(.white)
                    if !compact { Text(captain.title ?? "").font(.caption).foregroundStyle(.secondary) }
                    Text("\(StatFormatter.integer(captain.voteCount)) votes").font(.caption).foregroundStyle(PirateTheme.accentColor)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(PirateTheme.accentColor)
            }
            .padding(compact ? 10 : 16).pirateCardSurface()
        }
        .buttonStyle(PiratePressButtonStyle())
        .disabled(model.sending || model.pending != nil || !model.pendingLoaded)
        .accessibilityLabel("\(captain.name), \(captain.voteCount) votes. View voting details")
    }
}

struct CaptainVoteConfirmation: View {
    @EnvironmentObject private var model: CaptainsViewModel
    var body: some View {
        if model.confirmationOpen, let captain = model.selected {
            ZStack {
                Color.black.opacity(0.75).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        HStack {
                            Text("Back \(captain.name)").font(PirateTheme.font(size: 28))
                            Spacer()
                            Button { model.confirmationOpen = false } label: { Image(systemName: "xmark.circle.fill").font(.title2) }
                                .accessibilityLabel("Close vote confirmation")
                        }
                        CaptainPortrait(captain: captain).frame(height: 150)
                        CaptainElectionDeadline()
                        if model.session == nil || model.authRequired {
                            Text("Sign in with Twitch to use your voting tokens.")
                            CaptainsSignInButton()
                        } else {
                            Text("You have \(model.balance.map(StatFormatter.integer) ?? "—") tokens available.")
                            HStack {
                                Button { adjust(-1) } label: { Image(systemName: "minus.circle.fill").font(.title) }
                                    .accessibilityLabel("Spend one fewer token")
                                TextField("Tokens to spend", text: $model.amount)
                                    .keyboardType(.numberPad).multilineTextAlignment(.center).textFieldStyle(.roundedBorder)
                                    .accessibilityLabel("Tokens to spend")
                                Button { adjust(1) } label: { Image(systemName: "plus.circle.fill").font(.title) }
                                    .accessibilityLabel("Spend one more token")
                            }
                            .disabled(model.sending || model.pending != nil)
                            HStack {
                                Button("1 token") { model.amount = "1" }
                                Spacer()
                                Button("All tokens") { model.amount = "\(min(model.balance ?? 0, CaptainsContract.maximumVotes))" }
                            }
                            .disabled(model.sending || model.pending != nil)
                            if model.pending == nil {
                                TimelineView(.periodic(from: .now, by: 1)) { context in
                                    Button(model.sending ? "Casting…" : "Cast \(model.validAmount ?? 0) votes") {
                                        Task { await model.submitVote() }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(model.sending || !model.pendingLoaded || model.validAmount == nil || !model.isActive(at: context.date))
                                }
                            }
                            Text("Each token adds one vote. Cast votes can’t be taken back.").font(.footnote).foregroundStyle(.secondary)
                        }
                        CaptainsMessages()
                        if model.balance == 0 { CaptainTokenRules() }
                    }
                    .padding(22).background(PirateTheme.cardBgColor).clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(PirateTheme.accentColor.opacity(0.5)))
                    .padding(16)
                }
                .frame(maxWidth: 520, maxHeight: 740)
                .scrollDismissesKeyboard(.interactively)
            }
        }
    }
    private func adjust(_ difference: Int) {
        let current = max(1, min(CaptainsContract.maximumVotes, Int(model.amount) ?? 1))
        model.amount = "\(max(1, min(min(model.balance ?? 1, CaptainsContract.maximumVotes), current + difference)))"
    }
}

private struct CaptainsEmpty: View {
    @EnvironmentObject private var model: CaptainsViewModel
    let loading: Bool
    let text: String
    var body: some View {
        VStack(spacing: 12) {
            if loading { ProgressView("Bringing the crew aboard…") } else { Text(text).foregroundStyle(.secondary) }
            Button("Try again") { model.retry() }.disabled(model.loading)
        }.frame(maxWidth: .infinity).padding(24).pirateCardSurface()
    }
}

struct CaptainTokenRules: View {
    var body: some View {
        DisclosureGroup("How do I earn voting tokens?") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Redeem Pirate’s Vote for 5,000 channel points to earn 1 token after fulfillment.")
                Text("Subscriptions and gifted subs earn 1 / 2 / 6 tokens for Tier 1 / 2 / 3. Gift tokens go to the gifter. Shared resub messages count; silent renewals don’t.")
                Text("Unspent tokens carry over. Elections close Sundays at 5 PM Eastern. Pirate’s Vote is limited to 200 accepted redemptions per month across the channel; excess redemptions are refunded.")
            }.font(.subheadline).foregroundStyle(.secondary).padding(.top, 10)
        }.padding(18).pirateCardSurface()
    }
}

struct CaptainsSettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PiratePageHeader(title: "Captains", icon: "person.3.sequence.fill", subtitle: "Election alerts & voting preferences")
                Toggle("Show Captains Popups", isOn: $settings.captainsPopupsEnabled)
                    .tint(PirateTheme.accentColor).padding(18).pirateCardSurface()
                Text("Minimize an election to keep browsing. Open Captains anytime from The Crew, even with automatic popups turned off.").foregroundStyle(.secondary)
            }.frame(maxWidth: 720).padding(16).frame(maxWidth: .infinity)
        }
        .background(PirateScreenBackground())
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
    }
}
