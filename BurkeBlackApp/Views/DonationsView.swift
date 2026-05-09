import SwiftUI

struct DonationsView: View {
    let token: String
    @State private var donations: [Donation] = []
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let error {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if donations.isEmpty {
                ContentUnavailableView("No Donations", systemImage: "heart", description: Text("You haven't made any donations yet."))
            } else {
                List(donations) { donation in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(donation.formattedAmount)
                                .font(.headline)
                            Spacer()
                            Text(donation.formattedDate)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        if !donation.message.isEmpty {
                            Text(donation.message)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Donations")
        .navigationBarTitleDisplayMode(.inline)
        .task {
                appLog("DonationsView: loading")
            await loadDonations()
        }
    }

    private func loadDonations() async {
        do {
            donations = try await TwitchAuthService.shared.fetchDonations(token: token)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
