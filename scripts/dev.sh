#!/usr/bin/env bash
#
# Start a full local dev session: backend up, USB tunnel open, app running.
#
# Exists because the tunnel is the single most common reason the app cannot
# reach the server, and it is invisible when missing — the app just times out.
# Running this instead of `flutter run` makes that step impossible to forget.
#
#   ./scripts/dev.sh              run on the connected device
#   ./scripts/dev.sh -d linux     run on another Flutter device
#
# Two devices at once — a phone and an emulator, for rider-and-driver testing —
# is one invocation each, in its own terminal:
#
#   ./scripts/dev.sh -d 039d17e20405     # terminal 1, the phone
#   ./scripts/dev.sh -d emulator-5554    # terminal 2, the emulator
#
# Either invocation opens the tunnel for *every* attached device, so the order
# does not matter and the second one does not disturb the first.
#
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$(cd "$APP_DIR/../uniride_v2_backend" && pwd)"
PORT=3000
API_HEALTH="http://localhost:$PORT/api/v1/health"

say()  { printf '\033[0;36m==>\033[0m %s\n' "$1"; }
ok()   { printf '\033[0;32m  ok\033[0m %s\n' "$1"; }
warn() { printf '\033[0;33m  !!\033[0m %s\n' "$1"; }
die()  { printf '\033[0;31m  xx\033[0m %s\n' "$1" >&2; exit 1; }

# ── 1. Backend ───────────────────────────────────────────────────────────────
say "Checking backend on port $PORT"
if curl -sf -m 5 "$API_HEALTH" >/dev/null 2>&1; then
  ok "already running"
else
  warn "not responding — starting it"
  (cd "$BACKEND_DIR" && docker compose up -d)

  say "Waiting for it to become healthy (migrations run on boot)"
  for _ in $(seq 1 60); do
    curl -sf -m 5 "$API_HEALTH" >/dev/null 2>&1 && break
    sleep 2
  done
  curl -sf -m 5 "$API_HEALTH" >/dev/null 2>&1 \
    || die "backend never came up. Check: cd $BACKEND_DIR && docker compose logs app"
  ok "healthy"
fi

# ── 2. Device ────────────────────────────────────────────────────────────────
say "Checking for connected Android devices"
DEVICES=$(adb devices | tail -n +2 | awk '$2 == "device" { print $1 }')
DEVICE_COUNT=$(printf '%s' "$DEVICES" | grep -c . || true)
if [ "$DEVICE_COUNT" -eq 0 ]; then
  warn "no Android device — skipping the tunnel"
  warn "on a desktop/web target localhost works natively, so this is fine"
else
  ok "$DEVICE_COUNT connected"

  # ── 3. The tunnels ────────────────────────────────────────────────────────
  # A device's "localhost" is the device itself, not this machine. adb reverse
  # forwards its localhost:3000 back here — over USB for a phone, over the
  # emulator bridge for an AVD. Both work the same way, which is why the app
  # ships one base URL instead of the emulator-only 10.0.2.2 alias.
  #
  # It does NOT survive `flutter run` exiting (Flutter's teardown calls
  # `adb reverse --remove-all`), a cable reconnect, or a reboot — which is why
  # this runs every single time rather than being a one-off setup step.
  #
  # Every attached device gets a tunnel, not just the one being run. `adb`
  # refuses an un-targeted command whenever two devices are present, so the
  # `-s` is required rather than tidy — without it this whole step dies as
  # soon as you plug in a second device for rider-and-driver testing.
  say "Opening tunnels (device localhost:$PORT -> this machine)"
  for serial in $DEVICES; do
    adb -s "$serial" reverse tcp:$PORT tcp:$PORT >/dev/null \
      || die "adb reverse failed for $serial — reconnect it and retry"
    adb -s "$serial" reverse --list | grep -q "tcp:$PORT" \
      || die "tunnel did not open for $serial"
    ok "$serial"
  done
fi

# ── 4. App ───────────────────────────────────────────────────────────────────
say "Starting the app (Ctrl-C to stop)"
echo
cd "$APP_DIR"
flutter run "$@"

# Reaching here means flutter exited, which just wiped this device's tunnel.
echo
warn "flutter exited — its device's tunnel was removed with it."
warn "Re-run this script before launching the app again."
warn "Running a second device? Re-running this restores every tunnel, so the"
warn "other session keeps working — but check it after any cable reconnect."
