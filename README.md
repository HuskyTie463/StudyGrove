# Study Grove

A study organiser for **Windows** and **Mac**. Voice Chat, Lecture Lab, and the rest of the app live in this folder.

## Mac (for testers)

1. Install [Xcode](https://apps.apple.com/app/xcode/id497799835) from the App Store. Open it once so the extra tools can install.
2. Install [Flutter](https://docs.flutter.dev/get-started/install/macos/desktop).
3. In Terminal:

```bash
cd study-grove
flutter pub get
flutter run -d macos
```

If macOS says the app cannot be opened: right-click it → **Open**.

Allow the microphone when Voice Chat asks.

Voice Chat and Listen need an OpenAI key in **Settings → Listen voices**. Study AI needs an Anthropic or OpenAI key in Settings.

## Windows

```bash
flutter pub get
flutter run -d windows
```
