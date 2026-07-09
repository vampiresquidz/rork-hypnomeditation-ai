//
//  AuthStore.swift
//  HypnoFlow
//
//  Account identity via Sign in with Apple. Being signed in lets a returning
//  user skip onboarding, and gives a stable id we can hand to RevenueCat so
//  entitlements follow the person across devices.
//
//  The Apple user identifier is kept in the Keychain; the (one-time) name/email
//  Apple hands back on first sign-in are cached in UserDefaults for display.
//

import SwiftUI
import AuthenticationServices

@MainActor
@Observable
final class AuthStore {
    private(set) var userID: String?
    private(set) var displayName: String?
    private(set) var email: String?

    var isSignedIn: Bool { userID != nil }

    /// Fired when the user signs in / out, so other systems (RevenueCat) can
    /// identify or reset. Wired up in HypnoFlowApp.
    var onSignIn: ((String) -> Void)?
    var onSignOut: (() -> Void)?

    private enum Keys {
        static let userID = "auth.appleUserID"
        static let name = "auth.displayName"
        static let email = "auth.email"
    }

    init() {
        userID = Keychain.get(Keys.userID)
        displayName = UserDefaults.standard.string(forKey: Keys.name)
        email = UserDefaults.standard.string(forKey: Keys.email)
    }

    // MARK: - Sign in with Apple

    /// Configures the authorization request scopes. Pass to SignInWithAppleButton.
    func configureRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }

    /// Handles the SignInWithAppleButton completion result.
    func handle(_ result: Result<ASAuthorization, Error>) {
        guard
            case .success(let authorization) = result,
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential
        else { return }

        let id = credential.user
        userID = id
        Keychain.set(id, for: Keys.userID)

        // Apple only returns name/email the very first time — cache them if present.
        if let full = credential.fullName {
            let name = [full.givenName, full.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespaces)
            if !name.isEmpty {
                displayName = name
                UserDefaults.standard.set(name, forKey: Keys.name)
            }
        }
        if let mail = credential.email {
            email = mail
            UserDefaults.standard.set(mail, forKey: Keys.email)
        }

        onSignIn?(id)
    }

    func signOut() {
        userID = nil
        displayName = nil
        email = nil
        Keychain.delete(Keys.userID)
        UserDefaults.standard.removeObject(forKey: Keys.name)
        UserDefaults.standard.removeObject(forKey: Keys.email)
        onSignOut?()
    }

    /// On launch, confirm the stored Apple credential is still valid — the user
    /// may have revoked access in Settings. Signs out locally if so.
    func refreshCredentialState() async {
        guard let userID else { return }
        let provider = ASAuthorizationAppleIDProvider()
        let state: ASAuthorizationAppleIDProvider.CredentialState =
            await withCheckedContinuation { continuation in
                provider.getCredentialState(forUserID: userID) { state, _ in
                    continuation.resume(returning: state)
                }
            }
        if state == .revoked || state == .notFound {
            signOut()
        }
    }
}
