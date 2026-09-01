# iPhone TestFlight (no Mac)

You cannot drop a file into App Store Connect → TestFlight → **Builds**. That page lists builds Apple has already received. Windows also cannot make a signed `.ipa` that Apple will accept. This repo uses **GitHub Actions on a Mac runner** to sign the app and upload it for you.

App: **Study Grove**  
Bundle ID: `com.adaracurry.studygrove`  
Workflow: **Actions → iOS TestFlight → Run workflow**

---

## 1. App Store Connect API key (browser)

1. Open [App Store Connect](https://appstoreconnect.apple.com) and sign in.
2. Click **Users and Access**.
3. Open **Integrations** (sometimes labelled **Keys** under App Store Connect API).
4. Click **Generate API Key** (Account Holder or Admin).
5. Name it something like `Study Grove CI`. Role: **App Manager** (or Admin).
6. After it is created, copy:
   - **Key ID**
   - **Issuer ID** (shown at the top of the keys page)
7. Click **Download** on the `.p8` file. Apple lets you download it **once**. Keep it off the repo (Downloads is fine).

---

## 2. Apple Distribution certificate (Windows + openssl)

You need **Git for Windows** (it includes `openssl`). In PowerShell:

```powershell
cd $env:USERPROFILE\Downloads
& "C:\Program Files\Git\usr\bin\openssl.exe" genrsa -out studygrove.key 2048
& "C:\Program Files\Git\usr\bin\openssl.exe" req -new -key studygrove.key -out studygrove.csr -subj "/CN=Study Grove Distribution/C=AU"
```

1. Open [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/certificates/list).
2. **Certificates** → **+**.
3. Choose **Apple Distribution** → Continue.
4. Upload `studygrove.csr` from Downloads.
5. Download the certificate (`distribution.cer`) into Downloads.

Turn the `.cer` + private key into a `.p12`. Use `-legacy` so the Mac runner can import it:

```powershell
cd $env:USERPROFILE\Downloads
& "C:\Program Files\Git\usr\bin\openssl.exe" x509 -inform DER -in distribution.cer -out studygrove.pem
& "C:\Program Files\Git\usr\bin\openssl.exe" pkcs12 -export -legacy -inkey studygrove.key -in studygrove.pem -out studygrove.p12 -name "Apple Distribution"
```

Pick a password when asked. You will put that password in GitHub as `P12_PASSWORD`.

---

## 3. App Store provisioning profile

1. Same Apple Developer site → **Identifiers**. Confirm **App ID** `com.adaracurry.studygrove` exists (explicit, not a wildcard). Create it if needed.
2. **Profiles** → **+**.
3. Under Distribution, choose **App Store Connect**.
4. Select App ID `com.adaracurry.studygrove`.
5. Select the **Apple Distribution** certificate you just made.
6. Name it e.g. `Study Grove App Store`.
7. Download the `.mobileprovision` into Downloads.

---

## 4. Base64 the files and add GitHub secrets

In PowerShell (this copies one long line to the clipboard; it is not a password dump to the screen):

```powershell
cd $env:USERPROFILE\Downloads
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$PWD\studygrove.p12")) | Set-Clipboard
```

Then:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$PWD\<your-profile>.mobileprovision")) | Set-Clipboard
```

Replace `<your-profile>` with the real filename.

Open **https://github.com/HuskyTie463/StudyGrove/settings/secrets/actions** → **New repository secret**. Add these six:

| Secret name | What to paste |
|---|---|
| `APP_STORE_CONNECT_KEY_ID` | Key ID from step 1 |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID from step 1 |
| `APP_STORE_CONNECT_API_KEY` | Entire `.p8` file text, including the BEGIN / END lines |
| `BUILD_CERTIFICATE_BASE64` | Clipboard after encoding `studygrove.p12` |
| `P12_PASSWORD` | Password you set when creating the `.p12` |
| `BUILD_PROVISION_PROFILE_BASE64` | Clipboard after encoding the `.mobileprovision` |

Do **not** commit the `.p8`, `.p12`, `.key`, or `.mobileprovision` files.

---

## 5. Run the workflow

1. Open **https://github.com/HuskyTie463/StudyGrove/actions**.
2. Click **iOS TestFlight**.
3. Click **Run workflow** (branch `main` is fine).
4. Wait until the job is green. The first run often takes 15–25 minutes.

Each run uses the GitHub run number as the iOS build number (Apple requires it to go up every upload).

You can also push a git tag that starts with `ios-` (for example `ios-1.0.6`) to start the same job.

---

## 6. Wait in TestFlight, then Internal testing

1. Back in App Store Connect → **TestFlight** → **iOS** for Study Grove.
2. Refresh. Processing usually takes 10–30 minutes after the Action succeeds. “No Builds” is normal until then.
3. If Apple asks about **export compliance**, answer the form (HTTPS-only apps typically select the standard exemption).
4. Open **Internal testing**. Add yourself and your friend as testers (they need an App Store Connect user invite).
5. On the iPhone, install **TestFlight** from the App Store, accept the email/invite, and install Study Grove.

External testers are optional and need a review. Internal testing is the fast path for a friend.
