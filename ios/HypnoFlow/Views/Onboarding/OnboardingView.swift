//
//  OnboardingView.swift
//  HypnoFlow
//
//  A Superwall-style, multi-screen onboarding funnel. Research on subscription
//  onboarding is consistent: several focused screens convert far better than one
//  do-everything paywall, because each screen does a single job while the user is
//  at peak motivation (just after install). Our flow follows that arc:
//
//    welcome → social proof → goal → mind-state → experience → unwind time
//    → "building your plan" loader → personalized plan → notifications → offer
//
//  Every screen keeps Professor Jelly on stage doing something apt (waving,
//  swinging his watch while the plan "builds", celebrating when it's ready), and
//  the questions become personalization attributes used further down the funnel.
//

import SwiftUI
import UserNotifications

struct OnboardingView: View {
    @Environment(OnboardingStore.self) private var onboarding

    @State private var step: Step = .welcome
    @State private var goingForward = true
    @State private var showLogin = false

    enum Step: Int, CaseIterable {
        case welcome, social, goal, mind, experience, unwind, building, plan, progress, notifications, timeline, offer

        /// Question steps that drive the top progress bar.
        static let questionSteps: [Step] = [.goal, .mind, .experience, .unwind]
        var isQuestion: Bool { Step.questionSteps.contains(self) }
    }

    var body: some View {
        ZStack {
            AuroraBackground()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 6)

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.asymmetric(
                        insertion: .move(edge: goingForward ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: goingForward ? .leading : .trailing).combined(with: .opacity)
                    ))
                    .id(step)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showLogin) {
            LoginSheet()
        }
    }

    // MARK: - Top bar (back + progress)

    private var topBar: some View {
        HStack(spacing: 14) {
            if step != .welcome && step != .building {
                Button {
                    back()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 40, height: 40)
                        .glassCard(cornerRadius: 12)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }

            if let progress = questionProgress {
                ProgressBar(value: progress)
                    .frame(height: 6)
                    .transition(.opacity)
            } else {
                Spacer(minLength: 0)
            }
        }
        .frame(height: 40)
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    /// 0…1 across the four question screens (nil hides the bar).
    private var questionProgress: CGFloat? {
        guard let idx = Step.questionSteps.firstIndex(of: step) else { return nil }
        return CGFloat(idx + 1) / CGFloat(Step.questionSteps.count)
    }

    // MARK: - Step content

    @ViewBuilder
    private var content: some View {
        @Bindable var onboarding = onboarding

        switch step {
        case .welcome:
            WelcomeStep(onContinue: advance, onLogin: { showLogin = true })

        case .social:
            SocialProofStep(onContinue: advance)

        case .goal:
            GoalStep(selection: $onboarding.goal, onContinue: advance)

        case .mind:
            MindStateStep(selection: $onboarding.mindState, onContinue: advance)

        case .experience:
            ExperienceStep(selection: $onboarding.experience, onContinue: advance)

        case .unwind:
            UnwindTimeStep(selection: $onboarding.unwindTime, onContinue: advance)

        case .building:
            BuildingStep(goal: onboarding.goal, onDone: advance)

        case .plan:
            PlanPreviewStep(
                goal: onboarding.goal,
                mindState: onboarding.mindState,
                unwind: onboarding.unwindTime,
                onContinue: advance
            )

        case .progress:
            ProgressChartStep(goal: onboarding.goal, onContinue: advance)

        case .notifications:
            NotificationsStep(
                unwind: onboarding.unwindTime,
                onDecision: { advance() }
            )

        case .timeline:
            TrialTimelineStep(goal: onboarding.goal, onContinue: advance)

        case .offer:
            OfferStep(
                goal: onboarding.goal,
                onUnlock: { onboarding.complete(showPaywall: true) },
                onSkip: { onboarding.complete(showPaywall: false) }
            )
        }
    }

    // MARK: - Navigation

    private func advance() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        goingForward = true
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            step = next
        }
    }

    private func back() {
        guard let prev = Step(rawValue: step.rawValue - 1) else { return }
        goingForward = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            step = prev
        }
    }
}

// MARK: - Shared building blocks

/// A slim, rounded progress bar with an aurora fill.
struct ProgressBar: View {
    var value: CGFloat   // 0…1

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.card)
                Capsule()
                    .fill(Theme.gradientAmberTeal)
                    .frame(width: max(6, geo.size.width * min(max(value, 0), 1)))
                    .animation(.spring(response: 0.5, dampingFraction: 0.9), value: value)
            }
        }
    }
}

/// Consistent layout for every onboarding screen: mascot on top, a headline and
/// supporting line, the screen's body, then a pinned footer with the CTA.
struct OnboardingScaffold<Body: View, Footer: View>: View {
    var mascot: MascotPose
    var mascotSize: CGFloat = 150
    var title: String
    var subtitle: String?
    @ViewBuilder var content: () -> Body
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 18) {
                    MascotView(pose: mascot, size: mascotSize)
                        .padding(.top, 8)

                    VStack(spacing: 10) {
                        Text(title)
                            .font(.system(.title, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                            .multilineTextAlignment(.center)
                        if let subtitle {
                            Text(subtitle)
                                .font(.body)
                                .foregroundStyle(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, 8)

                    content()
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)

            footer()
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 10)
        }
    }
}

/// A tappable option row with an icon, title, optional subtitle, and a selected
/// ring. Used for every multiple-choice question.
struct SelectableCard: View {
    var symbol: String
    var title: String
    var subtitle: String?
    var tint: Color = Theme.teal
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            action()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(isSelected ? 0.28 : 0.14))
                        .frame(width: 46, height: 46)
                    Image(systemName: symbol)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(tint)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? tint : Theme.textFaint.opacity(0.5))
            }
            .padding(16)
            .glassCard(cornerRadius: 18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? tint.opacity(0.85) : .clear, lineWidth: 1.5)
            )
            .shadow(color: tint.opacity(isSelected ? 0.22 : 0), radius: 12)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

#Preview {
    OnboardingView()
        .environment(OnboardingStore())
        .environment(SubscriptionManager())
        .environment(CreditStore())
        .environment(AuthStore())
}
