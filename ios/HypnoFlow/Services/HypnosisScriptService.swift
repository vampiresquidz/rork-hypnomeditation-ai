//
//  HypnosisScriptService.swift
//  HypnoFlow
//
//  Generates a personalized hypnosis / meditation script by asking a
//  language model (via the Rork AI proxy) to return structured segments.
//

import Foundation

enum ScriptError: LocalizedError {
    case notConfigured
    case authError
    case rateLimited
    case serverError(Int)
    case emptyResponse
    case badFormat

    var errorDescription: String? {
        switch self {
        case .notConfigured: "AI features are not configured. Please restart the app."
        case .authError:     "AI features are currently unavailable. Please restart the app."
        case .rateLimited:   "Too many requests. Please wait a moment and try again."
        case .serverError:   "Something went wrong while writing your session. Please try again."
        case .emptyResponse: "No script was returned. Please try again."
        case .badFormat:     "The session couldn't be prepared. Please try again."
        }
    }
}

/// One line as returned by the model before we attach audio.
private struct RawSegment: Codable {
    let text: String
    let pause: Double
}

private struct RawScript: Codable {
    let title: String
    let segments: [RawSegment]
}

struct HypnosisScriptService {
    private let model = "anthropic/claude-sonnet-4"

    private var baseURL: String { Config.EXPO_PUBLIC_TOOLKIT_URL }
    private var secret: String { Config.EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY }

    /// Produces a complete, structured hypnosis script for the given request.
    func generate(
        goal: HypnosisGoal,
        intention: String,
        durationMinutes: Int
    ) async throws -> (title: String, segments: [ScriptSegment]) {
        guard !baseURL.isEmpty, !secret.isEmpty else { throw ScriptError.notConfigured }

        let url = URL(string: "\(baseURL)/v2/vercel/v1/chat/completions")!

        let system = Self.systemPrompt(durationMinutes: durationMinutes)
        let user = Self.userPrompt(goal: goal, intention: intention, durationMinutes: durationMinutes)

        let body: [String: Any] = [
            "model": model,
            "temperature": 0.85,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ScriptError.serverError(-1) }

        switch http.statusCode {
        case 200: break
        case 401, 403: throw ScriptError.authError
        case 429: throw ScriptError.rateLimited
        default: throw ScriptError.serverError(http.statusCode)
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"] as? String,
            !content.isEmpty
        else { throw ScriptError.emptyResponse }

        let raw = try Self.parse(content)
        let segments = raw.segments.map {
            ScriptSegment(text: $0.text.trimmingCharacters(in: .whitespacesAndNewlines),
                          pauseAfter: max(0, min($0.pause, 25)))
        }
        .filter { !$0.text.isEmpty }

        guard !segments.isEmpty else { throw ScriptError.badFormat }
        let title = raw.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return (title.isEmpty ? goal.title : title, segments)
    }

    // MARK: - Prompts

    private static func systemPrompt(durationMinutes: Int) -> String {
        """
        You are a world-class clinical hypnotherapist and meditation guide, in the style of \
        elite mindset coaches who work with high performers. You write deeply calming, \
        immersive hypnotic inductions with a warm, slow, permissive tone.

        Your voice: unhurried, soothing, confident, second person ("you"). Use classic \
        hypnotic language patterns — progressive relaxation, breath pacing, deepeners, \
        embedded suggestions, vivid sensory imagery, and gentle counting inductions. \
        Never sound clinical or robotic. Never mention that you are an AI.

        You MUST respond with ONLY valid JSON (no markdown, no code fences) in exactly this shape:
        {
          "title": "a short evocative session title (max 5 words)",
          "segments": [
            { "text": "one or two spoken sentences", "pause": 4 }
          ]
        }

        Rules:
        - "pause" is the seconds of silence AFTER that line (a number from 1 to 20). \
          Use longer pauses (8-18) during deep relaxation and imagery, shorter (1-4) during induction patter.
        - Keep each segment to 1-2 short sentences so it can be spoken slowly.
        - Open with a settling-in and a slow breathing induction.
        - Include a countdown deepener (counting down from 5 or 10, one number region per segment).
        - Weave in the user's specific intention as positive, present-tense suggestions.
        - End by gently guiding them either toward sleep or back to gentle awareness \
          depending on the goal.
        - Target roughly \(durationMinutes) minutes of total experience including pauses.
        """
    }

    private static func userPrompt(goal: HypnosisGoal, intention: String, durationMinutes: Int) -> String {
        let intentionLine = intention.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "No extra detail provided — craft a universally resonant session for this goal."
            : "Their personal intention in their own words: \"\(intention)\""

        return """
        Create a \(durationMinutes)-minute hypnosis session.
        Goal: \(goal.title) — \(goal.subtitle).
        \(intentionLine)

        Respond with the JSON object only.
        """
    }

    private static func parse(_ content: String) throws -> RawScript {
        // Strip any accidental code fences and isolate the JSON object.
        var cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            cleaned = cleaned.replacingOccurrences(of: "```json", with: "")
            cleaned = cleaned.replacingOccurrences(of: "```", with: "")
            cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let start = cleaned.firstIndex(of: "{"), let end = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[start...end])
        }
        guard let data = cleaned.data(using: .utf8),
              let raw = try? JSONDecoder().decode(RawScript.self, from: data) else {
            throw ScriptError.badFormat
        }
        return raw
    }
}
