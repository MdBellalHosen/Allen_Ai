# Architecture (Phase 2)

## Voice loop
`VoiceController` (Dart) drives: wake word / tap -> STT -> live transcript -> TTS echo.
Phase 4 swaps the echo for the LLM agent.

## STT modes (Settings > Voice language)
| Mode | Engine | Notes |
|---|---|---|
| বাংলা | on-device `SpeechRecognizer` `bn_BD` | fastest; needs the Bangla speech pack installed on the phone |
| English | on-device `en_US` | |
| Auto | cloud: record -> `POST /v1/stt` (Whisper) | detects language, best for Banglish; needs backend + `OPENAI_API_KEY` |

If the on-device recognizer is missing or errors, the app falls back to cloud STT automatically.
Recordings are deleted right after upload.

## Reply language
Bangla script or mixed -> Bangla; Banglish words -> Bangla; pure English -> English (`LanguageDetector`).

## Wake word ("Hey Allen")
Picovoice Porcupine. You must:
1. Create a free AccessKey at console.picovoice.ai and pass `--dart-define=PICOVOICE_ACCESS_KEY=...`.
2. Train a custom keyword "Hey Allen" for Android, save as `app/assets/wakeword/hey_allen_android.ppn`.
3. A Bangla "অ্যালেন" keyword needs a Bangla Porcupine language model from Picovoice; not included yet.
Without these, the toggle is disabled and tap-to-talk works normally. Porcupine holds the mic, so it is
stopped while STT runs and restarted afterwards. `AllenForegroundService` keeps the process alive with a
notification (Android 14+: it must be started while the app is visible, which the Settings toggle does).

## Auth
Stateless HMAC device tokens. `POST /v1/auth/device {device_id, registration_code}` -> token.
Set `REGISTRATION_CODE` in backend `.env` so strangers cannot mint tokens (cloud STT costs money).
Tokens last 90 days (`DEVICE_TOKEN_TTL_DAYS`). `SECRET_KEY` must be changed in production.
The app uses cleartext HTTP only for local dev (`usesCleartextTraffic`); use HTTPS in production.

## Decisions
- No DB tables yet: device auth is stateless. Models arrive when posts/jobs need them (Phase 5).
