//
//  SessionStore.swift
//  HypnoFlow
//
//  Owns the user's saved library and orchestrates generation
//  (script -> narration) with live progress reporting.
//

import Foundation
import SwiftUI

/// Live status while a session is being generated.
enum GenerationStage: Equatable {
    case idle
    case writing
    case recording(done: Int, total: Int)
    case finishing
    case failed(String)

    var headline: String {
        switch self {
        case .idle:        "Preparing"
        case .writing:     "Writing your session"
        case .recording:   "Recording the narration"
        case .finishing:   "Weaving in the soundscape"
        case .failed:      "Something interrupted us"
        }
    }

    var detail: String {
        switch self {
        case .idle:        "Getting things ready…"
        case .writing:     "Crafting a hypnosis journey just for you"
        case .recording(let done, let total):
            "Voicing line \(min(done + 1, total)) of \(total)"
        case .finishing:   "Almost there…"
        case .failed(let message): message
        }
    }
}

@MainActor
@Observable
final class SessionStore {
    private(set) var library: [MeditationSession] = []
    private(set) var stage: GenerationStage = .idle
    private(set) var isGenerating: Bool = false

    private let scriptService = HypnosisScriptService()
    private let narrationService = NarrationService()

    private let storeURL: URL = {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("library.json")
    }()

    init() {
        load()
    }

    // MARK: - Generation

    /// Generates a full session end-to-end. Returns the finished session on success.
    func generate(
        goal: HypnosisGoal,
        intention: String,
        durationMinutes: Int,
        voice: NarratorVoice,
        soundscape: Soundscape
    ) async -> MeditationSession? {
        isGenerating = true
        stage = .writing
        defer { isGenerating = false }

        do {
            let (title, rawSegments) = try await scriptService.generate(
                goal: goal,
                intention: intention,
                durationMinutes: durationMinutes
            )

            var session = MeditationSession(
                title: title,
                goal: goal,
                voice: voice,
                soundscape: soundscape,
                intention: intention,
                durationMinutes: durationMinutes,
                segments: rawSegments
            )

            stage = .recording(done: 0, total: session.segments.count)

            // Render narration sequentially to keep a calm, ordered progress bar
            // and avoid hammering the TTS endpoint.
            for index in session.segments.indices {
                let fileName = try await narrationService.renderSegment(
                    session.segments[index],
                    voice: voice,
                    sessionID: session.id
                )
                session.segments[index].audioFileName = fileName
                stage = .recording(done: index + 1, total: session.segments.count)
            }

            stage = .finishing

            // Stitch the individual clips into one continuous track with the
            // pauses baked in as silence. Falls back to per-segment playback
            // if stitching fails for any reason.
            session.stitchedAudioFileName = try? await narrationService.stitchSession(
                session.segments, sessionID: session.id
            )

            try? await Task.sleep(for: .milliseconds(400))

            insert(session)
            stage = .idle
            return session
        } catch {
            let message = (error as? LocalizedError)?.errorDescription
                ?? "Please check your connection and try again."
            stage = .failed(message)
            return nil
        }
    }

    func resetStage() {
        stage = .idle
    }

    // MARK: - Library

    func insert(_ session: MeditationSession) {
        library.insert(session, at: 0)
        persist()
    }

    func delete(_ session: MeditationSession) {
        library.removeAll { $0.id == session.id }
        try? FileManager.default.removeItem(at: NarrationService.sessionDirectory(for: session.id))
        persist()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let decoded = try? JSONDecoder().decode([MeditationSession].self, from: data) else {
            return
        }
        library = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(library) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }
}
