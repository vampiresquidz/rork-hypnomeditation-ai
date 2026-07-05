//
//  PlayerView.swift
//  HypnoFlow
//
//  The immersive playback screen: breathing orb, live narration line,
//  progress, and transport controls.
//

import SwiftUI

struct PlayerView: View {
    @Environment(\.dismiss) private var dismiss

    let session: MeditationSession

    @State private var player = SessionPlayer()
    @State private var showCountdown = true
    @State private var countdown = 3
    @State private var appeared = false

    var body: some View {
        ZStack {
            AuroraBackground()

            VStack(spacing: 0) {
                topBar

                Spacer()

                BreathingOrb(isActive: player.isPlaying, tint: session.goal.tint)
                    .frame(height: 340)

                Spacer()

                VStack(spacing: 14) {
                    phaseBadge
                    narrationLine
                }

                Spacer()

                progressSection
                    .padding(.horizontal, 30)

                transport
                    .padding(.top, 26)
                    .padding(.bottom, 40)
            }
            .opacity(showCountdown ? 0.25 : 1)
            .animation(.easeInOut(duration: 0.6), value: showCountdown)

            if showCountdown {
                countdownOverlay
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            player.load(session)
            startCountdown()
        }
        .onDisappear { player.stop() }
    }

    // MARK: Pieces

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.headline)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(Theme.card)
                    .clipShape(Circle())
            }
            Spacer()
            VStack(spacing: 2) {
                Text(session.title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("\(session.goal.shortTitle) · \(session.voice.displayName)")
                    .font(.caption2)
                    .foregroundStyle(Theme.textFaint)
            }
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var phaseBadge: some View {
        HStack(spacing: 7) {
            Image(systemName: phaseSymbol(player.currentPhase))
            Text(player.currentPhase.title.uppercased())
                .tracking(1.5)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(session.goal.tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(session.goal.tint.opacity(0.14), in: Capsule())
        .opacity(player.isFinished || showCountdown ? 0 : 1)
        .animation(.easeInOut(duration: 0.4), value: player.currentPhase)
        .animation(.easeInOut, value: player.isFinished)
    }

    private func phaseSymbol(_ phase: SessionPhase) -> String {
        switch phase {
        case .induction: "arrow.down.to.line"
        case .journey:   "sparkles"
        case .emergence: "sun.max"
        }
    }

    private var narrationLine: some View {
        Text(player.currentLine)
            .font(.system(.title3, design: .serif))
            .italic()
            .foregroundStyle(Theme.textPrimary)
            .multilineTextAlignment(.center)
            .lineSpacing(6)
            .padding(.horizontal, 34)
            .frame(minHeight: 90)
            .id(player.currentLine)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.5), value: player.currentLine)
    }

    private var progressSection: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.card)
                        .frame(height: 5)
                    Capsule()
                        .fill(Theme.gradientAmberTeal)
                        .frame(width: max(0, geo.size.width * player.progress), height: 5)
                }
            }
            .frame(height: 5)

            HStack {
                Text(timeString(player.elapsed))
                Spacer()
                Text(timeString(player.total))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(Theme.textFaint)
        }
    }

    private var transport: some View {
        HStack(spacing: 40) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 56, height: 56)
                    .background(Theme.card)
                    .clipShape(Circle())
            }

            Button {
                let g = UIImpactFeedbackGenerator(style: .soft)
                g.impactOccurred()
                player.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(Theme.gradientAmberTeal)
                        .frame(width: 86, height: 86)
                        .shadow(color: Theme.amber.opacity(0.5), radius: 20)
                    Image(systemName: player.isFinished ? "arrow.counterclockwise" : (player.isPlaying ? "pause.fill" : "play.fill"))
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Theme.void)
                        .offset(x: player.isPlaying || player.isFinished ? 0 : 3)
                }
            }
            .buttonStyle(.plain)

            Button {
                dismiss()
            } label: {
                Image(systemName: "checkmark")
                    .font(.title3)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 56, height: 56)
                    .background(Theme.card)
                    .clipShape(Circle())
            }
        }
    }

    private var countdownOverlay: some View {
        VStack(spacing: 20) {
            // Professor Jelly swings his watch to guide you down as you settle in.
            MascotView(pose: .hypnotize, size: 150)

            Text("Find a comfortable position")
                .font(.system(.title3, design: .rounded).weight(.medium))
                .foregroundStyle(Theme.textPrimary)
            Text("Let your eyes soften. We begin in")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Text("\(countdown)")
                .font(.system(size: 96, weight: .thin, design: .rounded))
                .foregroundStyle(Theme.amber)
                .contentTransition(.numericText(countsDown: true))
                .animation(.snappy, value: countdown)
        }
        .padding(40)
    }

    // MARK: Logic

    private func startCountdown() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if countdown <= 1 {
                timer.invalidate()
                withAnimation { showCountdown = false }
                player.play()
            } else {
                countdown -= 1
                let g = UIImpactFeedbackGenerator(style: .light)
                g.impactOccurred()
            }
        }
    }

    private func timeString(_ seconds: Double) -> String {
        let s = Int(seconds.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
