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
say "Checking for a connected Android device"
DEVICE_COUNT=$(adb devices | tail -n +2 | grep -cw "device" || true)
if [ "$DEVICE_COUNT" -eq 0 ]; then
  warn "no Android device — skipping the tunnel"
  warn "on a desktop/web target localhost works natively, so this is fine"
else
  ok "$DEVICE_COUNT connected"

  # ── 3. The tunnel ─────────────────────────────────────────────────────────
  # A physical device's "localhost" is the phone itself, not this machine.
  # adb reverse forwards the phone's localhost:3000 back over USB. It does NOT
  # survive `flutter run` exiting (Flutter's teardown calls
  # `adb reverse --remove-all`), a cable reconnect, or a reboot — which is why
  # this runs every single time rather than being a one-off setup step.
  say "Opening USB tunnel (device localhost:$PORT -> this machine)"
  adb reverse tcp:$PORT tcp:$PORT >/dev/null
  adb reverse --list | grep -q "tcp:$PORT" \
    || die "adb reverse failed — reconnect the cable and retry"
  ok "$(adb reverse --list | tr '\n' ' ')"
fi

# ── 4. App ───────────────────────────────────────────────────────────────────
say "Starting the app (Ctrl-C to stop)"
echo
cd "$APP_DIR"
flutter run "$@"

# Reaching here means flutter exited, which just wiped every reverse tunnel.
echo
warn "flutter exited — the USB tunnel was removed with it."
warn "Re-run this script before launching the app again."
