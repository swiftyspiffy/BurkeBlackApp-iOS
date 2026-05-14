import SwiftUI

struct SoundbytePick {
    let soundbyteId: Int
    let name: String
    let announce: Bool
}

struct OverlayPick {
    let imageId: Int?
    let gifToken: String?
    let name: String
    let mode: String
    let duration: Double
    let xPercent: Double
    let yPercent: Double
    let credit: Int
}

struct StreamInteractionsView: View {
    let token: String
    let username: String
    let userFilter: String
    var onCreditsChanged: ((Int) -> Void)?

    @State private var soundbytePick: SoundbytePick?
    @State private var overlayPick: OverlayPick?
    @State private var showSoundbytes = false
    @State private var showOverlay = false
    @State private var isSending = false
    @State private var sendResultMessage: String?
    @State private var showSendResult = false
    @State private var sendErrorMessage: String?
    @State private var showSendError = false
    @State private var streamIsLive = true
    @StateObject private var soundbytesVM: SoundbytesViewModel

    init(token: String, username: String, userFilter: String = "all", onCreditsChanged: ((Int) -> Void)? = nil) {
        self.token = token
        self.username = username
        self.userFilter = userFilter
        self.onCreditsChanged = onCreditsChanged
        _soundbytesVM = StateObject(wrappedValue: SoundbytesViewModel(token: token, onCreditsChanged: onCreditsChanged))
    }

    private var interactionsDisabled: Bool {
        soundbytesVM.soundbytesDisabled && !AppSettings.shared.debugOverrideInteractionsDisabled
    }

    private var totalCost: Int {
        (soundbytePick != nil ? 1 : 0) + (overlayPick?.credit ?? 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 12) {
                    if !streamIsLive {
                        HStack(spacing: 8) {
                            Image(systemName: "tv.slash")
                                .foregroundStyle(.red)
                            Text("Stream is currently offline")
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    if interactionsDisabled {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Stream interactions are currently disabled")
                                .font(.subheadline)
                                .foregroundStyle(.orange)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(PirateTheme.accentColor)
                        Text("Interaction Credits:")
                            .font(.subheadline)
                        Text(StatFormatter.integer(soundbytesVM.credits))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(PirateTheme.accentColor)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    InteractionCard(
                        icon: "music.note.list",
                        title: "Soundbytes",
                        subtitle: soundbytePick.map { "Selected: \($0.name) (\($0.announce ? "Announced" : "Quiet"))" } ?? "Play a sound on stream",
                        isSelected: soundbytePick != nil,
                        onTap: { showSoundbytes = true },
                        onDeselect: { soundbytePick = nil }
                    )

                    InteractionCard(
                        icon: "photo.fill",
                        title: "Image / GIF",
                        subtitle: overlayPick.map { "Selected: \($0.name) (\($0.mode.capitalized))" } ?? "Show an image or GIF on stream",
                        isSelected: overlayPick != nil,
                        onTap: { showOverlay = true },
                        onDeselect: { overlayPick = nil }
                    )

                    HStack {
                        Image(systemName: "bag.fill")
                            .foregroundStyle(PirateTheme.accentColor)
                        Text("Total Cost")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(totalCost) credit\(totalCost == 1 ? "" : "s")")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(totalCost > 0 ? PirateTheme.accentColor : .secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemGray6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(PirateTheme.accentColor.opacity(totalCost > 0 ? 0.3 : 0), lineWidth: 1)
                            )
                    )
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }

            VStack(spacing: 0) {
                Divider()
                Button {
                    Task { await sendInteractions() }
                } label: {
                    HStack(spacing: 8) {
                        if isSending {
                            ProgressView()
                                .tint(.white)
                        } else if !streamIsLive {
                            Image(systemName: "tv.slash")
                            Text("Stream is Offline")
                                .fontWeight(.semibold)
                        } else if interactionsDisabled {
                            Image(systemName: "nosign")
                            Text("Stream Interactions Disabled")
                                .fontWeight(.semibold)
                        } else {
                            Image(systemName: "paperplane.fill")
                            Text("Send to Stream!")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        totalCost > 0 && streamIsLive && !interactionsDisabled && !isSending
                            ? Color.green
                            : Color.gray.opacity(0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(totalCost == 0 || !streamIsLive || interactionsDisabled || isSending)
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .background(Color(.systemBackground))
        }
        .navigationTitle("Stream Interactions")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            async let loadSoundbytes: () = soundbytesVM.initialLoad()
            async let checkStream = TwitchAuthService.shared.fetchStreamStatus()
            _ = await loadSoundbytes
            let status = await checkStream
            streamIsLive = status.isLive
        }
        .fullScreenCover(isPresented: $showSoundbytes) {
            NavigationStack {
                SoundbytesContentView(viewModel: soundbytesVM, onSelect: { pick in
                    soundbytePick = pick
                    showSoundbytes = false
                })
                .navigationTitle("Soundbytes")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { showSoundbytes = false }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showOverlay) {
            OverlayImagesView(token: token, username: username, userFilter: userFilter) { pick in
                overlayPick = pick
                showOverlay = false
            }
        }
        .alert("Sent!", isPresented: $showSendResult) {
            Button("OK") {}
        } message: {
            Text(sendResultMessage ?? "")
        }
        .alert("Error", isPresented: $showSendError) {
            Button("OK") {}
        } message: {
            Text(sendErrorMessage ?? "")
        }
    }

    private func sendInteractions() async {
        isSending = true
        defer { isSending = false }

        var messages: [String] = []
        var latestCredits: Int?

        if let sb = soundbytePick {
            do {
                let result = try await TwitchAuthService.shared.sendSoundbyte(
                    token: token, soundbyteId: sb.soundbyteId, announce: sb.announce
                )
                messages.append(result.message)
                latestCredits = result.creditsRemaining
                appLog("StreamInteractions: soundbyte sent - \(result.soundbyteName)")
            } catch {
                appLog("StreamInteractions: soundbyte send failed - \(error.localizedDescription)")
                sendErrorMessage = error.localizedDescription
                showSendError = true
                return
            }
        }

        if let overlay = overlayPick {
            do {
                let body = OverlayTriggerBody(
                    imageId: overlay.imageId,
                    gifToken: overlay.gifToken,
                    mode: overlay.mode,
                    duration: overlay.duration,
                    username: username,
                    source: "app_ios",
                    xPercent: overlay.xPercent,
                    yPercent: overlay.yPercent,
                    test: AppSettings.shared.debugUseTestOverlay ? true : nil
                )
                let result = try await TwitchAuthService.shared.triggerOverlay(token: token, body: body)
                messages.append(result.message)
                latestCredits = result.creditsRemaining
                appLog("StreamInteractions: overlay triggered - \(result.message)")
            } catch {
                appLog("StreamInteractions: overlay trigger failed - \(error.localizedDescription)")
                sendErrorMessage = error.localizedDescription
                showSendError = true
                return
            }
        }

        if let credits = latestCredits {
            soundbytesVM.credits = credits
            onCreditsChanged?(credits)
        }

        soundbytePick = nil
        overlayPick = nil
        sendResultMessage = messages.joined(separator: "\n")
        showSendResult = true
    }
}

// MARK: - Interaction Card

private struct InteractionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let onTap: () -> Void
    let onDeselect: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                Button {
                    if isSelected { onDeselect() }
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isSelected ? PirateTheme.accentColor : .secondary)
                        .frame(width: 48)
                }
                .disabled(!isSelected)

                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(PirateTheme.accentColor)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(isSelected ? PirateTheme.accentColor : .secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.trailing, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? PirateTheme.accentColor.opacity(0.4) : Color.clear, lineWidth: 1.5)
                )
        )
        .buttonStyle(.plain)
    }
}
