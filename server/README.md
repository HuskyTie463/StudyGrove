# Study Grove AI server

The app talks to this small server instead of OpenAI or Anthropic. Keys stay on your computer (or a host you control). They are not packed into the app.

## Run it on this Windows PC

1. Open PowerShell in the Study Grove folder (`flutter_organiser`).
2. Install once:

```powershell
python -m pip install -r server\requirements.txt
```

3. Copy `server\.env.example` to `server\.env`.
4. Open `server\.env` in Notepad. Paste your Anthropic and OpenAI keys after the `=` signs. Save. Do not put this file on GitHub or USB.
5. Start the server:

```powershell
python -m uvicorn --app-dir server main:app --host 0.0.0.0 --port 8787
```

Leave that window open. On the same PC, the app uses `http://127.0.0.1:8787` by default.

## Phone on the same Wi‑Fi

In the `.env` window is not enough — the phone cannot see `127.0.0.1` on your PC.

1. Keep the server running with `--host 0.0.0.0` as above.
2. Find this PC’s Wi‑Fi address (something like `192.168.0.12`).
3. Rebuild the app with:

`--dart-define=STUDY_AI_PROXY_URL=http://192.168.0.12:8787`

Windows Firewall may ask to allow Python on private networks — allow it.

## TestFlight / a public URL

Point the build at a HTTPS URL you host (same command, or any host that can run this folder):

`--dart-define=STUDY_AI_PROXY_URL=https://your-proxy.example`

Store that URL as the GitHub secret `STUDY_AI_PROXY_URL` so Android and Mac store builds can use it.

You must be signed in to Study Grove. The server checks the Firebase login token. Project id: `study-app-18492`.
