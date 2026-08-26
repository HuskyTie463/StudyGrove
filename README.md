# Study Grove

A study organiser for **Windows** and **Mac**.

## Mac (USB stick — easiest)

You do **not** need Flutter or Xcode. Wait for the Mac package on this page:

**https://github.com/HuskyTie463/StudyGrove/releases/tag/macos-usb**

1. Download **StudyGrove-macos.zip**.
2. Copy that zip onto a USB stick.
3. On the Mac, unzip it.
4. Right-click **StudyGrove.app** → **Open** → **Open**.
5. Allow the microphone when Voice Chat asks.
6. In Settings, add an OpenAI key so Voice Chat can talk.

If macOS still blocks it, open Terminal and run:

```bash
xattr -cr ~/Desktop/StudyGrove/StudyGrove.app
```

then right-click → Open again.

## Windows

```bash
flutter pub get
flutter run -d windows
```
