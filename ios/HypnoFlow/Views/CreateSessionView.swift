//
//  CreateSessionView.swift
//  HypnoFlow
//
//  The customization sheet where the user shapes their session before
//  generation: goal, intention, duration, voice, and soundscape.
//

import SwiftUI

struct CreateSessionView: View {
    @Environment(SessionStore.self) private var store
    @Environment(CreditStore.self) private var credits
    @Environment(\.dismiss) private var dismiss

    let presetGoal: HypnosisGoal?
    let onReady: (MeditationSession) -> Void

    @State private var showPaywall = false

    /// Credits this session will cost, based on its length.
    private var cost: Int { creditCost(durationMinutes: duration) }
    private var canAfford: Bool { credits.total >= cost }

    @State private var goal: HypnosisGoal
    @State private var intention: String = ""
    @State private var duration: Int = 10
    @State private var voice: NarratorVoice = .george
    @State private var soundscape: Soundscape = .dream
    @State private var showGeneration = false
    @FocusState private var intentionFocused: Bool

    private let durations = [5, 10, 15, 20]

    init(presetGoal: HypnosisGoal?, onReady: @escaping (MeditationSession) -> Void) {
        self.presetGoal = presetGoal
        self.onReady = onReady
        _goal = State(initialValue: presetGoal ?? .calm)
        _soundscape = State(initialValue: (presetGoal ?? .calm).soundscape)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground(animated: false)

                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        goalSection
                        intentionSection
                        durationSection
                        voiceSection
                        soundscapeSection
                        Color.clear.frame(height: 90)
                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(.interactively)

                VStack(spacing: 8) {
                    Spacer()

                    HStack(spacing: 6) {
                        Image(systemName: "sparkles").font(.caption2)
                        Text(canAfford
                             ? "Uses \(cost) of your \(credits.total) credits"
                             : "You need \(cost) credit\(cost > 1 ? "s" : "") — you have \(credits.total)")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(canAfford ? Theme.textSecondary : Theme.amber)

                    PrimaryButton(
                        title: canAfford ? "Generate my session" : "Get credits to generate",
                        systemImage: canAfford ? "wand.and.stars" : "sparkles"
                    ) {
                        intentionFocused = false
                        if canAfford {
                            showGeneration = true
                        } else {
                            showPaywall = true
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }
                .background(
                    LinearGradient(colors: [.clear, Theme.void.opacity(0.9)],
                                   startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                )
            }
            .navigationTitle("Design your session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $showGeneration) {
                GenerationView(
                    goal: goal,
                    intention: intention,
                    duration: duration,
                    voice: voice,
                    soundscape: soundscape
                ) { session in
                    // Generation succeeded — spend the credits now.
                    credits.consume(cost)
                    showGeneration = false
                    dismiss()
                    // Give the sheet a beat to dismiss before presenting the player.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        onReady(session)
                    }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
        .tint(Theme.amber)
        .preferredColorScheme(.dark)
    }

    // MARK: Sections

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            label("Focus")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(HypnosisGoal.allCases) { g in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                goal = g
                                soundscape = g.soundscape
                            }
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: g.symbol)
                                Text(g.shortTitle)
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(goal == g ? Theme.void : Theme.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 11)
                            .background(goal == g ? AnyShapeStyle(g.tint) : AnyShapeStyle(Theme.card))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Theme.cardStroke, lineWidth: goal == g ? 0 : 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .contentMargins(.horizontal, 0)
            Text(goal.subtitle)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var intentionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            label("Your intention")
            Text("Optional — a few words about what's on your mind. The more personal, the deeper it lands.")
                .font(.caption)
                .foregroundStyle(Theme.textFaint)
            ZStack(alignment: .topLeading) {
                if intention.isEmpty {
                    Text(placeholder)
                        .font(.body)
                        .foregroundStyle(Theme.textFaint)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                }
                TextEditor(text: $intention)
                    .focused($intentionFocused)
                    .font(.body)
                    .foregroundStyle(Theme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(minHeight: 110)
            }
            .glassCard(cornerRadius: 18)
        }
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            label("Length")
            HStack(spacing: 10) {
                ForEach(durations, id: \.self) { d in
                    Button {
                        withAnimation(.spring(response: 0.3)) { duration = d }
                    } label: {
                        VStack(spacing: 2) {
                            Text("\(d)")
                                .font(.system(.title3, design: .rounded).weight(.bold))
                            Text("min")
                                .font(.caption2)
                        }
                        .foregroundStyle(duration == d ? Theme.void : Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(duration == d ? AnyShapeStyle(Theme.gradientAmberTeal) : AnyShapeStyle(Theme.card))
                        .clipShape(.rect(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.cardStroke, lineWidth: duration == d ? 0 : 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            label("Narrator")
            ForEach(NarratorVoice.allCases) { v in
                Button {
                    withAnimation(.spring(response: 0.3)) { voice = v }
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Theme.card)
                                .frame(width: 44, height: 44)
                            Image(systemName: "waveform")
                                .foregroundStyle(voice == v ? Theme.amber : Theme.textSecondary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(v.displayName)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                            Text(v.descriptor)
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: voice == v ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(voice == v ? Theme.amber : Theme.textFaint)
                    }
                    .padding(14)
                    .glassCard(cornerRadius: 18)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.amber.opacity(voice == v ? 0.6 : 0), lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var soundscapeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            label("Soundscape")
            HStack(spacing: 10) {
                ForEach(Soundscape.allCases) { s in
                    Button {
                        withAnimation(.spring(response: 0.3)) { soundscape = s }
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: s.symbol)
                                .font(.title3)
                                .foregroundStyle(soundscape == s ? Theme.amber : Theme.textSecondary)
                            Text(s.title)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Theme.textPrimary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .glassCard(cornerRadius: 16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.amber.opacity(soundscape == s ? 0.6 : 0), lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(1.5)
            .foregroundStyle(Theme.textFaint)
    }

    private var placeholder: String {
        switch goal {
        case .sleep:      "I keep waking at 3am with my mind racing…"
        case .confidence: "I have a big presentation on Friday…"
        case .anxiety:    "My chest feels tight and I can't switch off…"
        case .focus:      "I want to sit down and finish my project…"
        case .habit:      "I want to stop reaching for my phone…"
        case .calm:       "I just need to feel grounded again…"
        }
    }
}
