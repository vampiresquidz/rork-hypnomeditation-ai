//
//  SessionMigration.swift
//  HypnoFlow
//
//  One-time import of the pre-SwiftData library. Older builds stored the whole
//  library as `library.json` in Documents; this lifts those sessions into
//  SwiftData on first launch so nobody loses anything, then sets the audio aside.
//

import Foundation
import SwiftData

enum SessionMigration {
    private static let flagKey = "migration.libraryJSONToSwiftData.done"

    @MainActor
    static func runIfNeeded(context: ModelContext) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: flagKey) else { return }

        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let jsonURL = base.appendingPathComponent("library.json")

        defer { defaults.set(true, forKey: flagKey) }

        guard
            let data = try? Data(contentsOf: jsonURL),
            let legacy = try? JSONDecoder().decode([MeditationSession].self, from: data),
            !legacy.isEmpty
        else { return }

        for old in legacy {
            let model = SessionModel(
                id: old.id,
                title: old.title,
                goal: old.goal,
                voice: old.voice,
                soundscape: old.soundscape,
                intention: old.intention,
                durationMinutes: old.durationMinutes,
                segments: old.segments,
                stitchedAudioFileName: old.stitchedAudioFileName,
                createdAt: old.createdAt
            )
            context.insert(model)
        }
        try? context.save()

        // Keep the original as a backup rather than deleting outright.
        let backup = base.appendingPathComponent("library.migrated.json")
        try? FileManager.default.removeItem(at: backup)
        try? FileManager.default.moveItem(at: jsonURL, to: backup)
    }
}
