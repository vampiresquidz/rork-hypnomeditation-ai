//
//  OnboardingFlowSteps.swift
//  HypnoFlow
//
//  The individual screens of the onboarding funnel. Each is a small, focused
//  view; OnboardingView sequences them and owns navigation.
//

import SwiftUI
import UserNotifications

// MARK: - 1. Welcome

struct WelcomeStep: View {
    var onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            mascot: .wave,
            mascotSize: 168,
            title: "Meet Professor Jelly",
            subtitle: "Your personal hypnotist. Tell him what's on your mind and he writes and voices a meditation made just for you."
        ) {
            EmptyView()
        } footer: {
            VStack(spacing: 10) {
                PrimaryButton(title: "Get started", systemImage: "sparkles", action: onContinue)
                Text("Takes about 30 seconds")
                    .font(.caption)
                    .foregroundStyle(Theme.textFaint)
            }
        }
    }
}

// MARK: - 2. Social proof

struct SocialProofStep: View {
    var onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            mascot: .idle,
            mascotSize: 130,
            title: "You're in good company",
            subtitle: "Thousands drift off, calm down and focus with HypnoFlow every night."
        ) {
            VStack(spacing: 14) {
                HStack(spacing: 6) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill").foregroundStyle(Theme.amber)
                    }
                    Text("4.9")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                }
                .padding(.top, 4)

                TestimonialCard(
                    quote: "I stopped doom-scrolling at 1am. Now I put on a sleep session and I'm out in minutes.",
                    author: "Maya R.",
                    tint: Theme.teal
                )
                TestimonialCard(
                    quote: "It genuinely feels like it was written for me — because it was.",
                    author: "Devin K.",
                    tint: Theme.violet
                )
            }
            .padding(.top, 6)
        } footer: {
            PrimaryButton(title: "Continue", action: onContinue)
        }
    }
}

private struct TestimonialCard: View {
    var quote: String
    var author: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("“\(quote)”")
                .font(.callout)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("— \(author)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 18)
    }
}

// MARK: - 3. Goal

struct GoalStep: View {
    @Binding var selection: HypnosisGoal?
    var onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            mascot: .idle,
            mascotSize: 108,
            title: "What brings you here?",
            subtitle: "Pick the one that matters most right now. You can make sessions for anything later."
        ) {
            VStack(spacing: 12) {
                ForEach(HypnosisGoal.allCases) { goal in
                    SelectableCard(
                        symbol: goal.symbol,
                        title: goal.title,
                        subtitle: goal.subtitle,
                        tint: goal.tint,
                        isSelected: selection == goal
                    ) {
                        selection = goal
                    }
                }
            }
            .padding(.top, 4)
        } footer: {
            PrimaryButton(title: "Continue", enabled: selection != nil, action: onContinue)
        }
    }
}

// MARK: - 4. Mind state

struct MindStateStep: View {
    @Binding var selection: MindState?
    var onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            mascot: .idle,
            mascotSize: 108,
            title: "How's your mind been lately?",
            subtitle: "Professor Jelly will meet you where you are."
        ) {
            VStack(spacing: 12) {
                ForEach(MindState.allCases) { state in
                    SelectableCard(
                        symbol: state.symbol,
                        title: state.title,
                        tint: Theme.violet,
                        isSelected: selection == state
                    ) {
                        selection = state
                    }
                }
            }
            .padding(.top, 4)
        } footer: {
            PrimaryButton(title: "Continue", enabled: selection != nil, action: onContinue)
        }
    }
}

// MARK: - 5. Experience

struct ExperienceStep: View {
    @Binding var selection: ExperienceLevel?
    var onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            mascot: .meditate,
            mascotSize: 120,
            title: "Done this before?",
            subtitle: "We'll tune how gently we guide you in."
        ) {
            VStack(spacing: 12) {
                ForEach(ExperienceLevel.allCases) { level in
                    SelectableCard(
                        symbol: level.symbol,
                        title: level.title,
                        subtitle: level.subtitle,
                        tint: Theme.teal,
                        isSelected: selection == level
                    ) {
                        selection = level
                    }
                }
            }
            .padding(.top, 4)
        } footer: {
            PrimaryButton(title: "Continue", enabled: selection != nil, action: onContinue)
        }
    }
}

// MARK: - 6. Unwind time

struct UnwindTimeStep: View {
    @Binding var selection: UnwindTime?
    var onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            mascot: .idle,
            mascotSize: 108,
            title: "When do you want to unwind?",
            subtitle: "We'll suggest the perfect time for your daily reset."
        ) {
            VStack(spacing: 12) {
                ForEach(UnwindTime.allCases) { time in
                    SelectableCard(
                        symbol: time.symbol,
                        title: time.title,
                        tint: Theme.amber,
                        isSelected: selection == time
                    ) {
                        selection = time
                    }
                }
            }
            .padding(.top, 4)
        } footer: {
            PrimaryButton(title: "Continue", enabled: selection != nil, action: onContinue)
        }
    }
}

// MARK: - 7. Building the plan (loader)

struct BuildingStep: View {
    var goal: HypnosisGoal?
    var onDone: () -> Void

    private let tasks = [
        "Reading your intentions",
        "Composing your induction",
        "Choosing a soothing voice",
        "Layering your soundscape",
    ]
    @State private var completed = 0

    var body: some View {
        VStack(spacing: 26) {
            Spacer()

            MascotView(pose: .hypnotize, size: 170)

            VStack(spacing: 8) {
                Text("Designing your plan")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                if let goal {
                    Text("Tuning everything for \(goal.title.lowercased())")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(tasks.enumerated()), id: \.offset) { idx, label in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .stroke(Theme.cardStroke, lineWidth: 1.5)
                                .frame(width: 24, height: 24)
                            if idx < completed {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(Theme.teal)
                                    .transition(.scale.combined(with: .opacity))
                            } else if idx == completed {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(Theme.amber)
                            }
                        }
                        Text(label)
                            .font(.callout)
                            .foregroundStyle(idx <= completed ? Theme.textPrimary : Theme.textFaint)
                        Spacer()
                    }
                }
            }
            .padding(20)
            .glassCard(cornerRadius: 20)
            .padding(.horizontal, 30)

            Spacer()
        }
        .task {
            // Tick the checklist, then hand off to the plan reveal.
            for i in 1...tasks.count {
                try? await Task.sleep(for: .milliseconds(720))
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { completed = i }
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            }
            try? await Task.sleep(for: .milliseconds(600))
            onDone()
        }
    }
}

// MARK: - 8. Personalized plan preview

struct PlanPreviewStep: View {
    var goal: HypnosisGoal?
    var mindState: MindState?
    var unwind: UnwindTime?
    var onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            mascot: .celebrate,
            mascotSize: 168,
            title: "Your plan is ready",
            subtitle: headline
        ) {
            VStack(spacing: 12) {
                PlanRow(symbol: goal?.symbol ?? "sparkles",
                        title: goal?.title ?? "Personalized sessions",
                        detail: goal?.subtitle ?? "Made around your goal",
                        tint: goal?.tint ?? Theme.teal)
                PlanRow(symbol: "waveform",
                        title: "A real hypnotic arc",
                        detail: "Countdown in · guided journey · gentle count-out",
                        tint: Theme.violet)
                PlanRow(symbol: unwind?.symbol ?? "clock.fill",
                        title: unwind.map { "\($0.title) ritual" } ?? "Your daily ritual",
                        detail: "A calming reset at your favorite time",
                        tint: Theme.amber)
            }
            .padding(.top, 4)
        } footer: {
            PrimaryButton(title: "Love it — continue", systemImage: "heart.fill", action: onContinue)
        }
    }

    private var headline: String {
        switch mindState {
        case .racing:  "We'll help quiet that racing mind."
        case .anxious: "Let's melt that tension away."
        case .tired:   "Time to trade wired for truly rested."
        case .stuck:   "Let's gently shift you out of that rut."
        case .okay, .none: "Crafted around exactly what you told us."
        }
    }
}

private struct PlanRow: View {
    var symbol: String
    var title: String
    var detail: String
    var tint: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(tint.opacity(0.18)).frame(width: 44, height: 44)
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassCard(cornerRadius: 18)
    }
}

// MARK: - 9. Notifications

struct NotificationsStep: View {
    var unwind: UnwindTime?
    var onDecision: () -> Void

    @State private var requesting = false

    var body: some View {
        OnboardingScaffold(
            mascot: .wave,
            mascotSize: 140,
            title: "A gentle nudge?",
            subtitle: reminderLine
        ) {
            EmptyView()
        } footer: {
            VStack(spacing: 8) {
                PrimaryButton(title: "Enable reminders", systemImage: "bell.fill", enabled: !requesting) {
                    requestPermission()
                }
                Button("Not now") { onDecision() }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.vertical, 6)
            }
        }
    }

    private var reminderLine: String {
        if let unwind {
            "We'll remind you to take a moment for yourself in the \(unwind.title.lowercased()) — never spammy, always optional."
        } else {
            "One kind daily reminder to take a moment for yourself. Never spammy, always optional."
        }
    }

    private func requestPermission() {
        requesting = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            DispatchQueue.main.async {
                requesting = false
                onDecision()
            }
        }
    }
}

// MARK: - 10. Offer / paywall handoff

struct OfferStep: View {
    var goal: HypnosisGoal?
    var onUnlock: () -> Void
    var onSkip: () -> Void

    var body: some View {
        OnboardingScaffold(
            mascot: .celebrate,
            mascotSize: 132,
            title: "Start your first journey",
            subtitle: goal.map { "Your \($0.title) session is one tap away." }
                ?? "Your first personalized session is one tap away."
        ) {
            VStack(spacing: 12) {
                BenefitRow(symbol: "infinity", text: "Unlimited personalized sessions")
                BenefitRow(symbol: "waveform", text: "Premium, human-quality voices")
                BenefitRow(symbol: "moon.stars.fill", text: "Sleep, calm, focus & confidence")
                BenefitRow(symbol: "books.vertical.fill", text: "Your growing, replayable library")
            }
            .padding(.top, 4)
        } footer: {
            VStack(spacing: 8) {
                PrimaryButton(title: "See plans & start free", systemImage: "sparkles", action: onUnlock)
                Button("Continue with 3 free sessions") { onSkip() }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.vertical, 6)
            }
        }
    }
}

private struct BenefitRow: View {
    var symbol: String
    var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.amber)
                .frame(width: 26)
            Text(text)
                .font(.callout)
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14).padding(.vertical, 12)
        .glassCard(cornerRadius: 14)
    }
}
