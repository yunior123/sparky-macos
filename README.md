# Sparky — Native macOS Voice Assistant

> Your developer-focused Siri replacement. Built with Swift + SwiftUI, open source, always listening.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift 6](https://img.shields.io/badge/Swift-6.0-orange)
![License MIT](https://img.shields.io/badge/License-MIT-green)

## Features

- **Always-on wake word** — say "Hey Sparky" from anywhere
- **Zero dock footprint** — lives in your menu bar only
- **Floating HUD** — animated overlay shows listening/thinking/speaking state
- **Developer commands** — open projects, run git, flutter analyze, deploy
- **ElevenLabs TTS** — Daniel (British) voice with local fallback
- **LaunchAtLogin** — toggle from menu bar settings

## Commands

| Voice input | Action |
|---|---|
| `Hey Sparky open origna_gta` | Opens Terminal in that project dir + claude |
| `Hey Sparky run git status` | Injects `git status` into active Terminal |
| `Hey Sparky what's the weather` | Fetches Toronto weather (wttr.in) + speaks it |
| `Hey Sparky status` | Injects `git status` |
| `Hey Sparky analyze` | Injects `flutter analyze --no-fatal-infos` |
| `Hey Sparky deploy` | Injects `./scripts/deploy_web.sh` |
| `Hey Sparky <anything else>` | Injects raw command into active Terminal |

## Build from source

**Requirements:** macOS 13+, Xcode 15+, Swift 6

```bash
git clone https://github.com/yunior123/sparky-macos
cd sparky-macos

# Build & run directly
swift run

# Build .app bundle
./Scripts/package_app.sh

# Open the app
open dist/Sparky.app
```

## Architecture

```
SparkyApp.swift        — @main, MenuBarExtra, AppDelegate
SparkyViewModel.swift  — @MainActor state machine, orchestrates all engines
VoiceEngine.swift      — actor, continuous mic tap, VAD, wake word detection
SpeechRecognizer.swift — SFSpeechRecognizer + AVAudioEngine (from OrignaL)
CommandRouter.swift    — parse commands → execute (open/run/weather/inject)
TTSEngine.swift        — ElevenLabs Daniel voice + AVSpeechSynthesizer fallback
OverlayWindow.swift    — NSPanel floating HUD (always-on-top, no titlebar)
OverlayView.swift      — SwiftUI animated states (idle/listening/thinking/speaking)
AppTheme.swift         — colors, fonts, layout constants
LaunchAtLogin.swift    — SMAppService.mainApp API (macOS 13+)
```

## State machine

```
idle ──(sound)──▶ listening ──(silence)──▶ thinking ──(wake word)──▶ execute ──▶ idle
                                                  └──(no wake word)───────────────▶ idle
```

State is also written to `/tmp/sparky_state` for IPC compatibility with any external scripts.

## Permissions

On first launch, Sparky requests:
- **Microphone** — to hear your voice
- **Speech Recognition** — to transcribe commands
- **Accessibility** (prompted by System Settings) — to inject keystrokes into Terminal

## Configuration

ElevenLabs voice and API key can be updated in `TTSEngine.swift`. The default voice is [Daniel](https://elevenlabs.io/app/voice-lab) — British, warm, calm.

## License

MIT — see [LICENSE](LICENSE)
