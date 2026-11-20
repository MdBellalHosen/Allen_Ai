#!/usr/bin/env bash
# Run once after `flutter create --platforms ios .` (macOS only; the iOS CI job does this).
# Adds the usage strings iOS requires, enables permission_handler's permissions and sets iOS 15.
set -euo pipefail
cd "$(dirname "$0")/../app/ios"

PLIST=Runner/Info.plist
pb() { /usr/libexec/PlistBuddy -c "$1" "$PLIST" 2>/dev/null || true; }
pb "Add :NSMicrophoneUsageDescription string ALLEN listens for your voice commands."
pb "Add :NSSpeechRecognitionUsageDescription string ALLEN turns your speech into text to understand commands."
pb "Add :NSPhotoLibraryUsageDescription string ALLEN lets you pick videos to post."
pb "Set :CFBundleDisplayName ALLEN AI"

python3 - <<'PY'
import re
p = "Podfile"
s = open(p).read()
s = re.sub(r"#?\s*platform :ios, '[0-9.]+'", "platform :ios, '15.0'", s, count=1)
if "PERMISSION_MICROPHONE" not in s:
    s = s.replace(
        "flutter_additional_ios_build_settings(target)",
        "flutter_additional_ios_build_settings(target)\n"
        "    target.build_configurations.each do |config|\n"
        "      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)', 'PERMISSION_MICROPHONE=1', 'PERMISSION_NOTIFICATIONS=1', 'PERMISSION_PHOTOS=1']\n"
        "    end",
        1,
    )
open(p, "w").write(s)
PY
echo "ios build patched"
