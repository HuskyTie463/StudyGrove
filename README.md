# Study Grove

A study organiser for **Windows** and **Mac**.

## Mac (USB stick — easiest)

You do **not** need Flutter or Xcode. Wait for the Mac package on this page:

**https://github.com/HuskyTie463/StudyGrove/releases/tag/macos-usb**

1. Download **StudyGrove-macos.zip**.
2. Copy that zip onto a USB stick.
3. On the Mac, copy the unzipped **StudyGrove** folder to the Desktop. Do not run it from the USB stick.
4. Double-click **Open Study Grove.command**. If macOS blocks it, right-click → **Open**.
5. Allow the microphone when Voice Chat asks.

Voice Chat and Study AI already include built-in keys. You can still paste your own in Settings.

If it says **quit unexpectedly**, use a **new** download (old zips keep crashing), then in Terminal:

```bash
xattr -cr ~/Desktop/StudyGrove
open ~/Desktop/StudyGrove/StudyGrove.app
```

## Mac TestFlight (App Store — do this before iPhone)

You cannot upload a signed Mac or iPhone build from Windows. TestFlight’s **Builds** page is not a file-drop box.

1. In App Store Connect, open Study Grove and **add the macOS platform** (same app, same bundle ID). The record is iOS-only until you do this.
2. Follow **[TESTFLIGHT.md](TESTFLIGHT.md)** for the API key, **Mac App Distribution** + **Mac Installer** certificates, and Mac App Store profile.
3. **Actions → App Store TestFlight → Run workflow** with **platform = macos**.
4. When the job is green, refresh TestFlight → **macOS** → **Internal testing**. Your friend installs TestFlight from the Mac App Store.

iPhone is the same workflow later, with **platform = ios**. The USB zip above is a different, unsigned path and is unchanged.

## Windows

```bash
flutter pub get
flutter run -d windows
```
