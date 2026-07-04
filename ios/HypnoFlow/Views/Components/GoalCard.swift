//
//  GoalCard.swift
//  HypnoFlow
//

import SwiftUI

struct GoalCard: View {
    let goal: HypnosisGoal
    var isSelected: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                Circle()
                    .fill(goal.tint.opacity(0.18))
                    .frame(width: 46, height: 46)
                Image(systemName: goal.symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(goal.tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(goal.title)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(goal.subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard()
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(goal.tint.opacity(isSelected ? 0.9 : 0), lineWidth: 1.5)
        )
        .shadow(color: goal.tint.opacity(isSelected ? 0.25 : 0), radius: 14)
    }
}
