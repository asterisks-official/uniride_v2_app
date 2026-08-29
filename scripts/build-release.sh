#!/usr/bin/env bash
# Builds a release APK (or AAB) with the API origin compiled in, then proves it
# actually landed in the binary.
#
#   ./scripts/build-release.sh              # split APKs, production origin
#   ./scripts/build-release.sh --aab        # App Bundle, for the Play upload
#   API_ORIGIN=https://staging.example ./scripts/build-release.sh
#
# The verification step is the point. API_ORIGIN is a String.fromEnvironment,
# resolved at compile time, so a build that forgets the flag silently bakes in
# http://localhost:3000 -- and looks completely normal until it is installed on
# a device that is not the one that built it. That failure has already reached
# real hardware once; a grep of the compiled snapshot is cheap insurance.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$(dirname "$HERE")"

API_ORIGIN="${API_ORIGIN:-https://api-18-138-192-189.sslip.io}"
log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

case "${API_ORIGIN}" in
  https://*) ;;
  http://localhost*|http://127.0.0.1*)
    die "API_ORIGIN is $API_ORIGIN. A release build must not point at localhost." ;;
  *) die "API_ORIGIN must be an https:// URL, got: $API_ORIGIN" ;;
esac

log "Building against $API_ORIGIN"

if [ "${1:-}" = "--aab" ]; then
  flutter build appbundle --release --dart-define=API_ORIGIN="$API_ORIGIN"
  ARTIFACT=build/app/outputs/bundle/release/app-release.aab
  log "Built $ARTIFACT"
  log "Verify the signature before uploading:"
  echo "    keytool -printcert -jarfile $ARTIFACT"
  exit 0
fi

flutter build apk --split-per-abi --release --dart-define=API_ORIGIN="$API_ORIGIN"

# ─── Prove the origin is in the compiled snapshot, not just on the command line
FAILED=0
for ABI in arm64-v8a armeabi-v7a x86_64; do
  APK="build/app/outputs/flutter-apk/app-${ABI}-release.apk"
  [ -f "$APK" ] || { echo "  $ABI: not built"; continue; }

  FOUND=$(unzip -p "$APK" "lib/*/libapp.so" 2>/dev/null \
    | strings \
    | grep -oE "${API_ORIGIN}|http://localhost:3000" \
    | sort -u | tr '\n' ' ')

  case "$FOUND" in
    *"$API_ORIGIN"*) printf '  \033[1;32mok\033[0m   %-14s %s\n' "$ABI" "$API_ORIGIN" ;;
    *localhost*)     printf '  \033[1;31mBAD\033[0m  %-14s localhost was compiled in\n' "$ABI"; FAILED=1 ;;
    *)               printf '  \033[1;33m??\033[0m   %-14s origin not found in snapshot\n' "$ABI"; FAILED=1 ;;
  esac
done

[ "$FAILED" = 0 ] || die "Do not distribute these APKs."

echo
log "Install on a phone:"
echo "    adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
echo
log "arm64-v8a suits any phone from roughly 2017 on. armeabi-v7a is for older"
log "32-bit devices; x86_64 is for emulators."
