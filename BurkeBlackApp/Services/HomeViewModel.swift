import Foundation

@MainActor
class HomeViewModel: ObservableObject {
    @Published var isLive = false
    @Published var streamInfo: StreamInfo?
    @Published var announcements: [Announcement] = []
    @Published var stats: ChannelStats?
    @Published var isLoading = false
    @Published var error: String?

    func loadData() async {
        appLog("HomeVM: loading data")
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let homeData = try await APIService.shared.fetchHome()
            isLive = homeData.isLive
            streamInfo = homeData.stream
            announcements = homeData.announcements
            stats = homeData.stats
        } catch {
            self.error = error.localizedDescription
            appLog("HomeVM: load failed - " + error.localizedDescription)
        }
    }

    func refresh() async {
        await loadData()
    }
}
