//
//  ReminderManager.swift
//  HypnoFlow
//
//  Schedules Professor Jelly's daily "take a moment for yourself" reminder.
//
//  The design borrows the trick every good habit app (Duolingo especially) uses:
//  a *repeating* local notification can only carry one fixed message, which gets
//  stale fast and starts feeling like spam. So instead of one repeating trigger,
//  we pre-schedule a rolling window of one-shot notifications — one per day for
//  the next two weeks — each with its own rotating, emotion-appropriate copy and
//  a matching Professor Jelly reaction badge as its thumbnail. Every time the app
//  launches we tear the window down and rebuild it, so the queue always stays
//  fresh and two weeks deep even if the user doesn't open the app for a while.
//
//  Tone follows the time of day the user chose to unwind: a bedtime slot gets the
//  sleepy Jelly and "drift off" copy; a morning slot gets the bright, excited one.
//  Within a tone we rotate through several lines so no two days read the same.
//

import Foundation
import UserNotifications

@Observable
@MainActor
final class ReminderManager {

    // MARK: Persisted preferences

    /// Whether the user wants the daily nudge at all.
    private(set) var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Keys.enabled) }
    }
    /// Hour (0–23) the reminder fires.
    private(set) var hour: Int {
        didSet { defaults.set(hour, forKey: Keys.hour) }
    }
    /// Minute (0–59) the reminder fires.
    private(set) var minute: Int {
        didSet { defaults.set(minute, forKey: Keys.minute) }
    }

    /// The latest known system authorization status (refreshed on demand).
    private(set) var authorization: UNAuthorizationStatus = .notDetermined

    /// A `Date` today at the chosen hour/minute — handy for a DatePicker binding.
    var timeOfDay: Date {
        Calendar.current.date(
            bySettingHour: hour, minute: minute, second: 0, of: Date()
        ) ?? Date()
    }

    private let defaults: UserDefaults
    private let center = UNUserNotificationCenter.current()

    /// How many days ahead we keep the queue filled.
    private let windowDays = 14
    /// Identifier prefix so we only ever clear *our* pending requests.
    private let idPrefix = "hypnoflow.reminder."

    private enum Keys {
        static let enabled = "reminder.enabled"
        static let hour = "reminder.hour"
        static let minute = "reminder.minute"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.bool(forKey: Keys.enabled)
        // Default to a sensible 8:00 PM until onboarding tells us otherwise.
        hour = defaults.object(forKey: Keys.hour) as? Int ?? 20
        minute = defaults.object(forKey: Keys.minute) as? Int ?? 0
    }

    // MARK: - Authorization

    /// Ask the system for permission. Returns whether we ended up authorized.
    @discardableResult
    func requestAuthorization() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        await refreshAuthorization()
        return granted
    }

    /// Sync `authorization` with the system's current setting.
    func refreshAuthorization() async {
        let settings = await center.notificationSettings()
        authorization = settings.authorizationStatus
    }

    // MARK: - Public controls

    /// Turn reminders on at a given time, requesting permission if needed.
    /// Returns whether reminders are now active.
    @discardableResult
    func enable(at date: Date? = nil) async -> Bool {
        if let date { setTimeComponents(from: date) }

        await refreshAuthorization()
        if authorization == .notDetermined {
            _ = await requestAuthorization()
        }
        guard authorization == .authorized || authorization == .provisional else {
            isEnabled = false
            return false
        }

        isEnabled = true
        await reschedule()
        return true
    }

    /// Turn reminders off and clear the queue.
    func disable() {
        isEnabled = false
        clearPending()
    }

    /// Celebrate a practice-streak milestone with a proud one-off notification the
    /// next day at the usual reminder time, nudging the user to keep it alive. It
    /// reuses the next day's reminder slot (same identifier replaces it) so the
    /// user never gets two pings at once. No-op unless reminders are on.
    func celebrate(streak: Int) async {
        await refreshAuthorization()
        guard isEnabled,
              authorization == .authorized || authorization == .provisional else { return }

        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()),
              let fireDate = calendar.date(
                  bySettingHour: hour, minute: minute, second: 0, of: tomorrow
              )
        else { return }

        let content = UNMutableNotificationContent()
        content.title = "🔥 \(streak)-day streak!"
        content.body = "Professor Jelly is so proud of you. Keep the streak alive with today's session?"
        content.sound = .default
        content.threadIdentifier = "hypnoflow.daily-reminder"
        content.categoryIdentifier = "DAILY_REMINDER"
        if let attachment = ReminderTone.celebrate.attachment() {
            content.attachments = [attachment]
        }

        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        // Reuse the day-1 slot id so this replaces tomorrow's ordinary nudge.
        let request = UNNotificationRequest(
            identifier: idPrefix + "1", content: content, trigger: trigger
        )
        try? await center.add(request)
    }

    /// Change the fire time (reschedules if enabled).
    func updateTime(_ date: Date) async {
        setTimeComponents(from: date)
        if isEnabled { await reschedule() }
    }

    /// Adopt the reminder time implied by an onboarding "unwind time" answer,
    /// unless the user has already picked a time of their own.
    func adoptSuggestedTime(_ unwind: UnwindTime?) {
        guard defaults.object(forKey: Keys.hour) == nil, let unwind else { return }
        hour = unwind.suggestedHour
        minute = 0
    }

    /// Rebuild the rolling two-week window. Safe to call on every launch.
    func refreshScheduleIfNeeded() async {
        await refreshAuthorization()
        // If the user revoked permission in Settings, reflect that.
        if isEnabled && authorization != .authorized && authorization != .provisional {
            isEnabled = false
        }
        if isEnabled { await reschedule() }
    }

    // MARK: - Scheduling

    private func setTimeComponents(from date: Date) {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        hour = comps.hour ?? hour
        minute = comps.minute ?? minute
    }

    private func clearPending() {
        let ids = (0..<windowDays).map { idPrefix + String($0) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Fresh two-week window of one-shot daily reminders, each with rotating copy
    /// and its matching Professor Jelly reaction badge.
    private func reschedule() async {
        clearPending()

        let calendar = Calendar.current
        let now = Date()

        for dayOffset in 0..<windowDays {
            guard let base = calendar.date(byAdding: .day, value: dayOffset, to: now),
                  let fireDate = calendar.date(
                      bySettingHour: hour, minute: minute, second: 0, of: base
                  ), fireDate > now
            else { continue }

            // Rotate tone/copy by absolute day so the sequence never repeats
            // two identical days back to back.
            let dayIndex = calendar.ordinality(of: .day, in: .era, for: fireDate) ?? dayOffset
            let message = ReminderCopy.message(forDayIndex: dayIndex, hour: hour)

            let content = UNMutableNotificationContent()
            content.title = message.title
            content.body = message.body
            content.sound = .default
            content.threadIdentifier = "hypnoflow.daily-reminder"
            content.categoryIdentifier = "DAILY_REMINDER"
            if let attachment = message.tone.attachment() {
                content.attachments = [attachment]
            }

            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(
                identifier: idPrefix + String(dayOffset),
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }
}
