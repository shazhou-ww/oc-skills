#!/usr/bin/env bash
# uncaged-test/scripts/run-tests.sh
#
# Automated E2E tests for Uncaged Web UI.
# Usage: bash run-tests.sh [TOKEN_NAME]
#   TOKEN_NAME: Infisical secret name (default: UNCAGED_AGENT_TOKEN_XINGYUE)
#
# Exit codes:
#   0 = all passed
#   1 = one or more failures

set -euo pipefail

TOKEN_NAME="${1:-UNCAGED_AGENT_TOKEN_XINGYUE}"
BASE="https://uncaged.shazhou.work"
AGENT_BASE="$BASE/scott/doudou"
COOKIES="/tmp/uncaged-cookies-$$.txt"
PASS=0
FAIL=0
FAILURES=""

pass() { echo "  ✅ PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  ❌ FAIL: $1"; FAIL=$((FAIL + 1)); FAILURES="$FAILURES\n  - $1"; }

cleanup() { rm -f "$COOKIES" /tmp/uncaged-resp-$$.json; }
trap cleanup EXIT

echo "🧪 Uncaged E2E Tests"
echo "   Token: $TOKEN_NAME"
echo "   Target: $BASE"
echo ""

# ─── Get token ───
TOKEN=$(secret get "$TOKEN_NAME" 2>/dev/null) || { echo "ERROR: Cannot get token $TOKEN_NAME"; exit 1; }
TOKEN=$(echo "$TOKEN" | tr -d '\n')

# ═══════════════════════════════════════════
echo "=== S1: Auth ==="

# 1a. Token login
RESP=$(curl -s -w "\n%{http_code}" -X POST "$BASE/auth/token" \
  -H "Content-Type: application/json" \
  -d "{\"token\": \"$TOKEN\"}" \
  -c "$COOKIES")
HTTP=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | sed '$d')
if [ "$HTTP" = "200" ] && echo "$BODY" | grep -q '"userId"'; then
  pass "token login"
else
  fail "token login (HTTP $HTTP): $BODY"
fi

# 1b. Session check
RESP=$(curl -s -w "\n%{http_code}" "$BASE/auth/session" -b "$COOKIES")
HTTP=$(echo "$RESP" | tail -1)
if [ "$HTTP" = "200" ]; then pass "session check"; else fail "session check (HTTP $HTTP)"; fi

# 1c. Token refresh
RESP=$(curl -s -w "\n%{http_code}" -X POST "$BASE/auth/refresh" -b "$COOKIES" -c "$COOKIES")
HTTP=$(echo "$RESP" | tail -1)
if [ "$HTTP" = "200" ]; then pass "token refresh"; else fail "token refresh (HTTP $HTTP)"; fi

# ═══════════════════════════════════════════
echo ""
echo "=== S2: Chat ==="

# 2a. Send message
RESP=$(curl -s -w "\n%{http_code}" -X POST "$AGENT_BASE/api/chat" \
  -H "Content-Type: application/json" \
  -b "$COOKIES" \
  -d '{"message":"E2E test — reply with exactly: PONG"}' \
  --max-time 30)
HTTP=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | sed '$d')
if [ "$HTTP" = "200" ] && echo "$BODY" | python3 -c "import sys,json; r=json.load(sys.stdin); assert 'response' in r" 2>/dev/null; then
  pass "chat send"
else
  fail "chat send (HTTP $HTTP): $(echo "$BODY" | head -c 200)"
fi

# 2b. History
RESP=$(curl -s -w "\n%{http_code}" "$AGENT_BASE/api/history" -b "$COOKIES")
HTTP=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | sed '$d')
if [ "$HTTP" = "200" ]; then
  COUNT=$(echo "$BODY" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('history',[])))" 2>/dev/null || echo "?")
  pass "history ($COUNT messages)"
else
  fail "history (HTTP $HTTP)"
fi

# ═══════════════════════════════════════════
echo ""
echo "=== S3: Streaming ==="

STREAM_OUT=$(curl -s -N -X POST "$AGENT_BASE/api/chat/stream" \
  -H "Content-Type: application/json" \
  -b "$COOKIES" \
  --max-time 20 \
  -d '{"message":"Say OK"}' 2>&1 || true)

if echo "$STREAM_OUT" | grep -q '"type":"token"\|"type":"done"'; then
  pass "streaming"
else
  fail "streaming — no events. Output: $(echo "$STREAM_OUT" | head -c 200)"
fi

# ═══════════════════════════════════════════
echo ""
echo "=== S4: Tool Gateway ==="

# 4a. Builtin tools list
RESP=$(curl -s -w "\n%{http_code}" "$AGENT_BASE/api/v1/tools/builtin" -b "$COOKIES")
HTTP=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | sed '$d')
if [ "$HTTP" = "200" ]; then
  COUNT=$(echo "$BODY" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "?")
  pass "builtin tools list ($COUNT tools)"
else
  fail "builtin tools list (HTTP $HTTP)"
fi

# 4b. sigil_query
RESP=$(curl -s -w "\n%{http_code}" -X POST "$AGENT_BASE/api/v1/tools/sigil_query/invoke" \
  -H "Content-Type: application/json" \
  -b "$COOKIES" \
  -d '{"args":{"q":"test","limit":2}}' --max-time 30)
HTTP=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | sed '$d')
if [ "$HTTP" = "200" ] && echo "$BODY" | python3 -c "import sys,json; assert json.load(sys.stdin)['success']" 2>/dev/null; then
  pass "sigil_query invoke"
else
  fail "sigil_query invoke (HTTP $HTTP): $(echo "$BODY" | head -c 200)"
fi

# 4c. memory_search
RESP=$(curl -s -w "\n%{http_code}" -X POST "$AGENT_BASE/api/v1/tools/memory_search/invoke" \
  -H "Content-Type: application/json" \
  -b "$COOKIES" \
  -d '{"args":{"query":"hello"}}' --max-time 30)
HTTP=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | sed '$d')
if [ "$HTTP" = "200" ] && echo "$BODY" | python3 -c "import sys,json; assert json.load(sys.stdin)['success']" 2>/dev/null; then
  pass "memory_search invoke"
else
  fail "memory_search invoke (HTTP $HTTP): $(echo "$BODY" | head -c 200)"
fi

# ═══════════════════════════════════════════
echo ""
echo "=== S5: Error Handling ==="

# 5a. Invalid token
RESP=$(curl -s -w "\n%{http_code}" -X POST "$BASE/auth/token" \
  -H "Content-Type: application/json" \
  -d '{"token":"0000000000000000000000000000000000000000000000000000000000000000"}')
HTTP=$(echo "$RESP" | tail -1)
if [ "$HTTP" = "401" ]; then pass "invalid token rejected"; else fail "invalid token (HTTP $HTTP, expected 401)"; fi

# 5b. Unauthenticated chat
RESP=$(curl -s -w "\n%{http_code}" -X POST "$AGENT_BASE/api/chat" \
  -H "Content-Type: application/json" \
  -d '{"message":"no auth"}')
HTTP=$(echo "$RESP" | tail -1)
if [ "$HTTP" = "401" ]; then pass "unauth chat rejected"; else fail "unauth chat (HTTP $HTTP, expected 401)"; fi

# 5c. Non-existent tool
RESP=$(curl -s -w "\n%{http_code}" -X POST "$AGENT_BASE/api/v1/tools/nonexistent_xyz/invoke" \
  -H "Content-Type: application/json" \
  -b "$COOKIES" \
  -d '{"args":{}}')
HTTP=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | sed '$d')
if [ "$HTTP" = "404" ] || echo "$BODY" | grep -q '"success":false'; then
  pass "nonexistent tool rejected"
else
  fail "nonexistent tool (HTTP $HTTP): $(echo "$BODY" | head -c 200)"
fi

# ═══════════════════════════════════════════
echo ""
echo "════════════════════════════════════════"
echo "  Results: $PASS passed, $FAIL failed"
echo "════════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "Failures:"
  echo -e "$FAILURES"
  echo ""
  echo "Run log collection (see SKILL.md) and open a bug issue."
  exit 1
fi

echo ""
echo "All tests passed! 🎉"
exit 0
