//
//  SettingsView.swift
//  HypnoFlow
//
//  The app's settings hub: account (Sign in with Apple), subscription & credits
//  (buy credits, manage/cancel subscription, restore), notifications, and
//  support/legal. Opened from the gear on Home.
//

import SwiftUI
import UIKit
import RevenueCatUI

struct SettingsView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(SubscriptionManager.self) private var subs
    @Environment(CreditStore.self) private var credits
    @Environment(ReminderManager.self) private var reminders
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var confirmSignOut = false
    @State private var showPaywall = false
    @State private var showCustomerCenter = false
    @State private var reminderTime = Date()
    @State private var reminderOn = false

    // Legal / support endpoints.
    private let privacyURL = URL(string: "https://hypnoflow.dev/privacy.html")!
    private let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private let supportEmail = "support@hypnoflow.dev"

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground(animated: false)

                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        accountSection
                        subscriptionSection
                        notificationsSection
                        supportSection

                        if auth.isSignedIn {
                            signOutButton
                        }

                        footer
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showCustomerCenter) {
                // RevenueCat's self-service hub: cancel, change plan, restore,
                // request refunds, and reach support — all handled natively.
                CustomerCenterView()
                    .onDisappear { Task { await subs.refresh() } }
            }
            .confirmationDialog("Sign out of HypnoFlow?", isPresented: $confirmSignOut, titleVisibility: .visible) {
                Button("Sign out", role: .destructive) { auth.signOut() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your sessions stay on this device and in iCloud. You can sign back in anytime.")
            }
        }
        .tint(Theme.amber)
        .preferredColorScheme(.dark)
    }

    // MARK: - Account

    private var accountSection: some View {
        section("Account") {
            if auth.isSignedIn {
                identityCard
            } else {
                VStack(spacing: 12) {
                    VStack(spacing: 6) {
                        Text("Save your progress")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Sign in to keep your library and plan synced across your devices.")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    AppleSignInButton()
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .glassCard(cornerRadius: 18)
            }
        }
    }

    private var identityCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Theme.gradientVioletIndigo).frame(width: 52, height: 52)
                Text(initials)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(auth.displayName ?? "Signed in")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                if let email = auth.email {
                    Text(email)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(Theme.teal)
        }
        .padding(16)
        .glassCard(cornerRadius: 18)
    }

    // MARK: - Subscription & credits

    private var subscriptionSection: some View {
        section("Subscription & credits") {
            VStack(spacing: 12) {
                planCard

                actionRow(symbol: "sparkles", tint: Theme.amber,
                          title: "Buy credits",
                          subtitle: "One-time top-ups that never expire") {
                    showPaywall = true
                }

                if subs.tier == .free {
                    actionRow(symbol: "crown.fill", tint: Theme.teal,
                              title: "Go Plus or Pro",
                              subtitle: "Monthly credits and premium voices") {
                        showPaywall = true
                    }
                } else {
                    actionRow(symbol: "creditcard", tint: Theme.teal,
                              title: "Manage subscription",
                              subtitle: "Change plan, cancel, or get help") {
                        showCustomerCenter = true
                    }
                }

                actionRow(symbol: "arrow.clockwise", tint: Theme.textSecondary,
                          title: "Restore purchases",
                          subtitle: "Already subscribed? Restore it here") {
                    Task { await subs.restore() }
                }
            }
        }
    }

    private var planCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .foregroundStyle(Theme.amber)
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(planName)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("^[\(credits.total) credit](inflect: true) available")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .glassCard(cornerRadius: 18)
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        section("Notifications") {
            VStack(spacing: 12) {
                // The daily reminder toggle + time picker.
                VStack(spacing: 14) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(Theme.violet.opacity(0.16)).frame(width: 42, height: 42)
                            Image(systemName: "bell.fill").foregroundStyle(Theme.violet)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Daily reminder")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                            Text("A gentle nudge from Professor Jelly")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer(minLength: 0)
                        Toggle("", isOn: $reminderOn)
                            .labelsHidden()
                            .tint(Theme.teal)
                    }

                    if reminderOn {
                        Divider().overlay(Theme.textFaint.opacity(0.2))
                        HStack {
                            Text("Time")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                            Spacer(minLength: 0)
                            DatePicker("", selection: $reminderTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }
                    }
                }
                .padding(16)
                .glassCard(cornerRadius: 18)

                if reminderOn && reminders.authorization == .denied {
                    actionRow(symbol: "exclamationmark.triangle.fill", tint: Theme.amber,
                              title: "Notifications are off",
                              subtitle: "Turn them on in iOS Settings to get reminders") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                }
            }
        }
        .task {
            await reminders.refreshAuthorization()
            reminderOn = reminders.isEnabled
            reminderTime = reminders.timeOfDay
        }
        .onChange(of: reminderOn) { _, on in
            Task {
                if on {
                    let ok = await reminders.enable(at: reminderTime)
                    // If permission was denied the manager can't turn on — reflect that.
                    if !ok { reminderOn = false }
                } else {
                    reminders.disable()
                }
            }
        }
        .onChange(of: reminderTime) { _, newTime in
            guard reminderOn else { return }
            Task { await reminders.updateTime(newTime) }
        }
    }

    // MARK: - Support & legal

    private var supportSection: some View {
        section("Support & legal") {
            VStack(spacing: 12) {
                actionRow(symbol: "envelope.fill", tint: Theme.teal,
                          title: "Contact support",
                          subtitle: supportEmail) {
                    if let url = URL(string: "mailto:\(supportEmail)") { openURL(url) }
                }
                actionRow(symbol: "hand.raised.fill", tint: Theme.textSecondary,
                          title: "Privacy Policy", subtitle: nil) {
                    openURL(privacyURL)
                }
                actionRow(symbol: "doc.text.fill", tint: Theme.textSecondary,
                          title: "Terms of Use", subtitle: nil) {
                    openURL(termsURL)
                }
            }
        }
    }

    private var signOutButton: some View {
        Button(role: .destructive) {
            confirmSignOut = true
        } label: {
            Text("Sign out")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .glassCard(cornerRadius: 16)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.amber)
    }

    private var footer: some View {
        VStack(spacing: 6) {
            MascotView(pose: .idle, size: 64, glow: false)
            Text("HypnoFlow \(appVersion)")
                .font(.caption)
                .foregroundStyle(Theme.textFaint)
            Text("Made with a little help from Professor Jelly 🪼")
                .font(.caption2)
                .foregroundStyle(Theme.textFaint)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Building blocks

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(1.5)
                .foregroundStyle(Theme.textFaint)
            content()
        }
    }

    private func actionRow(
        symbol: String,
        tint: Color,
        title: String,
        subtitle: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(tint.opacity(0.16)).frame(width: 42, height: 42)
                    Image(systemName: symbol).foregroundStyle(tint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textFaint)
            }
            .padding(14)
            .glassCard(cornerRadius: 18)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var planName: String {
        switch subs.tier {
        case .free: "Free plan"
        case .plus: "Plus plan"
        case .pro:  "Pro plan"
        }
    }

    private var initials: String {
        guard let name = auth.displayName, !name.isEmpty else { return "🪼" }
        let letters = name.split(separator: " ").prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(v) (\(b))"
    }
}
