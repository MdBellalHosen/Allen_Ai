# MAYA — Voice-Controlled Phone Agent (by ALLEN AI)

Paste everything below the line into Claude Code as your first message, in an empty project folder.

---

## 0. Your role

You are a senior Android + backend engineer. Build **ALLEN AI**, an Android app whose assistant is named **MAYA**. The user speaks (in **Bangla, English, or mixed Banglish**) and MAYA controls the phone and manages social media on their behalf. Build it in phases (Section 9). After each phase, run what can be run, show me what works, and stop for my review before the next phase. Do not add a Claude co-author line to any git commit.

## 1. Product vision

"Speak, and the phone obeys." Examples of what the user says:

| Voice command (Bangla / English) | What MAYA does |
|---|---|
| "মায়া, এই ভিডিওটা Instagram আর Facebook এ আপলোড করো" / "Upload this video to Instagram and Facebook" | Picks the video, writes title + caption + hashtags, shows a preview, asks "Post korbo?", then posts |
| "YouTube এ ঢুকে 'Arijit Singh' সার্চ করো" | Opens YouTube, taps search, types, plays first result |
| "গান বদলাও" / "Next song" / "Music pause koro" | Controls the active media session |
| "ভলিউম বাড়াও", "Wi-Fi অফ করো", "টর্চ জ্বালাও" | System controls |
| "Rahim ke WhatsApp e message pathao: ..." | Opens app, finds contact, types, **asks confirmation**, sends |
| "ফেসবুকে ঢুকে স্ক্রল করো", "Back jao", "Home e jao" | Generic UI control |

## 2. Hard constraints (read carefully, do not work around them silently)

1. **Android only.** iOS does not allow an app to control other apps. Say so in the README; do not fake it.
2. **Phone control = Android `AccessibilityService`** (tap, swipe, scroll, type text, read screen, global actions) plus `Intent`s for direct app/deep-link launches (always prefer an Intent over tapping when one exists — it is faster and more reliable).
3. **Social posting must use official APIs where they exist**, not UI scraping:
   - **Instagram**: Instagram Graph API (content publishing). Needs an Instagram *Business/Creator* account linked to a Facebook Page. Reels publishing requires the video to be at a **publicly reachable HTTPS URL** → the backend must upload the video to object storage (S3 / Cloudflare R2 / Supabase Storage) and pass the URL.
   - **Facebook**: Graph API video upload to a **Page**. (Posting to a personal profile through the API is not allowed; for personal profile use the accessibility fallback, flagged as "best effort".)
   - **YouTube**: YouTube Data API v3 `videos.insert` (optional, Phase 5).
   - Accessibility-based posting is only a **fallback** when no API path exists.
4. **"Trending hashtags"**: Instagram has no official trending-hashtag API. Implement a `HashtagService` that combines (a) LLM-generated niche + broad tags from the video's content/topic, (b) optional trend signals (Google Trends via a pluggable provider, YouTube trending/most-popular API), and (c) a user-editable "my hashtag sets" list. Label the output honestly as "suggested", not "guaranteed trending".
5. **Safety**: Any irreversible or outward-facing action (post, send message, delete, payment, call) requires a spoken or tapped **confirmation** with a readable preview. Never auto-run payments, banking, or password screens; MAYA must refuse and tell the user to do it manually.
6. **Secrets**: No API keys in the APK. All LLM calls and social tokens live on the backend. The app talks only to my backend with a per-device token.
7. **Privacy**: Screen content is read only while a command is executing. Nothing is logged to the cloud unless the user enables "debug logs". Show a clear consent screen for Accessibility, Microphone, Notifications, and Media access.
8. **Play Store note**: Google restricts Accessibility API use. Build for personal/sideload use first; add a README section on policy risk. Don't hide it.

## 3. Tech stack (use these unless you can justify a change in writing)

- **App**: Flutter (Dart) for UI + a native **Kotlin** module for AccessibilityService, MediaSession control, foreground service, and wake-word, bridged with platform channels (`MethodChannel` / `EventChannel`).
- **Backend**: Python 3.12, **FastAPI**, Pydantic, `httpx`, PostgreSQL (SQLAlchemy + Alembic), Redis + a worker (RQ/Celery) for upload jobs, Docker Compose.
- **LLM brain**: Claude API with **tool use**. The model receives the transcript + compact screen state and returns structured tool calls (see Section 5). Make the model name a config value (`LLM_MODEL`), not hardcoded.
- **Speech-to-text (STT)**: Provider interface with two implementations: (a) on-device Android `SpeechRecognizer` with `bn-BD` / `en-US` for low latency, (b) cloud fallback (Whisper API or Google Cloud STT) for better Bangla accuracy. Auto-detect language per utterance; handle code-switching.
- **Text-to-speech (TTS)**: Android TTS with `bn-BD` and `en-US`; reply in the language the user spoke.
- **Wake word**: "Hey Maya" / "মায়া" via Picovoice Porcupine (custom keyword) in a foreground service, with a tap-to-talk button and a floating overlay button as fallbacks.
- **Video pipeline**: `ffmpeg` on the backend for thumbnail + optional transcode to Instagram-compatible H.264/AAC, 9:16, ≤90s for Reels.

## 4. How a voice command flows

```
Wake word / tap
  → record audio → STT (bn/en) → transcript
  → POST /v1/agent/command {transcript, locale, screen_state?, device_caps}
  → LLM plans → returns tool calls (JSON)
  → app executes device tools locally (Intent / Accessibility)
  → backend executes cloud tools (social post, hashtags, upload)
  → risky step? → ConfirmationRequest → user says "হ্যাঁ/yes" or taps
  → result → TTS reply in user's language
```

Multi-step tasks (e.g. "open YouTube, search X, play first result") run as a loop: execute step → read new screen → ask LLM for next step → until `done` or `max_steps` (default 15) or user says "থামো/stop". Add a global **kill switch** (volume-down ×3, or say "Maya stop") that aborts everything instantly.

## 5. Tool contract (LLM ↔ app)

Define these as JSON-schema tools; keep names stable.

**Device tools (run on phone):**
`open_app(package|name)`, `open_url(url)`, `search_in_app(app, query)`, `tap(selector|x,y)`, `type_text(text)`, `scroll(direction, amount)`, `swipe(...)`, `press_global(back|home|recents|notifications)`, `read_screen()` (returns compact tree of visible text/ids/bounds), `media_control(play|pause|next|previous|seek)`, `set_volume(level|up|down)`, `toggle_setting(wifi|bluetooth|flashlight|dnd)`, `pick_media(type, recent|query)`, `share_to(app, file)`.

**Cloud tools (run on backend):**
`generate_post_content(video_id, platforms[], tone, language)` → `{title, caption, hashtags[]}`,
`upload_video(file)`, `publish_post(platform, video_id, title, caption, hashtags, schedule_at?)`, `get_post_status(job_id)`.

**Control tools:** `ask_user(question)`, `confirm(action_preview)`, `speak(text, lang)`, `done(summary)`.

Selectors must prefer `resource-id` / `contentDescription` / visible text, with fuzzy Bangla+English matching, and fall back to coordinates only as a last resort.

## 6. Social media feature spec

1. **Voice upload flow**: user says "upload this video" → `pick_media` (latest video or user-chosen) → backend upload → `generate_post_content` → show a preview card (video thumbnail, title, caption, hashtags, selected platforms) → read it aloud in short form → ask for confirmation → `publish_post` per platform → report success/failure per platform with a link.
2. **Caption/title generation**: platform-aware (Instagram: short hook + hashtags; Facebook: slightly longer; YouTube: SEO title + description). Tone presets: funny, professional, emotional, promotional. Language: Bangla, English, or Banglish. User can say "caption ta aro choto koro" and MAYA regenerates.
3. **Hashtags**: 8–15 per post, mix of broad + niche + a Bangladesh-local set when relevant; de-duplicate; user can pin favorite sets.
4. **Scheduling**: "কাল সন্ধ্যা ৭টায় পোস্ট করো" → parse Bangla/English date-time in the `Asia/Dhaka` timezone → store job → publish via worker.
5. **Accounts**: OAuth connect screens for Facebook Page + Instagram Business; tokens encrypted at rest (Fernet/KMS), with refresh handling and a clear "reconnect" error path.
6. **History**: list of posts (status, platform, link, retry button).

## 7. Languages

- All UI strings in `intl` ARB files: `app_en.arb`, `app_bn.arb`. User can switch in Settings or follow system.
- Command understanding must work for: pure Bangla (বাংলা script), pure English, and **Banglish** (Bangla in Latin letters, e.g. "youtube e dhuke gaan chalao"). Include a test set of at least 60 utterances across these three styles with expected tool calls.
- TTS replies in the language of the command; if mixed, reply in Bangla.
- Use a Bangla-capable font (Noto Sans Bengali) in the UI.

## 8. File structure to create

```
allen-ai/
├── README.md
├── docker-compose.yml
├── .env.example
├── .gitignore
├── docs/
│   ├── ARCHITECTURE.md
│   ├── PERMISSIONS_AND_POLICY.md        # accessibility consent, Play policy risk
│   ├── SOCIAL_API_SETUP.md              # FB app, IG business, tokens, review steps
│   └── COMMAND_TEST_SET.md              # the 60+ bn/en/banglish utterances
│
├── app/                                 # Flutter + Kotlin
│   ├── pubspec.yaml
│   ├── l10n/ (app_en.arb, app_bn.arb)
│   ├── lib/
│   │   ├── main.dart
│   │   ├── core/ (config, theme, router, di, logger)
│   │   ├── data/
│   │   │   ├── api/ (backend_client.dart, models/)
│   │   │   └── repositories/ (agent_repo.dart, social_repo.dart, auth_repo.dart)
│   │   ├── voice/
│   │   │   ├── stt_service.dart         # interface + on-device + cloud impls
│   │   │   ├── tts_service.dart
│   │   │   ├── wake_word_service.dart
│   │   │   └── language_detector.dart
│   │   ├── agent/
│   │   │   ├── agent_controller.dart    # the step loop, kill switch
│   │   │   ├── tool_dispatcher.dart     # routes tool calls → platform channel
│   │   │   └── confirmation_manager.dart
│   │   ├── platform/
│   │   │   └── device_bridge.dart       # MethodChannel wrappers
│   │   └── features/
│   │       ├── home/ (mic button, live transcript, status)
│   │       ├── onboarding/ (permissions walkthrough)
│   │       ├── social/ (accounts, post_preview, history, schedule)
│   │       ├── settings/ (language, wake word, hashtag sets, safety)
│   │       └── history/ (command log)
│   └── android/app/src/main/
│       ├── AndroidManifest.xml
│       ├── res/xml/accessibility_service_config.xml
│       └── kotlin/com/allen/maya/
│           ├── MainActivity.kt
│           ├── bridge/DeviceBridgePlugin.kt
│           ├── accessibility/
│           │   ├── MayaAccessibilityService.kt
│           │   ├── ScreenReader.kt       # compact screen tree
│           │   ├── NodeFinder.kt         # fuzzy bn/en selector matching
│           │   └── GestureExecutor.kt
│           ├── actions/
│           │   ├── AppLauncher.kt        # Intents + deep links
│           │   ├── MediaController.kt    # MediaSession / AudioManager
│           │   ├── SystemSettings.kt
│           │   └── MediaPicker.kt
│           ├── service/
│           │   ├── MayaForegroundService.kt   # wake word + overlay
│           │   └── OverlayButton.kt
│           └── safety/SensitiveScreenGuard.kt # blocks bank/password screens
│
├── backend/
│   ├── Dockerfile
│   ├── pyproject.toml
│   ├── alembic/
│   └── app/
│       ├── main.py
│       ├── config.py
│       ├── deps.py
│       ├── api/v1/
│       │   ├── agent.py                  # /agent/command
│       │   ├── stt.py                    # cloud STT fallback
│       │   ├── media.py                  # upload, thumbnails
│       │   ├── social.py                 # connect, publish, status, history
│       │   └── auth.py                   # device registration/token
│       ├── agent/
│       │   ├── planner.py                # Claude tool-use loop
│       │   ├── tools_schema.py           # Section 5 as JSON schema
│       │   ├── prompts/ (system_bn_en.md, social_caption.md)
│       │   └── guardrails.py             # confirmation + forbidden actions
│       ├── services/
│       │   ├── caption_service.py
│       │   ├── hashtag_service.py
│       │   ├── trend_providers/ (base.py, google_trends.py, youtube_trending.py)
│       │   ├── video_service.py          # ffmpeg
│       │   ├── storage_service.py        # S3/R2 signed URLs
│       │   ├── scheduler_service.py
│       │   └── datetime_parser.py        # Bangla/English → Asia/Dhaka
│       ├── integrations/
│       │   ├── instagram_graph.py
│       │   ├── facebook_graph.py
│       │   └── youtube_api.py
│       ├── workers/publish_worker.py
│       ├── models/ (device, account, post, job, command_log)
│       ├── schemas/
│       └── core/ (security.py, crypto.py, logging.py)
│   └── tests/ (test_planner_commands.py, test_hashtags.py, test_instagram_flow.py, ...)
│
└── scripts/ (dev_up.sh, gen_keystore.sh, seed_hashtag_sets.py)
```

## 9. Build phases (stop after each for my review)

1. **Foundations**: repo scaffold, Docker Compose, FastAPI `/health`, Flutter shell with bn/en localization, onboarding + permissions screens.
2. **Voice loop**: wake word + tap-to-talk, STT (bn/en), TTS, live transcript UI. Echo the transcript back by voice.
3. **Phone control**: AccessibilityService, `open_app`, `media_control`, volume/torch/Wi-Fi, `read_screen`, `search_in_app` for YouTube. Hard-coded intent parser first (no LLM) to prove the device layer works.
4. **LLM agent**: Claude tool-use planner, step loop, confirmation manager, kill switch, SensitiveScreenGuard. Run the 60-utterance test set; report pass rate.
5. **Social media**: storage + ffmpeg, caption/hashtag services, Facebook Page + Instagram Reels publishing, preview + confirm flow, history, scheduling. YouTube upload as a bonus.
6. **Polish**: error handling, offline behaviour, battery tuning, logs toggle, README with demo steps, signed release APK instructions.

## 10. Acceptance criteria

- Saying "মায়া, YouTube এ গিয়ে 'lofi music' সার্চ করে প্রথম ভিডিও চালাও" works end-to-end without touching the phone.
- Saying "Upload this video to Instagram and Facebook" produces a preview with title, caption, hashtags, and **does not post until I confirm**.
- Bangla, English, and Banglish versions of the same command produce the same tool calls.
- "Maya stop" aborts any running task within 1 second.
- Banking / password / payment screens are detected and MAYA refuses to act on them.
- No secrets in the APK; `.env.example` lists every key needed; backend tests pass in CI.

## 11. Working rules for you (Claude Code)

- Ask me only for things you truly cannot decide (e.g. which cloud storage I have). Otherwise pick a sensible default and note it in `docs/ARCHITECTURE.md`.
- Never claim a feature works unless you ran it or a test. If something needs a real device, Meta app review, or a real token, say exactly what I must do.
- Keep code typed, small-file, and commented where behaviour is non-obvious (especially accessibility selectors and Graph API quirks).
- Do not add Claude as a co-author or contributor in any commit.
