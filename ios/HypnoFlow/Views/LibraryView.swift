//
//  LibraryView.swift
//  HypnoFlow
//
//  The user's saved sessions, with search, goal filters, and sorting.
//  When the library is empty, Professor Jelly hovers to invite a first session.
//

import SwiftUI

private enum LibrarySort: String, CaseIterable, Identifiable {
    case newest, oldest, longest
    var id: String { rawValue }
    var label: String {
        switch self {
        case .newest:  "Newest first"
        case .oldest:  "Oldest first"
        case .longest: "Longest first"
        }
    }
    var symbol: String {
        switch self {
        case .newest:  "clock"
        case .oldest:  "clock.arrow.circlepath"
        case .longest: "timer"
        }
    }
}

struct LibraryView: View {
    @Environment(SessionStore.self) private var store
    @Binding var playingSession: MeditationSession?

    @State private var query = ""
    @State private var selectedGoal: HypnosisGoal? = nil
    @State private var sort: LibrarySort = .newest

    var body: some View {
        ZStack {
            AuroraBackground(animated: false)

            if store.library.isEmpty {
                emptyState
            } else {
                VStack(spacing: 14) {
                    searchField
                    filterBar
                    countLine

                    if filtered.isEmpty {
                        noMatchState
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filtered) { session in
                                    Button {
                                        playingSession = session
                                    } label: {
                                        SessionRow(session: session)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            delete(session)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .padding(.bottom, 30)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            if !store.library.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort", selection: $sort) {
                            ForEach(LibrarySort.allCases) { s in
                                Label(s.label, systemImage: s.symbol).tag(s)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundStyle(Theme.amber)
                    }
                }
            }
        }
    }

    // MARK: - Filtering

    /// Goals that actually have at least one saved session.
    private var availableGoals: [HypnosisGoal] {
        HypnosisGoal.allCases.filter { g in store.library.contains { $0.goal == g } }
    }

    private var filtered: [MeditationSession] {
        var items = store.library

        if let goal = selectedGoal {
            items = items.filter { $0.goal == goal }
        }

        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            items = items.filter {
                $0.title.lowercased().contains(q) || $0.intention.lowercased().contains(q)
            }
        }

        switch sort {
        case .newest:  items.sort { $0.createdAt > $1.createdAt }
        case .oldest:  items.sort { $0.createdAt < $1.createdAt }
        case .longest: items.sort { $0.durationMinutes > $1.durationMinutes }
        }
        return items
    }

    private func delete(_ session: MeditationSession) {
        store.delete(session)
        // If the active goal filter no longer has any sessions, clear it.
        if let goal = selectedGoal, !store.library.contains(where: { $0.goal == goal }) {
            withAnimation { selectedGoal = nil }
        }
    }

    // MARK: - Pieces

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.textFaint)
            TextField("", text: $query, prompt: Text("Search titles & intentions")
                .foregroundStyle(Theme.textFaint))
                .foregroundStyle(Theme.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.textFaint)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .glassCard(cornerRadius: 14)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                chip(title: "All", symbol: "square.stack.3d.up",
                     selected: selectedGoal == nil, tint: Theme.amber) {
                    withAnimation(.spring(response: 0.3)) { selectedGoal = nil }
                }
                ForEach(availableGoals) { g in
                    chip(title: g.shortTitle, symbol: g.symbol,
                         selected: selectedGoal == g, tint: g.tint) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedGoal = (selectedGoal == g) ? nil : g
                        }
                    }
                }
            }
        }
        .contentMargins(.horizontal, 0)
    }

    private func chip(title: String, symbol: String, selected: Bool,
                      tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                Text(title)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(selected ? Theme.void : Theme.textPrimary)
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .background(selected ? AnyShapeStyle(tint) : AnyShapeStyle(Theme.card))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Theme.cardStroke, lineWidth: selected ? 0 : 1))
        }
        .buttonStyle(.plain)
    }

    private var countLine: some View {
        HStack {
            Text("^[\(filtered.count) session](inflect: true)")
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.textFaint)
            Spacer()
        }
    }

    // MARK: - Empty states

    private var emptyState: some View {
        VStack(spacing: 22) {
            MascotView(pose: .idle, size: 170)
            VStack(spacing: 10) {
                Text("No sessions yet")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Create your first hypnosis session and Professor Jelly will keep it right here for you.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 44)
            }
        }
    }

    private var noMatchState: some View {
        VStack(spacing: 16) {
            Spacer()
            MascotView(pose: .idle, size: 130)
            Text("Nothing matches")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("Try a different filter or search term.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
