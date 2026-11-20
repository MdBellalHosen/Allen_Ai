# Command test set

The executable list lives in `app/test/rule_parser_test.dart` (Phase 3: 30+ Bangla / English / Banglish
utterances -> expected tool calls). Phase 4 extends it to 60+ and runs it against the LLM planner.

Manual device checklist (needs a phone with the accessibility service enabled):
1. "open youtube" -> YouTube opens
2. "YouTube এ ঢুকে 'lofi music' সার্চ করো প্রথম ভিডিও চালাও" -> results, first video plays
3. "next song" / "pause koro" while a music app plays
4. "volume up", "volume 50 percent", "torch on", "torch off"
5. "wifi off koro" -> Wi-Fi panel opens (you flip the switch)
6. "scroll down" inside any list; "back jao"; "home e jao"
7. Open a banking app / password screen and say "scroll down" -> ALLEN must refuse
