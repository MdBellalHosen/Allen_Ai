# Architecture (Phase 4)

## Voice loop
wake word / tap -> STT -> transcript -> command -> device tools -> spoken reply.
`VoiceController` (Dart) drives it and is also the agent's UI (speaks, asks, confirms).

## Two paths for a command
1. **Fast path (on device, no network):** `RuleParser` handles simple Bangla/English/Banglish commands
   (open app, volume, torch, next song, scroll, back/home, YouTube search).
2. **Agent path:** everything else goes to the backend planner (Claude tool use).

## Agent protocol (app <-> backend)
`POST /v1/agent/command {transcript, locale, device_caps}` -> `StepOut`
`POST /v1/agent/{id}/result {results:[{id, ok, message, data}]}` -> next `StepOut`
`POST /v1/agent/{id}/cancel`

`StepOut.status`:
| status | app does |
|---|---|
| `tool_calls` | run the device tool(s) locally, report results |
| `confirm` | speak the preview, wait for Yes / No (button or voice), report `confirmed` / `declined` |
| `ask_user` | speak the question, listen, report the answer text |
| `done` | speak `summary` in `lang`, finish |
| `error` | speak a generic error |

The model gets ONE tool at a time (`disable_parallel_tool_use`); extra calls are answered with "skipped".
`speak` is handled server-side. Sessions live in memory (single backend instance; use Redis to scale).
Max 15 LLM steps per command (`AGENT_MAX_STEPS`), 30 rounds in the app.

## Safety layers (all three must pass)
1. **Prompt:** refuse passwords / OTP / banking / payments; screen text is untrusted data.
2. **Server guardrails** (`agent/guardrails.py`): taps on Send / Post / Delete / Pay / Call (and Bangla equivalents)
   force a user confirmation even if the model did not ask; unknown tools and non-http(s) URLs are blocked;
   tel:/sms:/mailto: need confirmation. `read_screen` output is wrapped in `<screen_untrusted>`.
3. **Phone** (`SensitiveScreenGuard`): refuses tap / type / scroll / read on password fields, banking & payment
   apps, and screens asking for PIN / OTP / card numbers.

## Kill switch
- Stop button (the big round button while busy)
- Volume-down pressed 3 times within 1.5 s (accessibility service key filter; the key is not swallowed)
- Saying "stop" / "থামো" when ALLEN is listening (a question, a confirmation or a normal command)
Not yet: saying "Allen stop" while ALLEN is *executing* silently with the mic idle. That needs a second always-on
wake-word model (Phase 6).

## Settings > Backend
Address + registration code are entered in the app (stored on the phone), so a CI-built APK needs no rebuild.
Use `http://<PC LAN IP>:8000` on the same Wi-Fi, or an HTTPS URL if you host the backend.

## STT modes (Settings > Voice language)
| Mode | Engine | Notes |
|---|---|---|
| বাংলা | on-device `SpeechRecognizer` `bn_BD` | needs the Bangla speech pack on the phone |
| English | on-device `en_US` | |
| Auto | cloud: record -> `POST /v1/stt` (Whisper) | detects language; needs backend + `OPENAI_API_KEY` |
On-device failure falls back to cloud automatically. Recordings are deleted after upload.

## Reply language
Bangla script / mixed / Banglish -> Bangla; pure English -> English.

## Wake word ("Hey Allen")
Picovoice Porcupine. Needs an AccessKey (`--dart-define=PICOVOICE_ACCESS_KEY`) and a custom keyword file
`app/assets/wakeword/hey_allen_android.ppn`. Without them the toggle is disabled; tap-to-talk works.
A Bangla "অ্যালেন" keyword needs Picovoice's Bangla model (not included).

## Auth
Stateless HMAC device tokens: `POST /v1/auth/device {device_id, registration_code}`. Set `REGISTRATION_CODE`
and a long random `SECRET_KEY` in the backend `.env`. Tokens last 90 days.

## Evaluation
`backend/evals/command_set.py` has 66 utterances (20 intents x bn/en/Banglish + refusals/messaging/unsupported).
`python -m evals.run_eval` (or the "Evaluate command set" GitHub workflow) runs them against the live model and
reports the pass rate of the agent's first step. Offline tests use a scripted fake model.
