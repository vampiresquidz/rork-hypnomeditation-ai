//
//  GenerationView.swift
//  HypnoFlow
//
//  Shows an atmospheric loading experience while the session is written
//  and narrated, then hands the finished session to the caller.
//

import SwiftUI

struct GenerationView: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let goal: HypnosisGoal
    let intention: String
    let duration: Int
    let voice: NarratorVoice
    let soundscape: Soundscape
    let onComplete: (MeditationSession) -> Void

    @State private var started = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            AuroraBackground()

            VStack(spacing: 34) {
                Spacer()

                ZStack {
                    ForEach(0..<3) { i in
                        Circle()
                            .stroke(goal.tint.opacity(0.4), lineWidth: 1)
                            .frame(width: 120 + CGFloat(i) * 50, height: 120 + CGFloat(i) * 50)
                            .scaleEffect(pulse ? 1.15 : 0.85)
                            .opacity(pulse ? 0 : 0.8)
                            .animation(
                                .easeOut(duration: 2.6).repeatForever(autoreverses: false).delay(Double(i) * 0.8),
                                value: pulse
                            )
                    }
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white.opacity(0.9), goal.tint, Theme.violet.opacity(0.9)],
                                center: .init(x: 0.4, y: 0.35),
                                startRadius: 2, endRadius: 70
                            )
                        )
                        .frame(width: 96, height: 96)
                        .shadow(color: goal.tint.opacity(0.6), radius: 24)
                        .scaleEffect(pulse ? 1.06 : 0.96)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulse)
                }
                .frame(height: 240)

                VStack(spacing: 10) {
                    Text(store.stage.headline)
                        .font(.system(.title2, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .contentTransition(.opacity)
                    Text(store.stage.detail)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .contentTransition(.opacity)
                        .padding(.horizontal, 40)
                }
                .animation(.easeInOut, value: store.stage)

                if case .recording(let done, let total) = store.stage {
                    ProgressView(value: Double(done), total: Double(total))
                        .tint(goal.tint)
                        .frame(width: 220)
                }

                Spacer()

                if case .failed = store.stage {
                    VStack(spacing: 14) {
                        PrimaryButton(title: "Try again", systemImage: "arrow.clockwise") {
                            Task { await run() }
                        }
                        Button("Go back") { dismiss() }
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.horizontal, 30)
                } else {
                    Text("Please keep the app open")
                        .font(.caption)
                        .foregroundStyle(Theme.textFaint)
                }

                Spacer().frame(height: 20)
            }
        }
        .onAppear {
            pulse = true
            if !started {
                started = true
                Task { await run() }
            }
        }
    }

    private func run() async {
        let session = await store.generate(
            goal: goal,
            intention: intention,
            durationMinutes: duration,
            voice: voice,
            soundscape: soundscape
        )
        if let session {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            onComplete(session)
        }
    }
}
