import SwiftUI

struct DebugLogsView: View {
    @State private var logs = ""
    @State private var showShareSheet = false

    var body: some View {
        ScrollView {
            Text(logs)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .textSelection(.enabled)
        }
        .background(Color.black)
        .navigationTitle("Debug Logs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(logs.isEmpty)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [logs])
        }
        .task {
            logs = await AppLogger.shared.getAllLogs()
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
