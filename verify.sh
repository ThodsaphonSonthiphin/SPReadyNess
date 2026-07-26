#!/usr/bin/env bash
#
# verify.sh — runs the verification steps that Task 13 could not run in the
# agent environment (no Connect IQ SDK installed there). Run this on a
# machine with the Connect IQ SDK on PATH.
#
# What it does:
#   1. Checks monkeyc/monkeydo are on PATH.
#   2. Generates developer_key.der if missing.
#   3. Builds and runs the unit-test binary.
#   4. Builds the app binary.
#   5. Prints a checklist of what still needs a human eye in the simulator.
#
set -euo pipefail

DEVELOPER_KEY="developer_key.der"
JUNGLE="monkey.jungle"
DEVICE="fr165"
TEST_BIN="bin/test.prg"
APP_BIN="bin/spreadyness.prg"

echo "==> Checking for the Connect IQ SDK (monkeyc, monkeydo) on PATH..."
if ! command -v monkeyc >/dev/null 2>&1; then
    echo "ERROR: 'monkeyc' not found on PATH."
    echo "Install the Garmin Connect IQ SDK and ensure its bin/ directory is on PATH."
    echo "See: https://developer.garmin.com/connect-iq/sdk/"
    exit 1
fi
if ! command -v monkeydo >/dev/null 2>&1; then
    echo "ERROR: 'monkeydo' not found on PATH."
    echo "Install the Garmin Connect IQ SDK and ensure its bin/ directory is on PATH."
    echo "See: https://developer.garmin.com/connect-iq/sdk/"
    exit 1
fi
echo "    monkeyc: $(command -v monkeyc)"
echo "    monkeydo: $(command -v monkeydo)"

echo "==> Checking for a developer key..."
if [ ! -f "$DEVELOPER_KEY" ]; then
    echo "    $DEVELOPER_KEY not found — generating one."
    openssl genrsa -out developer_key.pem 4096
    openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out "$DEVELOPER_KEY" -nocrypt
    echo "    generated $DEVELOPER_KEY"
else
    echo "    found existing $DEVELOPER_KEY, reusing it."
fi

mkdir -p bin

echo "==> Building the unit-test binary..."
monkeyc -f "$JUNGLE" -d "$DEVICE" -o "$TEST_BIN" -y "$DEVELOPER_KEY" --unit-test

echo "==> Running the unit-test suite..."
monkeydo "$TEST_BIN" "$DEVICE" -t

echo "==> Building the app binary..."
monkeyc -f "$JUNGLE" -d "$DEVICE" -o "$APP_BIN" -y "$DEVELOPER_KEY"

echo ""
echo "==> Build and automated tests complete."
echo ""
echo "The following still need a human eye in the simulator"
echo "(connectiq & ; monkeydo $APP_BIN $DEVICE) — see docs/mockups/screens.html:"
echo ""
echo "  1. Fresh install (Simulation -> Reset app data): Morning page shows"
echo "     NO number and 'FIRST SCORE / TOMORROW MORNING' — never a zero."
echo "  2. Morning page with a CURRENT record: solid arc, band-coloured"
echo "     score and caption, three coloured dials."
echo "  3. Morning page with a STALE record: dimmed arc/track, dimmed dials,"
echo "     '<N> DAYS AGO' caption."
echo "  4. Morning page with an UNCHECKED record (RHR missing today):"
echo "     dimmed presentation, 'NO RHR - UNCHECKED' caption."
echo "  5. Page down to the Now Score: DASHED arc (never solid), 'NOW hh:mm'"
echo "     stamp, and a score that may legitimately differ from the morning"
echo "     one."
echo "  6. Background is pure black (#000000) in every state above, and in"
echo "     the glance."
echo ""
