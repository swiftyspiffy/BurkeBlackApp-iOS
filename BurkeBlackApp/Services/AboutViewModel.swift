import Foundation

@MainActor
class AboutViewModel: ObservableObject {
    @Published var bio: String?
    @Published var avatarURL: URL?

    func loadProfile() async {
        appLog("AboutVM: \(#function)")
        do {
            let profile = try await APIService.shared.fetchProfile()
            bio = profile.bio
            if let urlString = profile.avatarURL {
                avatarURL = URL(string: urlString)
            }
        } catch {
            // Silently fail - views handle empty state
        }
    }
}
