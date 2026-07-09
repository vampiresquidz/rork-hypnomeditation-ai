//
//  SubscriptionManager.swift
//  HypnoFlow
//
//  Wraps RevenueCat: resolves the active subscription tier, exposes purchasable
//  packages (subscriptions + credit top-ups), and drives purchases/restores.
//
//  Requires the RevenueCat Swift package (https://github.com/RevenueCat/purchases-ios)
//  and Config.REVENUECAT_API_KEY. See ios/CONFIG.md.
//

import Foundation
import RevenueCat

@MainActor
@Observable
final class SubscriptionManager {
    private(set) var tier: Tier = .free
    private(set) var offerings: Offerings?
    private(set) var isConfigured = false

    /// Invoked with the resolved tier whenever entitlements change — wire this
    /// to CreditStore.sync(tier:) so credits are (re)granted on renewal.
    var onTierChange: ((Tier) -> Void)?

    func configure() {
        let key = Config.REVENUECAT_API_KEY.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !isConfigured else { return }

        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: key)
        isConfigured = true

        Task { await refresh() }
        Task {
            for await info in Purchases.shared.customerInfoStream {
                apply(info)
            }
        }
    }

    func refresh() async {
        guard isConfigured else { return }
        offerings = try? await Purchases.shared.offerings()
        if let info = try? await Purchases.shared.customerInfo() { apply(info) }
    }

    private func apply(_ info: CustomerInfo) {
        if info.entitlements.active[Entitlement.pro]?.isActive == true {
            tier = .pro
        } else if info.entitlements.active[Entitlement.plus]?.isActive == true {
            tier = .plus
        } else {
            tier = .free
        }
        onTierChange?(tier)
    }

    // MARK: - Products

    /// All packages across every offering (subscriptions and top-ups).
    private var packages: [Package] {
        guard let offerings else { return [] }
        if let current = offerings.current { return current.availablePackages }
        return offerings.all.values.flatMap { $0.availablePackages }
    }

    private func package(id productID: String) -> Package? {
        packages.first { $0.storeProduct.productIdentifier == productID }
    }

    /// Localized price (e.g. "$12.99") for a product, if the store returned it.
    func priceString(for productID: String) -> String? {
        package(id: productID)?.storeProduct.localizedPriceString
    }

    // MARK: - Purchase / restore

    /// Purchases a product by identifier. Returns the purchased product id on
    /// success, or nil if the user cancelled.
    @discardableResult
    func purchase(productID: String) async throws -> String? {
        guard let package = package(id: productID) else { return nil }
        let result = try await Purchases.shared.purchase(package: package)
        if result.userCancelled { return nil }
        apply(result.customerInfo)
        return result.transaction?.productIdentifier ?? productID
    }

    func restore() async {
        if let info = try? await Purchases.shared.restorePurchases() { apply(info) }
    }

    // MARK: - Identity

    /// Associates purchases/entitlements with a stable account id (the Apple user
    /// identifier) so a subscription follows the person across devices.
    func identify(_ appUserID: String) async {
        guard isConfigured else { return }
        if let (info, _) = try? await Purchases.shared.logIn(appUserID) { apply(info) }
    }

    /// Returns to an anonymous RevenueCat user (on sign out).
    func signOutUser() async {
        guard isConfigured else { return }
        if let info = try? await Purchases.shared.logOut() { apply(info) }
    }

    // MARK: - Manage / cancel

    /// Presents Apple's native "Manage Subscriptions" sheet, where the user can
    /// change or cancel their plan (apps can't cancel a subscription directly).
    /// Returns false if it couldn't be shown, so the caller can fall back to the
    /// App Store subscriptions URL.
    @discardableResult
    func openManageSubscriptions() async -> Bool {
        guard isConfigured else { return false }
        do {
            try await Purchases.shared.showManageSubscriptions()
            await refresh()   // reflect any change they made
            return true
        } catch {
            return false
        }
    }
}
