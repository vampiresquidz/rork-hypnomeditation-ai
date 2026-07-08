//
//  OnboardingStore.swift
//  HypnoFlow
//
//  Holds the answers a new user gives during the first-run onboarding flow and
//  remembers, across launches, that they've finished it. The answers double as
//  personalization attributes — the same idea Superwall calls "onboarding
//  attributes" — so later screens (the plan preview, the paywall, the first
//  session) can speak back to what the user told us.
//

import SwiftUI

/// How the user's mind has felt lately — the emotional "why now".
enum MindState: String, CaseIterable, Codable, Identifiable {
    case racing, anxious, tired, stuck, okay
    var id: String { rawValue }

    var title: String {
        switch self {
        case .racing:  "Racing & restless"
        case .anxious: "Anxious & tense"
        case .tired:   "Tired but wired"
        case .stuck:   "Stuck in a rut"
        case .okay:    "Pretty good, just curious"
        }
    }

    var symbol: String {
        switch self {
        case .racing:  "wind"
        case .anxious: "bolt.heart"
        case .tired:   "zzz"
        case .stuck:   "arrow.triangle.2.circlepath"
        case .okay:    "sparkles"
        }
    }
}

/// How much the user has practised meditation or hypnosis before — tunes how
/// much hand-holding the first sessions give.
enum ExperienceLevel: String, CaseIterable, Codable, Identifiable {
    case newbie, dabbled, regular
    var id: String { rawValue }

    var title: String {
        switch self {
        case .newbie:  "Total beginner"
        case .dabbled: "I've dabbled"
        case .regular: "Regular practice"
        }
    }

    var subtitle: String {
        switch self {
        case .newbie:  "Never really tried it"
        case .dabbled: "A few apps or sessions"
        case .regular: "It's part of my routine"
        }
    }

    var symbol: String {
        switch self {
        case .newbie:  "leaf"
        case .dabbled: "sparkle"
        case .regular: "flame"
        }
    }
}

/// When the user most wants to unwind — becomes their suggested reminder time.
enum UnwindTime: String, CaseIterable, Codable, Identifiable {
    case morning, afternoon, evening, night
    var id: String { rawValue }

    var title: String {
        switch self {
        case .morning:   "Morning"
        case .afternoon: "Afternoon"
        case .evening:   "Evening"
        case .night:     "Right before bed"
        }
    }

    var symbol: String {
        switch self {
        case .morning:   "sunrise.fill"
        case .afternoon: "sun.max.fill"
        case .evening:   "sunset.fill"
        case .night:     "moon.stars.fill"
        }
    }

    /// A sensible default hour to suggest for a reminder.
    var suggestedHour: Int {
        switch self {
        case .morning:   7
        case .afternoon: 14
        case .evening:   19
        case .night:     22
        }
    }
}

@Observable
final class OnboardingStore {
    /// Whether the user has finished onboarding at least once.
    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.completed) }
    }

    // Collected answers (persisted so we can personalize later runs too).
    var goal: HypnosisGoal? {
        didSet { defaults.set(goal?.rawValue, forKey: Keys.goal) }
    }
    var mindState: MindState? {
        didSet { defaults.set(mindState?.rawValue, forKey: Keys.mind) }
    }
    var experience: ExperienceLevel? {
        didSet { defaults.set(experience?.rawValue, forKey: Keys.experience) }
    }
    var unwindTime: UnwindTime? {
        didSet { defaults.set(unwindTime?.rawValue, forKey: Keys.unwind) }
    }

    /// Transient: set when the user finishes onboarding by choosing to see plans,
    /// so the app can present the paywall once at peak motivation.
    var wantsPaywallOnEntry = false

    private let defaults: UserDefaults
    private enum Keys {
        static let completed = "onboarding.completed"
        static let goal = "onboarding.goal"
        static let mind = "onboarding.mindState"
        static let experience = "onboarding.experience"
        static let unwind = "onboarding.unwindTime"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hasCompletedOnboarding = defaults.bool(forKey: Keys.completed)
        goal = defaults.string(forKey: Keys.goal).flatMap(HypnosisGoal.init)
        mindState = defaults.string(forKey: Keys.mind).flatMap(MindState.init)
        experience = defaults.string(forKey: Keys.experience).flatMap(ExperienceLevel.init)
        unwindTime = defaults.string(forKey: Keys.unwind).flatMap(UnwindTime.init)
    }

    /// Finish onboarding, optionally routing straight to the paywall.
    func complete(showPaywall: Bool) {
        wantsPaywallOnEntry = showPaywall
        withAnimation(.easeInOut(duration: 0.4)) {
            hasCompletedOnboarding = true
        }
    }

    /// Wipe everything — handy for previews and a "reset onboarding" debug action.
    func reset() {
        hasCompletedOnboarding = false
        goal = nil; mindState = nil; experience = nil; unwindTime = nil
        wantsPaywallOnEntry = false
    }
}
