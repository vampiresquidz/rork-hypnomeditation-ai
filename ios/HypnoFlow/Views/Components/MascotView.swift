//
//  MascotView.swift
//  HypnoFlow
//
//  Professor Jelly — the app's hypnotic jellyfish mascot. Each action is a
//  pre-rendered animation baked into a sprite sheet (a 6×5 grid of 30 frames)
//  in the asset catalog. This view slices the sheet once, caches the frames,
//  and plays them on a TimelineView clock so the character is always alive —
//  floating, waving, swinging his pocket watch, meditating, or sleeping.
//  Falls back to the still illustration if a sheet is ever missing.
//

import SwiftUI
import UIKit

/// The actions Professor Jelly can perform. Each maps to an animated sprite
/// sheet (MascotAnim*) plus a still fallback (Mascot*) in the asset catalog.
enum MascotPose: String, CaseIterable {
    case idle       // gentle floating
    case wave       // saying hello
    case hypnotize  // swinging the pocket watch
    case meditate   // lotus hands, slow breathing
    case sleep      // eyes closed, Zzz
    case celebrate  // tentacles raised in a joyful cheer

    var sheetName: String {
        switch self {
        case .idle:      "MascotAnimIdle"
        case .wave:      "MascotAnimWave"
        case .hypnotize: "MascotAnimHypno"
        case .meditate:  "MascotAnimMeditate"
        case .sleep:     "MascotAnimSleep"
        case .celebrate: "MascotAnimCelebrate"
        }
    }

    var stillName: String {
        switch self {
        case .idle:      "MascotIdle"
        case .wave:      "MascotWave"
        case .hypnotize: "MascotHypno"
        case .meditate:  "MascotMeditate"
        case .sleep:     "MascotSleep"
        case .celebrate: "MascotCelebrate"
        }
    }
}

/// Slices the sprite sheets into frames once and caches them.
private enum MascotSprites {
    static let cols = 6
    static let rows = 5
    static let count = 30
    static let fps = 15.0   // 30 frames → a smooth 2-second loop

    private static var cache: [String: [Image]] = [:]

    static func frames(for pose: MascotPose) -> [Image] {
        if let cached = cache[pose.sheetName] { return cached }
        let sliced = slice(pose.sheetName)
        cache[pose.sheetName] = sliced
        return sliced
    }

    private static func slice(_ name: String) -> [Image] {
        guard let ui = UIImage(named: name), let cg = ui.cgImage else { return [] }
        let cw = cg.width / cols
        let ch = cg.height / rows
        guard cw > 0, ch > 0 else { return [] }

        var out: [Image] = []
        out.reserveCapacity(count)
        for i in 0..<count {
            let r = i / cols
            let c = i % cols
            let rect = CGRect(x: c * cw, y: r * ch, width: cw, height: ch)
            if let sub = cg.cropping(to: rect) {
                out.append(Image(uiImage: UIImage(cgImage: sub, scale: ui.scale, orientation: .up)))
            }
        }
        return out
    }
}

struct MascotView: View {
    /// The action the mascot is currently performing.
    var pose: MascotPose = .idle
    /// Rendered width/height in points.
    var size: CGFloat = 120
    /// Soft luminous halo behind the character.
    var glow: Bool = true

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let halo = 0.5 + (sin(t * 0.9) * 0.5 + 0.5) * 0.5   // 0.5 → 1.0

            ZStack {
                if glow {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Theme.teal.opacity(0.45), Theme.violet.opacity(0.18), .clear],
                                center: .center,
                                startRadius: 2,
                                endRadius: size * 0.62
                            )
                        )
                        .frame(width: size * 1.5, height: size * 1.5)
                        .opacity(halo)
                        .blur(radius: 6)
                }

                poseFrame(at: t)
                    .frame(width: size, height: size)
                    .shadow(color: .black.opacity(0.28), radius: 12, y: 8)
            }
            .frame(width: size * 1.5, height: size * 1.5)
        }
        .accessibilityLabel("Professor Jelly, your hypnosis guide")
    }

    /// The current animation frame, crossfading whenever the action changes.
    @ViewBuilder
    private func poseFrame(at t: TimeInterval) -> some View {
        let frames = MascotSprites.frames(for: pose)
        Group {
            if frames.isEmpty {
                Image(pose.stillName).resizable().scaledToFit()   // fallback
            } else {
                let idx = Int(t * MascotSprites.fps) % frames.count
                frames[idx].resizable().scaledToFit()
            }
        }
        .id(pose)
        .transition(.opacity.combined(with: .scale(scale: 0.94)))
        .animation(.easeInOut(duration: 0.4), value: pose)
    }
}

#Preview {
    ZStack {
        AuroraBackground()
        VStack(spacing: 30) {
            MascotView(pose: .idle, size: 150)
            HStack(spacing: 20) {
                MascotView(pose: .wave, size: 90)
                MascotView(pose: .hypnotize, size: 90)
                MascotView(pose: .meditate, size: 90)
                MascotView(pose: .sleep, size: 90)
            }
        }
    }
}
