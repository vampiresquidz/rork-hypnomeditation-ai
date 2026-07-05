//
//  NarrationService.swift
//  HypnoFlow
//
//  Renders each script segment to an MP3 file using ElevenLabs text-to-speech
//  via the Rork proxy, and caches the results on disk.
//

import Foundation
import AVFoundation

enum NarrationError: LocalizedError {
    case notConfigured
    case authError
    case rateLimited
    case serverError(Int)
    case noAudio

    var errorDescription: String? {
        switch self {
        case .notConfigured: "AI features are not configured. Please restart the app."
        case .authError:     "AI features are currently unavailable. Please restart the app."
        case .rateLimited:   "Too many requests. Please wait a moment and try again."
        case .serverError:   "Something went wrong recording the narration. Please try again."
        case .noAudio:       "No narration audio was returned. Please try again."
        }
    }
}

struct NarrationService {
    private let modelId = "eleven_multilingual_v2"

    private var baseURL: String { Config.EXPO_PUBLIC_TOOLKIT_URL }
    private var secret: String { Config.EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY }

    /// Directory where rendered narration clips live for a session.
    static func sessionDirectory(for id: UUID) -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("sessions/\(id.uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Calm, consistent, slow hypnotic delivery.
    private var voiceSettings: [String: Any] {
        [
            "stability": 0.65,
            "similarity_boost": 0.75,
            "style": 0.15,
            "use_speaker_boost": true
        ]
    }

    /// Renders one line of narration and writes it to disk, returning the file name.
    func renderSegment(
        _ segment: ScriptSegment,
        voice: NarratorVoice,
        sessionID: UUID
    ) async throws -> String {
        // Prefer a directly-configured ElevenLabs key; otherwise use the Rork proxy.
        let directKey = Config.ELEVENLABS_API_KEY.trimmingCharacters(in: .whitespacesAndNewlines)

        var request: URLRequest
        if !directKey.isEmpty {
            let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voice.voiceId)?output_format=mp3_44100_128")!
            request = URLRequest(url: url)
            request.setValue(directKey, forHTTPHeaderField: "xi-api-key")
            request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        } else {
            guard !baseURL.isEmpty, !secret.isEmpty else { throw NarrationError.notConfigured }
            let url = URL(string: "\(baseURL)/v2/elevenlabs/v1/text-to-speech/\(voice.voiceId)")!
            request = URLRequest(url: url)
            request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = [
            "text": segment.text,
            "model_id": modelId,
            "voice_settings": voiceSettings
        ]

        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw NarrationError.serverError(-1) }

        switch http.statusCode {
        case 200: break
        case 401, 403: throw NarrationError.authError
        case 429: throw NarrationError.rateLimited
        default: throw NarrationError.serverError(http.statusCode)
        }

        guard !data.isEmpty else { throw NarrationError.noAudio }

        let fileName = "\(segment.id.uuidString).mp3"
        let dest = Self.sessionDirectory(for: sessionID).appendingPathComponent(fileName)
        try data.write(to: dest)
        return fileName
    }

    /// Stitches every rendered segment into one continuous narration track,
    /// inserting each segment's `pauseAfter` as real silence between the clips.
    /// Returns the file name of the exported `.m4a`, or throws on failure.
    func stitchSession(_ segments: [ScriptSegment], sessionID: UUID) async throws -> String {
        let dir = Self.sessionDirectory(for: sessionID)
        let composition = AVMutableComposition()
        guard let track = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else { throw NarrationError.noAudio }

        // Empty regions of a composition track render as silence, so we simply
        // advance the cursor by `pauseAfter` after inserting each clip.
        var cursor = CMTime.zero
        let scale: CMTimeScale = 44100

        for segment in segments {
            if let name = segment.audioFileName {
                let asset = AVURLAsset(url: dir.appendingPathComponent(name))
                if let assetTrack = try? await asset.loadTracks(withMediaType: .audio).first,
                   let duration = try? await asset.load(.duration),
                   duration.seconds > 0 {
                    try? track.insertTimeRange(
                        CMTimeRange(start: .zero, duration: duration),
                        of: assetTrack, at: cursor
                    )
                    cursor = CMTimeAdd(cursor, duration)
                }
            }
            if segment.pauseAfter > 0 {
                cursor = CMTimeAdd(cursor, CMTime(seconds: segment.pauseAfter, preferredTimescale: scale))
            }
        }

        guard cursor.seconds > 0 else { throw NarrationError.noAudio }

        let fileName = "session_full.m4a"
        let out = dir.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: out)

        guard let export = AVAssetExportSession(
            asset: composition, presetName: AVAssetExportPresetAppleM4A
        ) else { throw NarrationError.serverError(-2) }
        export.outputURL = out
        export.outputFileType = .m4a

        await withCheckedContinuation { continuation in
            export.exportAsynchronously { continuation.resume() }
        }

        guard export.status == .completed else {
            throw NarrationError.serverError(-3)
        }
        return fileName
    }
}
