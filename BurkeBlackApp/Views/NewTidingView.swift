import SwiftUI
import PhotosUI
import UIKit

// MARK: - Mode

enum TidingEditorMode {
    case create
    case edit(existing: Tiding,
              isVisibleOnIos: Bool,
              isVisibleOnAndroid: Bool,
              isVisibleOnWebsite: Bool)

    var isEdit: Bool {
        if case .edit = self { return true } else { return false }
    }
}

// MARK: - View

struct NewTidingView: View {
    let mode: TidingEditorMode
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var bodyText: String
    @State private var bodySelection: NSRange = NSRange(location: 0, length: 0)
    @State private var sendPush: Bool = true
    @State private var visibleIos: Bool
    @State private var visibleAndroid: Bool
    @State private var visibleWebsite: Bool

    @State private var selectedTab: Int = 0  // 0 = Edit, 1 = Preview
    @State private var isSubmitting = false
    @State private var isUploadingImage = false
    @State private var showLinkSheet = false
    @State private var showPhotoPicker = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var snackbarMessage: String?

    init(mode: TidingEditorMode, onSaved: @escaping () -> Void) {
        self.mode = mode
        self.onSaved = onSaved
        switch mode {
        case .create:
            _title = State(initialValue: "")
            _bodyText = State(initialValue: "")
            _visibleIos = State(initialValue: true)
            _visibleAndroid = State(initialValue: true)
            _visibleWebsite = State(initialValue: true)
        case .edit(let existing, let ios, let android, let website):
            _title = State(initialValue: existing.title)
            _bodyText = State(initialValue: existing.body)
            _visibleIos = State(initialValue: ios)
            _visibleAndroid = State(initialValue: android)
            _visibleWebsite = State(initialValue: website)
        }
    }

    private var anyPlatformVisible: Bool { visibleIos || visibleAndroid || visibleWebsite }
    private var pushReachable: Bool { visibleIos || visibleAndroid }
    private var canSubmit: Bool {
        !isSubmitting &&
            !title.trimmingCharacters(in: .whitespaces).isEmpty &&
            !bodyText.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        titleField
                        tabRow
                        if selectedTab == 0 {
                            editorSection
                        } else {
                            previewSection
                        }
                        Divider().overlay(Color.white.opacity(0.1))
                        visibilitySection
                        if !mode.isEdit {
                            Divider().overlay(Color.white.opacity(0.1))
                            pushSection
                        }
                        submitButton
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                if let msg = snackbarMessage {
                    VStack {
                        Spacer()
                        Text(msg)
                            .font(.subheadline)
                            .padding(12)
                            .background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.white)
                            .padding(.bottom, 24)
                            .padding(.horizontal, 16)
                            .transition(.opacity)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    if snackbarMessage == msg { snackbarMessage = nil }
                                }
                            }
                    }
                }
            }
            .navigationTitle(mode.isEdit ? "Edit Tiding" : "New Tiding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .sheet(isPresented: $showLinkSheet) {
                LinkInsertSheet(currentSelection: selectedText) { displayText, url in
                    insertLink(displayText: displayText, url: url)
                }
            }
            .photosPicker(
                isPresented: $showPhotoPicker,
                selection: $photoPickerItem,
                matching: .images
            )
            .onChange(of: photoPickerItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    isUploadingImage = true
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        await uploadImage(data: data)
                    } else {
                        snackbarMessage = "Couldn't read selected image"
                    }
                    isUploadingImage = false
                    photoPickerItem = nil
                }
            }
        }
    }

    // MARK: - Sections

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Title").font(.caption).foregroundStyle(.white.opacity(0.6))
            TextField("", text: $title, prompt: Text("Title").foregroundStyle(.white.opacity(0.3)))
                .foregroundStyle(.white)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.15), lineWidth: 1))
                .onChange(of: title) { _, newValue in
                    if newValue.count > 255 { title = String(newValue.prefix(255)) }
                }
        }
    }

    private var tabRow: some View {
        HStack(spacing: 0) {
            tabButton("Edit", index: 0)
            tabButton("Preview", index: 1)
        }
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
    }

    private func tabButton(_ label: String, index: Int) -> some View {
        Button {
            selectedTab = index
        } label: {
            Text(label)
                .font(PirateTheme.font(size: 16))
                .foregroundStyle(selectedTab == index ? PirateTheme.accentColor : .white.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    Rectangle()
                        .fill(PirateTheme.accentColor.opacity(selectedTab == index ? 0.12 : 0))
                )
        }
        .buttonStyle(.plain)
    }

    private var editorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            markdownToolbar
            BodyTextEditor(text: $bodyText, selection: $bodySelection)
                .frame(minHeight: 280)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.15), lineWidth: 1))
                .onChange(of: bodyText) { _, newValue in
                    if newValue.count > 65000 { bodyText = String(newValue.prefix(65000)) }
                }
            Text("Tip: Tap the toolbar buttons to format. Use the image button to add a photo from your phone.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private var markdownToolbar: some View {
        HStack(spacing: 4) {
            toolbarButton(systemName: "bold", description: "Bold") {
                wrapSelection(prefix: "**", suffix: "**", placeholder: "bold")
            }
            toolbarButton(systemName: "italic", description: "Italic") {
                wrapSelection(prefix: "*", suffix: "*", placeholder: "italic")
            }
            toolbarButton(systemName: "textformat", description: "Heading") {
                prefixCurrentLine(with: "## ")
            }
            toolbarButton(systemName: "list.bullet", description: "List") {
                prefixCurrentLine(with: "- ")
            }
            toolbarButton(systemName: "link", description: "Link") {
                showLinkSheet = true
            }
            if isUploadingImage {
                ProgressView()
                    .tint(PirateTheme.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                Button {
                    showPhotoPicker = true
                } label: {
                    Image(systemName: "photo")
                        .foregroundStyle(PirateTheme.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .accessibilityLabel("Image")
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
    }

    private func toolbarButton(systemName: String, description: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .foregroundStyle(PirateTheme.accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .accessibilityLabel(description)
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if bodyText.isEmpty {
                HStack {
                    Spacer()
                    Text("Nothing to preview yet.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.4))
                    Spacer()
                }
                .frame(minHeight: 200)
            } else {
                MarkdownBodyView(markdown: bodyText)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
            }
        }
    }

    private var visibilitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Visibility").font(.headline).foregroundStyle(.white)
            Text("Choose which platforms see this tiding.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
            HStack(spacing: 16) {
                visibilityCheckbox("iOS", isOn: $visibleIos)
                visibilityCheckbox("Android", isOn: $visibleAndroid)
                visibilityCheckbox("Website", isOn: $visibleWebsite)
                Spacer()
            }
            if !mode.isEdit && sendPush && !pushReachable {
                Text("Push needs iOS or Android visibility to reach anyone.")
                    .font(.caption2)
                    .foregroundStyle(Color(red: 1.0, green: 0.7, blue: 0.28))
            }
        }
    }

    private func visibilityCheckbox(_ label: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isOn.wrappedValue ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isOn.wrappedValue ? PirateTheme.accentColor : .white.opacity(0.5))
                Text(label).foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
    }

    private var pushSection: some View {
        Toggle(isOn: $sendPush) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Send push notification")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Notifies users with Channel Tidings notifications enabled.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .tint(PirateTheme.accentColor)
    }

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            HStack {
                Spacer()
                if isSubmitting {
                    ProgressView().tint(.black)
                } else {
                    Text(mode.isEdit ? "Save Changes" : "Post Tiding")
                        .font(.headline)
                        .foregroundStyle(.black)
                }
                Spacer()
            }
            .padding(.vertical, 14)
            .background(canSubmit ? PirateTheme.accentColor : PirateTheme.accentColor.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!canSubmit)
    }

    // MARK: - Markdown helpers

    private var selectedText: String {
        let nsBody = bodyText as NSString
        let safe = clampedSelection()
        guard safe.length > 0 else { return "" }
        return nsBody.substring(with: safe)
    }

    private func wrapSelection(prefix: String, suffix: String, placeholder: String) {
        let nsBody = bodyText as NSString
        let safeRange = clampedSelection()
        let inserted: String
        let newSelection: NSRange
        if safeRange.length == 0 {
            inserted = "\(prefix)\(placeholder)\(suffix)"
            newSelection = NSRange(location: safeRange.location + prefix.count, length: placeholder.count)
        } else {
            let chunk = nsBody.substring(with: safeRange)
            inserted = "\(prefix)\(chunk)\(suffix)"
            newSelection = NSRange(location: safeRange.location + inserted.count, length: 0)
        }
        bodyText = nsBody.replacingCharacters(in: safeRange, with: inserted)
        bodySelection = newSelection
    }

    private func prefixCurrentLine(with prefix: String) {
        let nsBody = bodyText as NSString
        let safeRange = clampedSelection()
        let lineStart = nsBody.range(of: "\n", options: .backwards, range: NSRange(location: 0, length: safeRange.location)).location
        let insertAt = (lineStart == NSNotFound) ? 0 : lineStart + 1
        // Don't double-prefix
        let after = nsBody.substring(from: insertAt)
        if after.hasPrefix(prefix) { return }
        bodyText = nsBody.replacingCharacters(in: NSRange(location: insertAt, length: 0), with: prefix)
        bodySelection = NSRange(location: safeRange.location + prefix.count, length: 0)
    }

    private func insertAtCursor(_ text: String) {
        let nsBody = bodyText as NSString
        let safeRange = clampedSelection()
        let needsLeadingNewline = safeRange.location > 0 && nsBody.character(at: safeRange.location - 1) != 10
        let insertion = (needsLeadingNewline ? "\n" : "") + text + "\n"
        bodyText = nsBody.replacingCharacters(in: safeRange, with: insertion)
        bodySelection = NSRange(location: safeRange.location + insertion.count, length: 0)
    }

    private func insertLink(displayText: String, url: String) {
        let nsBody = bodyText as NSString
        let safeRange = clampedSelection()
        let markdown = "[\(displayText)](\(url))"
        bodyText = nsBody.replacingCharacters(in: safeRange, with: markdown)
        bodySelection = NSRange(location: safeRange.location + markdown.count, length: 0)
    }

    private func clampedSelection() -> NSRange {
        let length = (bodyText as NSString).length
        let loc = max(0, min(bodySelection.location, length))
        let len = max(0, min(bodySelection.length, length - loc))
        return NSRange(location: loc, length: len)
    }

    // MARK: - Image upload

    private func uploadImage(data: Data) async {
        guard let token = AccountViewModel.getBearerToken() else {
            snackbarMessage = "Not signed in"
            return
        }
        if data.count > 5 * 1024 * 1024 {
            snackbarMessage = "Image too large (max 5 MB)"
            return
        }
        guard let url = URL(string: "https://api.burkeblack.tv/app/mod/news/upload-image") else { return }
        let boundary = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        TwitchAuthService.addPlatformHeaders(&req)
        var bodyData = Data()
        bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
        bodyData.append("Content-Disposition: form-data; name=\"image\"; filename=\"upload.jpg\"\r\n".data(using: .utf8)!)
        bodyData.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        bodyData.append(data)
        bodyData.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = bodyData
        do {
            let (respData, response) = try await URLSession.shared.data(for: req)
            struct UploadResp: Codable {
                let success: Bool
                let data: ImageData?
                let error: String?
                struct ImageData: Codable { let url: String; let filename: String }
            }
            let decoded = try JSONDecoder().decode(UploadResp.self, from: respData)
            if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200,
               decoded.success, let imageUrl = decoded.data?.url {
                insertAtCursor("![image](\(imageUrl))")
            } else {
                snackbarMessage = decoded.error ?? "Image upload failed"
            }
        } catch {
            appLog("Tidings: image upload threw \(error.localizedDescription)")
            snackbarMessage = "Image upload failed"
        }
    }

    // MARK: - Submit

    private func submit() async {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty, !bodyText.isEmpty else {
            snackbarMessage = "Title and body are required"
            return
        }
        if !anyPlatformVisible {
            snackbarMessage = "Pick at least one platform to publish to"
            return
        }
        guard let token = AccountViewModel.getBearerToken() else {
            snackbarMessage = "Not signed in"
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }

        let path: String
        var payload: [String: Any] = [
            "subject": title.trimmingCharacters(in: .whitespaces),
            "body": bodyText,
            "is_visible_on_ios": visibleIos ? 1 : 0,
            "is_visible_on_android": visibleAndroid ? 1 : 0,
            "is_visible_on_website": visibleWebsite ? 1 : 0,
        ]
        switch mode {
        case .create:
            path = "/mod/news"
            payload["send_push"] = (sendPush && pushReachable) ? 1 : 0
        case .edit(let existing, _, _, _):
            path = "/mod/news/update"
            payload["id"] = existing.id
        }

        guard let url = URL(string: "https://api.burkeblack.tv/app\(path)") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        TwitchAuthService.addPlatformHeaders(&req)
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            struct Resp: Codable { let success: Bool; let error: String? }
            let decoded = try JSONDecoder().decode(Resp.self, from: data)
            if decoded.success {
                appLog("Tidings: \(mode.isEdit ? "updated" : "created") article")
                onSaved()
                dismiss()
            } else {
                snackbarMessage = decoded.error ?? "Save failed"
            }
        } catch {
            appLog("Tidings: save error \(error.localizedDescription)")
            snackbarMessage = "Couldn't reach the ship's log"
        }
    }
}

// MARK: - Body editor (UITextView wrapper for cursor / selection access)

private struct BodyTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var selection: NSRange

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.backgroundColor = .clear
        tv.textColor = UIColor.white.withAlphaComponent(0.9)
        tv.font = UIFont.systemFont(ofSize: 15)
        tv.tintColor = UIColor(red: 1, green: 215.0/255, blue: 0, alpha: 1)
        tv.autocapitalizationType = .sentences
        tv.autocorrectionType = .yes
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        if tv.text != text {
            tv.text = text
        }
        // Push selection to the view only if it differs from what we last got from the view.
        if context.coordinator.lastReportedSelection != selection {
            tv.selectedRange = selection
            context.coordinator.lastReportedSelection = selection
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: BodyTextEditor
        var lastReportedSelection: NSRange = NSRange(location: 0, length: 0)

        init(_ parent: BodyTextEditor) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            lastReportedSelection = textView.selectedRange
            parent.selection = textView.selectedRange
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            lastReportedSelection = textView.selectedRange
            parent.selection = textView.selectedRange
        }
    }
}

// MARK: - Link insert sheet

private struct LinkInsertSheet: View {
    let currentSelection: String
    let onInsert: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var displayText: String
    @State private var url: String = ""

    init(currentSelection: String, onInsert: @escaping (String, String) -> Void) {
        self.currentSelection = currentSelection
        self.onInsert = onInsert
        _displayText = State(initialValue: currentSelection)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Display text") {
                    TextField("Optional — defaults to URL", text: $displayText)
                }
                Section("URL") {
                    TextField("https://...", text: $url)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
            }
            .navigationTitle("Insert Link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Insert") {
                        let text = displayText.isEmpty ? url : displayText
                        onInsert(text, url)
                        dismiss()
                    }
                    .disabled(url.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
