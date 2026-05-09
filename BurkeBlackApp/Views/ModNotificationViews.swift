import SwiftUI


// MARK: - Send Mod Notification

struct ModSendNotificationView: View {
    @ObservedObject private var settings = AppSettings.shared
    let token: String
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var message = ""
    @State private var url = ""
    @State private var isSending = false
    @State private var showConfirm = false
    @State private var showResult = false
    @State private var resultMessage = ""

    var body: some View {
        Form {
            Section("Notification") {
                TextField("Title", text: $title)
                TextEditor(text: $message)
                    .frame(minHeight: 100)
                TextField("Link (optional)", text: $url)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
            }

            Section {
                Button {
                    showConfirm = true
                } label: {
                    HStack {
                        Spacer()
                        if isSending { ProgressView() }
                        else { Text("Send to All Pirates").fontWeight(.semibold) }
                        Spacer()
                    }
                }
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || message.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
            }
        }
        .navigationTitle("Send Announcement")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Send this notification to all users?", isPresented: $showConfirm, titleVisibility: .visible) {
            Button("Send Now") { Task { await send() } }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Result", isPresented: $showResult) {
            Button("OK") { if resultMessage.contains("Sent") { dismiss() } }
        } message: {
            Text(resultMessage)
        }
    }

    private func send() async {
        isSending = true
        defer { isSending = false }
        appLog("ModNotification: sending mod announcement")

        guard let reqUrl = URL(string: "https://api.burkeblack.tv/app/mod/send-notification") else { return }

        var request = URLRequest(url: reqUrl)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        TwitchAuthService.addPlatformHeaders(&request)

        let body: [String: String] = [
            "title": title.trimmingCharacters(in: .whitespaces),
            "message": message.trimmingCharacters(in: .whitespaces),
            "url": url.trimmingCharacters(in: .whitespaces),
        ]
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0

            if code == 200 {
                if let json = try? JSONDecoder().decode(APISuccessResponse<SendNotificationResult>.self, from: data), let result = json.data {
                    resultMessage = "Sent to \(result.ios_sent + result.android_sent) devices"
                } else {
                    resultMessage = "Sent!"
                }
            } else {
                if let json = try? JSONDecoder().decode(APIErrorOrSuccess.self, from: data) {
                    resultMessage = json.error ?? "Failed"
                } else {
                    resultMessage = "Error (\(code))"
                }
            }
            showResult = true
        } catch {
            resultMessage = error.localizedDescription
            showResult = true
        }
    }
}

// MARK: - Notification History

struct ModNotificationHistoryView: View {
    let token: String
    @State private var history: [NotificationHistoryItem] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                VStack { Spacer(); ProgressView(); Spacer() }
            } else if history.isEmpty {
                VStack { Spacer(); Text("No notifications sent yet").foregroundStyle(.secondary); Spacer() }
            } else {
                List(history) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.typeLabel)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.orange.opacity(0.15))
                                .clipShape(Capsule())
                            Spacer()
                            Text(item.timeAgo)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text(item.title)
                            .font(.headline)
                        Text(item.message)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        HStack(spacing: 8) {
                            if let sender = item.sent_by_username {
                                Text("by \(sender)").font(.caption2).foregroundStyle(.secondary)
                            }
                            Text("iOS: \(item.ios_sent)").font(.caption2).foregroundStyle(.secondary)
                            Text("Android: \(item.android_sent)").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Notification History")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { Task { await load() } }
    }

    private func load() async {
        guard let url = URL(string: "https://api.burkeblack.tv/app/mod/notification-history?limit=50") else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        TwitchAuthService.addPlatformHeaders(&request)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONDecoder().decode(APISuccessResponse<HistoryResponse>.self, from: data), let result = json.data {
                history = result.history
            }
        } catch {
            appLog("ModNotificationHistory: load failed")
        }
        isLoading = false
    }
}
