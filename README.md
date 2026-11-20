# ALLEN AI

Voice-controlled Android phone agent (Bangla + English + Banglish). Say a command and ALLEN controls the phone and posts to social media.

- Full spec / build prompt: [docs/MASTER_PROMPT.md](docs/MASTER_PROMPT.md)
- Android only (iOS does not let an app control other apps).
- Status: **Phase 4** (voice + phone control + Claude agent with confirmations and kill switch). Install the APK from Releases > latest-apk, enable ALLEN AI in Settings > Accessibility, then set the backend address in the app Settings.

## Run backend
```bash
./scripts/dev_up.sh        # docker compose; API at http://localhost:8000/health
```

## Run app
```bash
cd app
flutter create --org com.allen --project-name allen_ai --platforms android .   # one time
git checkout -- android/app/src/main   # restore our manifest + Kotlin code
../scripts/patch_android_build.sh      # minSdk 24 + compileSdk fix for old plugins (Git Bash / WSL)
# if it overwrites AndroidManifest.xml / MainActivity.kt, restore them with `git checkout -- android/app/src/main`
flutter gen-l10n
flutter run \
  --dart-define=BACKEND_URL=http://10.0.2.2:8000 \
  --dart-define=REGISTRATION_CODE=<same as backend .env> \
  --dart-define=PICOVOICE_ACCESS_KEY=<optional>
```
