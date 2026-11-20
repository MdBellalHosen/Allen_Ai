# ALLEN web app (PWA) — free, works on PC and iPhone

The backend serves the website at `/app/`. It uses the same agent API as the Android app.

## 1. Try on your PC
1. Put your free LLM key in `.env` (see FREE_SETUP.md), then run `scripts/dev_up.sh`.
2. Open `http://localhost:8000/app/` in Chrome or Edge. Mic works on localhost.
3. Say or type: "youtube e lofi music search koro", "Facebook kholo".

## 2. iPhone (needs HTTPS)
1. Install cloudflared (free): https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/
2. With the backend running: `cloudflared tunnel --url http://localhost:8000`
3. Open the printed `https://....trycloudflare.com/app/` link in **Safari**.
4. Share button -> Add to Home Screen. Open ALLEN from the home screen icon.
5. The link changes every time you restart the tunnel, and your PC must stay on.

Set `REGISTRATION_CODE` in `.env` so strangers who find the link cannot use your AI key.
Tap the gear icon in the app and enter the same code.

## Limits of a website
- Cannot launch other apps, tap, scroll, change volume, torch. ALLEN shows a link and you tap it.
- Voice input uses the browser's speech recognition. On iPhone it follows Siri dictation settings; Bangla may be weak. Typing always works.
- Social posting (Phase 5) will work here, because uploads go through the backend.
