//
//  SessionStore.swift
//  HypnoFlow
//
//  Orchestrates generation (script -> narration -> stitch) with live progress
//  and writes finished sessions into SwiftData. The saved library itself is read
//  by the views via @Query, so this type no longer holds the array — SwiftData
//  (and CloudKit) are the single source of truth.
//

import Foundation
import SwiftData

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
    private(set) var stage: GenerationStage = .idle
    private(set) var isGenerating: Bool = false

    private let scriptService = HypnosisScriptService()
    private let narrationService = NarrationService()

    /// The SwiftData context finished sessions are written into. Shared with the
    /// container's mainContext, so @Query views update the moment we insert.
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    #if DEBUG
    /// Convenience for previews — spins up an in-memory store.
    convenience init() {
        let container = try! ModelContainer(
            for: SessionModel.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        self.init(context: container.mainContext)
    }
    #endif

    // MARK: - Generation

    /// Generates a full session end-to-end and persists it. Returns it on success.
    func generate(
        goal: HypnosisGoal,
        intention: String,
        durationMinutes: Int,
        voice: NarratorVoice,
        soundscape: Soundscape
    ) async -> SessionModel? {
        isGenerating = true
        stage = .writing
        defer { isGenerating = false }

        do {
            let (title, rawSegments) = try await scriptService.generate(
                goal: goal,
                intention: intention,
                durationMinutes: durationMinutes
            )

            // One id keys both the model and its on-disk audio directory.
            let sessionID = UUID()
            var segments = rawSegments

            stage = .recording(done: 0, total: segments.count)

            // Render narration sequentially — a calm, ordered progress bar and
            // no hammering the TTS endpoint. Build the finished array locally so
            // we only touch SwiftData once, at the end.
            for index in segments.indices {
                let fileName = try await narrationService.renderSegment(
                    segments[index],
                    voice: voice,
                    sessionID: sessionID
                )
                segments[index].audioFileName = fileName
                stage = .recording(done: index + 1, total: segments.count)
            }

            stage = .finishing

            // Stitch clips into one continuous track (pauses baked in as silence).
            let stitched = try? await narrationService.stitchSession(segments, sessionID: sessionID)

            try? await Task.sleep(for: .milliseconds(400))

            let session = SessionModel(
                id: sessionID,
                title: title,
                goal: goal,
                voice: voice,
                soundscape: soundscape,
                intention: intention,
                durationMinutes: durationMinutes,
                segments: segments,
                stitchedAudioFileName: stitched
            )
            context.insert(session)
            try? context.save()

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

    func delete(_ session: SessionModel) {
        // Remove the rendered audio for this session, then the record.
        try? FileManager.default.removeItem(at: NarrationService.sessionDirectory(for: session.id))
        context.delete(session)
        try? context.save()
    }
}
