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
    private(set) var elapsed: Double = 0
    private(set) var total: Double = 1

    var progress: Double { total > 0 ? min(elapsed / total, 1) : 0 }

    private var session: MeditationSession?
    private var narrationPlayer: AVAudioPlayer?
    private var ambientPlayer: AVAudioPlayer?
    private var chimePlayer: AVAudioPlayer?

    private var segmentDurations: [Double] = []
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
        self.currentLine = session.segments.first?.text ?? ""

        configureAudioSession()
        prepareAmbient(session.soundscape)
        prepareChime()

        // Precompute per-segment durations for the progress bar.
        segmentDurations = session.segments.map { seg in
            let dir = NarrationService.sessionDirectory(for: session.id)
            var speak = estimatedSpokenDuration(seg.text)
            if let name = seg.audioFileName {
                let url = dir.appendingPathComponent(name)
                if let player = try? AVAudioPlayer(contentsOf: url) {
                    speak = player.duration
                }
            }
            return speak + seg.pauseAfter
        }
        total = max(segmentDurations.reduce(0, +), 1)
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
        if narrationPlayer == nil {
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
    }

    // MARK: - Sequencing

    private func speakCurrentSegment() {
        guard let session, currentIndex < session.segments.count else {
            finish()
            return
        }
        let segment = session.segments[currentIndex]
        currentLine = segment.text

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
        guard currentIndex < segmentDurations.count else { return }
        var base = 0.0
        for i in 0..<currentIndex { base += segmentDurations[i] }
        var within = 0.0
        if let player = narrationPlayer {
            within = player.currentTime
        }
        elapsed = min(base + within, total)
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
            self.handleNarrationFinished()
        }
    }
}
