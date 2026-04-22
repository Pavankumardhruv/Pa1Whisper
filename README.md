<h1 align="center">Pa1Whisper</h1>

<p align="center">
  <strong>Free, open-source, offline voice-to-text for macOS.</strong><br>
  Tap a key, speak, tap again — your words appear at the cursor. 100% local, nothing leaves your Mac.
</p>

<p align="center">
  <a href="https://github.com/Pavankumardhruv/Pa1Whisper/blob/main/LICENSE"><img src="https://img.shields.io/github/license/Pavankumardhruv/Pa1Whisper?style=flat-square" alt="License"></a>
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue?style=flat-square&logo=apple&logoColor=white" alt="Platform">
  <img src="https://img.shields.io/badge/Swift-5.10-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift">
  <img src="https://img.shields.io/badge/Apple%20Silicon-M1%2FM2%2FM3%2FM4-000000?style=flat-square&logo=apple&logoColor=white" alt="Apple Silicon">
  <img src="https://img.shields.io/badge/100%25-offline-2ea44f?style=flat-square" alt="Offline">
</p>

<p align="center">
  <a href="#quick-start">Install</a> &bull;
  <a href="#how-it-works">Usage</a> &bull;
  <a href="#features">Features</a> &bull;
  <a href="#architecture">Architecture</a> &bull;
  <a href="#contributing">Contributing</a>
</p>

---

Pa1Whisper is a lightweight macOS menu-bar app that transcribes speech to text entirely on your Mac using [WhisperKit](https://github.com/argmaxinc/WhisperKit) (OpenAI Whisper optimized for Apple Silicon). Optional local LLM cleanup via [Ollama](https://ollama.com) fixes grammar and removes filler words — all without an internet connection.

**No cloud. No subscription. No data collection. Just fast, accurate voice typing.**

## Features

- **100% Local & Private** — All speech recognition runs on-device. No audio ever leaves your Mac
- **Works Offline** — After the one-time model download, no internet needed
- **Tap-to-Talk** — Tap Right ⌥ to start, speak, tap again to stop. Text appears at your cursor
- **Works in Any App** — VS Code, Terminal, Chrome, Slack, Notes, Pages — anywhere you type
- **AI Grammar Cleanup** — Optional local LLM removes filler words and fixes punctuation via Ollama
- **Transcription History** — Searchable log of all transcriptions with timestamps, duration, and one-click copy
- **Voice Assistant** — Tap Left ⌥ to ask a question, get a spoken answer (powered by Ollama)
- **Text to Speech** — Built-in TTS panel with voice selection and speed control
- **Multiple Whisper Models** — Tiny (39 MB), Base (140 MB), Small (460 MB) — pick your tradeoff
- **29 Languages** — English, Hindi, Spanish, French, German, Chinese, Japanese, and more
- **Lightweight** — <100 MB RAM, <1% CPU when idle
- **Menu Bar App** — Lives in your menu bar, no dock icon clutter

## Pa1Whisper vs Cloud Dictation

| | Pa1Whisper | Cloud Services |
|---|---|---|
| **Privacy** | 100% local | Voice uploaded to servers |
| **Internet** | Works offline | Required |
| **Cost** | Free forever | $10–20/month |
| **Latency** | Instant on-device | Network delay |
| **Data collection** | None | Voice stored on third-party servers |

## Quick Start

```bash
git clone https://github.com/Pavankumardhruv/Pa1Whisper.git
cd Pa1Whisper
bash build.sh
open build/Pa1Whisper.app
```

First build downloads WhisperKit dependencies (~2 min). Subsequent builds take ~5 seconds.

### After Launching

1. **Grant Microphone** — prompted automatically on first launch
2. **Grant Accessibility** — System Settings → Privacy & Security → Accessibility → toggle **ON**
3. The Whisper model downloads automatically on first launch (~140 MB for `base`)

Pa1Whisper lives in your **menu bar** (top-right). Look for the microphone icon.

## How It Works

**Tap Right ⌥** → speak → **tap Right ⌥** again. That's it.

```
1. Tap Right ⌥      →  Recording starts, Flow Bar shows "Listening..."
2. Speak             →  Audio captured locally at 16 kHz mono
3. Tap Right ⌥      →  Recording stops, audio sent to on-device Whisper
4. Cleanup (opt.)    →  Text cleaned by local LLM (if Ollama enabled)
5. Paste             →  Text automatically pasted at your cursor
```

Works in every app — editors, terminals, browsers, chat apps, documents.

## Whisper Models

| Model | Size | Speed | Accuracy | Best For |
|---|---|---|---|---|
| `tiny` | 39 MB | Fastest | Good | Quick notes, short phrases |
| `base` | 140 MB | Fast | Better | General dictation *(default)* |
| `small` | 460 MB | Moderate | Best | Longer passages, multilingual |
| `small.en` | 460 MB | Moderate | Best (EN) | English-only, highest accuracy |

Models download once from HuggingFace and are cached locally.

## Settings

| Setting | Description | Default |
|---|---|---|
| **Model** | Whisper model size | `base` |
| **Language** | 29 languages + auto-detect | English |
| **LLM Cleanup** | Ollama grammar correction | On |
| **Voice Assistant** | Left ⌥ voice chat | On |
| **Auto-paste** | Paste at cursor vs clipboard only | On |
| **Flow Bar** | Floating recording indicator | On |
| **Launch at Login** | Start on boot | Off |

## Optional: LLM Grammar Cleanup

When enabled, a local LLM cleans up transcriptions — removes "um", "uh", "like", fixes grammar and punctuation — before pasting. Everything stays on your Mac.

```bash
brew install ollama
ollama pull qwen2.5:3b
```

Pa1Whisper auto-detects Ollama. If unavailable, raw Whisper output is used (no errors).

## Architecture

```
Pa1Whisper.app (menu bar)
├── Core
│   ├── AudioEngine          — AVAudioEngine, 16 kHz mono capture
│   ├── WhisperTranscriber   — WhisperKit (CoreML + Apple Neural Engine)
│   ├── LLMCleanup           — Ollama HTTP API (localhost:11434)
│   ├── TextInjector         — NSPasteboard + CGEvent paste
│   ├── TranscriptionHistory — Persistent JSON storage in ~/Application Support
│   ├── VoiceAssistant       — Ollama conversation + TTS response
│   └── TTSManager           — AVSpeechSynthesizer with voice selection
├── Hotkey
│   └── GlobalHotkey         — Tap-to-toggle via NSEvent monitors
└── UI
    ├── SettingsView         — Menu bar popover (SwiftUI)
    ├── FlowBar              — Floating recording indicator with waveform
    ├── HistoryView          — Searchable transcription log panel
    └── TTSPanelView         — Text-to-speech interface
```

All speech recognition runs locally. The only network calls are:
- **One-time model download** from HuggingFace (first launch)
- **Ollama API** on `localhost:11434` (never leaves your machine)

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon (M1 / M2 / M3 / M4)
- Xcode Command Line Tools — `xcode-select --install`
- Ollama *(optional)* — for AI grammar cleanup and voice assistant

## Troubleshooting

<details>
<summary><strong>"Model not loaded" in the Flow Bar</strong></summary>

The Whisper model is still downloading. Check the settings panel for a progress indicator. First download takes 1–2 minutes depending on model size.
</details>

<details>
<summary><strong>Text isn't pasting into my app</strong></summary>

- Verify Accessibility permission is granted
- Some apps block CGEvent paste — turn off "Auto-paste" and use Cmd+V manually
</details>

<details>
<summary><strong>Ollama cleanup isn't working</strong></summary>

- Check Ollama is running: `ollama list` should show `qwen2.5:3b`
- If not installed: `brew install ollama && ollama pull qwen2.5:3b`
- Green dot next to "LLM Cleanup" in settings = Ollama connected
</details>

<details>
<summary><strong>Recording doesn't start on tap</strong></summary>

- Grant Accessibility permission in System Settings and restart the app
</details>

## Development

```bash
swift build              # Debug build
bash build.sh            # Build & package .app bundle
open build/Pa1Whisper.app
tail -f /tmp/pa1whisper.log  # View logs
```

Built with Swift 5.10, SwiftUI, and Swift Package Manager. No Xcode project required — builds entirely from the command line.

## Contributing

Contributions welcome:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes
4. Push and open a Pull Request

## License

MIT — see [LICENSE](LICENSE) for details.
