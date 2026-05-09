import SwiftUI

private let pirateDark = Color(red: 0x48/255, green: 0x29/255, blue: 0x34/255)

struct HomeView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var deepLink = DeepLinkManager.shared
    @State private var startDate = Date.now
    @State private var streamStatus: StreamStatus?
    @State private var livePulse = false
    @State private var showAccount = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Glow animation layer
                TimelineView(.animation) { timeline in
                    let elapsed = timeline.date.timeIntervalSince(startDate)
                    GlowContent(elapsed: elapsed)
                }

                // Static content on top (not inside TimelineView)
                VStack {
                    StatusBar(streamStatus: streamStatus, livePulse: livePulse)
                        .frame(minHeight: 40)
                        .padding(.top, 10)

                    Spacer()

                    // Profile image - tap to open Twitch stream
                    Link(destination: URL(string: "https://twitch.tv/burkeblack")!) {
                        Image("burkeblack_profile")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 260, height: 260)
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(PirateTheme.accentColor.opacity(0.6), lineWidth: 2)
                            )
                    }

                    Text("The Dirty Skull")
                        .font(PirateTheme.font(size: 38))
                        .foregroundStyle(.white)
                        .padding(.top, 16)

                    HStack(spacing: 0) {
                        Text("Home of the Pirates on ")
                            .foregroundStyle(.gray)
                        Link("Twitch", destination: URL(string: "https://twitch.tv/burkeblack")!)
                            .foregroundStyle(.purple)
                            .shadow(color: .purple.opacity(0.6), radius: 6)
                        Text(" and ")
                            .foregroundStyle(.gray)
                        Link("YouTube", destination: URL(string: "https://youtube.com/burkeblack")!)
                            .foregroundStyle(.red)
                            .shadow(color: .red.opacity(0.6), radius: 6)
                        Text("!")
                            .foregroundStyle(.gray)
                    }
                    .font(PirateTheme.font(size: 16))

                    Button { showAccount = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "person.bust")
                                .font(.body)
                            Text("Captain's Quarters")
                                .font(PirateTheme.font(size: 18))
                        }
                        .foregroundStyle(PirateTheme.accentColor)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(PirateTheme.accentColor.opacity(0.15))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(PirateTheme.accentColor.opacity(0.4), lineWidth: 1))
                    }
                    .padding(.top, 16)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: $showAccount) {
                NavigationStack {
                    AccountView()
                        .navigationTitle("Captain's Quarters")
                        .navigationBarTitleDisplayMode(.inline)
                        .navigationBarHidden(false)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { showAccount = false }
                            }
                        }
                }
            }
            .onChange(of: deepLink.navigateToAccount) { _, shouldNavigate in
                if shouldNavigate {
                    showAccount = true
                    deepLink.navigateToAccount = false
                }
            }
            .task { await checkStreamStatus() }
            .onAppear {
                appLog("Home: view appeared")
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                    livePulse = true
                }
            }
        }
    }

    private func checkStreamStatus() async {
        streamStatus = await TwitchAuthService.shared.fetchStreamStatus()
        appLog("Stream status: \(streamStatus?.isLive == true ? "LIVE" : "offline")")
    }
}

// MARK: - Glow Animation (inside TimelineView)

private struct GlowContent: View {
    let elapsed: TimeInterval
    private var rotationAngle: Double { elapsed / 6 * 360 }
    private var pulseScale: Double { 1.0 + 0.06 * sin(elapsed * .pi / 3) }
    private var pulseScaleInverse: Double { 1.0 - 0.06 * sin(elapsed * .pi / 3) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Circle()
                .fill(
                    AngularGradient(
                        colors: [PirateTheme.accentColor.opacity(0.8), pirateDark.opacity(0.4), PirateTheme.accentColor.opacity(0.1), pirateDark.opacity(0.4), PirateTheme.accentColor.opacity(0.8)],
                        center: .center, angle: .degrees(rotationAngle)
                    )
                )
                .frame(width: 310, height: 310)
                .blur(radius: 25)
                .scaleEffect(pulseScale)

            Circle()
                .fill(
                    AngularGradient(
                        colors: [pirateDark.opacity(0.6), .clear, PirateTheme.accentColor.opacity(0.7), .clear, pirateDark.opacity(0.6)],
                        center: .center, angle: .degrees(-rotationAngle * 0.7)
                    )
                )
                .frame(width: 330, height: 330)
                .blur(radius: 40)
                .scaleEffect(pulseScaleInverse)
        }
    }
}

// MARK: - Status Bar (outside TimelineView)

private struct StatusBar: View {
    let streamStatus: StreamStatus?
    let livePulse: Bool

    var body: some View {
        Group {
            if let status = streamStatus, status.isLive {
                Link(destination: URL(string: "https://twitch.tv/burkeblack")!) {
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Circle().fill(.red).frame(width: 8, height: 8)
                                .scaleEffect(livePulse ? 1.2 : 0.8)
                            Text("LIVE").font(.caption).fontWeight(.black).foregroundStyle(.red)
                        }
                        if let title = status.title {
                            Text(title).font(.caption2).foregroundStyle(.white.opacity(0.8)).lineLimit(1)
                        }
                        HStack(spacing: 12) {
                            if let game = status.gameName {
                                Text(game).font(.caption2).foregroundStyle(.gray)
                            }
                            if let viewers = status.viewerCount {
                                HStack(spacing: 3) {
                                    Image(systemName: "eye.fill").font(.caption2)
                                    Text(StatFormatter.integer(viewers)).font(.caption2)
                                }.foregroundStyle(.gray)
                            }
                        }
                    }.padding(.horizontal)
                }
            } else {
                VStack(spacing: 6) {
                    Link(destination: URL(string: "https://twitch.tv/burkeblack")!) {
                        HStack(spacing: 6) {
                            Circle().fill(.gray.opacity(0.5)).frame(width: 8, height: 8)
                            Text("Stream Offline").font(.caption).foregroundStyle(.gray)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(.white.opacity(0.05)).clipShape(Capsule())
                    }
                    StreamCountdownView()
                }
            }
        }
    }
}

// MARK: - Countdown (outside TimelineView, state persists)

struct StreamCountdownView: View {
    @State private var now = Date()
    @State private var streamJustStarted = false
    @State private var isCheckingLive = false
    @State private var confirmedLive = false
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var eastern: TimeZone { TimeZone(identifier: "America/New_York")! }

    private var nextStream: Date? {
        let cal = Calendar.current
        var components = cal.dateComponents(in: eastern, from: now)

        for dayOffset in 0..<8 {
            var check = components
            check.hour = 22; check.minute = 0; check.second = 0
            if dayOffset > 0 || (components.hour ?? 0) >= 22 {
                check.day = (check.day ?? 0) + (dayOffset == 0 ? 1 : dayOffset)
            }
            if let date = cal.date(from: check) {
                let weekday = cal.component(.weekday, from: date)
                if weekday != 1 && date > now { return date }
            }
        }
        return nil
    }

    private var countdownText: String? {
        guard let next = nextStream else { return nil }
        let diff = next.timeIntervalSince(now)
        if diff <= 0 { return nil }
        let h = Int(diff) / 3600, m = (Int(diff) % 3600) / 60, s = Int(diff) % 60
        return h > 0 ? String(format: "%dh %02dm %02ds", h, m, s) : String(format: "%02dm %02ds", m, s)
    }

    private var isStreamTime: Bool {
        guard let next = nextStream else { return true }
        return next.timeIntervalSince(now) <= 0
    }

    /// Check if we're in the stream window (10PM - 6AM EST)
    private var isInStreamWindow: Bool {
        let cal = Calendar.current
        let components = cal.dateComponents(in: eastern, from: now)
        let hour = components.hour ?? 0
        let weekday = components.weekday ?? 1
        // Sunday = 1, no stream. Window: 10PM (22) to 6AM (6)
        if weekday == 1 { return false }
        // After 10PM same day, or before 6AM next day (Mon morning after Sun has no stream)
        if hour >= 22 { return true }
        if hour < 6 {
            // Check if yesterday was Sunday
            if weekday == 2 { return false } // Monday before 6AM = after Sunday = no stream
            return true
        }
        return false
    }

    var body: some View {
        Group {
            if confirmedLive {
                Link(destination: URL(string: "https://twitch.tv/burkeblack")!) {
                    HStack(spacing: 8) {
                        Circle().fill(.red).frame(width: 8, height: 8)
                        Text("BurkeBlack is LIVE!")
                            .font(.caption).fontWeight(.bold)
                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(.red.opacity(0.3))
                    .clipShape(Capsule())
                }
                .transition(.scale.combined(with: .opacity))
            } else if streamJustStarted || (isStreamTime && !isCheckingLive) {
                Link(destination: URL(string: "https://twitch.tv/burkeblack")!) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill").font(.caption2)
                        Text("Stream should be starting!").font(.caption).fontWeight(.medium)
                    }.foregroundStyle(PirateTheme.accentColor)
                }
                .transition(.scale.combined(with: .opacity))
            } else if isCheckingLive {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini)
                    Text("Checking stream...").font(.caption2).foregroundStyle(.gray)
                }
            } else if let text = countdownText {
                Text("Next stream in \(text)")
                    .font(.caption2).foregroundStyle(.gray.opacity(0.6)).monospacedDigit()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: isStreamTime)
        .animation(.easeInOut(duration: 0.5), value: confirmedLive)
        .animation(.easeInOut(duration: 0.5), value: streamJustStarted)
        .onReceive(timer) { _ in
            let wasStreamTime = isStreamTime
            now = Date()
            // Countdown just hit zero
            if !wasStreamTime && isStreamTime && !streamJustStarted {
                withAnimation {
                    streamJustStarted = true
                }
                Task { await checkIfLive() }
            }
        }
        .task {
            // On first load, if we're in the stream window, check if live
            if isInStreamWindow || isStreamTime {
                await checkIfLive()
            }
        }
    }

    private func checkIfLive() async {
        appLog("Countdown check: verifying if stream is live")
        isCheckingLive = true
        let status = await TwitchAuthService.shared.fetchStreamStatus()
        withAnimation(.easeInOut(duration: 0.5)) {
            confirmedLive = status.isLive
            appLog("Countdown live check result: \(status.isLive)")
            isCheckingLive = false
        }
    }
}

#Preview { HomeView() }
