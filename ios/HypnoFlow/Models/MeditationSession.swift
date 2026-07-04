//
//  MeditationSession.swift
//  HypnoFlow
//

import Foundation

/// A single spoken line plus the silent pause that follows it.
/// Pauses are where the "space" of a hypnosis session lives.
struct ScriptSegment: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    /// The words the narrator speaks.
    var text: String
    /// Seconds of silence after this line before the next begins.
    var pauseAfter: Double

    /// Local file name of the rendered narration audio (in the app's caches dir).
    var audioFileName: String?
}

/// The narrator voice used to render a session.
enum NarratorVoice: String, CaseIterable, Codable, Identifiable {
    case george
    case brian
    case brittney

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .george:   "Elias"
        case .brian:    "Marcus"
        case .brittney: "Aria"
        }
    }

    var descriptor: String {
        switch self {
        case .george:   "Warm British guide"
        case .brian:    "Deep, grounding tone"
        case .brittney: "Soft, soothing calm"
        }
    }

    /// ElevenLabs voice id.
    var voiceId: String {
        switch self {
        case .george:   "JBFqnCBsd6RMkjVDRZzb"
        case .brian:    "nPczCjzI2devNBz1zQrb"
        case .brittney: "pjcYQlDFKMbcOUp6F5GD"
        }
    }
}

/// A fully generated, playable hypnosis session.
struct MeditationSession: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var goal: HypnosisGoal
    var voice: NarratorVoice
    var soundscape: Soundscape
    var intention: String
    var durationMinutes: Int
    var segments: [ScriptSegment]
    var createdAt: Date = Date()

    /// Estimated total run time (spoken words + pauses).
    var estimatedSeconds: Double {
        segments.reduce(0) { total, seg in
            let words = Double(seg.text.split(separator: " ").count)
            // Hypnosis narration is slow: ~2.2 words/sec.
            return total + (words / 2.2) + seg.pauseAfter
        }
    }
}
