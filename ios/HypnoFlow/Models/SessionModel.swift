//
//  SessionModel.swift
//  HypnoFlow
//
//  The persisted, CloudKit-synced record for a generated session. This is the
//  SwiftData `@Model` the whole app reads from (via @Query) and writes to.
//
//  CloudKit imposes a few schema rules that shape this model:
//   • every stored property must be optional or have a default value,
//   • no unique constraints (so `id` is a plain attribute, not `.unique`),
//   • no non-optional relationships.
//  We keep the script (lines/pauses/phases) as an encoded blob because it's a
//  value object we never query into — simpler and fully CloudKit-safe.
//
//  Audio itself is NOT stored here: rendered clips live on disk in Caches,
//  keyed by `id`. The record syncs across devices; the audio is per-device.
//

import Foundation
import SwiftData

@Model
final class SessionModel {
    // Stored (persisted + synced). All have defaults for CloudKit.
    var id: UUID = UUID()
    var title: String = ""
    var createdAt: Date = Date.now
    var intention: String = ""
    var durationMinutes: Int = 10

    // Enums persist by their String raw value — CloudKit-friendly scalars.
    var goalRaw: String = HypnosisGoal.calm.rawValue
    var voiceRaw: String = NarratorVoice.george.rawValue
    var soundscapeRaw: String = Soundscape.dream.rawValue

    /// File name of the single stitched narration track (nil = play per-segment).
    var stitchedAudioFileName: String?

    /// The script encoded as JSON. Accessed through `segments` below.
    var segmentsData: Data = Data()

    init(
        id: UUID = UUID(),
        title: String,
        goal: HypnosisGoal,
        voice: NarratorVoice,
        soundscape: Soundscape,
        intention: String,
        durationMinutes: Int,
        segments: [ScriptSegment],
        stitchedAudioFileName: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.goalRaw = goal.rawValue
        self.voiceRaw = voice.rawValue
        self.soundscapeRaw = soundscape.rawValue
        self.intention = intention
        self.durationMinutes = durationMinutes
        self.stitchedAudioFileName = stitchedAudioFileName
        self.createdAt = createdAt
        self.segments = segments   // encodes into segmentsData
    }

    // MARK: - Typed accessors (computed → not persisted separately)

    var goal: HypnosisGoal { HypnosisGoal(rawValue: goalRaw) ?? .calm }
    var voice: NarratorVoice { NarratorVoice(rawValue: voiceRaw) ?? .george }
    var soundscape: Soundscape { Soundscape(rawValue: soundscapeRaw) ?? .dream }

    /// The spoken lines + pauses + phases. Backed by `segmentsData`.
    var segments: [ScriptSegment] {
        get { (try? JSONDecoder().decode([ScriptSegment].self, from: segmentsData)) ?? [] }
        set { segmentsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    /// Estimated total run time (spoken words + pauses).
    var estimatedSeconds: Double {
        segments.reduce(0) { total, seg in
            let words = Double(seg.text.split(separator: " ").count)
            return total + (words / 2.2) + seg.pauseAfter
        }
    }
}

#if DEBUG
extension ModelContainer {
    /// In-memory container for SwiftUI previews.
    @MainActor static let preview: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: SessionModel.self, configurations: config)
    }()
}
#endif
