# How to Build & Install Study Nook

**Study Nook** is your app. To install it properly (so it appears in the Start menu and can be pinned to the taskbar), use the MSIX installer.

---

## One-step install (recommended)

1. Open **PowerShell** in this folder (shift+right-click → "Open PowerShell window here", or `cd` to this folder).
2. Run:
   ```powershell
   .\build_nook.ps1
   ```
3. When asked *"Do you want to install the certificate?"* type **y** and press Enter.
4. When done, the installer **StudyNook.msix** will be in your **Downloads** folder and a file explorer window will open.
5. **Double-click** StudyNook.msix.
6. Click **Install**.
7. Open the **Start menu** → search for **Study Nook** → right-click → **Pin to taskbar**.

After that, Study Nook will be in your Start menu and on your taskbar, like any normal Windows app.

---

## Where things go

| What | Location |
|------|----------|
| MSIX installer (StudyNook.msix) | Your **Downloads** folder |
| Installed app (after you run the MSIX) | `C:\Program Files\WindowsApps\<package-id>\` (managed by Windows) |
| Start menu shortcut | Created automatically when you install |
| Raw exe (no installer) | `build\windows\x64\runner\Release\StudyNook.exe` |

---

## Manual build (if the script fails)

```powershell
# If Flutter isn't in your PATH:
$f = "C:\Users\adara\flutter\bin"
& "$f\flutter.bat" build windows --release
"y" | & "$f\dart.bat" run msix:create
```

---

## "ZIP decompression failed (-5)" error

If you see `cmake -E tar: error: ZIP decompression failed (-5)`, it usually means the Firebase SDK cache is corrupted. The build script now runs `flutter clean` first to fix this. If it still happens, run this manually:

```powershell
C:\Users\adara\flutter\bin\flutter.bat clean
Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue
C:\Users\adara\flutter\bin\flutter.bat pub get
C:\Users\adara\flutter\bin\flutter.bat build windows --release
```

Then run `.\build_nook.ps1` again (or run `dart run msix:create` to create the installer).

The `.msix` file will appear in the project folder. Copy it to Downloads (or anywhere) and double-click to install.

---

## Changing the logo

1. Replace `assets/app_icon.png` (1024×1024 recommended).
2. Run: `dart run flutter_launcher_icons`
3. Copy: `Copy-Item assets\app_icon.png windows\runner\resources\app_icon.png`
4. Rebuild and recreate the MSIX.
