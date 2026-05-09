import SwiftUI


struct ClipVotingView: View {
    @ObservedObject private var settings = AppSettings.shared
    @StateObject private var viewModel: ClipVotingViewModel
    @Environment(\.dismiss) private var dismiss

    init() {
        _viewModel = StateObject(wrappedValue: ClipVotingViewModel())
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.clips.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error, viewModel.clips.isEmpty {
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
                    Button("Try Again") { Task { await viewModel.fetchClips() } }
                        .buttonStyle(.borderedProminent)
                        .tint(PirateTheme.accentColor)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                clipContent
            }
        }
        .onAppear { appLog("ClipVoting: appeared") }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Monthly Clip Voting")
                    .font(PirateTheme.font(size: 20))
                    .foregroundStyle(PirateTheme.accentColor)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") { dismiss() }
            }
        }
        .alert("Vote Submitted!", isPresented: $viewModel.submitSuccess) {
            Button("OK") {}
        } message: {
            Text("Your vote has been recorded. Thanks for voting!")
        }
    }

    private var clipContent: some View {
        ZStack(alignment: .bottom) {
            List {
                periodInfoSection
                votingInstructionsSection

                // Rankings editor (ranked mode, has selections, not yet voted)
                if viewModel.isRankedMode && !viewModel.selections.isEmpty && !viewModel.userHasVoted {
                    rankingsSection
                }

                clipsSection

                // Spacer so last clip isn't hidden behind sticky button
                if viewModel.canSubmit {
                    Section {
                        Spacer()
                            .frame(height: 60)
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .refreshable { await viewModel.fetchClips() }

            // Sticky "Cast Yer Vote!" button
            if viewModel.canSubmit && !viewModel.userHasVoted {
                Button {
                    Task { await viewModel.submitVote() }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isSubmitting {
                            ProgressView().tint(.black)
                        } else {
                            Image(systemName: "person.2.badge.key.fill")
                                .font(.body)
                        }
                        Text("Cast Yer Vote!")
                            .font(PirateTheme.font(size: 20))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(PirateTheme.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: PirateTheme.accentColor.opacity(0.4), radius: 8, y: 4)
                }
                .disabled(viewModel.isSubmitting)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.4), value: viewModel.canSubmit)
            }
        }
    }

    // MARK: - Period Info

    private var periodInfoSection: some View {
        Section {
            VStack(spacing: 8) {
                Text(formatPeriod(start: viewModel.periodStart, end: viewModel.periodEnd))
                    .font(PirateTheme.font(size: 18))
                    .foregroundStyle(.white)

                HStack(spacing: 16) {
                    Label("\(viewModel.totalVoters) voters", systemImage: "person.2.fill")
                        .font(PirateTheme.font(size: 14))
                        .foregroundStyle(.secondary)

                    if let config = viewModel.config {
                        Label(
                            viewModel.isRankedMode
                                ? "Rank yer top \(config.voteCount)"
                                : "Pick \(config.voteCount)",
                            systemImage: "person.2.badge.key.fill"
                        )
                        .font(PirateTheme.font(size: 14))
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .listRowBackground(PirateTheme.accentColor.opacity(0.15))
        }
    }

    // MARK: - Instructions

    private var votingInstructionsSection: some View {
        Section {
            if viewModel.userHasVoted {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text("Ye've already voted this period!")
                        .font(PirateTheme.font(size: 16))
                        .foregroundStyle(.green)
                }
            } else if let config = viewModel.config {
                Text(viewModel.isRankedMode
                     ? "Rank yer top \(config.voteCount) clips \u{2013} #1 gets the most booty!"
                     : "Select \(config.voteCount) clip\(config.voteCount == 1 ? "" : "s") to cast yer vote.")
                    .font(PirateTheme.font(size: 15))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Rankings (with up/down arrows)

    private var rankingsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text("Yer Rankings")
                    .font(PirateTheme.font(size: 20))
                    .foregroundStyle(PirateTheme.accentColor)
                    .padding(.bottom, 4)

                ForEach(Array(viewModel.selections.enumerated()), id: \.element) { index, clipId in
                    if let clip = viewModel.clips.first(where: { $0.clipId == clipId }) {
                        HStack(spacing: 10) {
                            // Rank number badge
                            Text("\(index + 1)")
                                .font(PirateTheme.font(size: 16))
                                .foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(PirateTheme.accentColor)
                                .clipShape(Circle())

                            Text(clip.title)
                                .font(.subheadline)
                                .lineLimit(1)
                                .foregroundStyle(.primary)

                            Spacer()

                            // Up arrow
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.moveSelectionUp(index: index)
                                }
                            } label: {
                                Image(systemName: "chevron.up")
                                    .font(.body)
                                    .foregroundStyle(index > 0 ? PirateTheme.accentColor : .gray.opacity(0.3))
                            }
                            .disabled(index == 0)
                            .buttonStyle(.plain)

                            // Down arrow
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.moveSelectionDown(index: index)
                                }
                            } label: {
                                Image(systemName: "chevron.down")
                                    .font(.body)
                                    .foregroundStyle(index < viewModel.selections.count - 1 ? PirateTheme.accentColor : .gray.opacity(0.3))
                            }
                            .disabled(index >= viewModel.selections.count - 1)
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 6)

                        if index < viewModel.selections.count - 1 {
                            Divider()
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Clips

    private var votedClips: [VotingClip] {
        viewModel.clips.filter { $0.userRank != nil }.sorted { ($0.userRank ?? 0) < ($1.userRank ?? 0) }
    }

    private var remainingClips: [VotingClip] {
        viewModel.clips.filter { $0.userRank == nil }
    }

    private var clipsSection: some View {
        Group {
            if viewModel.userHasVoted && !votedClips.isEmpty {
                Section("Yer Votes") {
                    ForEach(votedClips) { clip in
                        ClipCardView(
                            clip: clip,
                            config: viewModel.config,
                            isSelected: true,
                            rank: clip.userRank,
                            hasVoted: true,
                            onTap: {}
                        )
                    }
                }

                if !remainingClips.isEmpty {
                    Section("Other Clips") {
                        ForEach(remainingClips) { clip in
                            ClipCardView(
                                clip: clip,
                                config: viewModel.config,
                                isSelected: false,
                                rank: nil,
                                hasVoted: true,
                                onTap: {}
                            )
                        }
                    }
                }
            } else {
                Section {
                    ForEach(viewModel.clips) { clip in
                        ClipCardView(
                            clip: clip,
                            config: viewModel.config,
                            isSelected: viewModel.selections.contains(clip.clipId),
                            rank: viewModel.selections.firstIndex(of: clip.clipId).map { $0 + 1 },
                            hasVoted: viewModel.userHasVoted,
                            onTap: { viewModel.toggleSelection(clip.clipId) }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatMonth(_ raw: String) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM"
        guard let date = df.date(from: raw) else { return raw }
        let out = DateFormatter()
        out.dateFormat = "MMMM yyyy"
        return out.string(from: date)
    }

    private func formatPeriod(start: String, end: String) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let shortFmt = DateFormatter()
        shortFmt.dateFormat = "MMM d"
        let longFmt = DateFormatter()
        longFmt.dateFormat = "MMM d, yyyy"

        let startStr = df.date(from: String(start.prefix(10))).map { shortFmt.string(from: $0) } ?? start
        let endStr = df.date(from: String(end.prefix(10))).map { longFmt.string(from: $0) } ?? end
        return "Top clips from \(startStr) \u{2013} \(endStr)"
    }
}

// MARK: - Clip Card

private struct ClipCardView: View {
    let clip: VotingClip
    let config: ClipVotingConfig?
    let isSelected: Bool
    let rank: Int?
    let hasVoted: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: { if !hasVoted { onTap() } }) {
            VStack(alignment: .leading, spacing: 0) {
                // Thumbnail
                ZStack {
                    AsyncImage(url: URL(string: clip.thumbnailUrl)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .overlay(ProgressView())
                    }
                    .frame(height: 180)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    // Rank badge (top-left)
                    if let rank {
                        VStack {
                            HStack {
                                Text("#\(rank)")
                                    .font(PirateTheme.font(size: 16))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(PirateTheme.accentColor)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .padding(8)
                                Spacer()
                            }
                            Spacer()
                        }
                    }

                    // Duration badge (bottom-right)
                    if clip.duration > 0 {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text(formatDuration(clip.duration))
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.black.opacity(0.7))
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .padding(8)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(clip.title)
                        .font(PirateTheme.font(size: 16))
                        .lineLimit(2)
                        .foregroundStyle(.white)

                    Text("by \(clip.creatorName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        if config?.showViewCounts == true {
                            Label(formatViewCount(clip.viewCount), systemImage: "eye.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if config?.showVoteCounts == true {
                            Label("\(clip.voteCount) votes", systemImage: "hand.thumbsup.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if config?.showPoints == true && clip.totalPoints > 0 {
                            Label("\(clip.totalPoints) pts", systemImage: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(PirateTheme.accentColor)
                        }
                    }

                    // Selection state
                    HStack {
                        Spacer()
                        if hasVoted {
                            if let rank = clip.userRank {
                                Text("Yer #\(rank) Pick")
                                    .font(PirateTheme.font(size: 14))
                                    .foregroundStyle(.green)
                            }
                        } else {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isSelected ? PirateTheme.accentColor : .secondary)
                                .font(.title3)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    private func formatDuration(_ seconds: Float) -> String {
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    private func formatViewCount(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return "\(count)"
    }
}
