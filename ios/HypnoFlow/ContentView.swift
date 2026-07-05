//
//  ContentView.swift
//  HypnoFlow
//
//  Root shell: a bottom tab bar to move between Home and the Library.
//

import SwiftUI

struct ContentView: View {
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
    }
}

/// The Library as a top-level tab: its own navigation stack plus the player
/// presentation, so sessions can be played straight from here.
private struct LibraryTab: View {
    @State private var playingSession: MeditationSession?

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
    ContentView()
        .environment(SessionStore())
        .environment(SubscriptionManager())
        .environment(CreditStore())
}
