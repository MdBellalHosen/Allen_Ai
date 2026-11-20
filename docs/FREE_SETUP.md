# ALLEN AI — totally free setup

| Part | Free choice | Notes |
|---|---|---|
| AI brain | Groq or Google AI Studio free API key | Rate limited (per minute/day). Free-tier data may be used by the provider. Check each provider's current limits. |
| Speech to text | On-device Android recognizer (bn-BD / en-US) | Do not set OPENAI_API_KEY (cloud Whisper is paid). |
| Backend | Run on your own PC (`scripts/dev_up.sh`) | Phone and PC on same Wi-Fi; set backend address in app Settings. |
| App build | GitHub Actions on a public repo | Releases: `latest-apk`, `latest-ipa`. |
| iPhone install | Sideloadly + free Apple ID | Expires every 7 days; max 3 apps. |
| Wake word | Picovoice free plan (personal use) | Optional; no Bangla wake word. Use the button instead. |

Steps: copy `.env.example` to `.env`, paste your free key into `LLM_API_KEY`, start the backend.
If the AI says rate limit (429), wait a minute; simple commands (open app, volume, torch) still work without the AI.
