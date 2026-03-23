<p align="center">
  <img src="Pa1Whisper/Resources/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="128" height="128" alt="Pa1Whisper icon" />
</p>

<h1 align="center">Pa1Whisper</h1>

<p align="center">
  <strong>Free, open-source, offline voice-to-text for macOS.</strong><br>
  Hold a key, speak, release — your words appear at the cursor. 100% local, nothing leaves your Mac.
</p>

<p align="center">
  <a href="#installation">Install</a> &bull;
  <a href="#how-it-works">Usage</a> &bull;
  <a href="#features">Features</a> &bull;
  <a href="#settings">Settings</a> &bull;
  <a href="#contributing">Contributing</a>
</p>

---

Pa1Whisper is a lightweight macOS menu-bar app that transcribes speech to text entirely on your Mac using [WhisperKit](https://github.com/argmaxinc/WhisperKit) (OpenAI Whisper optimized for Apple Silicon). Optional local LLM cleanup via [Ollama](https://ollama.com) fixes grammar and removes filler words — all without an internet connection.

**No cloud. No subscription. No data collection. Just fast, accurate voice typing.**

## Features

- **100% Local & Private** — All speech recognition runs on-device. No audio ever leaves your Mac
- **Works Offline** — After the one-time model download, no internet needed
- **Hold-to-Talk** — Hold Right Option (⌥), speak, release. Text appears at your cursor
- **Works in Any App** — VS Code, Terminal, Chrome, Slack, Notes, Pages — anywhere you type
- **AI Grammar Cleanup** — Optional local LLM removes filler words, fixes punctuation (via Ollama)
- **Multiple Whisper Models** — Tiny (39 MB), Base (140 MB), Small (460 MB) — pick your tradeoff
- **29 Languages** — English, Hindi, Spanish, French, German, Chinese, Japanese, and more
- **Lightweight** — <100 MB RAM, <1% CPU when idle
- **Menu Bar App** — Lives in your menu bar. No dock icon clutter

## Pa1Whisper vs Cloud Dictation Services

| | Pa1Whisper | Cloud Services |
|---|---|---|
| **Privacy** | 100% local | Voice uploaded to servers |
| **Internet** | Works offline | Required |
| **Cost** | Free forever | $10–20/month |
| **Latency** | Instant on-device | Network delay |
| **Data collection** | None | Voice stored on third-party servers |

## Requirements

- **macOS 14.0** (Sonoma) or later
- **Apple Silicon** Mac (M1 / M2 / M3 / M4)
- **Xcode Command Line Tools** — `xcode-select --install`
- **Ollama** *(optional)* — for AI grammar cleanup

## Installation

### Quick Start

```bash
git clone https://github.com/Pavankumardhruv/Pa1Whisper.git
cd Pa1Whisper
bash build.sh
open build/Pa1Whisper.app
```

The first build downloads WhisperKit dependencies (~2 min). Subsequent builds take ~5 seconds.

### After Launching

1. **Grant Microphone** — prompted automatically on first launch
2. **Grant Accessibility** — System Settings → Privacy & Security → Accessibility → toggle **ON** Pa1Whisper
3. The Whisper model downloads automatically on first launch (~140 MB for `base`)

Pa1Whisper lives in your **menu bar** (top-right of your screen). Look for the microphone icon.

### Install to /Applications (optional)

The build script automatically copies Pa1Whisper to `/Applications`. To skip this:

```bash
SKIP_INSTALL=1 bash build.sh
```

### Launch at Login

Enable "Launch at Login" in the Pa1Whisper settings panel to start automatically on boot.

## How It Works

**Hold Right ⌥ (Option)** → speak → release. That's it.

```
1. Hold Right ⌥     →  Recording starts, Flow Bar shows "Listening..."
2. Speak             →  Audio captured locally at 16 kHz mono
3. Release           →  Audio transcribed by on-device Whisper model
4. Cleanup (opt.)    →  Text cleaned by local LLM (if Ollama enabled)
5. Paste             →  Text automatically pasted at your cursor
```

Works in every app — editors, terminals, browsers, chat apps, documents.

## Whisper Models

Choose a model in the settings panel:

| Model | Size | Speed | Accuracy | Best For |
|---|---|---|---|---|
| `tiny` | 39 MB | Fastest | Good | Quick notes, short phrases |
| `base` | 140 MB | Fast | Better | General dictation *(default)* |
| `small` | 460 MB | Moderate | Best | Longer passages, multilingual |
| `small.en` | 460 MB | Moderate | Best (EN) | English-only, highest accuracy |

Models are downloaded once from HuggingFace and cached locally.

## Settings

| Setting | Description | Default |
|---|---|---|
| **Model** | Whisper model size | `base` |
| **Language** | 29 languages + auto-detect | English |
| **LLM Cleanup** | Ollama grammar correction | On |
| **Auto-paste** | Paste at cursor vs clipboard only | On |
| **Flow Bar** | Floating recording indicator | On |
| **Launch at Login** | Start on boot | Off |

## Optional: LLM Grammar Cleanup

When enabled, a local LLM cleans up transcriptions — removes "um", "uh", "like", fixes grammar and punctuation — before pasting. Everything stays on your Mac.

```bash
# Install Ollama
brew install ollama

# Pull the cleanup model (1.5 GB one-time download)
ollama pull qwen2.5:3b
```

Pa1Whisper auto-detects Ollama. If unavailable, raw Whisper output is used instead (no errors).

## macOS Permissions

| Permission | Why | How |
|---|---|---|
| **Microphone** | Capture voice for transcription | Auto-prompted on first use |
| **Accessibility** | Global hotkey detection & auto-paste | System Settings → Privacy → Accessibility |

## Supported Languages

English, Spanish, French, German, Italian, Portuguese, Dutch, Russian, Chinese, Japanese, Korean, Hindi, Telugu, Tamil, Kannada, Malayalam, Bengali, Marathi, Gujarati, Urdu, Punjabi, Arabic, Turkish, Polish, Thai, Vietnamese, Indonesian, Ukrainian, Swedish.

## Architecture

```
Pa1Whisper.app (menu bar)
├── AudioEngine        — AVAudioEngine, 16 kHz mono capture
├── WhisperTranscriber — WhisperKit (CoreML + Apple Neural Engine)
├── LLMCleanup         — Ollama HTTP API (localhost:11434)
├── TextInjector       — NSPasteboard + CGEvent Cmd+V
├── GlobalHotkey       — Right ⌥ via NSEvent monitors
└── UI
    ├── MenuBar + Settings popover
    └── FlowBar (floating NSPanel with waveform animation)
```

All speech recognition runs locally. The only network calls are:
- **One-time model download** from HuggingFace (first launch)
- **Ollama API** on `localhost:11434` (never leaves your machine)

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
<summary><strong>Recording doesn't start when I hold Right ⌥</strong></summary>

- Grant Accessibility permission and restart the app
</details>

<details>
<summary><strong>Build fails</strong></summary>

- Install Xcode Command Line Tools: `xcode-select --install`
- Requires macOS 14.0+ and Apple Silicon (M1/M2/M3/M4)
</details>

## Development

```bash
# Build (debug)
swift build

# Build & package .app bundle
bash build.sh

# Run
open build/Pa1Whisper.app

# View logs
tail -f /tmp/pa1whisper.log
```

Built with Swift 5.10, SwiftUI, and Swift Package Manager. No Xcode project required — builds entirely from the command line.

## Contributing

Contributions are welcome! Feel free to:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

MIT License — see [LICENSE](LICENSE) for details.

---

<p align="center">
  Made with ❤️ by <a href="https://github.com/Pavankumardhruv">Pavan</a>
</p>
