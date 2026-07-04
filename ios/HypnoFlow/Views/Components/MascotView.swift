//
//  MascotView.swift
//  HypnoFlow
//
//  Professor Jelly — the app's hypnotic jellyfish mascot. A single view that
//  keeps the character gently "alive" (always floating and breathing) and can
//  play distinct actions: waving hello, swinging the pocket watch, meditating,
//  or drifting off to sleep. The motion is procedural (driven by a TimelineView)
//  so nothing has to be pre-rendered — each pose is one illustration that we
//  bob, sway, and breathe in code.
//

import SwiftUI

/// The actions Professor Jelly can perform. Each maps to one imageset in the
/// asset catalog plus a set of motion parameters.
enum MascotPose: String, CaseIterable {
    case idle       // gentle floating
    case wave       // saying hello
    case hypnotize  // swinging the pocket watch
    case meditate   // lotus hands, slow breathing
    case sleep      // eyes closed, Zzz

    var imageName: String {
        switch self {
        case .idle:      "MascotIdle"
        case .wave:      "MascotWave"
        case .hypnotize: "MascotHypno"
        case .meditate:  "MascotMeditate"
        case .sleep:     "MascotSleep"
        }
    }

    /// How the mascot moves while holding this pose.
    fileprivate var motion: MascotMotion {
        switch self {
        //                       bobAmp bobSpd  rotDeg rotSpd  breathe
        case .idle:      .init(     7,   1.4,     2.5,   0.9,    0.010)
        case .wave:      .init(     5,   2.0,     7.0,   3.0,    0.010)
        case .hypnotize: .init(     6,   1.2,     4.0,   1.5,    0.012)
        case .meditate:  .init(     4,   0.7,     0.0,   0.0,    0.035)
        case .sleep:     .init(     3,   0.5,     1.5,   0.4,    0.022)
        }
    }
}

private struct MascotMotion {
    let bobAmp: Double     // vertical float, points
    let bobSpeed: Double   // radians/sec
    let rotDeg: Double     // sway amplitude, degrees
    let rotSpeed: Double   // radians/sec
    let breathe: Double    // scale amplitude (fraction)

    init(_ bobAmp: Double, _ bobSpeed: Double, _ rotDeg: Double, _ rotSpeed: Double, _ breathe: Double) {
        self.bobAmp = bobAmp; self.bobSpeed = bobSpeed
        self.rotDeg = rotDeg; self.rotSpeed = rotSpeed; self.breathe = breathe
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
            let m = pose.motion

            let bob = sin(t * m.bobSpeed) * m.bobAmp
            let rot = sin(t * m.rotSpeed) * m.rotDeg
            let scale = 1 + sin(t * max(m.bobSpeed * 0.6, 0.4)) * m.breathe
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

                mascotImage
                    .scaleEffect(scale)
                    .rotationEffect(.degrees(rot))
                    .offset(y: bob)
                    .shadow(color: .black.opacity(0.28), radius: 12, y: 8)
            }
            .frame(width: size * 1.5, height: size * 1.5)
        }
        .accessibilityLabel("Professor Jelly, your hypnosis guide")
    }

    /// The pose illustration, crossfading whenever the action changes.
    private var mascotImage: some View {
        ZStack {
            Image(pose.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .id(pose)
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
        }
        .animation(.easeInOut(duration: 0.45), value: pose)
    }
}

#Preview {
    ZStack {
        AuroraBackground()
        VStack(spacing: 30) {
            MascotView(pose: .idle, size: 130)
            HStack(spacing: 24) {
                MascotView(pose: .wave, size: 90)
                MascotView(pose: .meditate, size: 90)
                MascotView(pose: .sleep, size: 90)
            }
        }
    }
}
