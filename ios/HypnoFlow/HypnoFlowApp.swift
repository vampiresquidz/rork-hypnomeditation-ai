//
//  HypnoFlowApp.swift
//  HypnoFlow
//
//  Created by Rork on July 4, 2026.
//

import SwiftUI
import SwiftData

@main
struct HypnoFlowApp: App {
    private let container: ModelContainer

    @State private var store: SessionStore
    @State private var subscriptions = SubscriptionManager()
    @State private var credits = CreditStore()
    @State private var onboarding = OnboardingStore()
    @State private var auth = AuthStore()
    @State private var reminders = ReminderManager()
    @State private var streaks = StreakStore()

    init() {
        let container = Self.makeContainer()
        self.container = container
        _store = State(initialValue: SessionStore(context: container.mainContext))
        // Lift any pre-SwiftData library into the store on first launch.
        SessionMigration.runIfNeeded(context: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(subscriptions)
                .environment(credits)
                .environment(onboarding)
                .environment(auth)
                .environment(reminders)
                .environment(streaks)
                .task {
                    // Grant onboarding/monthly credits, then keep them in sync
                    // as the subscription entitlement changes.
                    credits.sync(tier: subscriptions.tier)
                    subscriptions.onTierChange = { tier in
                        credits.sync(tier: tier)
                    }

                    // Tie account identity to RevenueCat so entitlements follow
                    // the person across devices.
                    auth.onSignIn = { userID in
                        Task { await subscriptions.identify(userID) }
                    }
                    auth.onSignOut = {
                        Task { await subscriptions.signOutUser() }
                    }

                    subscriptions.configure()

                    // Confirm the stored Apple credential is still valid, and
                    // (re)identify an already-signed-in user with RevenueCat.
                    await auth.refreshCredentialState()
                    if let userID = auth.userID {
                        await subscriptions.identify(userID)
                    }

                    // Adopt the reminder time the user hinted at during onboarding,
                    // then keep the rolling two-week reminder window fresh.
                    reminders.adoptSuggestedTime(onboarding.unwindTime)
                    await reminders.refreshScheduleIfNeeded()
                }
        }
        .modelContainer(container)
    }

    /// Builds the SwiftData container. Prefers an iCloud-synced store so a user's
    /// library follows them across devices; if the CloudKit entitlement isn't set
    /// up yet, falls back to a local-only store so the app still runs everywhere.
    private static func makeContainer() -> ModelContainer {
        let schema = Schema([SessionModel.self])

        let cloudConfig = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        if let container = try? ModelContainer(for: schema, configurations: cloudConfig) {
            return container
        }

        let localConfig = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: localConfig)
        } catch {
            fatalError("Could not create the HypnoFlow data store: \(error)")
        }
    }
}
