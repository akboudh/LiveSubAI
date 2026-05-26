# LiveSubAI

LiveSubAI is a native macOS app that shows live captions for system audio playing on your Mac.

It is an early MVP. It supports live captions through Deepgram streaming transcription and experimental translate-to-English subtitles through DeepL. Offline mode, full settings, and release signing are not implemented yet.

I am not responsible for anything that happens from using this software.

## Features

- Captures macOS system audio with Core Audio process taps.
- Avoids ScreenCaptureKit video capture, so it should not trigger screen-recording video capture paths.
- Streams multilingual audio to Deepgram over WebSocket.
- Shows partial and final transcript updates in an always-on-top click-through overlay.
- Translates finalized non-English subtitle segments to English with DeepL.
- Supports original-only, translate-to-English, and original + English display modes.
- Keeps translated final segments ordered even when translation responses return out of order.
- Menu bar controls for start/stop, caption mode, API key entry, show overlay, and quit.
- Global hotkey: `Option+Command+S` toggles subtitles.
- Global hotkey: `Option+Command+T` cycles caption mode.
- Stores Deepgram and DeepL API keys in Keychain.

## Requirements

- macOS 14.2 or newer.
- Apple Silicon Mac.
- Xcode 15 or newer.
- Deepgram API key.
- DeepL API key for translation mode.

## Build And Run

```sh
./script/build_and_run.sh
```

The script builds `LiveSubAI.xcodeproj` with `xcodebuild`, stages `dist/LiveSubAI.app`, and launches it.

If Xcode is in `~/Downloads/Xcode.app`, the script uses that automatically.

## API Keys

LiveSubAI uses Deepgram for live speech-to-text, so you need a Deepgram API key.

To get one:

1. Create or log in to a Deepgram account at [console.deepgram.com](https://console.deepgram.com/).
2. Select a project from the project dropdown.
3. Open **Settings**.
4. Open **API Keys**.
5. Click **Create a New API Key**.
6. Give it a recognizable name, choose the permissions/role Deepgram recommends for API usage, and create it.
7. Copy the key secret immediately and keep it somewhere safe. Deepgram does not show the full secret again after creation.

On first run, use **Set Deepgram API Key** in the control window or menu bar.

You can also seed Keychain once with:

```sh
DEEPGRAM_API_KEY="your-key" ./script/build_and_run.sh
```

For translation mode, LiveSubAI uses DeepL.

To get a DeepL API key:

1. Sign up for a DeepL API account from the [DeepL API plans page](https://www.deepl.com/pro-api).
2. Open your DeepL account.
3. Go to **API Keys & Limits** / **API Keys**.
4. Create or copy an API key.
5. In LiveSubAI, use **Set DeepL API Key** in the control window or menu bar.

DeepL Free API keys usually end in `:fx`; LiveSubAI uses that suffix to call DeepL's Free API endpoint automatically.

You can also seed Keychain once with:

```sh
DEEPL_API_KEY="your-key" ./script/build_and_run.sh
```

Do not commit API keys.

## Caption Modes

- **Original Only**: shows Deepgram captions directly.
- **Translate to English**: shows a small listening/translating state while speech is in progress, then displays the English translation for finalized segments.
- **Original + English**: shows English as the primary subtitle and the original source line below it.

Translation runs only on finalized transcript segments. Partials are not translated, which avoids flicker, repeated work, and unnecessary API cost.

## Permissions

LiveSubAI requests macOS **System Audio Recording** permission. It does not capture screen video.

After granting permission, quit and reopen the app if macOS asks you to.

## Unsigned Builds

This project is currently distributed as source. Prebuilt apps from this repo are unsigned and not notarized. macOS may show Gatekeeper warnings.

For best results, build locally with Xcode.

## Package Locally

```sh
./script/package_release.sh
```

Without an Apple Developer Program membership, the zip cannot be Developer ID signed and notarized.

## Roadmap

- Phase 2 hardening: test multilingual Deepgram quality on real content, add optional language hints, and tune translation latency.
- Phase 3: offline mode with whisper.cpp and settings polish.
- Phase 4: signed/notarized distribution, launch at login, and updater placeholder.

## License

MIT
