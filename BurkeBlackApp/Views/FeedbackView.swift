import SwiftUI
import PhotosUI

struct FeedbackView: View {
    let username: String?
    let userId: String?

    @ObservedObject private var settings = AppSettings.shared
    @State private var selectedTarget = "Stream"
    @State private var message = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var attachedImages: [UIImage] = []
    @State private var includeDiagnostics = false
    @Environment(\.dismiss) private var dismiss

    private let targets = ["Stream", "App", "Website", "Extension", "General"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Message in a Bottle")
                        .font(PirateTheme.font(size: 28))
                        .foregroundStyle(PirateTheme.accentColor)
                    Text("Send word to the ship\u{2019}s crew")
                        .font(PirateTheme.font(size: 15))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.top, 8)

                // From card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("From")
                            .font(PirateTheme.font(size: 15))
                            .foregroundStyle(.white.opacity(0.4))
                        Spacer()
                        Text(username ?? "Anonymous")
                            .font(PirateTheme.font(size: 15))
                            .foregroundStyle(PirateTheme.accentColor)
                    }

                    Divider().overlay(PirateTheme.accentColor.opacity(0.15))

                    HStack {
                        Text("Topic")
                            .font(PirateTheme.font(size: 15))
                            .foregroundStyle(.white.opacity(0.4))
                        Spacer()
                        Menu {
                            ForEach(targets, id: \.self) { target in
                                Button(target) { selectedTarget = target }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(selectedTarget)
                                    .font(PirateTheme.font(size: 15))
                                    .foregroundStyle(PirateTheme.accentColor)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                                    .foregroundStyle(PirateTheme.accentColor.opacity(0.6))
                            }
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AnyShapeStyle(PirateTheme.cardGradient))
                )

                // Message section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Yer Message")
                        .font(PirateTheme.font(size: 16))
                        .foregroundStyle(PirateTheme.accentColor.opacity(0.7))

                    TextEditor(text: $message)
                        .frame(minHeight: 150)
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.05))
                        )
                        .font(PirateTheme.font(size: 14))
                }

                // Attachments section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Attachments")
                        .font(PirateTheme.font(size: 16))
                        .foregroundStyle(PirateTheme.accentColor.opacity(0.7))

                    if !attachedImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(attachedImages.indices, id: \.self) { index in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: attachedImages[index])
                                            .resizable().scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        Button {
                                            attachedImages.remove(at: index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.white, .red).font(.caption)
                                        }.offset(x: 4, y: -4)
                                    }
                                }
                            }
                        }
                    }

                    PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 5, matching: .images) {
                        HStack(spacing: 10) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.title3)
                                .foregroundStyle(PirateTheme.accentColor)
                                .frame(width: 36, height: 36)
                                .background(PirateTheme.iconBgColor)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            Text("Add Images")
                                .font(PirateTheme.font(size: 15))
                                .foregroundStyle(.white)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.05))
                        )
                    }
                    .onChange(of: selectedPhotos) { _, newItems in
                        Task {
                            attachedImages = []
                            for item in newItems {
                                if let data = try? await item.loadTransferable(type: Data.self),
                                   let image = UIImage(data: data) {
                                    attachedImages.append(image)
                                }
                            }
                        }
                    }
                }

                // Ship's Log toggle
                HStack(spacing: 14) {
                    Toggle(isOn: $includeDiagnostics) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Include Ship\u{2019}s Log")
                                .font(PirateTheme.font(size: 15))
                                .foregroundStyle(.white)
                            Text("May include identifying details like Twitch username and IP address. These logs will be used to help fix app issues.")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                    .tint(PirateTheme.accentColor)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.05))
                )

                // Submit button
                Button {
                    Task { await submit() }
                } label: {
                    HStack(spacing: 8) {
                        if isSubmitting {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.body)
                            Text("Cast into the Sea")
                                .font(PirateTheme.font(size: 18))
                        }
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(PirateTheme.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isSubmitting || (message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachedImages.isEmpty && !includeDiagnostics))
                .opacity((isSubmitting || (message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachedImages.isEmpty && !includeDiagnostics)) ? 0.5 : 1.0)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .alert("Sent!", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        } message: { Text("Thank you for your feedback!") }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: { Text(errorMessage) }
    }

    private func submit() async {
        isSubmitting = true
        appLog("Feedback submission: topic=\(selectedTarget) diagnostics=\(includeDiagnostics) images=\(attachedImages.count)")
        defer { isSubmitting = false }

        guard let url = URL(string: "https://api.burkeblack.tv/app/feedback") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        TwitchAuthService.addPlatformHeaders(&request)

        var imageStrings: [String]? = nil
        if !attachedImages.isEmpty {
            imageStrings = attachedImages.compactMap {
                $0.jpegData(compressionQuality: 0.6)?.base64EncodedString()
            }
        }

        var diagnostics: String? = nil
        if includeDiagnostics {
            diagnostics = await AppLogger.shared.getDiagnostics(username: username)
        }

        struct FeedbackBody: Encodable {
            let username: String
            let user_id: String?
            let target: String
            let message: String
            let images: [String]?
            let diagnostics: String?
        }

        request.httpBody = try? JSONEncoder().encode(FeedbackBody(
            username: username ?? "Anonymous",
            user_id: userId,
            target: selectedTarget,
            message: message.trimmingCharacters(in: .whitespacesAndNewlines),
            images: imageStrings,
            diagnostics: diagnostics
        ))

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return }
            if httpResponse.statusCode == 200 {
                appLog("Feedback submitted: \(selectedTarget)")
                showSuccess = true
            } else {
                if let decoded = try? JSONDecoder().decode(APIErrorOrSuccess.self, from: data) {
                    errorMessage = decoded.error ?? "Unknown error"
                } else {
                    errorMessage = "Server error (\(httpResponse.statusCode))"
                }
                showError = true
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
