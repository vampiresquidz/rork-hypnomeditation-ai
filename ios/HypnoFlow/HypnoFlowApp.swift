//
//  HypnoFlowApp.swift
//  HypnoFlow
//
//  Created by Rork on July 4, 2026.
//

import SwiftUI

@main
struct HypnoFlowApp: App {
    @State private var store = SessionStore()
    @State private var subscriptions = SubscriptionManager()
    @State private var credits = CreditStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(subscriptions)
                .environment(credits)
                .task {
                    // Grant onboarding/monthly credits, then keep them in sync
                    // as the subscription entitlement changes.
                    credits.sync(tier: subscriptions.tier)
                    subscriptions.onTierChange = { tier in
                        credits.sync(tier: tier)
                    }
                    subscriptions.configure()
                }
        }
    }
}
