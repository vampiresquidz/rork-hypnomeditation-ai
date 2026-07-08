# Data layer: SwiftData + CloudKit

HypnoFlow's saved library is a **SwiftData** store (`SessionModel`), read by the
views through `@Query` and written by `SessionStore`. When the iCloud capability
is enabled, SwiftData mirrors the store to **CloudKit** so a user's library
follows them across their devices automatically.

The code already ships with CloudKit wired up (`ModelConfiguration(cloudKitDatabase: .automatic)`),
with a **graceful fallback to a local-only store** if the capability isn't set up
yet — so the app builds and runs in every state. To actually turn on sync you must
enable the capability in Xcode (it needs your Apple Developer account, so it can't
be scripted).

## One-time Xcode setup (on your Mac)

1. **Signing & Capabilities** → select the **HypnoFlow** target.
2. Click **＋ Capability** → add **iCloud**.
   - Check **CloudKit**.
   - Under **Containers**, click **＋** and create:
     `iCloud.com.jellyfishai.hypnoflow`
     (must match the bundle id; Xcode registers it in your account.)
3. Click **＋ Capability** again → add **Background Modes**.
   - Check **Remote notifications** (lets CloudKit push changes for live sync).
4. Build & run on a device signed into iCloud. On first launch SwiftData creates
   the CloudKit schema automatically. To see records in
   [CloudKit Console](https://icloud.developer.apple.com/), promote the schema to
   Production before you ship (Console → Schema → **Deploy Schema Changes**).

That's it — no entitlements file to hand-edit; the capability toggles above create
`HypnoFlow.entitlements` and set it in the build settings for you.

## What syncs vs. what doesn't (important)

- **Syncs:** the session record — title, goal, voice, soundscape, intention,
  length, the script (lines/pauses/phases), and timestamps. Add a session on your
  iPhone and it appears on your iPad.
- **Does NOT sync:** the rendered **audio** files. They live in `Caches/` on each
  device (keyed by session id), which iOS never backs up or syncs. So on a second
  device a synced session shows up but would have no narration audio.

  If you want audio on every device, two options (happy to implement either):
  1. **Regenerate on demand** — if the stitched file is missing on this device,
     re-run narration for that session (costs TTS credits again).
  2. **Sync the stitched track** — store `session_full.m4a` as a CloudKit asset
     (`@Attribute(.externalStorage)` on a `Data` field, or a CKAsset) so the one
     combined file rides along. Simplest good-enough answer.

## SwiftData model rules we follow (for CloudKit)

CloudKit constrains the schema, and `SessionModel` is written to satisfy it:
- every stored property has a default value or is optional,
- no `@Attribute(.unique)` (CloudKit forbids unique constraints),
- no required relationships — the script is stored as an encoded blob
  (`segmentsData`) since we never query into it.

Keep these rules in mind when adding fields, or CloudKit mirroring will fail.

## Migration

First launch runs `SessionMigration.runIfNeeded`, which imports any pre-SwiftData
`library.json` (older builds) into the store and renames it to
`library.migrated.json` as a backup. It's guarded by a `UserDefaults` flag so it
only runs once. Nobody loses their existing sessions.
