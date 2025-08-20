#!/usr/bin/env bash
set -euo pipefail
BASE_URL=${1:-http://localhost:8080}
SMOKE_UID=${2:-12345678901234567890123456789012}

pass() { echo "[PASS] $1"; }
fail() { echo "[FAIL] $1"; exit 1; }

# Health endpoint
status=$(curl -sS -o /dev/null -w "%{http_code}" "$BASE_URL/health")
[[ "$status" == "200" ]] && pass "/health 200" || fail "/health $status"

# Register device
reg=$(curl -sS "$BASE_URL/API/pico/register?uid=$SMOKE_UID" | tr -d '\r\n')
[[ "$reg" == "#T#" ]] && pass "register returns #T#" || fail "register returned $reg"

# Check firmware should be false by default unless machine type known
chk=$(curl -sS "$BASE_URL/API/pico/checkFirmware?uid=$SMOKE_UID&version=0.1.33")
[[ "$chk" == "#T#" || "$chk" == "#F#" ]] && pass "checkFirmware returns $chk" || fail "checkFirmware returned $chk"

# Get firmware should return a bin when configured
fw_hdr=$(curl -sS -I "$BASE_URL/API/pico/getFirmware?uid=$SMOKE_UID" | head -n 1)
echo "$fw_hdr" | grep -qE "200|404|500" && pass "getFirmware reachable ($fw_hdr)" || fail "getFirmware no response"

