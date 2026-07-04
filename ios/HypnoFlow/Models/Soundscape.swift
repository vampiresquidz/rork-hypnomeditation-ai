//
//  Soundscape.swift
//  HypnoFlow
//

import Foundation

/// A bundled ambient music bed that plays under the narration.
enum Soundscape: String, CaseIterable, Codable, Identifiable {
    case dream
    case deepSleep
    case focus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dream:     "Dream Pads"
        case .deepSleep: "Deep Sleep"
        case .focus:     "Clear Sky"
        }
    }

    var detail: String {
        switch self {
        case .dream:     "Warm, floating ambience"
        case .deepSleep: "Low, enveloping night drone"
        case .focus:     "Airy, uplifting calm"
        }
    }

    var symbol: String {
        switch self {
        case .dream:     "sparkles"
        case .deepSleep: "moon.zzz.fill"
        case .focus:     "cloud.sun.fill"
        }
    }

    /// Bundled resource name (auto-bundled ambient asset).
    var resource: String {
        switch self {
        case .dream:     "ethereal_ambient_meditation"
        case .deepSleep: "deep_sleep_ambient_drone"
        case .focus:     "ambient_focus_pad"
        }
    }
}
