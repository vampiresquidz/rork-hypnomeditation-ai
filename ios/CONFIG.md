# Configuration (`Config.swift`)

`ios/HypnoFlow/Config.swift` holds secrets and is **gitignored** — it is never
committed, so you must create/fill it on every machine you build on (e.g. your Mac).

Create `ios/HypnoFlow/Config.swift` with:

```swift
import Foundation

enum Config {
    // Your own ElevenLabs API key — narration calls ElevenLabs directly when set.
    static let ELEVENLABS_API_KEY = "sk_your_elevenlabs_key_here"

    // Rork AI proxy — used for AI script generation (and for narration only if
    // ELEVENLABS_API_KEY is left empty).
    static let EXPO_PUBLIC_TOOLKIT_URL = "https://your-rork-toolkit-url"
    static let EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY = "your_rork_secret"
}
```

## How narration is generated

- **`ELEVENLABS_API_KEY` set** → `NarrationService` POSTs directly to
  `https://api.elevenlabs.io/v1/text-to-speech/{voiceId}` with the
  `xi-api-key` header. Recommended.
- **`ELEVENLABS_API_KEY` empty** → falls back to the Rork proxy
  (`EXPO_PUBLIC_TOOLKIT_URL` + bearer secret).

## Script generation

The hypnosis **script** (the words) is still written by the LLM through the Rork
proxy, so `EXPO_PUBLIC_TOOLKIT_URL` / `EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY` are
still required even when using a direct ElevenLabs key.

## Get an ElevenLabs key

https://elevenlabs.io → Profile → API Keys. The three narrator voice IDs used by
the app are defined in `Models/MeditationSession.swift` (`NarratorVoice.voiceId`) —
make sure your ElevenLabs account has access to those voices, or swap in your own IDs.
```
