//
//  CreditStore.swift
//  HypnoFlow
//
//  Tracks the user's generation credits. Subscription credits reset each month
//  (no rollover); top-up credits never expire. Stored locally for now — this is
//  the MVP ledger; a server-authoritative balance (RevenueCat Virtual Currency
//  or your own backend) would harden it against tampering later.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class CreditStore {
    /// This month's subscription allotment (resets, no rollover).
    private(set) var monthlyCredits: Int = 0
    /// Purchased top-up credits (never expire).
    private(set) var topUpCredits: Int = 0

    /// Total credits available to spend right now.
    var total: Int { monthlyCredits + topUpCredits }

    private var lastGrantPeriod: String = ""
    private var didOnboard: Bool = false

    private let defaults = UserDefaults.standard
    private enum Key {
        static let monthly = "credits.monthly"
        static let topup   = "credits.topup"
        static let period  = "credits.period"
        static let onboard = "credits.onboard"
    }

    init() { load() }

    /// Called on launch and whenever the subscription tier changes. Grants the
    /// monthly allotment when a new billing month begins.
    func sync(tier: Tier) {
        // One-time onboarding grant (non-expiring) so first-timers can try it.
        if !didOnboard {
            topUpCredits += 3
            didOnboard = true
        }

        let period = Self.currentPeriod()
        if tier == .free {
            monthlyCredits = 0
        } else if period != lastGrantPeriod {
            monthlyCredits = tier.monthlyCredits   // reset — no rollover
            lastGrantPeriod = period
        }
        persist()
    }

    /// Spends `amount` credits, drawing from the monthly pool first. Returns
    /// false (and changes nothing) when the balance is insufficient.
    @discardableResult
    func consume(_ amount: Int) -> Bool {
        guard amount > 0, total >= amount else { return false }
        let fromMonthly = min(monthlyCredits, amount)
        monthlyCredits -= fromMonthly
        topUpCredits   -= (amount - fromMonthly)
        persist()
        return true
    }

    /// Adds purchased top-up credits.
    func addTopUp(_ amount: Int) {
        guard amount > 0 else { return }
        topUpCredits += amount
        persist()
    }

    // MARK: - Persistence

    private func load() {
        monthlyCredits  = defaults.integer(forKey: Key.monthly)
        topUpCredits    = defaults.integer(forKey: Key.topup)
        lastGrantPeriod = defaults.string(forKey: Key.period) ?? ""
        didOnboard      = defaults.bool(forKey: Key.onboard)
    }

    private func persist() {
        defaults.set(monthlyCredits, forKey: Key.monthly)
        defaults.set(topUpCredits, forKey: Key.topup)
        defaults.set(lastGrantPeriod, forKey: Key.period)
        defaults.set(didOnboard, forKey: Key.onboard)
    }

    private static func currentPeriod() -> String {
        let c = Calendar.current.dateComponents([.year, .month], from: Date())
        return "\(c.year ?? 0)-\(c.month ?? 0)"
    }
}
