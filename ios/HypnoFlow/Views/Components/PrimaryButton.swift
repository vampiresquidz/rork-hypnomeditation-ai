//
//  PrimaryButton.swift
//  HypnoFlow
//

import SwiftUI

struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var gradient: LinearGradient = Theme.gradientAmberTeal
    var enabled: Bool = true
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            action()
        } label: {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.headline)
                }
                Text(title)
                    .font(.headline)
            }
            .foregroundStyle(Theme.void)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(gradient)
            .clipShape(.rect(cornerRadius: 20))
            .shadow(color: Theme.amber.opacity(enabled ? 0.35 : 0), radius: 18, y: 8)
            .scaleEffect(pressed ? 0.97 : 1)
            .opacity(enabled ? 1 : 0.4)
        }
        .disabled(!enabled)
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeOut(duration: 0.12)) { pressed = true } }
                .onEnded { _ in withAnimation(.spring(response: 0.3)) { pressed = false } }
        )
    }
}
