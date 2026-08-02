#!/usr/bin/env bash
#
# Differentiate a fresh onebusaway-android checkout so the nightly APK can live alongside the
# official Play Store build instead of colliding with it.
#
# Two things collide otherwise:
#   1. The `oba` brand hardcodes applicationId com.joulespersecond.seattlebusbot — identical to the
#      Play build. Signed with our key rather than the project's, Android refuses to install it over
#      an existing OneBusAway, and the user can't keep both.
#   2. Both would show up in the launcher as "OneBusAway", with nothing to tell them apart.
#
# Every edit below asserts its target exists before touching it. If upstream restructures, this
# script must fail the build rather than quietly ship an APK that claims to be the real app.
#
# Usage: patch-nightly.sh <path-to-upstream-checkout>

set -euo pipefail

readonly APP_ID_SUFFIX=".maplibre.nightly"
readonly VERSION_NAME_SUFFIX="-maplibre-nightly"
readonly APP_NAME="OneBusAway (Libre)"

die() { echo "patch-nightly: $*" >&2; exit 1; }

[ $# -eq 1 ] || die "usage: $0 <path-to-upstream-checkout>"
readonly ROOT="$1"
[ -d "$ROOT" ] || die "not a directory: $ROOT"

readonly BUILD_GRADLE="$ROOT/onebusaway-android/build.gradle.kts"
readonly VALUES_DIR="$ROOT/onebusaway-android/src/main/res"

# --- validate everything before mutating anything ------------------------------------------------
#
# Checked up front so a checkout that fails the second assertion isn't left carrying the first edit.

[ -f "$BUILD_GRADLE" ] || die "missing $BUILD_GRADLE"
grep -q 'getByName("release")' "$BUILD_GRADLE" ||
    die "no release build type found in $BUILD_GRADLE — upstream layout changed"
grep -q 'applicationIdSuffix' "$BUILD_GRADLE" &&
    die "$BUILD_GRADLE already sets applicationIdSuffix — patch would double-apply"

[ -d "$VALUES_DIR" ] || die "missing $VALUES_DIR"
mapfile -t name_files < <(grep -rl --include='strings.xml' '<string name="app_name">' "$VALUES_DIR")
[ ${#name_files[@]} -gt 0 ] ||
    die "no strings.xml defines app_name under $VALUES_DIR — upstream layout changed"

# --- 1. applicationId + versionName suffixes -----------------------------------------------------
#
# Appended as a second top-level `android { }` block rather than edited in place: configuring the
# extension twice is ordinary Kotlin DSL, and it means we never have to match against the shape of
# upstream's own buildTypes block.

cat >> "$BUILD_GRADLE" <<EOF

// ---- appended by onebusaway-maplibre-nightly (not upstream) ----
// Keeps this build installable alongside the official Play Store app, which uses the unsuffixed
// applicationId and a different signing key.
android {
    buildTypes {
        getByName("release") {
            applicationIdSuffix = "$APP_ID_SUFFIX"
            versionNameSuffix = "$VERSION_NAME_SUFFIX"
        }
    }
}
EOF
echo "patch-nightly: applied applicationIdSuffix=$APP_ID_SUFFIX versionNameSuffix=$VERSION_NAME_SUFFIX"

# --- 2. app_name ---------------------------------------------------------------------------------
#
# app_name is the launcher label (android:label in src/main/AndroidManifest.xml) and is also
# interpolated into ~20 other strings via %1$s, so renaming it here propagates through the UI.
# Localized values-*/strings.xml files get the same treatment so translated builds stay consistent.

for f in "${name_files[@]}"; do
    # Rewrite only the element body; any attributes on the tag (e.g. translatable) are preserved.
    perl -0777 -pi -e \
        's{(<string name="app_name"[^>]*>).*?(</string>)}{$1'"$APP_NAME"'$2}s' "$f"
    grep -qF ">$APP_NAME</string>" "$f" ||
        die "app_name rewrite did not take effect in $f"
done
echo "patch-nightly: renamed app_name to '$APP_NAME' in ${#name_files[@]} file(s)"
