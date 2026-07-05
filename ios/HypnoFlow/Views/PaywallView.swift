//
//  PaywallView.swift
//  HypnoFlow
//
//  Presents subscriptions (Plus / Pro) and consumable credit top-ups, driven
//  by RevenueCat offerings via SubscriptionManager.
//

import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionManager.self) private var subs
    @Environment(CreditStore.self) private var credits

    @State private var busyProduct: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground(animated: false)

                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        heroHeader
                        subscriptionSection
                        topUpSection

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(Theme.amber)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }

                        Button("Restore purchases") {
                            Task { await subs.restore() }
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)

                        Text("Subscriptions renew automatically until cancelled. Credits from your plan reset each month and don't roll over; purchased top-up credits never expire.")
                            .font(.caption2)
                            .foregroundStyle(Theme.textFaint)
                            .multilineTextAlignment(.center)

                        Color.clear.frame(height: 10)
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .tint(Theme.amber)
        .preferredColorScheme(.dark)
    }

    // MARK: - Sections

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            MascotView(pose: .wave, size: 96, glow: true)
                .frame(maxWidth: .infinity)

            Text("Keep your practice going")
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.textPrimary)

            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                Text("You have ^[\(credits.total) credit](inflect: true) left")
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Theme.amber)
        }
        .padding(.bottom, 4)
    }

    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Subscribe & save")

            planCard(
                title: "Plus",
                highlight: subs.tier == .plus,
                credits: "\(Tier.plus.monthlyCredits) credits / month",
                blurb: "Standard voices and every soundscape.",
                monthlyID: StoreProductID.plusMonthly,
                yearlyID: StoreProductID.plusYearly,
                tint: Theme.teal
            )

            planCard(
                title: "Pro",
                highlight: subs.tier == .pro,
                credits: "\(Tier.pro.monthlyCredits) credits / month",
                blurb: "Premium voices, 20-minute sessions, priority generation.",
                monthlyID: StoreProductID.proMonthly,
                yearlyID: StoreProductID.proYearly,
                tint: Theme.amber
            )
        }
    }

    private var topUpSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Out of credits? Top up")
            Text("One-time packs that never expire.")
                .font(.caption)
                .foregroundStyle(Theme.textFaint)

            topUpRow(StoreProductID.credits5, count: 5)
            topUpRow(StoreProductID.credits15, count: 15, tag: "Popular")
            topUpRow(StoreProductID.credits50, count: 50, tag: "Best value")
        }
    }

    // MARK: - Components

    private func planCard(title: String, highlight: Bool, credits: String, blurb: String,
                          monthlyID: String, yearlyID: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                if highlight {
                    Text("Current")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.void)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(tint, in: Capsule())
                }
                Spacer()
                Text(credits)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
            }
            Text(blurb)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)

            HStack(spacing: 10) {
                purchaseButton(productID: monthlyID, caption: "Monthly", tint: tint, filled: false)
                purchaseButton(productID: yearlyID, caption: "Yearly · best", tint: tint, filled: true)
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(highlight ? tint.opacity(0.6) : .clear, lineWidth: 1.5)
        )
    }

    private func purchaseButton(productID: String, caption: String, tint: Color, filled: Bool) -> some View {
        Button {
            buy(productID)
        } label: {
            VStack(spacing: 2) {
                Text(caption)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(filled ? Theme.void.opacity(0.8) : Theme.textSecondary)
                Text(subs.priceString(for: productID) ?? "—")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(filled ? Theme.void : Theme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(filled ? AnyShapeStyle(tint) : AnyShapeStyle(Theme.card))
            .clipShape(.rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.cardStroke, lineWidth: filled ? 0 : 1))
            .opacity(busyProduct == productID ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(busyProduct != nil)
    }

    private func topUpRow(_ productID: String, count: Int, tag: String? = nil) -> some View {
        Button {
            buy(productID)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Theme.amber.opacity(0.16)).frame(width: 44, height: 44)
                    Image(systemName: "sparkles").foregroundStyle(Theme.amber)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 7) {
                        Text("\(count) credits")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                        if let tag {
                            Text(tag)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.teal)
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(Theme.teal.opacity(0.15), in: Capsule())
                        }
                    }
                    Text("≈ \(count) sessions")
                        .font(.caption).foregroundStyle(Theme.textFaint)
                }
                Spacer()
                Text(subs.priceString(for: productID) ?? "—")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.amber)
            }
            .padding(14)
            .glassCard(cornerRadius: 18)
            .opacity(busyProduct == productID ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(busyProduct != nil)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(1.5)
            .foregroundStyle(Theme.textFaint)
    }

    // MARK: - Actions

    private func buy(_ productID: String) {
        guard busyProduct == nil else { return }
        errorMessage = nil
        busyProduct = productID
        Task {
            defer { busyProduct = nil }
            do {
                guard let purchased = try await subs.purchase(productID: productID) else { return }
                if let topUp = StoreProductID.topUpCredits(for: purchased) {
                    credits.addTopUp(topUp)
                }
                dismiss()
            } catch {
                errorMessage = "That purchase didn't go through. Please try again."
            }
        }
    }
}
