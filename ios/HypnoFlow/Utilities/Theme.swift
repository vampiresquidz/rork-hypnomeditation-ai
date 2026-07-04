//
//  Theme.swift
//  HypnoFlow
//
//  Central design tokens for the Hypno Flow aesthetic:
//  a deep, cinematic midnight palette with aurora accents.
//

import SwiftUI

enum Theme {
    // Backgrounds
    static let void = Color(red: 0.03, green: 0.03, blue: 0.08)
    static let deepIndigo = Color(red: 0.06, green: 0.06, blue: 0.16)
    static let midnight = Color(red: 0.09, green: 0.08, blue: 0.22)

    // Aurora accents
    static let violet = Color(red: 0.44, green: 0.33, blue: 0.85)
    static let indigoGlow = Color(red: 0.30, green: 0.36, blue: 0.92)
    static let teal = Color(red: 0.29, green: 0.78, blue: 0.80)
    static let amber = Color(red: 0.98, green: 0.78, blue: 0.42)

    // Text
    static let textPrimary = Color(red: 0.96, green: 0.96, blue: 1.0)
    static let textSecondary = Color(red: 0.72, green: 0.73, blue: 0.86)
    static let textFaint = Color(red: 0.50, green: 0.52, blue: 0.66)

    // Surfaces
    static let card = Color.white.opacity(0.06)
    static let cardStroke = Color.white.opacity(0.10)

    static let gradientAmberTeal = LinearGradient(
        colors: [amber, teal],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let gradientVioletIndigo = LinearGradient(
        colors: [violet, indigoGlow],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension View {
    /// Glassy card styling used across the app.
    func glassCard(cornerRadius: CGFloat = 22) -> some View {
        self
            .background(Theme.card)
            .clipShape(.rect(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Theme.cardStroke, lineWidth: 1)
            )
    }
}
