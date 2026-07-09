# Accounts: Sign in with Apple

HypnoFlow uses **Sign in with Apple** for account identity — no backend required.
Being signed in:

- lets a returning user **skip onboarding** (the funnel only shows for signed-out,
  not-yet-onboarded users),
- gives RevenueCat a **stable app user id** so a subscription follows the person
  across devices,
- pairs with CloudKit (which already syncs the library by iCloud account).

## How it works in the app

- `AuthStore` (`Services/AuthStore.swift`) holds the signed-in state. The Apple
  user identifier is stored in the **Keychain**; the one-time name/email Apple
  returns on first sign-in are cached in UserDefaults for display.
- The onboarding welcome screen has an **"Already have an account? Log in"**
  button → presents `LoginSheet` with the Apple button.
- `Home` has a profile button (top-left) → `AccountView` to sign in/out and
  restore purchases.
- On launch the app verifies the stored credential is still valid
  (`getCredentialState`) and signs the user out locally if they revoked access.

## One-time Xcode setup (on your Mac)

Sign in with Apple needs a capability + entitlement. Until it's added, the button
appears but authorization fails at runtime.

1. **Signing & Capabilities** → select the **HypnoFlow** target.
2. Click **＋ Capability** → add **Sign in with Apple**.

That's it — Xcode adds the `com.apple.developer.applesignin` entitlement and
registers the capability with your App ID. (Requires the paid Apple Developer
Program, same as CloudKit / in-app purchases.)

## Notes

- Apple hands back the user's **name/email only on the first authorization**. We
  cache them then; on later sign-ins only the stable `user` id comes through.
- Signing out returns RevenueCat to an anonymous user and clears the local
  identity, but **does not delete** the on-device / iCloud library.
- This is identity only — there's no server. If you later add email/password or
  social logins, Apple requires Sign in with Apple to remain offered alongside
  them.
