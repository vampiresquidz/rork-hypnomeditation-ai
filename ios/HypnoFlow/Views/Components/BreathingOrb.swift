//
//  BreathingOrb.swift
//  HypnoFlow
//
//  The signature hypnotic orb: a glowing sphere wrapped in slowly rotating
//  concentric rings that breathe in and out. Used on the player screen.
//

import SwiftUI

struct BreathingOrb: View {
    /// When true the orb breathes and rotates; when paused it settles gently.
    var isActive: Bool
    var tint: Color = Theme.amber

    @State private var breathe: Bool = false
    @State private var rotate: Double = 0

    var body: some View {
        ZStack {
            // Outer glow halo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [tint.opacity(0.35), .clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 180
                    )
                )
                .frame(width: 360, height: 360)
                .scaleEffect(breathe ? 1.08 : 0.9)

            // Rotating hypnotic rings
            ForEach(0..<4) { i in
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [tint.opacity(0.05), tint.opacity(0.6), Theme.teal.opacity(0.4), tint.opacity(0.05)],
                            center: .center
                        ),
                        lineWidth: 1.5
                    )
                    .frame(width: 150 + CGFloat(i) * 34, height: 150 + CGFloat(i) * 34)
                    .rotationEffect(.degrees(rotate * (i.isMultiple(of: 2) ? 1 : -1)))
                    .opacity(0.8)
            }

            // Core sphere
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.95), tint, Theme.violet.opacity(0.9)],
                        center: .init(x: 0.38, y: 0.34),
                        startRadius: 4,
                        endRadius: 120
                    )
                )
                .frame(width: 132, height: 132)
                .shadow(color: tint.opacity(0.6), radius: 30)
                .scaleEffect(breathe ? 1.12 : 0.94)
                .overlay(
                    Circle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 26, height: 26)
                        .blur(radius: 6)
                        .offset(x: -22, y: -26)
                )
        }
        .onAppear { restartAnimations() }
        .onChange(of: isActive) { _, _ in restartAnimations() }
    }

    private func restartAnimations() {
        withAnimation(.easeInOut(duration: isActive ? 5 : 7).repeatForever(autoreverses: true)) {
            breathe = isActive ? true : false
        }
        withAnimation(.linear(duration: isActive ? 40 : 90).repeatForever(autoreverses: false)) {
            rotate = 360
        }
    }
}

#Preview {
    ZStack {
        AuroraBackground()
        BreathingOrb(isActive: true)
    }
}
