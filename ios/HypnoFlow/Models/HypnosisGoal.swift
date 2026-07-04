//
//  HypnosisGoal.swift
//  HypnoFlow
//

import SwiftUI

/// A high-level intention the user can build a hypnosis session around.
enum HypnosisGoal: String, CaseIterable, Codable, Identifiable {
    case sleep
    case confidence
    case anxiety
    case focus
    case habit
    case calm

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sleep:      "Deep Sleep"
        case .confidence: "Unshakable Confidence"
        case .anxiety:    "Release Anxiety"
        case .focus:      "Laser Focus"
        case .habit:      "Break a Habit"
        case .calm:       "Total Calm"
        }
    }

    var shortTitle: String {
        switch self {
        case .sleep:      "Sleep"
        case .confidence: "Confidence"
        case .anxiety:    "Anxiety"
        case .focus:      "Focus"
        case .habit:      "Habits"
        case .calm:       "Calm"
        }
    }

    var subtitle: String {
        switch self {
        case .sleep:      "Drift into a deep, restorative rest"
        case .confidence: "Step into your most powerful self"
        case .anxiety:    "Let tension dissolve and soften"
        case .focus:      "Sharpen the mind, quiet the noise"
        case .habit:      "Reprogram an old pattern for good"
        case .calm:       "Return to a still, centered place"
        }
    }

    var symbol: String {
        switch self {
        case .sleep:      "moon.stars.fill"
        case .confidence: "flame.fill"
        case .anxiety:    "wind"
        case .focus:      "scope"
        case .habit:      "arrow.triangle.2.circlepath"
        case .calm:       "leaf.fill"
        }
    }

    var tint: Color {
        switch self {
        case .sleep:      Color(red: 0.42, green: 0.45, blue: 0.95)
        case .confidence: Theme.amber
        case .anxiety:    Theme.teal
        case .focus:      Color(red: 0.55, green: 0.80, blue: 0.95)
        case .habit:      Color(red: 0.80, green: 0.55, blue: 0.95)
        case .calm:       Color(red: 0.55, green: 0.85, blue: 0.62)
        }
    }

    /// Default soundscape paired with this goal.
    var soundscape: Soundscape {
        switch self {
        case .sleep:      .deepSleep
        case .confidence: .focus
        case .anxiety:    .dream
        case .focus:      .focus
        case .habit:      .dream
        case .calm:       .dream
        }
    }
}
