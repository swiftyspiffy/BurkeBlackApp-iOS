import Foundation
import SwiftUI

@MainActor
class ClipVotingViewModel: ObservableObject {
    @Published var clips: [VotingClip] = []
    @Published var config: ClipVotingConfig?
    @Published var month = ""
    @Published var periodStart = ""
    @Published var periodEnd = ""
    @Published var totalVoters = 0
    @Published var userHasVoted = false
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var error: String?
    @Published var selections: [String] = []
    @Published var submitSuccess = false

    private var token: String? {
        UserDefaults.standard.string(forKey: "app_bearer_token")
    }

    init() {
        Task { await fetchClips() }
    }

    func fetchClips() async {
        isLoading = true
        error = nil
        do {
            let response = try await TwitchAuthService.shared.fetchClips(token: token)
            month = response.month
            periodStart = response.periodStart
            periodEnd = response.periodEnd
            totalVoters = response.totalVoters
            userHasVoted = response.userHasVoted
            config = response.config

            var shuffled = response.clips.shuffled()
            // Pre-populate selections if user already voted
            if response.userHasVoted {
                let ranked = response.clips.filter { $0.userRank != nil }.sorted { ($0.userRank ?? 0) < ($1.userRank ?? 0) }
                selections = ranked.map(\.clipId)
                shuffled = ranked + response.clips.filter { $0.userRank == nil }
            }
            clips = shuffled
            appLog("Clips: loaded \(clips.count) clips for \(month)")
        } catch {
            self.error = "Could not load clips"
            appLog("Clips error: \(error.localizedDescription)")
        }
        isLoading = false
    }

    func toggleSelection(_ clipId: String) {
        guard let config else { return }
        if let index = selections.firstIndex(of: clipId) {
            selections.remove(at: index)
        } else if selections.count < config.voteCount {
            selections.append(clipId)
        }
    }

    func moveSelection(from source: IndexSet, to destination: Int) {
        selections.move(fromOffsets: source, toOffset: destination)
    }

    func moveSelectionUp(index: Int) {
        guard index > 0 else { return }
        selections.swapAt(index, index - 1)
    }

    func moveSelectionDown(index: Int) {
        guard index < selections.count - 1 else { return }
        selections.swapAt(index, index + 1)
    }

    var isRankedMode: Bool {
        guard let config else { return false }
        return config.votingMode == "ranked" || config.multiType == "ranked"
    }

    var canSubmit: Bool {
        guard let config else { return false }
        return selections.count == config.voteCount && !userHasVoted
    }

    func submitVote() async {
        guard let token, canSubmit else { return }
        isSubmitting = true
        do {
            let response = try await TwitchAuthService.shared.submitClipVote(token: token, rankings: selections)
            appLog("Vote submitted: \(response.message)")
            submitSuccess = true
            await fetchClips()
        } catch {
            self.error = "Failed to submit vote"
            appLog("Vote error: \(error.localizedDescription)")
        }
        isSubmitting = false
    }
}
