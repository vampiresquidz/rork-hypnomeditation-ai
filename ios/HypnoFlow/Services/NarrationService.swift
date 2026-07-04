//
//  NarrationService.swift
//  HypnoFlow
//
//  Renders each script segment to an MP3 file using ElevenLabs text-to-speech
//  via the Rork proxy, and caches the results on disk.
//

import Foundation

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

    /// Renders one line of narration and writes it to disk, returning the file name.
    func renderSegment(
        _ segment: ScriptSegment,
        voice: NarratorVoice,
        sessionID: UUID
    ) async throws -> String {
        guard !baseURL.isEmpty, !secret.isEmpty else { throw NarrationError.notConfigured }

        let url = URL(string: "\(baseURL)/v2/elevenlabs/v1/text-to-speech/\(voice.voiceId)")!

        let body: [String: Any] = [
            "text": segment.text,
            "model_id": modelId,
            "voice_settings": [
                // Calm, consistent, slow hypnotic delivery.
                "stability": 0.65,
                "similarity_boost": 0.75,
                "style": 0.15,
                "use_speaker_boost": true
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
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
}
