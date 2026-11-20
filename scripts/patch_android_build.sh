#!/usr/bin/env bash
# Run once after `flutter create` (CI does this too). Patches the generated Android build files:
#  1. minSdk 24  (record / porcupine need >= 23-24)
#  2. compileSdk 36 for plugin subprojects: older plugins (flutter_voice_processor) compile against
#     android-31 but their androidx dependencies require 34+.
set -euo pipefail
cd "$(dirname "$0")/../app/android"

sed -i 's/minSdk = flutter.minSdkVersion/minSdk = 24/; s/minSdkVersion flutter.minSdkVersion/minSdkVersion 24/' app/build.gradle* || true

if [ -f build.gradle.kts ] && ! grep -q "ALLEN-PATCH" build.gradle.kts; then
cat >> build.gradle.kts <<'KTS'

// ALLEN-PATCH: raise compileSdk of plugin subprojects (see scripts/patch_android_build.sh)
subprojects {
    if (name != "app") {
        afterEvaluate {
            extensions.findByName("android")?.withGroovyBuilder { "compileSdkVersion"(36) }
        }
    }
}
KTS
elif [ -f build.gradle ] && ! grep -q "ALLEN-PATCH" build.gradle; then
cat >> build.gradle <<'GRADLE'

// ALLEN-PATCH: raise compileSdk of plugin subprojects (see scripts/patch_android_build.sh)
subprojects {
    if (project.name != "app") {
        afterEvaluate { p ->
            if (p.hasProperty("android")) { p.android.compileSdkVersion 36 }
        }
    }
}
GRADLE
fi
echo "android build patched"
