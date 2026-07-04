//
//  LibraryView.swift
//  HypnoFlow
//

import SwiftUI

struct LibraryView: View {
    @Environment(SessionStore.self) private var store
    @Binding var playingSession: MeditationSession?

    var body: some View {
        ZStack {
            AuroraBackground(animated: false)

            if store.library.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(store.library) { session in
                            Button {
                                playingSession = session
                            } label: {
                                SessionRow(session: session)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    store.delete(session)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "moon.stars")
                .font(.system(size: 46))
                .foregroundStyle(Theme.textFaint)
            Text("No sessions yet")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("Create your first hypnosis session and it will live here.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}
