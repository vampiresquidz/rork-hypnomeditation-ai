//
//  AuthViews.swift
//  HypnoFlow
//
//  Sign in with Apple UI: the button and the "welcome back" login sheet used
//  from onboarding. Account management lives in SettingsView.
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
