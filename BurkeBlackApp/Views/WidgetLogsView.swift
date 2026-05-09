import SwiftUI

struct WidgetLogsView: View {
    @State private var logs = ""
    @State private var showShareSheet = false

    var body: some View {
        ScrollView {
            Text(logs.isEmpty ? "No widget logs yet" : logs)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .textSelection(.enabled)
        }
        .background(Color.black)
        .navigationTitle("Widget Logs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    Button {
                        UserDefaults(suiteName: "group.com.swiftyspiffy.BurkeBlackApp")?.removeObject(forKey: "widget.logs")
                        logs = ""
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(logs.isEmpty)

                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(logs.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            WidgetLogsShareSheet(items: [logs])
        }
        .onAppear {
            loadLogs()
        }
    }

    private func loadLogs() {
        guard let defaults = UserDefaults(suiteName: "group.com.swiftyspiffy.BurkeBlackApp"),
              let entries = defaults.stringArray(forKey: "widget.logs") else {
            logs = ""
            return
        }
        logs = entries.joined(separator: "\n")
    }
}

private struct WidgetLogsShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
