# Configuration (`Config.swift`)

`ios/HypnoFlow/Config.swift` holds secrets and is **gitignored** — it is never
committed, so you must create/fill it on every machine you build on (e.g. your Mac).

Create `ios/HypnoFlow/Config.swift` with:

```swift
import Foundation

enum Config {
    // Your own OpenAI API key — scripts are written by calling OpenAI directly
    // when set. Empty = fall back to the Rork proxy.
    static let OPENAI_API_KEY = "sk-proj-your_openai_key_here"
    static let OPENAI_MODEL = "gpt-4o"

    // Your own ElevenLabs API key — narration calls ElevenLabs directly when set.
    static let ELEVENLABS_API_KEY = "sk_your_elevenlabs_key_here"

    // RevenueCat public SDK key (starts with "appl_"). Empty = IAP disabled.
    static let REVENUECAT_API_KEY = "appl_your_revenuecat_key"

    // Rork AI proxy — the fallback for script generation and narration when the
    // direct keys above are left empty.
    static let EXPO_PUBLIC_TOOLKIT_URL = "https://your-rork-toolkit-url"
    static let EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY = "your_rork_secret"
}
```

## In-app purchases (RevenueCat)

Payments use [RevenueCat](https://www.revenuecat.com). To make the paywall work:

1. **SDK — already added.** The RevenueCat Swift package
   (`https://github.com/RevenueCat/purchases-ios`, up-to-next-major from 5.0.0) is
   referenced in the Xcode project, so it resolves automatically on first build
   (needs network once). Nothing to add manually. If Xcode ever asks, use
   File → Packages → Resolve Package Versions.

2. **App Store Connect** → create the products with these exact IDs:

   | Type | Product ID | |
   |------|-----------|--|
   | Auto-renewable sub | `hypnoflow_plus_monthly` | Plus, $12.99/mo, 12 credits |
   | Auto-renewable sub | `hypnoflow_plus_yearly`  | Plus, $79.99/yr |
   | Auto-renewable sub | `hypnoflow_pro_monthly`  | Pro, $24.99/mo, 30 credits |
   | Auto-renewable sub | `hypnoflow_pro_yearly`   | Pro, $149.99/yr |
   | Consumable | `hypnoflow_credits_5`  | 5 credits, $4.99 |
   | Consumable | `hypnoflow_credits_15` | 15 credits, $12.99 |
   | Consumable | `hypnoflow_credits_50` | 50 credits, $39.99 |

3. **RevenueCat dashboard**:
   - Create **entitlements** named exactly `plus` and `pro`.
   - Attach the Plus products to `plus`, the Pro products to `pro`.
   - Create an **Offering** (the "current" one) and add all seven products as
     packages (subscriptions + the three consumable top-ups).
   - Copy the **public app-specific API key** (`appl_…`) into
     `Config.REVENUECAT_API_KEY`.

4. **Credit rules** (in code, `Models/Purchasing.swift`): Plus = 12 credits/mo,
   Pro = 30 credits/mo, reset monthly with no rollover; sessions ≤10 min cost 1
   credit, 15–20 min cost 2. New users get 3 onboarding credits. Balances are
   currently stored on-device (`CreditStore`); move to RevenueCat Virtual
   Currency or a backend before scaling if tamper-resistance matters.

## How narration is generated

- **`ELEVENLABS_API_KEY` set** → `NarrationService` POSTs directly to
  `https://api.elevenlabs.io/v1/text-to-speech/{voiceId}` with the
  `xi-api-key` header. Recommended.
- **`ELEVENLABS_API_KEY` empty** → falls back to the Rork proxy
  (`EXPO_PUBLIC_TOOLKIT_URL` + bearer secret).

## Script generation

- **`OPENAI_API_KEY` set** → `HypnosisScriptService` POSTs directly to
  `https://api.openai.com/v1/chat/completions` using `OPENAI_MODEL`. Recommended.
- **`OPENAI_API_KEY` empty** → falls back to the Rork proxy
  (`EXPO_PUBLIC_TOOLKIT_URL` + bearer secret), which requires both values to be set.

Either way the model must return the same JSON (`{title, segments[]}`); markdown
code fences around it are tolerated.

## Get an ElevenLabs key

https://elevenlabs.io → Profile → API Keys. The three narrator voice IDs used by
the app are defined in `Models/MeditationSession.swift` (`NarratorVoice.voiceId`) —
make sure your ElevenLabs account has access to those voices, or swap in your own IDs.
```
