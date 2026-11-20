# ALLEN AI

Voice-controlled Android phone agent (Bangla + English + Banglish). Say a command and MAYA controls the phone and posts to social media.

- Full spec / build prompt: [docs/MASTER_PROMPT.md](docs/MASTER_PROMPT.md)
- Android only (iOS does not let an app control other apps).
- Status: **Phase 2** (voice loop: tap-to-talk + optional "Hey Maya" wake word, Bangla/English STT, TTS echo).

## Run backend
```bash
./scripts/dev_up.sh        # docker compose; API at http://localhost:8000/health
```

## Run app
```bash
cd app
flutter create --org com.allen --project-name maya --platforms android .   # one time, generates the android/ gradle files. It must keep package com.allen.maya;
# if it overwrites AndroidManifest.xml / MainActivity.kt, restore them with `git checkout -- android/app/src/main`
flutter gen-l10n
flutter run \
  --dart-define=BACKEND_URL=http://10.0.2.2:8000 \
  --dart-define=REGISTRATION_CODE=<same as backend .env> \
  --dart-define=PICOVOICE_ACCESS_KEY=<optional>
```
