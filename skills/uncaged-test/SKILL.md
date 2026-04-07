---
name: uncaged-test
version: 2.0.0
description: >
  Automated E2E testing for Uncaged Web UI (uncaged.shazhou.work).
  派给 subagent 即可运行完整场景验证，失败时自动收集前后端 log 并开 bug issue。
  Use when: verifying deployment, testing new features, running regression checks,
  or debugging production issues.
metadata:
  requiredTools: ["secret"]
---

# Uncaged Test v2

Automated E2E testing for the Uncaged Web UI. Designed to be **run by subagents**.

## Quick Start — Run All Tests

```bash
bash <skill_dir>/scripts/run-tests.sh
```

Or step by step — see sections below.

## Setup (one-time per agent)

### 1. Ensure token exists

```bash
# Check if you already have a token
secret get UNCAGED_AGENT_TOKEN_XINGYUE 2>/dev/null && echo "Token exists" || echo "Need to create token"
```

If no token, create one:

```bash
TOKEN=$(openssl rand -hex 32)
HASH=$(echo -n "$TOKEN" | shasum -a 256 | cut -d' ' -f1)
secret set UNCAGED_AGENT_TOKEN_<YOUR_NAME> "$TOKEN"

# Insert into D1
CF_TOKEN=$(secret get CLOUDFLARE_API_TOKEN)
CF_ACCOUNT=$(secret get CLOUDFLARE_ACCOUNT_ID)
cd <uncaged-repo>/packages/worker
CLOUDFLARE_API_TOKEN="$CF_TOKEN" CLOUDFLARE_ACCOUNT_ID="$CF_ACCOUNT" \
  npx wrangler d1 execute uncaged-memory --remote \
  --command "INSERT INTO agent_tokens (id, user_id, agent_id, token_hash, label, created_at) VALUES (lower(hex(randomblob(8))), 'owner-scott', 'doudou', '${HASH}', '<label>', unixepoch());"
```

### 2. Login and save cookies

```bash
TOKEN=$(secret get UNCAGED_AGENT_TOKEN_<YOUR_NAME>)
curl -s -X POST "https://uncaged.shazhou.work/auth/token" \
  -H "Content-Type: application/json" \
  -d "{\"token\": \"$TOKEN\"}" \
  -c /tmp/uncaged-cookies.txt -o /tmp/uncaged-login.json
cat /tmp/uncaged-login.json
# Expected: {"userId":"owner-scott","ownerSlug":"scott","agentSlug":"doudou"}
```

## Test Scenarios

Run each scenario, record PASS/FAIL. On FAIL, collect logs (see Log Collection below).

### Scenario 1: Auth

```bash
echo "=== S1: Auth ==="

# 1a. Token login
RESP=$(curl -s -w "\n%{http_code}" -X POST "https://uncaged.shazhou.work/auth/token" \
  -H "Content-Type: application/json" \
  -d "{\"token\": \"$(secret get UNCAGED_AGENT_TOKEN_XINGYUE)\"}" \
  -c /tmp/uncaged-cookies.txt)
HTTP=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
if [ "$HTTP" = "200" ]; then echo "PASS: token login ($BODY)"; else echo "FAIL: token login HTTP=$HTTP body=$BODY"; fi

# 1b. Session check
RESP=$(curl -s -w "\n%{http_code}" "https://uncaged.shazhou.work/auth/session" -b /tmp/uncaged-cookies.txt)
HTTP=$(echo "$RESP" | tail -1)
if [ "$HTTP" = "200" ]; then echo "PASS: session check"; else echo "FAIL: session check HTTP=$HTTP"; fi

# 1c. Token refresh
RESP=$(curl -s -w "\n%{http_code}" -X POST "https://uncaged.shazhou.work/auth/refresh" \
  -b /tmp/uncaged-cookies.txt -c /tmp/uncaged-cookies.txt)
HTTP=$(echo "$RESP" | tail -1)
if [ "$HTTP" = "200" ]; then echo "PASS: token refresh"; else echo "FAIL: token refresh HTTP=$HTTP"; fi
```

### Scenario 2: Chat (non-streaming)

```bash
echo "=== S2: Chat ==="
BASE="https://uncaged.shazhou.work/scott/doudou"

# 2a. Send message
RESP=$(curl -s -w "\n%{http_code}" -X POST "$BASE/api/chat" \
  -H "Content-Type: application/json" \
  -b /tmp/uncaged-cookies.txt \
  -d '{"message":"E2E test — reply OK"}')
HTTP=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
if [ "$HTTP" = "200" ] && echo "$BODY" | python3 -c "import sys,json; json.load(sys.stdin)['response']" 2>/dev/null; then
  echo "PASS: chat send"
else
  echo "FAIL: chat send HTTP=$HTTP body=$BODY"
fi

# 2b. History
RESP=$(curl -s -w "\n%{http_code}" "$BASE/api/history" -b /tmp/uncaged-cookies.txt)
HTTP=$(echo "$RESP" | tail -1)
if [ "$HTTP" = "200" ]; then
  COUNT=$(echo "$RESP" | head -1 | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('history',[])))" 2>/dev/null)
  echo "PASS: history ($COUNT messages)"
else
  echo "FAIL: history HTTP=$HTTP"
fi
```

### Scenario 3: SSE Streaming

```bash
echo "=== S3: Streaming ==="
BASE="https://uncaged.shazhou.work/scott/doudou"

# Send streaming request, capture first 5 seconds
STREAM_OUT=$(timeout 15 curl -s -N -X POST "$BASE/api/chat/stream" \
  -H "Content-Type: application/json" \
  -b /tmp/uncaged-cookies.txt \
  -d '{"message":"Say hello in one word"}' 2>&1)

# Check for token events
if echo "$STREAM_OUT" | grep -q '"type":"token"'; then
  echo "PASS: streaming (got token events)"
elif echo "$STREAM_OUT" | grep -q '"type":"done"'; then
  echo "PASS: streaming (got done event, may have been fast)"
else
  echo "FAIL: streaming — no token events. Output: $(echo "$STREAM_OUT" | head -3)"
fi
```

### Scenario 4: Tool Gateway

```bash
echo "=== S4: Tool Gateway ==="
BASE="https://uncaged.shazhou.work/scott/doudou"

# 4a. Builtin tools list
RESP=$(curl -s -w "\n%{http_code}" "$BASE/api/v1/tools/builtin" -b /tmp/uncaged-cookies.txt)
HTTP=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
if [ "$HTTP" = "200" ]; then
  COUNT=$(echo "$BODY" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null)
  echo "PASS: builtin tools ($COUNT tools)"
else
  echo "FAIL: builtin tools HTTP=$HTTP"
fi

# 4b. sigil_query invoke
RESP=$(curl -s -w "\n%{http_code}" -X POST "$BASE/api/v1/tools/sigil_query/invoke" \
  -H "Content-Type: application/json" \
  -b /tmp/uncaged-cookies.txt \
  -d '{"args":{"q":"test","limit":2}}')
HTTP=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
if [ "$HTTP" = "200" ] && echo "$BODY" | python3 -c "import sys,json; assert json.load(sys.stdin)['success']" 2>/dev/null; then
  echo "PASS: sigil_query invoke"
else
  echo "FAIL: sigil_query invoke HTTP=$HTTP body=$(echo "$BODY" | head -c 200)"
fi

# 4c. memory_search invoke
RESP=$(curl -s -w "\n%{http_code}" -X POST "$BASE/api/v1/tools/memory_search/invoke" \
  -H "Content-Type: application/json" \
  -b /tmp/uncaged-cookies.txt \
  -d '{"args":{"query":"test"}}')
HTTP=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
if [ "$HTTP" = "200" ] && echo "$BODY" | python3 -c "import sys,json; assert json.load(sys.stdin)['success']" 2>/dev/null; then
  echo "PASS: memory_search invoke"
else
  echo "FAIL: memory_search invoke HTTP=$HTTP body=$(echo "$BODY" | head -c 200)"
fi
```

### Scenario 5: Error Handling

```bash
echo "=== S5: Error Handling ==="

# 5a. Invalid token
RESP=$(curl -s -w "\n%{http_code}" -X POST "https://uncaged.shazhou.work/auth/token" \
  -H "Content-Type: application/json" \
  -d '{"token":"0000000000000000000000000000000000000000000000000000000000000000"}')
HTTP=$(echo "$RESP" | tail -1)
if [ "$HTTP" = "401" ]; then echo "PASS: invalid token rejected (401)"; else echo "FAIL: invalid token HTTP=$HTTP (expected 401)"; fi

# 5b. Chat without auth
RESP=$(curl -s -w "\n%{http_code}" -X POST "https://uncaged.shazhou.work/scott/doudou/api/chat" \
  -H "Content-Type: application/json" \
  -d '{"message":"no auth"}')
HTTP=$(echo "$RESP" | tail -1)
if [ "$HTTP" = "401" ]; then echo "PASS: unauth chat rejected (401)"; else echo "FAIL: unauth chat HTTP=$HTTP (expected 401)"; fi

# 5c. Non-existent tool
RESP=$(curl -s -w "\n%{http_code}" -X POST "https://uncaged.shazhou.work/scott/doudou/api/v1/tools/nonexistent_tool_xyz/invoke" \
  -H "Content-Type: application/json" \
  -b /tmp/uncaged-cookies.txt \
  -d '{"args":{}}')
HTTP=$(echo "$RESP" | tail -1)
if [ "$HTTP" = "404" ] || echo "$RESP" | head -1 | grep -q '"success":false'; then
  echo "PASS: nonexistent tool rejected"
else
  echo "FAIL: nonexistent tool HTTP=$HTTP body=$(echo "$RESP" | head -1 | head -c 200)"
fi
```

## Log Collection

When a test fails, collect logs to diagnose. Run these and include output in bug reports.

### Backend Logs (Cloudflare Worker)

```bash
# Real-time tail (run in background, reproduce the bug, then kill)
CF_TOKEN=$(secret get CLOUDFLARE_API_TOKEN)
CF_ACCOUNT=$(secret get CLOUDFLARE_ACCOUNT_ID)
cd <uncaged-repo>/packages/worker

# Capture 30 seconds of logs
timeout 30 bash -c "CLOUDFLARE_API_TOKEN='$CF_TOKEN' CLOUDFLARE_ACCOUNT_ID='$CF_ACCOUNT' \
  npx wrangler tail --format json 2>/dev/null" > /tmp/uncaged-worker-logs.json &
TAIL_PID=$!
sleep 3

# Reproduce the failing request here
curl -s -X POST "https://uncaged.shazhou.work/scott/doudou/api/chat" \
  -H "Content-Type: application/json" \
  -b /tmp/uncaged-cookies.txt \
  -d '{"message":"reproduce bug"}' > /tmp/uncaged-repro-response.json 2>&1

sleep 10
kill $TAIL_PID 2>/dev/null
wait $TAIL_PID 2>/dev/null

# Extract relevant log entries
echo "=== Worker Logs ==="
cat /tmp/uncaged-worker-logs.json | python3 -c "
import sys, json
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    try:
        entry = json.loads(line)
        logs = entry.get('logs', [])
        exceptions = entry.get('exceptions', [])
        status = entry.get('event', {}).get('response', {}).get('status', '?')
        url = entry.get('event', {}).get('request', {}).get('url', '?')
        if logs or exceptions or status >= 400:
            print(f'[{status}] {url}')
            for log in logs:
                print(f'  LOG: {log.get(\"message\", log)}')
            for exc in exceptions:
                print(f'  ERR: {exc.get(\"message\", exc)}')
    except: pass
" 2>/dev/null
```

### Frontend State

```bash
# Check what the API actually returns
echo "=== Frontend Debug ==="

# Current session
echo "--- Session ---"
curl -s "https://uncaged.shazhou.work/auth/session" -b /tmp/uncaged-cookies.txt | python3 -m json.tool 2>/dev/null

# Chat history (last 3 messages)
echo "--- History (last 3) ---"
curl -s "https://uncaged.shazhou.work/scott/doudou/api/history" -b /tmp/uncaged-cookies.txt | python3 -c "
import sys,json
msgs = json.load(sys.stdin).get('history', [])
for m in msgs[-3:]:
    role = m['role']
    content = str(m.get('content',''))[:100]
    tc = len(m.get('tool_calls', []))
    print(f'  [{role}] {content}' + (f' (+{tc} tool calls)' if tc else ''))
" 2>/dev/null

# Builtin tools
echo "--- Builtin Tools ---"
curl -s "https://uncaged.shazhou.work/scott/doudou/api/v1/tools/builtin" -b /tmp/uncaged-cookies.txt | python3 -c "
import sys,json
tools = json.load(sys.stdin)
print(f'  {len(tools)} tools: {[t[\"slug\"] for t in tools]}')
" 2>/dev/null
```

### D1 Database State

```bash
CF_TOKEN=$(secret get CLOUDFLARE_API_TOKEN)
CF_ACCOUNT=$(secret get CLOUDFLARE_ACCOUNT_ID)
cd <uncaged-repo>/packages/worker

echo "=== D1 State ==="

# Users
echo "--- Users ---"
CLOUDFLARE_API_TOKEN="$CF_TOKEN" CLOUDFLARE_ACCOUNT_ID="$CF_ACCOUNT" \
  npx wrangler d1 execute uncaged-memory --remote --json \
  --command "SELECT id, slug, display_name FROM users LIMIT 10;" 2>/dev/null | \
  python3 -c "import sys,json; [print(f'  {r}') for r in json.load(sys.stdin)[0]['results']]" 2>/dev/null

# Agents
echo "--- Agents ---"
CLOUDFLARE_API_TOKEN="$CF_TOKEN" CLOUDFLARE_ACCOUNT_ID="$CF_ACCOUNT" \
  npx wrangler d1 execute uncaged-memory --remote --json \
  --command "SELECT id, slug, display_name FROM agents LIMIT 10;" 2>/dev/null | \
  python3 -c "import sys,json; [print(f'  {r}') for r in json.load(sys.stdin)[0]['results']]" 2>/dev/null

# Agent tokens
echo "--- Active Tokens ---"
CLOUDFLARE_API_TOKEN="$CF_TOKEN" CLOUDFLARE_ACCOUNT_ID="$CF_ACCOUNT" \
  npx wrangler d1 execute uncaged-memory --remote --json \
  --command "SELECT id, label, user_id, agent_id, created_at FROM agent_tokens WHERE revoked = 0;" 2>/dev/null | \
  python3 -c "import sys,json; [print(f'  {r}') for r in json.load(sys.stdin)[0]['results']]" 2>/dev/null
```

## Opening a Bug Issue

When a test fails, open a GitHub issue with collected evidence.

### Template

```bash
SCENARIO="<which scenario failed>"
EXPECTED="<what should happen>"
ACTUAL="<what actually happened>"
LOGS="<paste relevant logs from Log Collection>"

gh issue create --repo oc-xiaoju/uncaged \
  --title "bug: $SCENARIO" \
  --body "## Bug Report (automated)

### Scenario
$SCENARIO

### Expected
$EXPECTED

### Actual
$ACTUAL

### Reproduction
\`\`\`bash
<curl command that reproduces the issue>
\`\`\`

### Response
\`\`\`
$(cat /tmp/uncaged-repro-response.json 2>/dev/null)
\`\`\`

### Worker Logs
\`\`\`
$LOGS
\`\`\`

### Environment
- Time: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Deploy version: $(curl -s https://uncaged.shazhou.work/ -o /dev/null -w '%{redirect_url}' 2>/dev/null || echo 'unknown')

---
*Auto-generated by uncaged-test skill*" \
  --label "bug"
```

### Example: Opening a bug for failed chat

```bash
gh issue create --repo oc-xiaoju/uncaged \
  --title "bug: chat API returns 500 on message send" \
  --body "## Bug Report (automated)

### Scenario
S2: Chat — send message via POST /api/chat

### Expected
HTTP 200 with {\"response\": \"...\"}

### Actual
HTTP 500 with {\"error\": \"Internal error\"}

### Worker Logs
\`\`\`
[500] https://uncaged.shazhou.work/scott/doudou/api/chat
  ERR: TypeError: Cannot read properties of undefined (reading 'query')
\`\`\`

---
*Auto-generated by uncaged-test skill*" \
  --label "bug"
```

## API Quick Reference

| Endpoint | Method | Auth | Notes |
|:---------|:-------|:-----|:------|
| `/auth/token` | POST | none | Token login, sets cookies |
| `/auth/session` | GET | cookie | Check current session |
| `/auth/refresh` | POST | cookie | Refresh access token |
| `/:owner/:agent/api/chat` | POST | cookie | Send message (non-streaming) |
| `/:owner/:agent/api/chat/stream` | POST | cookie | Send message (SSE streaming) |
| `/:owner/:agent/api/history` | GET | cookie | Load chat history |
| `/:owner/:agent/api/clear` | POST | cookie | Clear chat history |
| `/:owner/:agent/api/v1/tools/builtin` | GET | none | List builtin tools |
| `/:owner/:agent/api/v1/tools/:slug/invoke` | POST | none | Invoke a tool directly |

**⚠️ Use `/api/chat` not `/api/v1/chat`** — v1 path returns 401 due to web channel auth guard.

## Architecture

- **Domain**: `uncaged.shazhou.work`
- **Stack**: CF Worker + D1 + KV + Vectorize + Durable Objects
- **Frontend**: React 19 + Tailwind v4 (SPA via `[assets]` binding)
- **Auth**: JWT (access 15min + refresh 7d), cookie-based
- **CI/CD**: GitHub Actions → auto deploy on push to main
- **Tool Registry**: SSOT in `packages/core/src/llm/tool-registry.ts`
- **Repo**: `oc-xiaoju/uncaged`
