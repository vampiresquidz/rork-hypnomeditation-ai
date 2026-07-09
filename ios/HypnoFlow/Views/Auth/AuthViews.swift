//
//  AuthViews.swift
//  HypnoFlow
//
//  Sign in with Apple UI: the button, the "welcome back" login sheet used from
//  onboarding, and the account panel opened from Home.
//

import SwiftUI
import AuthenticationServices

/// The native Sign in with Apple button, wired to AuthStore.
struct AppleSignInButton: View {
    @Environment(AuthStore.self) private var auth
    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            auth.configureRequest(request)
        } onCompletion: { result in
            auth.handle(result)
        }
        .signInWithAppleButtonStyle(.white)
        .frame(height: 52)
        .clipShape(.rect(cornerRadius: 16))
    }
}

/// Presented from onboarding when a returning user taps "Log in".
struct LoginSheet: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AuroraBackground(animated: false)

            VStack(spacing: 22) {
                MascotView(pose: .wave, size: 150)

                VStack(spacing: 8) {
                    Text("Welcome back")
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Sign in and pick up right where you left off — your library and plan follow you.")
                        .font(.body)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }

                AppleSignInButton()
                    .padding(.horizontal, 30)
                    .padding(.top, 6)

                Text("We only use this to recognize you and sync your sessions.")
                    .font(.caption)
                    .foregroundStyle(Theme.textFaint)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)

                Spacer()
            }
            .padding(.top, 70)
            .padding(.horizontal, 24)
        }
        .preferredColorScheme(.dark)
        .overlay(alignment: .topLeading) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 40, height: 40)
                    .glassCard(cornerRadius: 12)
            }
            .buttonStyle(.plain)
            .padding(20)
        }
        // Dismiss automatically once sign-in succeeds.
        .onChange(of: auth.isSignedIn) { _, signedIn in
            if signedIn { dismiss() }
        }
    }
}

/// Account panel opened from Home: shows who you're signed in as (or invites
/// sign-in), your plan, and restore purchases.
struct AccountView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(SubscriptionManager.self) private var subs
    @Environment(CreditStore.self) private var credits
    @Environment(\.dismiss) private var dismiss

    @State private var confirmSignOut = false

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground(animated: false)

                ScrollView {
                    VStack(spacing: 20) {
                        MascotView(pose: auth.isSignedIn ? .celebrate : .wave, size: 128)
                            .padding(.top, 8)

                        if auth.isSignedIn {
                            identityCard
                            planCard
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
                        } else {
                            VStack(spacing: 8) {
                                Text("Save your progress")
                                    .font(.system(.title2, design: .rounded).weight(.bold))
                                    .foregroundStyle(Theme.textPrimary)
                                Text("Sign in to keep your library and plan safe and synced across your devices.")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 12)
                            AppleSignInButton()
                            planCard
                        }

                        Button("Restore purchases") {
                            Task { await subs.restore() }
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.top, 4)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
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

    private var planName: String {
        switch subs.tier {
        case .free: "Free plan"
        case .plus: "Plus plan"
        case .pro:  "Pro plan"
        }
    }

    private var initials: String {
        guard let name = auth.displayName, !name.isEmpty else { return "🪼" }
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }
}
