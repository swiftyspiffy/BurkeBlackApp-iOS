import SwiftUI


struct GiveawayPopupView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject var wsManager: GiveawayWebSocketManager
    @State private var isActionLoading = false
    @State private var actionCooldown = false
    @State private var confettiParticles: [ConfettiParticle] = []
    @State private var showConfetti = false
    @State private var now = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @State private var appeared = false

    var body: some View {
        if let giveaway = wsManager.activeGiveaway, !wsManager.isDismissedToMini {
            ZStack {
                // Confetti layer
                if showConfetti {
                    ForEach(confettiParticles) { particle in
                        Circle()
                            .fill(particle.color)
                            .frame(width: particle.size, height: particle.size)
                            .position(particle.position)
                            .opacity(particle.opacity)
                    }
                    .allowsHitTesting(false)
                }

                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 16) {
                        // Header
                        HStack {
                            Image(systemName: headerIcon(giveaway.phase))
                                .foregroundStyle(headerColor(giveaway.phase))
                            Text(phaseTitle(giveaway.phase))
                                .font(.headline)
                                .fontWeight(.bold)
                            Spacer()
                            // Minimize button
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    if giveaway.phase == .claimed {
                                        wsManager.dismissGiveaway()
                                        appLog("Giveaway: dismissed")
                                        showConfetti = false
                                    } else {
                                        wsManager.minimizeGiveaway()
                                        appLog("Giveaway: minimized")
                                    }
                                    appeared = false
                                }
                            } label: {
                                Image(systemName: giveaway.phase == .claimed ? "xmark.circle.fill" : "minus.circle.fill")
                                    .foregroundStyle(.gray)
                                    .font(.title3)
                            }
                        }

                        // Giveaway info
                        VStack(spacing: 8) {
                            HStack {
                                Text("Giveaway").font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Text(giveaway.name).font(.body).fontWeight(.semibold)
                            }
                            HStack {
                                Text("From").font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Text(giveaway.donator).font(.body)
                            }
                            if let entries = giveaway.totalEntries {
                                HStack {
                                    Text("Entries").font(.caption).foregroundStyle(.secondary)
                                    Spacer()
                                    Text(entries).font(.body).fontWeight(.semibold).foregroundStyle(PirateTheme.accentColor)
                                }
                            }
                            if let remaining = currentTimeRemaining(giveaway), giveaway.phase == .entry {
                                HStack {
                                    Text("Time Left").font(.caption).foregroundStyle(.secondary)
                                    Spacer()
                                    Text(formatRemaining(remaining))
                                        .font(.body).fontWeight(.bold).monospacedDigit()
                                        .foregroundStyle(remaining < 60 ? .red : .primary)
                                }
                            }
                            if let winner = giveaway.winner {
                                HStack {
                                    Text("Winner").font(.caption).foregroundStyle(.secondary)
                                    Spacer()
                                    HStack(spacing: 4) {
                                        Image(systemName: "trophy.fill").font(.caption).foregroundStyle(.yellow)
                                        Text(winner).font(.body).fontWeight(.bold).foregroundStyle(.green)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        // Action button
                        if giveaway.phase == .entry {
                            Button {
                                Task { await handleAction(giveaway) }
                            } label: {
                                HStack {
                                    Spacer()
                                    if isActionLoading {
                                        ProgressView().tint(.white)
                                    } else {
                                        Image(systemName: giveaway.isEntered ? "xmark" : "checkmark")
                                        Text(giveaway.isEntered ? "Leave Giveaway" : "Enter Giveaway")
                                            .fontWeight(.semibold)
                                    }
                                    Spacer()
                                }
                                .foregroundStyle(.white)
                                .frame(height: 44)
                                .background(giveaway.isEntered ? Color.red : PirateTheme.accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .disabled(isActionLoading || actionCooldown)
                            .opacity(actionCooldown ? 0.5 : 1)
                        } else if giveaway.phase == .claimed {
                            Text("🎉 Prize has been claimed!")
                                .font(.subheadline).fontWeight(.medium)
                                .foregroundStyle(.green)
                        } else if giveaway.phase == .winner {
                            if wsManager.isCurrentUserWinner() {
                                HStack(spacing: 12) {
                                    Button {
                                        Task { await wsManager.claimGiveaway()
                                            appLog("Giveaway: claimed") }
                                    } label: {
                                        HStack {
                                            Image(systemName: "gift.fill")
                                            Text("Claim")
                                                .fontWeight(.semibold)
                                        }
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(.green)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }

                                    Button {
                                        Task { await wsManager.passGiveaway()
                                            appLog("Giveaway: passed") }
                                    } label: {
                                        HStack {
                                            Image(systemName: "hand.raised.fill")
                                            Text("Pass")
                                                .fontWeight(.semibold)
                                        }
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(.red)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                }
                            } else {
                                Text("⏳ Waiting for winner to claim...")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(20)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: headerColor(giveaway.phase).opacity(0.3), radius: 20)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                    .offset(y: appeared ? 0 : 300)
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared ? 1 : 0.9, anchor: .bottom)
                    .onAppear {
                        appLog("Giveaway: popup appeared, phase=\(giveaway.phase)")
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                            appeared = true
                        }
                    }
                    .onDisappear { appeared = false }
                }
            }
            .animation(.spring(response: 0.4), value: giveaway.phase)
            .onReceive(timer) { _ in now = Date() }
            .onChange(of: giveaway.phase) { _, newPhase in
                appLog("Giveaway: phase changed to \(newPhase)")
                if newPhase == .winner {
                    startSmallCelebration()
                } else if newPhase == .claimed {
                    startCelebration()
                }
            }
        }
    }

    private func headerIcon(_ phase: GiveawayPhase) -> String {
        switch phase {
        case .entry: return "gift.fill"
        case .winner: return "trophy.fill"
        case .claimed: return "party.popper.fill"
        }
    }

    private func headerColor(_ phase: GiveawayPhase) -> Color {
        switch phase {
        case .entry: return PirateTheme.accentColor
        case .winner: return .yellow
        case .claimed: return .green
        }
    }

    private func phaseTitle(_ phase: GiveawayPhase) -> String {
        switch phase {
        case .entry: return "New Giveaway!"
        case .winner: return "Winner Drawn!"
        case .claimed: return "Prize Claimed!"
        }
    }

    private func handleAction(_ giveaway: ActiveGiveaway) async {
        isActionLoading = true
        if giveaway.isEntered {
            await wsManager.leaveGiveaway()
            appLog("Giveaway: left")
        } else {
            await wsManager.enterGiveaway()
            appLog("Giveaway: entered")
        }
        isActionLoading = false
        actionCooldown = true
        Task { try? await Task.sleep(nanoseconds: 20_000_000_000); actionCooldown = false }
    }

    private func currentTimeRemaining(_ giveaway: ActiveGiveaway) -> Int? {
        guard let total = giveaway.timeRemaining, let start = giveaway.countdownStart else { return nil }
        let elapsed = Int(now.timeIntervalSince(start))
        let remaining = total - elapsed
        return remaining > 0 ? remaining : nil
    }

    private func formatRemaining(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return m > 0 ? String(format: "%d:%02d", m, s) : String(format: "0:%02d", s)
    }

    private func startSmallCelebration() {
        let colors: [Color] = [.yellow, .orange, PirateTheme.accentColor]
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height

        confettiParticles = (0..<15).map { _ in
            ConfettiParticle(
                color: colors.randomElement()!,
                size: CGFloat.random(in: 3...7),
                position: CGPoint(
                    x: CGFloat.random(in: screenWidth * 0.2...screenWidth * 0.8),
                    y: screenHeight * 0.5
                ),
                opacity: 1
            )
        }
        showConfetti = true

        for i in confettiParticles.indices {
            let delay = Double.random(in: 0...0.3)
            let duration = Double.random(in: 1.0...2.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeOut(duration: duration)) {
                    confettiParticles[i].position.y -= CGFloat.random(in: 100...250)
                    confettiParticles[i].position.x += CGFloat.random(in: -60...60)
                }
                withAnimation(.easeIn(duration: duration * 0.5).delay(duration * 0.5)) {
                    confettiParticles[i].opacity = 0
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            showConfetti = false
            confettiParticles = []
        }
    }

    private func startCelebration() {
        let colors: [Color] = [.red, .green, .blue, .yellow, .purple, .orange, .pink, PirateTheme.accentColor]
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height

        confettiParticles = (0..<60).map { _ in
            ConfettiParticle(
                color: colors.randomElement()!,
                size: CGFloat.random(in: 4...10),
                position: CGPoint(x: CGFloat.random(in: 0...screenWidth), y: -20),
                opacity: 1
            )
        }
        showConfetti = true

        // Animate particles falling
        for i in confettiParticles.indices {
            let delay = Double.random(in: 0...0.5)
            let duration = Double.random(in: 1.5...3.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeIn(duration: duration)) {
                    confettiParticles[i].position.y = screenHeight + 50
                    confettiParticles[i].position.x += CGFloat.random(in: -80...80)
                }
                withAnimation(.easeIn(duration: duration).delay(duration * 0.6)) {
                    confettiParticles[i].opacity = 0
                }
            }
        }

        // Clean up after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            showConfetti = false
            confettiParticles = []
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let size: CGFloat
    var position: CGPoint
    var opacity: Double
}
