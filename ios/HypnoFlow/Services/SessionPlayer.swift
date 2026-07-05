//
//  SessionPlayer.swift
//  HypnoFlow
//
//  Plays a generated session: sequences narration clips with timed pauses,
//  layered over a looping ambient soundscape, plus start/end singing bowls.
//

import AVFoundation
import SwiftUI

@MainActor
@Observable
final class SessionPlayer: NSObject {
    // Playback state
    private(set) var isPlaying: Bool = false
    private(set) var isFinished: Bool = false
    private(set) var currentIndex: Int = 0
    private(set) var currentLine: String = ""
    private(set) var currentPhase: SessionPhase = .induction
    private(set) var elapsed: Double = 0
    private(set) var total: Double = 1

    var progress: Double { total > 0 ? min(elapsed / total, 1) : 0 }

    private var session: MeditationSession?
    private var narrationPlayer: AVAudioPlayer?
    private var ambientPlayer: AVAudioPlayer?
    private var chimePlayer: AVAudioPlayer?

    /// True when playing a single pre-stitched track rather than sequencing clips.
    private var singleFile = false
    private var segmentDurations: [Double] = []
    /// Absolute start time (seconds) of each segment's speech on the timeline.
    private var segmentStarts: [Double] = []
    private var advanceTask: Task<Void, Never>?
    private var ticker: Timer?

    private let ambientVolume: Float = 0.32

    // MARK: - Loading

    func load(_ session: MeditationSession) {
        stop()
        self.session = session
        self.isFinished = false
        self.currentIndex = 0
        self.elapsed = 0
        self.singleFile = false
        self.currentLine = session.segments.first?.text ?? ""
        self.currentPhase = session.segments.first?.phase ?? .induction

        configureAudioSession()
        prepareAmbient(session.soundscape)
        prepareChime()

        let dir = NarrationService.sessionDirectory(for: session.id)

        // Precompute per-segment durations (speech + pause) for the progress bar
        // and the absolute start time of each segment on the timeline.
        segmentDurations = session.segments.map { seg in
            var speak = estimatedSpokenDuration(seg.text)
            if let name = seg.audioFileName,
               let player = try? AVAudioPlayer(contentsOf: dir.appendingPathComponent(name)) {
                speak = player.duration
            }
            return speak + seg.pauseAfter
        }
        segmentStarts = []
        var acc = 0.0
        for d in segmentDurations {
            segmentStarts.append(acc)
            acc += d
        }
        total = max(acc, 1)

        // Prefer the single stitched track when it exists — smoother playback.
        if let name = session.stitchedAudioFileName,
           let player = try? AVAudioPlayer(contentsOf: dir.appendingPathComponent(name)) {
            player.delegate = self
            player.prepareToPlay()
            narrationPlayer = player
            total = max(player.duration, 1)
            singleFile = true
        }
    }

    // MARK: - Controls

    func play() {
        guard let session, !session.segments.isEmpty else { return }
        if isFinished { load(session) }
        isPlaying = true
        try? AVAudioSession.sharedInstance().setActive(true)
        fadeAmbient(to: ambientVolume)
        ambientPlayer?.play()
        startTicker()

        if singleFile {
            // Soft opening bowl only at the very start (not on resume).
            if (narrationPlayer?.currentTime ?? 0) < 0.05 { playChime() }
            narrationPlayer?.play()
        } else if narrationPlayer == nil {
            // Fresh start: soft opening bowl, then begin.
            playChime()
            speakCurrentSegment()
        } else {
            narrationPlayer?.play()
        }
    }

    func pause() {
        isPlaying = false
        narrationPlayer?.pause()
        advanceTask?.cancel()
        stopTicker()
        fadeAmbient(to: 0.12)
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func stop() {
        advanceTask?.cancel()
        advanceTask = nil
        stopTicker()
        narrationPlayer?.stop()
        narrationPlayer = nil
        ambientPlayer?.stop()
        ambientPlayer = nil
        isPlaying = false
        singleFile = false
    }

    // MARK: - Sequencing

    private func speakCurrentSegment() {
        guard let session, currentIndex < session.segments.count else {
            finish()
            return
        }
        let segment = session.segments[currentIndex]
        currentLine = segment.text
        currentPhase = segment.phase ?? .journey

        let dir = NarrationService.sessionDirectory(for: session.id)
        if let name = segment.audioFileName {
            let url = dir.appendingPathComponent(name)
            if let player = try? AVAudioPlayer(contentsOf: url) {
                player.delegate = self
                player.prepareToPlay()
                narrationPlayer = player
                player.play()
                return
            }
        }
        // No audio for this line — just honor its pause, then continue.
        scheduleAdvance(after: estimatedSpokenDuration(segment.text) + segment.pauseAfter)
    }

    private func handleNarrationFinished() {
        guard let session, isPlaying else { return }
        let pause = currentIndex < session.segments.count ? session.segments[currentIndex].pauseAfter : 0
        scheduleAdvance(after: pause)
    }

    private func scheduleAdvance(after seconds: Double) {
        advanceTask?.cancel()
        advanceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(0, seconds)))
            guard let self, !Task.isCancelled else { return }
            await MainActor.run {
                self.narrationPlayer = nil
                self.currentIndex += 1
                if let session = self.session, self.currentIndex >= session.segments.count {
                    self.finish()
                } else {
                    self.speakCurrentSegment()
                }
            }
        }
    }

    private func finish() {
        isPlaying = false
        isFinished = true
        stopTicker()
        elapsed = total
        currentLine = "Rest here as long as you like."
        playChime()
        fadeAmbient(to: 0)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            self?.ambientPlayer?.stop()
        }
    }

    // MARK: - Progress ticker

    private func startTicker() {
        stopTicker()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isPlaying else { return }
                self.recomputeElapsed()
            }
        }
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func recomputeElapsed() {
        if singleFile {
            let t = narrationPlayer?.currentTime ?? 0
            elapsed = min(t, total)
            updateLine(at: t)
            return
        }
        guard currentIndex < segmentDurations.count else { return }
        var base = 0.0
        for i in 0..<currentIndex { base += segmentDurations[i] }
        var within = 0.0
        if let player = narrationPlayer {
            within = player.currentTime
        }
        elapsed = min(base + within, total)
    }

    /// In single-file mode, map the playhead to the active segment so the
    /// on-screen line and phase track the stitched narration.
    private func updateLine(at t: Double) {
        guard let session, !segmentStarts.isEmpty else { return }
        var idx = 0
        for i in segmentStarts.indices where segmentStarts[i] <= t + 0.05 { idx = i }
        guard idx != currentIndex else { return }
        currentIndex = idx
        if idx < session.segments.count {
            currentLine = session.segments[idx].text
            currentPhase = session.segments[idx].phase ?? .journey
        }
    }

    // MARK: - Audio setup

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [])
    }

    private func prepareAmbient(_ soundscape: Soundscape) {
        guard let url = Bundle.main.url(forResource: soundscape.resource, withExtension: "mp3") else { return }
        let player = try? AVAudioPlayer(contentsOf: url)
        player?.numberOfLoops = -1
        player?.volume = 0
        player?.prepareToPlay()
        ambientPlayer = player
    }

    private func prepareChime() {
        guard let url = Bundle.main.url(forResource: "tibetan_bowl_strike", withExtension: "mp3") else { return }
        chimePlayer = try? AVAudioPlayer(contentsOf: url)
        chimePlayer?.volume = 0.5
        chimePlayer?.prepareToPlay()
    }

    private func playChime() {
        chimePlayer?.currentTime = 0
        chimePlayer?.play()
    }

    private func fadeAmbient(to target: Float) {
        ambientPlayer?.setVolume(target, fadeDuration: 1.5)
    }

    // MARK: - Helpers

    private func estimatedSpokenDuration(_ text: String) -> Double {
        let words = Double(text.split(separator: " ").count)
        return max(1.5, words / 2.2)
    }
}

extension SessionPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self, player === self.narrationPlayer else { return }
            if self.singleFile {
                self.finish()
            } else {
                self.handleNarrationFinished()
            }
        }
    }
}
