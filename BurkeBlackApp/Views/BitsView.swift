import SwiftUI

private func cheerImage(for bits: Int) -> String {
    if bits >= 10000 { return "cheer_10000" }
    if bits >= 5000 { return "cheer_5000" }
    if bits >= 100 { return "cheer_100" }
    return "cheer_1"
}

private func cheerColor(for bits: Int) -> Color {
    if bits >= 10000 { return .red }
    if bits >= 5000 { return .blue }
    if bits >= 100 { return .purple }
    return .gray
}

struct BitsView: View {
    let token: String
    @State private var bits: [BitCheer] = []
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let error {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if bits.isEmpty {
                ContentUnavailableView("No Bits", systemImage: "star", description: Text("You haven't cheered any bits yet."))
            } else {
                List(bits) { cheer in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            HStack(spacing: 4) {
                                Image(cheerImage(for: cheer.bits))
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                                Text(StatFormatter.integer(cheer.bits))
                                    .font(.headline)
                                    .foregroundStyle(cheerColor(for: cheer.bits))
                            }
                            Spacer()
                            Text(cheer.formattedDate)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        if !cheer.message.isEmpty {
                            Text(cheer.message)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Bits Cheered")
        .navigationBarTitleDisplayMode(.inline)
        .task {
                appLog("BitsView: loading")
            do {
                bits = try await TwitchAuthService.shared.fetchBits(token: token)
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}
