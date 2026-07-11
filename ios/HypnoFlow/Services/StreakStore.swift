//
//  StreakStore.swift
//  HypnoFlow
//
//  Tracks the user's daily practice streak — how many days in a row they've
//  finished a session. Completing a session "checks in" for the day; miss a day
//  and the streak resets. Hitting a milestone (3, 7, 14, 30, …) is the moment we
//  let Professor Jelly celebrate, both in-app and with a proud little push the
//  next day nudging the user to keep it alive.
//

import Foundation

@Observable
@MainActor
final class StreakStore {

    /// Consecutive days (including today) the user has practised.
    private(set) var current: Int {
        didSet { defaults.set(current, forKey: Keys.current) }
    }
    /// The longest streak the user has ever reached.
    private(set) var best: Int {
        didSet { defaults.set(best, forKey: Keys.best) }
    }

    /// Streak lengths worth celebrating.
    private let milestones: Set<Int> = [3, 7, 14, 21, 30, 50, 75, 100, 150, 200, 365]

    private let defaults: UserDefaults
    private enum Keys {
        static let current = "streak.current"
        static let best = "streak.best"
        static let lastDay = "streak.lastPracticeDay"   // days since reference
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        current = defaults.integer(forKey: Keys.current)
        best = defaults.integer(forKey: Keys.best)
        // If more than a day has lapsed since the last check-in, the streak is dead.
        if let last = storedLastDay, Self.dayNumber(for: Date()) - last > 1 {
            current = 0
        }
    }

    /// Whether the user has already practised today.
    var practisedToday: Bool {
        storedLastDay == Self.dayNumber(for: Date())
    }

    /// Record that the user finished a session today. Returns the streak length if
    /// this check-in landed on a celebration-worthy milestone, else nil.
    @discardableResult
    func recordPractice(on date: Date = Date()) -> Int? {
        let today = Self.dayNumber(for: date)

        // Already counted today — nothing changes.
        if let last = storedLastDay, last == today { return nil }

        if let last = storedLastDay, today - last == 1 {
            current += 1            // consecutive day
        } else {
            current = 1             // first day, or streak was broken
        }

        defaults.set(today, forKey: Keys.lastDay)
        best = max(best, current)

        return milestones.contains(current) ? current : nil
    }

    /// Reset everything (previews / debug).
    func reset() {
        current = 0
        best = 0
        defaults.removeObject(forKey: Keys.lastDay)
    }

    // MARK: - Helpers

    private var storedLastDay: Int? {
        defaults.object(forKey: Keys.lastDay) as? Int
    }

    /// Whole-day number for a date, so "consecutive days" is a simple subtraction
    /// that ignores time of day and respects the user's calendar/timezone.
    private static func dayNumber(for date: Date) -> Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        return cal.ordinality(of: .day, in: .era, for: start) ?? 0
    }
}
