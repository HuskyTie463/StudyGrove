# TestFlight (no Mac of your own)

You cannot drop a file into App Store Connect → TestFlight → **Builds**. Windows cannot make a signed Mac or iPhone build that Apple will accept. GitHub Actions uses a cloud Mac to sign and upload.

**Do Mac first**, then iPhone. Same app, same bundle ID: `com.adaracurry.studygrove`.

The USB zip workflow is separate. It stays unsigned for a stick. This page is **App Store / TestFlight** only.

Workflow: **Actions → App Store TestFlight → Run workflow**  
Leave **platform** on `macos` the first time. Choose `ios` later.

---

## 0. Add the macOS platform (browser)

Your Study Grove record is iOS-only so far. Mac TestFlight will not appear until you add Mac to the **same** app.

1. Open [App Store Connect](https://appstoreconnect.apple.com) → **My Apps** → **Study Grove**.
2. Under **Distribution** (or the **+** next to Platforms), click **Add Platform**.
3. Choose **macOS**. Do **not** create a second app.
4. Keep bundle ID `com.adaracurry.studygrove`.

Also on [Identifiers](https://developer.apple.com/account/resources/identifiers/list): open that App ID and enable **macOS** if it is not already on.

---

## 1. App Store Connect API key (once, used for Mac and iPhone)

1. **Users and Access** → **Integrations** (App Store Connect API).
2. **Generate API Key**. Name: `Study Grove CI`. Role: **App Manager** (or Admin).
3. Copy **Key ID** and **Issuer ID**.
4. **Download** the `.p8` (Apple allows this once). Leave it in Downloads. Never commit it.

---

## 2. Mac certificates from Windows (openssl)

You need **two** Mac certificates (not iOS):

- **Mac App Distribution** — signs the `.app`
- **Mac Installer Distribution** — signs the `.pkg` Apple actually accepts

Git for Windows includes openssl. In PowerShell:

```powershell
cd $env:USERPROFILE\Downloads
$ossl = "C:\Program Files\Git\usr\bin\openssl.exe"

& $ossl genrsa -out mac-app.key 2048
& $ossl req -new -key mac-app.key -out mac-app.csr -subj "/CN=Study Grove Mac App/C=AU"

& $ossl genrsa -out mac-installer.key 2048
& $ossl req -new -key mac-installer.key -out mac-installer.csr -subj "/CN=Study Grove Mac Installer/C=AU"
```

Then in [Certificates](https://developer.apple.com/account/resources/certificates/list) → **+**:

1. Choose **Mac App Distribution** → upload `mac-app.csr` → download the `.cer`.
2. Choose **Mac Installer Distribution** → upload `mac-installer.csr` → download that `.cer`.

Turn each `.cer` into a `.p12`. Use **the same password** both times, and use `-legacy`:

```powershell
cd $env:USERPROFILE\Downloads
$ossl = "C:\Program Files\Git\usr\bin\openssl.exe"

& $ossl x509 -inform DER -in macos_distribution.cer -out mac-app.pem
& $ossl pkcs12 -export -legacy -inkey mac-app.key -in mac-app.pem -out mac-app.p12 -name "Mac App Distribution"

& $ossl x509 -inform DER -in mac_installer.cer -out mac-installer.pem
& $ossl pkcs12 -export -legacy -inkey mac-installer.key -in mac-installer.pem -out mac-installer.p12 -name "Mac Installer Distribution"
```

Apple’s download names vary. If the files are not those names, use the real `.cer` filenames in Downloads. The password you type is `P12_PASSWORD`.

---

## 3. Mac App Store provisioning profile

1. [Profiles](https://developer.apple.com/account/resources/profiles/list) → **+**.
2. Under Distribution choose **Mac App Store**.
3. App ID: `com.adaracurry.studygrove`.
4. Certificate: the **Mac App Distribution** cert from step 2.
5. Name it e.g. `Study Grove Mac App Store`.
6. Download the `.provisionprofile` into Downloads.

---

## 4. GitHub secrets (Mac first)

PowerShell (copies one long line; it does not print the secret):

```powershell
cd $env:USERPROFILE\Downloads
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$PWD\mac-app.p12")) | Set-Clipboard
# paste into MAC_BUILD_CERTIFICATE_BASE64, then:
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$PWD\mac-installer.p12")) | Set-Clipboard
# paste into MAC_INSTALLER_CERTIFICATE_BASE64, then:
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$PWD\<your-mac-profile>.provisionprofile")) | Set-Clipboard
```

https://github.com/HuskyTie463/StudyGrove/settings/secrets/actions → **New repository secret**:

| Secret | Paste |
|---|---|
| `APP_STORE_CONNECT_KEY_ID` | Key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID |
| `APP_STORE_CONNECT_API_KEY` | Entire `.p8` text, including BEGIN / END lines |
| `MAC_BUILD_CERTIFICATE_BASE64` | `mac-app.p12` as base64 |
| `MAC_INSTALLER_CERTIFICATE_BASE64` | `mac-installer.p12` as base64 |
| `MAC_PROVISION_PROFILE_BASE64` | Mac `.provisionprofile` as base64 |
| `P12_PASSWORD` | Password you set on both `.p12` files |

Do not commit `.p8`, `.p12`, `.key`, or `.provisionprofile` files.

---

## 5. Run Mac TestFlight

1. https://github.com/HuskyTie463/StudyGrove/actions
2. **App Store TestFlight** → **Run workflow**.
3. Leave **platform** = `macos`.
4. Wait for a green job (often 15–25 minutes).

---

## 6. TestFlight on the Mac

1. App Store Connect → Study Grove → **TestFlight** → **macOS**.
2. Refresh. Processing is often 10–30 minutes after the Action succeeds. “No Builds” is normal until then.
3. Answer **export compliance** if Apple asks (HTTPS-only apps usually take the standard exemption).
4. **Internal testing**: add yourself and your friend (they need an App Store Connect invite).
5. On the Mac: install **TestFlight** from the Mac App Store, accept the invite, install Study Grove.

---

## 7. iPhone after Mac works

Only do this once a Mac build is on TestFlight.

**Certificates:** Apple Developer → **+** → **Apple Distribution** (this one is for iPhone). New CSR, same openssl pattern, `ios-app.p12`.

**Profile:** Profiles → **+** → **App Store Connect** → App ID `com.adaracurry.studygrove` → that Apple Distribution cert → download `.mobileprovision`.

**Extra secrets** (API key and `P12_PASSWORD` can stay as they are):

| Secret | Paste |
|---|---|
| `BUILD_CERTIFICATE_BASE64` | `ios-app.p12` as base64 |
| `BUILD_PROVISION_PROFILE_BASE64` | iOS `.mobileprovision` as base64 |

Then **App Store TestFlight** → **Run workflow** → set **platform** to `ios`.

When that job is green: TestFlight → **iOS** → Internal testing. Friend installs TestFlight on iPhone and installs Study Grove.
