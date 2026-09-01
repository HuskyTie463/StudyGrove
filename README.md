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

## iPhone (TestFlight — no Mac)

You cannot upload an IPA from Windows, and TestFlight’s **Builds** page is not a file-drop box. A GitHub Action on a Mac runner signs Study Grove and sends it to App Store Connect.

Follow **[TESTFLIGHT.md](TESTFLIGHT.md)**: create the API key, certificate, and profile in the browser, paste six GitHub secrets, then **Actions → iOS TestFlight → Run workflow**. When that job is green, refresh TestFlight and use **Internal testing**.

## Windows

```bash
flutter pub get
flutter run -d windows
```
