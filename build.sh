#!/usr/bin/env bash
#
# Compile the watch face into a .prg you can side-load onto a watch.
#
#   ./build.sh                     # fenix8solar47mm, release build
#   ./build.sh fenix8solar51mm     # the other device in manifest.xml
#   ./build.sh fenix8solar47mm -d  # debug build (needed for the simulator)
#
# Requires the Connect IQ SDK. See README.md for how to install it; point
# CIQ_SDK at it if it lives somewhere unusual.
set -euo pipefail

DEVICE="${1:-fenix8solar47mm}"
MODE="${2:-}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

# --- locate the SDK -----------------------------------------------------------
find_sdk() {
  if [[ -n "${CIQ_SDK:-}" ]]; then
    echo "$CIQ_SDK"
    return
  fi
  if command -v monkeyc >/dev/null 2>&1; then
    dirname "$(dirname "$(command -v monkeyc)")"
    return
  fi
  # Default SDK Manager install locations, newest version last.
  for root in "$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks" \
              "$HOME/.Garmin/ConnectIQ/Sdks"; do
    if [[ -d "$root" ]]; then
      local newest
      newest="$(ls -1d "$root"/*/ 2>/dev/null | sort -V | tail -1 || true)"
      if [[ -n "$newest" ]]; then
        echo "${newest%/}"
        return
      fi
    fi
  done
}

SDK="$(find_sdk)"
if [[ -z "$SDK" || ! -x "$SDK/bin/monkeyc" ]]; then
  cat >&2 <<'MSG'
error: could not find the Connect IQ SDK.

Install it (see README.md), then either add its bin/ directory to PATH or set
CIQ_SDK to the SDK root, e.g.

    export CIQ_SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-8.1.1"
MSG
  exit 1
fi
MONKEYC="$SDK/bin/monkeyc"

# --- developer key ------------------------------------------------------------
# Every .prg is signed. Any RSA key works for side-loading; keep the same one
# for the Connect IQ store, because it identifies you as the publisher.
KEY="${CIQ_KEY:-$HERE/developer_key.der}"
if [[ ! -f "$KEY" ]]; then
  echo "generating a developer key at $KEY"
  tmp="$(mktemp -d)"
  openssl genrsa -out "$tmp/key.pem" 4096 2>/dev/null
  openssl pkcs8 -topk8 -inform PEM -outform DER -in "$tmp/key.pem" -out "$KEY" -nocrypt
  rm -rf "$tmp"
  echo "keep this file safe and out of git — it is your publisher identity"
fi

# --- build --------------------------------------------------------------------
mkdir -p bin
OUT="bin/dashboard-$DEVICE.prg"

ARGS=(-o "$OUT" -f monkey.jungle -y "$KEY" -d "$DEVICE" -w)
if [[ "$MODE" == "-d" || "$MODE" == "--debug" ]]; then
  echo "building $DEVICE (debug)"
else
  echo "building $DEVICE (release)"
  ARGS+=(-r)
fi

"$MONKEYC" "${ARGS[@]}"
echo
echo "built $HERE/$OUT"
echo "copy it to GARMIN/APPS/ on the watch over USB, then reboot the watch"
