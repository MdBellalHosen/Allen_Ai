# Permissions and policy

| Permission | Why | When |
|---|---|---|
| Microphone | hear commands | always, only while listening / wake word on |
| Notifications + foreground service | keep the wake word alive | wake word enabled |
| Media (videos) | pick videos to post | Phase 5 |
| **Accessibility service** | tap / scroll / type / read the screen in other apps | user enables it manually in system Settings |

## Accessibility rules the code follows
- The screen is read **only while a command is running** (nothing is polled, `onAccessibilityEvent` is empty).
- `SensitiveScreenGuard` refuses `tap`, `type_text`, `scroll`, `read_screen` on password fields and on
  banking/payment apps (package keyword list, extend as needed). The user does those manually.
- Password field text is never returned by `ScreenReader`.
- Wi-Fi / Bluetooth / Do-Not-Disturb: Android (10+) does not let apps flip them, so ALLEN opens the panel and says so.

## Play Store risk
Google restricts the Accessibility API to apps that help users with disabilities, and reviews general
automation apps strictly. Build for personal / sideload use first. A Play release would need a Permissions
Declaration and probably a different design.

## Background launches
Android 10+ can block starting activities from the background. ALLEN launches through the accessibility
service context, which usually works; if a device blocks it, the reply says "open ALLEN first". The fix
if needed is the "display over other apps" permission (planned with the overlay button in Phase 6).
