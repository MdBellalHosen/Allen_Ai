# ALLEN AI

Voice-controlled Android phone agent (Bangla + English + Banglish). Say a command and MAYA controls the phone and posts to social media.

- Full spec / build prompt: [docs/MASTER_PROMPT.md](docs/MASTER_PROMPT.md)
- Android only (iOS does not let an app control other apps).
- Status: **Phase 1** (scaffold, backend `/health`, Flutter shell with bn/en + onboarding).

## Run backend
```bash
./scripts/dev_up.sh        # docker compose; API at http://localhost:8000/health
```

## Run app
```bash
cd app
flutter create --org com.maya --project-name maya --platforms android .   # one time, generates android/ gradle files
flutter gen-l10n
flutter run --dart-define=BACKEND_URL=http://10.0.2.2:8000
```
