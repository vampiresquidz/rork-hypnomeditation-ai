//
//  AuroraBackground.swift
//  HypnoFlow
//
//  A slowly drifting aurora gradient used behind every screen to create
//  depth and atmosphere.
//

import SwiftUI

struct AuroraBackground: View {
    var animated: Bool = true

    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            Theme.void.ignoresSafeArea()

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                blob(Theme.violet.opacity(0.55), size: w * 1.1)
                    .offset(x: -w * 0.25 + sin(phase) * 30,
                            y: -h * 0.18 + cos(phase * 0.8) * 40)

                blob(Theme.indigoGlow.opacity(0.50), size: w * 1.0)
                    .offset(x: w * 0.35 + cos(phase) * 40,
                            y: h * 0.08 + sin(phase * 0.9) * 30)

                blob(Theme.teal.opacity(0.30), size: w * 0.9)
                    .offset(x: w * 0.05 + sin(phase * 1.1) * 50,
                            y: h * 0.55 + cos(phase) * 40)
            }
            .blur(radius: 70)
            .ignoresSafeArea()

            // Subtle darkening vignette to keep text crisp.
            RadialGradient(
                colors: [.clear, Theme.void.opacity(0.65)],
                center: .center,
                startRadius: 120,
                endRadius: 520
            )
            .ignoresSafeArea()
        }
        .onAppear {
            guard animated else { return }
            withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) {
                phase = .pi * 2
            }
        }
    }

    private func blob(_ color: Color, size: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
    }
}

#Preview {
    AuroraBackground()
}
