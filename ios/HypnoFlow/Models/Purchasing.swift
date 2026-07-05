//
//  Purchasing.swift
//  HypnoFlow
//
//  Subscription tiers, product identifiers, and the credit rules that tie the
//  business model to the code. Keep these product IDs in sync with App Store
//  Connect and the RevenueCat dashboard.
//

import Foundation

/// The subscription level the user is on.
enum Tier: String, Codable {
    case free, plus, pro

    var displayName: String {
        switch self {
        case .free: "Free"
        case .plus: "Plus"
        case .pro:  "Pro"
        }
    }

    /// Credits granted at the start of each billing month (do not roll over).
    var monthlyCredits: Int {
        switch self {
        case .free: 0
        case .plus: 12
        case .pro:  30
        }
    }
}

/// RevenueCat entitlement identifiers (configured in the dashboard).
enum Entitlement {
    static let plus = "plus"
    static let pro  = "pro"
}

/// App Store / RevenueCat product identifiers.
enum StoreProductID {
    // Auto-renewable subscriptions
    static let plusMonthly = "hypnoflow_plus_monthly"
    static let plusYearly  = "hypnoflow_plus_yearly"
    static let proMonthly  = "hypnoflow_pro_monthly"
    static let proYearly   = "hypnoflow_pro_yearly"

    // Consumable credit top-ups
    static let credits5  = "hypnoflow_credits_5"
    static let credits15 = "hypnoflow_credits_15"
    static let credits50 = "hypnoflow_credits_50"

    /// Credits granted by a consumable top-up product (nil if not a top-up).
    static func topUpCredits(for productID: String) -> Int? {
        switch productID {
        case credits5:  5
        case credits15: 15
        case credits50: 50
        default:        nil
        }
    }
}

/// How many credits a session costs, by length. Longer sessions cost more so
/// the credit ↔ fulfilment-cost relationship stays honest.
func creditCost(durationMinutes: Int) -> Int {
    durationMinutes >= 15 ? 2 : 1
}
