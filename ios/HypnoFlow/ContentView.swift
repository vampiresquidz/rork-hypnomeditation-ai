//
//  ContentView.swift
//  HypnoFlow
//
//  Root shell: a bottom tab bar to move between Home and the Library.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(OnboardingStore.self) private var onboarding
    @Environment(AuthStore.self) private var auth
    @State private var showPaywall = false

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            LibraryTab()
                .tabItem {
                    Label("Library", systemImage: "books.vertical.fill")
                }
        }
        .tint(Theme.amber)
        .preferredColorScheme(.dark)
        // First-run onboarding funnel — skipped entirely once the user is signed
        // in, and stays up for new/guest users until they finish it.
        .fullScreenCover(isPresented: .init(
            get: { !auth.isSignedIn && !onboarding.hasCompletedOnboarding },
            set: { _ in }
        )) {
            OnboardingView()
        }
        // If they finished onboarding by choosing to see plans, present the
        // paywall once, at peak motivation.
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .onChange(of: onboarding.hasCompletedOnboarding) { _, done in
            guard done, onboarding.wantsPaywallOnEntry else { return }
            onboarding.wantsPaywallOnEntry = false
            // Let the onboarding cover finish dismissing before presenting.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(550))
                showPaywall = true
            }
        }
    }
}

/// The Library as a top-level tab: its own navigation stack plus the player
/// presentation, so sessions can be played straight from here.
private struct LibraryTab: View {
    @State private var playingSession: SessionModel?

    var body: some View {
        NavigationStack {
            LibraryView(playingSession: $playingSession)
        }
        .fullScreenCover(item: $playingSession) { session in
            PlayerView(session: session)
        }
        .tint(Theme.amber)
    }
}

#Preview {
    let onboarding = OnboardingStore()
    onboarding.hasCompletedOnboarding = true
    return ContentView()
        .modelContainer(.preview)
        .environment(SessionStore())
        .environment(SubscriptionManager())
        .environment(CreditStore())
        .environment(onboarding)
        .environment(AuthStore())
}
