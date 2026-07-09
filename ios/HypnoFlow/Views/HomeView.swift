//
//  HomeView.swift
//  HypnoFlow
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(CreditStore.self) private var credits
    @Query(sort: \SessionModel.createdAt, order: .reverse) private var sessions: [SessionModel]

    @State private var showCreate = false
    @State private var presetGoal: HypnosisGoal? = nil
    @State private var playingSession: SessionModel?
    @State private var mascotPose: MascotPose = .wave
    @State private var showPaywall = false
    @State private var showAccount = false

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        creditsBar

                        header

                        beginCard

                        sectionTitle("Choose your journey")
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(HypnosisGoal.allCases) { goal in
                                Button {
                                    presetGoal = goal
                                    showCreate = true
                                } label: {
                                    GoalCard(goal: goal)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if !sessions.isEmpty {
                            recentSection
                        }

                        Color.clear.frame(height: 30)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showCreate) {
                CreateSessionView(presetGoal: presetGoal) { session in
                    playingSession = session
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showAccount) {
                AccountView()
            }
            .fullScreenCover(item: $playingSession) { session in
                PlayerView(session: session)
            }
        }
        .tint(Theme.amber)
    }

    private var creditsBar: some View {
        HStack {
            Button {
                showAccount = true
            } label: {
                Image(systemName: "person.circle")
                    .font(.title2)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 38, height: 38)
                    .glassCard(cornerRadius: 999)
            }
            .buttonStyle(.plain)

            Spacer()
            Button {
                showPaywall = true
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Theme.amber)
                    Text("^[\(credits.total) credit](inflect: true)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("· Get more")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .glassCard(cornerRadius: 999)
            }
            .buttonStyle(.plain)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                Text(greeting)
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Where would you like your mind to go today?")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
            MascotView(pose: mascotPose, size: 76, glow: false)
                .offset(y: -14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
        .onAppear {
            // Wave hello on arrival, then settle into a calm idle float.
            mascotPose = .wave
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                withAnimation { mascotPose = .idle }
            }
        }
    }

    private var beginCard: some View {
        Button {
            presetGoal = nil
            showCreate = true
        } label: {
            HStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(Theme.gradientAmberTeal)
                        .frame(width: 60, height: 60)
                        .shadow(color: Theme.amber.opacity(0.5), radius: 16)
                    Image(systemName: "sparkles")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Theme.void)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Create a session")
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("AI writes & narrates a hypnosis just for you")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Theme.textFaint)
            }
            .padding(18)
            .glassCard()
        }
        .buttonStyle(.plain)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionTitle("Your library")
                Spacer()
                NavigationLink {
                    LibraryView(playingSession: $playingSession)
                } label: {
                    Text("See all")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.amber)
                }
            }
            ForEach(sessions.prefix(3)) { session in
                Button {
                    playingSession = session
                } label: {
                    SessionRow(session: session)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(.title3, design: .rounded).weight(.semibold))
            .foregroundStyle(Theme.textPrimary)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default:      return "Time to unwind"
        }
    }
}

struct SessionRow: View {
    let session: SessionModel

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(session.goal.tint.opacity(0.18))
                    .frame(width: 46, height: 46)
                Image(systemName: session.goal.symbol)
                    .foregroundStyle(session.goal.tint)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(session.title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text("\(session.goal.shortTitle) · \(session.durationMinutes) min")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Image(systemName: "play.circle.fill")
                .font(.title2)
                .foregroundStyle(Theme.amber)
        }
        .padding(14)
        .glassCard(cornerRadius: 18)
    }
}
