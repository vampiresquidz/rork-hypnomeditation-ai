//
//  ReminderCopy.swift
//  HypnoFlow
//
//  The words and faces of Professor Jelly's reminders. Each notification carries
//  an emotional *tone*, and every tone maps to one of Jelly's reaction badges
//  (the Duolingo-style square icons) plus a small pool of copy lines written in
//  that mood. A daily reminder picks its tone from the time of day, then rotates
//  through the pool so the nudges feel like a character checking in, not a cron
//  job firing the same string forever.
//

import Foundation
import UserNotifications

/// The emotional register of a reminder — each backed by a Professor Jelly badge.
enum ReminderTone: String, CaseIterable {
    case happy      // bright, friendly check-in
    case excited    // eager, "let's go"
    case zen        // calm, mindful
    case hypnotic   // "ready to drop in?"
    case sleepy     // wind down, drift off
    case love       // warm, "made this for you"
    case celebrate  // streaks & milestones
    case pleading   // gentle "we miss you"

    /// The bundled badge image file (see Resources/NotificationBadges).
    var badgeResource: String { "badge-\(rawValue)" }

    /// Build a notification attachment from the tone's badge, if present.
    func attachment() -> UNNotificationAttachment? {
        guard let url = Bundle.main.url(
            forResource: badgeResource, withExtension: "jpg",
            subdirectory: "NotificationBadges"
        ) ?? Bundle.main.url(forResource: badgeResource, withExtension: "jpg")
        else { return nil }

        let options = [UNNotificationAttachmentOptionsThumbnailHiddenKey: false]
        return try? UNNotificationAttachment(
            identifier: badgeResource, url: url, options: options
        )
    }
}

/// A single reminder: a tone (which face) plus the title/body to show.
struct ReminderMessage {
    let tone: ReminderTone
    let title: String
    let body: String
}

enum ReminderCopy {

    /// Pick a message for a given absolute day index and fire hour. The hour sets
    /// the mood (morning = bright, night = sleepy); the day index rotates the
    /// specific line and occasionally swaps in a warmer tone for variety.
    static func message(forDayIndex dayIndex: Int, hour: Int) -> ReminderMessage {
        let pool = tonePool(for: hour)
        let tone = pool[dayIndex % pool.count]
        let lines = lines(for: tone)
        // Offset the line rotation by the day so tone+line don't move in lockstep.
        let line = lines[(dayIndex / pool.count) % lines.count]
        return ReminderMessage(tone: tone, title: line.title, body: line.body)
    }

    /// A message in a specific tone (used for one-off notifications like a
    /// milestone celebration).
    static func message(tone: ReminderTone, variant: Int = 0) -> ReminderMessage {
        let lines = lines(for: tone)
        let line = lines[variant % lines.count]
        return ReminderMessage(tone: tone, title: line.title, body: line.body)
    }

    // MARK: - Tone rotation by time of day

    private static func tonePool(for hour: Int) -> [ReminderTone] {
        switch hour {
        case 5..<11:   return [.happy, .excited, .zen, .love]         // morning
        case 11..<16:  return [.happy, .zen, .hypnotic, .love]        // afternoon
        case 16..<21:  return [.zen, .hypnotic, .happy, .love]        // evening
        default:       return [.sleepy, .zen, .hypnotic, .love]       // night / late
        }
    }

    // MARK: - Copy pools

    private static func lines(for tone: ReminderTone) -> [(title: String, body: String)] {
        switch tone {
        case .happy:
            return [
                ("Professor Jelly is ready 🪼", "Two minutes of calm is waiting whenever you are."),
                ("Your daily moment", "Let's make a little pocket of quiet together."),
                ("Knock knock", "It's Professor Jelly — time for your session?"),
            ]
        case .excited:
            return [
                ("Let's do this ✨", "A fresh session, made just for you. Tap to begin."),
                ("Ooh, good timing!", "Professor Jelly's been waiting to guide you today."),
            ]
        case .zen:
            return [
                ("Take a breath", "One slow breath in… and out. Ready when you are."),
                ("A quiet minute", "Set everything down for a moment with Professor Jelly."),
                ("Room to unwind", "Your calm is one tap away."),
            ]
        case .hypnotic:
            return [
                ("Ready to drop in? 🌀", "Professor Jelly's watch is swinging. Shall we?"),
                ("Feeling heavy-eyed?", "Let's ease you down into a deeper calm."),
                ("Your session awaits", "Follow the watch… and let the day melt away."),
            ]
        case .sleepy:
            return [
                ("Time to drift off 😴", "Let Professor Jelly guide you gently to sleep."),
                ("Winding down", "Tuck in — your bedtime session is ready."),
                ("Sweet dreams soon", "A calm count-down into deep, natural rest."),
            ]
        case .love:
            return [
                ("Made something for you 💜", "Professor Jelly saved a moment of calm with your name on it."),
                ("Thinking of you", "A little peace, whenever you need it today."),
            ]
        case .celebrate:
            return [
                ("Look at you go! 🎉", "Another day of calm in the books. Keep the streak alive?"),
                ("Milestone unlocked", "Professor Jelly is so proud. One more session today?"),
            ]
        case .pleading:
            return [
                ("We miss you 🥺", "Professor Jelly kept your spot warm. Come drift with him?"),
                ("It's been a while", "Just two minutes of calm — your mind will thank you."),
            ]
        }
    }
}
