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
    @Environment(StreakStore.self) private var streaks
    @Environment(ReminderManager.self) private var reminders

    let session: SessionModel

    @State private var player = SessionPlayer()
    @State private var showCountdown = true
    @State private var countdown = 3
    @State private var appeared = false
    @State private var celebration: Int?

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

            if let streak = celebration {
                StreakCelebrationOverlay(streak: streak) {
                    withAnimation(.easeInOut) { celebration = nil }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            player.onFinish = recordPractice
            player.load(session)
            startCountdown()
        }
        .onDisappear { player.stop() }
        .onChange(of: player.currentPhase) { _, _ in
            // A soft tick as the listener crosses from one phase into the next.
            guard !showCountdown else { return }
            let g = UIImpactFeedbackGenerator(style: .soft)
            g.impactOccurred()
        }
    }

    // MARK: Streak

    /// Called when the session plays through to the end: check in for today and,
    /// if this lands on a milestone, celebrate in-app and queue a proud push for
    /// tomorrow so the user is nudged to keep the streak alive.
    private func recordPractice() {
        let milestone = streaks.recordPractice()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        guard let milestone else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            celebration = milestone
        }
        Task { await reminders.celebrate(streak: milestone) }
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
        VStack(spacing: 10) {
            PhaseScrubber(
                spans: player.phaseSpans,
                progress: player.progress,
                enabled: player.canSeek && !showCountdown,
                colorFor: phaseColor
            ) { fraction in
                player.seek(to: fraction)
            }
            .frame(height: 22)

            HStack {
                Text(timeString(player.elapsed))
                Spacer()
                Text(timeString(player.total))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(Theme.textFaint)

            if player.phaseSpans.count > 1 {
                phaseLegend
                    .padding(.top, 2)
            }
        }
    }

    private var phaseLegend: some View {
        HStack(spacing: 16) {
            ForEach(legendPhases, id: \.self) { phase in
                Button {
                    guard player.canSeek else { return }
                    let g = UIImpactFeedbackGenerator(style: .soft)
                    g.impactOccurred()
                    player.seek(to: startFraction(of: phase))
                } label: {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(phaseColor(phase))
                            .frame(width: 7, height: 7)
                        Text(phase.title)
                            .font(.caption2)
                            .foregroundStyle(player.currentPhase == phase ? phaseColor(phase) : Theme.textFaint)
                    }
                }
                .buttonStyle(.plain)
                .disabled(!player.canSeek)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: player.currentPhase)
    }

    /// Timeline fraction where a given phase begins.
    private func startFraction(of phase: SessionPhase) -> Double {
        player.phaseSpans.first { $0.phase == phase }?.start ?? 0
    }

    /// The distinct phases, in the order they appear on the timeline.
    private var legendPhases: [SessionPhase] {
        var seen: [SessionPhase] = []
        for span in player.phaseSpans where !seen.contains(span.phase) {
            seen.append(span.phase)
        }
        return seen
    }

    private func phaseColor(_ phase: SessionPhase) -> Color {
        switch phase {
        case .induction: Theme.violet
        case .journey:   session.goal.tint
        case .emergence: Theme.amber
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

/// A progress bar split into the three phases (each tinted), showing played
/// progress and — when the stitched track is available — draggable to seek.
private struct PhaseScrubber: View {
    let spans: [PhaseSpan]
    let progress: Double
    let enabled: Bool
    let colorFor: (SessionPhase) -> Color
    let onSeek: (Double) -> Void

    private let trackHeight: CGFloat = 6
    private let gap: CGFloat = 3

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                if spans.isEmpty {
                    Capsule().fill(Theme.card)
                        .frame(height: trackHeight)
                    Capsule().fill(Theme.gradientAmberTeal)
                        .frame(width: max(0, w * progress), height: trackHeight)
                } else {
                    segments(width: w, opacity: 0.22)
                    segments(width: w, opacity: 0.95)
                        .mask(alignment: .leading) {
                            Rectangle().frame(width: max(0, w * progress))
                        }
                }

                if enabled {
                    Circle()
                        .fill(.white)
                        .frame(width: 15, height: 15)
                        .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                        .offset(x: min(max(w * progress - 7.5, 0), w - 15))
                }
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard enabled, w > 0 else { return }
                        onSeek(min(max(value.location.x / w, 0), 1))
                    }
            )
        }
    }

    private func segments(width w: CGFloat, opacity: Double) -> some View {
        ZStack(alignment: .leading) {
            ForEach(spans) { span in
                Capsule()
                    .fill(colorFor(span.phase).opacity(opacity))
                    .frame(width: max(2, w * (span.end - span.start) - gap), height: trackHeight)
                    .offset(x: w * span.start)
            }
        }
    }
}

/// A celebratory takeover shown when the user reaches a practice-streak milestone
/// — Professor Jelly cheering over a dimmed backdrop. Taps through, and auto-
/// dismisses after a few seconds so it never blocks the wind-down.
private struct StreakCelebrationOverlay: View {
    let streak: Int
    let onDismiss: () -> Void

    @State private var shown = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 18) {
                MascotView(pose: .celebrate, size: 170)
                    .scaleEffect(shown ? 1 : 0.6)

                Text("\(streak)-day streak!")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.amber)

                Text("Professor Jelly is so proud of you 🪼\nSee you again tomorrow?")
                    .font(.system(.headline, design: .rounded).weight(.regular))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)

                Button(action: onDismiss) {
                    Text("Keep it going")
                        .font(.headline)
                        .foregroundStyle(Theme.void)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 14)
                        .background(Theme.gradientAmberTeal, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(36)
            .opacity(shown ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { shown = true }
            // Auto-dismiss so it doesn't interrupt the calm for long.
            Task {
                try? await Task.sleep(for: .seconds(6))
                onDismiss()
            }
        }
    }
}
