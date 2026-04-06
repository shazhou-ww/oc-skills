---
name: uncaged-test
version: 1.1.0
description: >
  Test and interact with the Uncaged Web UI (uncaged.shazhou.work). Use when
  you need to: log in to the Uncaged web interface for testing, verify deployment
  after code changes, check if the chat UI / streaming / tool calls work correctly,
  or run end-to-end tests against the live Uncaged instance. Covers agent token
  auto-login, session verification, and common test scenarios.
metadata:
  requiredTools: ["secret"]
---

# Uncaged Test

How to test the Uncaged Web UI as an AI Agent.

## ⚠️ `secret` CLI Output Warning

The `secret` CLI outputs ANSI escape codes and info text. **Always clean output** before using as env vars:

```bash
# WRONG — will include ANSI codes and break everything
export CLOUDFLARE_API_TOKEN=$(secret get CLOUDFLARE_API_TOKEN)

# RIGHT — strip ANSI, take first line, trim newline
secret get KEY 2>/dev/null | head -1 | tr -d '\n' | sed 's/\x1b\[[0-9;]*m//g' | cut -d' ' -f1
```

Helper function (add to your shell or use inline):
```bash
clean_secret() { secret get "$1" 2>/dev/null | head -1 | tr -d '\n' | sed 's/\x1b\[[0-9;]*m//g' | cut -d' ' -f1; }
```

## Quick Start — Agent Token Login

Each agent can generate their own secret token and inject it into D1.

### Prerequisites

- `secret` CLI (Infisical) — for storing the token
- Cloudflare API credentials — `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` in Infisical
- `wrangler` — for D1 operations (`npx wrangler` in the uncaged repo)
- Uncaged repo cloned (path varies per machine — check your setup)

### Step 1: Generate token and inject into D1

```bash
# 1. Generate a random token and its SHA-256 hash
TOKEN=$(openssl rand -hex 32)
# macOS uses shasum, Linux uses sha256sum
HASH=$(echo -n "$TOKEN" | shasum -a 256 | cut -d' ' -f1)

# 2. Store the token in Infisical
secret set UNCAGED_AGENT_TOKEN_<YOUR_NAME> "$TOKEN"

# 3. Set CF credentials (clean ANSI output!)
CF_TOKEN=$(secret get CLOUDFLARE_API_TOKEN 2>/dev/null | head -1 | tr -d '\n' | sed 's/\x1b\[[0-9;]*m//g' | cut -d' ' -f1)
CF_ACCOUNT=$(secret get CLOUDFLARE_ACCOUNT_ID 2>/dev/null | head -1 | tr -d '\n' | sed 's/\x1b\[[0-9;]*m//g' | cut -d' ' -f1)

# 4. Look up user_id and agent_id in D1
cd <your-uncaged-repo>/packages/worker
CLOUDFLARE_API_TOKEN="$CF_TOKEN" CLOUDFLARE_ACCOUNT_ID="$CF_ACCOUNT" \
  npx wrangler d1 execute uncaged-memory --remote --json \
  --command "SELECT id, slug FROM users;"

CLOUDFLARE_API_TOKEN="$CF_TOKEN" CLOUDFLARE_ACCOUNT_ID="$CF_ACCOUNT" \
  npx wrangler d1 execute uncaged-memory --remote --json \
  --command "SELECT id, slug FROM agents;"

# 5. Insert token (replace <user_id> and <agent_id> with values from step 4)
CLOUDFLARE_API_TOKEN="$CF_TOKEN" CLOUDFLARE_ACCOUNT_ID="$CF_ACCOUNT" \
  npx wrangler d1 execute uncaged-memory --remote \
  --command "INSERT INTO agent_tokens (id, user_id, agent_id, token_hash, label, created_at) VALUES (lower(hex(randomblob(8))), '<user_id>', '<agent_id>', '${HASH}', '<your-label>', unixepoch());"
```

**Example** (for user `owner-scott`, agent `doudou`):
```bash
CLOUDFLARE_API_TOKEN="$CF_TOKEN" CLOUDFLARE_ACCOUNT_ID="$CF_ACCOUNT" \
  npx wrangler d1 execute uncaged-memory --remote \
  --command "INSERT INTO agent_tokens (id, user_id, agent_id, token_hash, label, created_at) VALUES (lower(hex(randomblob(8))), 'owner-scott', 'doudou', '${HASH}', 'xingyue-test', unixepoch());"
```

### Step 2: Verify token works

```bash
TOKEN=$(secret get UNCAGED_AGENT_TOKEN_<YOUR_NAME> 2>/dev/null | head -1 | tr -d '\n' | sed 's/\x1b\[[0-9;]*m//g' | cut -d' ' -f1)

# POST /auth/token — should return 200 with userId
curl -s -X POST "https://uncaged.shazhou.work/auth/token" \
  -H "Content-Type: application/json" \
  -d "{\"token\": \"$TOKEN\"}" \
  -c /tmp/uncaged-cookies.txt
# Expected: {"userId":"owner-scott","ownerSlug":"scott","agentSlug":"doudou"}
```

### Step 3: Login via browser

```
https://uncaged.shazhou.work/login#<your-token>
```

The page will read the hash, clear it from URL bar, verify via `/auth/token`, set JWT cookies, and redirect to the agent chat page.

### Step 4: Verify session

```bash
curl -s "https://uncaged.shazhou.work/auth/session" \
  -b /tmp/uncaged-cookies.txt
# Expected: user info + agents array
```

## API Reference

### POST /auth/token

Agent token login endpoint.

**Request:**
```json
{ "token": "<64-char hex string>" }
```

**Success (200):** Sets `access_token` + `refresh_token` as HttpOnly cookies.
```json
{ "userId": "owner-scott", "ownerSlug": "scott", "agentSlug": "doudou" }
```

**Errors:** `400` missing token, `401` invalid/revoked, `429` rate limited (5/min/IP)

### Chat API

**⚠️ Use `/api/chat` not `/api/v1/chat`** — the v1 path returns 401 due to web channel auth guard.

```bash
# Send message (with cookies from token login)
curl -s -X POST "https://uncaged.shazhou.work/scott/doudou/api/chat" \
  -H "Content-Type: application/json" \
  -b /tmp/uncaged-cookies.txt \
  -d '{"message":"hello"}'

# Load history
curl -s "https://uncaged.shazhou.work/scott/doudou/api/history" \
  -b /tmp/uncaged-cookies.txt
```

### SSE Streaming

```bash
curl -s -N -X POST "https://uncaged.shazhou.work/scott/doudou/api/chat/stream" \
  -H "Content-Type: application/json" \
  -b /tmp/uncaged-cookies.txt \
  -d '{"message":"hello"}'
# Returns: data: {"type":"token","text":"..."}\n lines
```

### Tool Gateway

```bash
# Invoke a builtin tool directly
curl -s -X POST "https://uncaged.shazhou.work/scott/doudou/api/v1/tools/sigil_query/invoke" \
  -H "Content-Type: application/json" \
  -b /tmp/uncaged-cookies.txt \
  -d '{"args":{"q":"test","limit":3}}'

# List all user-invocable builtin tools
curl -s "https://uncaged.shazhou.work/scott/doudou/api/v1/tools/builtin" \
  -b /tmp/uncaged-cookies.txt
```

## Common Test Scenarios

### 1. Chat basic flow
```bash
# Send message + verify response
curl -s -X POST ".../api/chat" -b /tmp/uncaged-cookies.txt \
  -H "Content-Type: application/json" \
  -d '{"message":"请回复 OK"}' | python3 -c "import sys,json; print(json.load(sys.stdin)['response'])"
# Expected: OK (or similar)

# Verify history persists
curl -s ".../api/history" -b /tmp/uncaged-cookies.txt | python3 -c "
import sys,json; msgs=json.load(sys.stdin)['history']; print(f'{len(msgs)} messages, last: {msgs[-1][\"content\"][:50]}')"
```

### 2. Tool invocation
```bash
# sigil_query — search capabilities
curl -s -X POST ".../api/v1/tools/sigil_query/invoke" -b /tmp/uncaged-cookies.txt \
  -H "Content-Type: application/json" \
  -d '{"args":{"q":"test"}}' | python3 -c "
import sys,json; d=json.load(sys.stdin); print(f'Success: {d[\"success\"]}, Tools: {len(d[\"result\"][\"items\"])}')"

# memory_search — search memories
curl -s -X POST ".../api/v1/tools/memory_search/invoke" -b /tmp/uncaged-cookies.txt \
  -H "Content-Type: application/json" \
  -d '{"args":{"query":"hello"}}' | python3 -c "
import sys,json; d=json.load(sys.stdin); print(f'Success: {d[\"success\"]}, Entries: {d[\"result\"][\"total\"]}')"
```

### 3. Auth token refresh
```bash
# Refresh token (using refresh_token cookie)
curl -s -X POST "https://uncaged.shazhou.work/auth/refresh" \
  -b /tmp/uncaged-cookies.txt -c /tmp/uncaged-cookies.txt
```

## Architecture Notes

- **Domain**: `uncaged.shazhou.work` (single domain, path-based routing)
- **Stack**: Cloudflare Worker + D1 + KV + Vectorize + Durable Objects
- **Frontend**: React 19 + Tailwind v4, served as SPA via Worker `[assets]` binding
- **Auth**: JWT (access 15min + refresh 7d), cookie-based
- **CI/CD**: GitHub Actions → auto deploy on push to main
- **Tool Registry**: SSOT in `packages/core/src/llm/tool-registry.ts`

## D1 Info

- **Database name**: `uncaged-memory`
- **Wrangler config**: `packages/worker/wrangler.toml`
- **CF credentials**: `CLOUDFLARE_API_TOKEN` + `CLOUDFLARE_ACCOUNT_ID` in Infisical
- **Token naming**: `UNCAGED_AGENT_TOKEN_<NAME>` in Infisical

## Troubleshooting

### Token login returns 401
- Verify hash: `echo -n "<token>" | shasum -a 256` (macOS) or `sha256sum` (Linux)
- Check D1: `SELECT * FROM agent_tokens WHERE revoked = 0;`
- Ensure `user_id` and `agent_id` match existing rows in `users` and `agents` tables

### Chat API returns 401
- Use `/api/chat` not `/api/v1/chat` (v1 path goes through web channel auth guard)
- Check cookies are being sent (`-b /tmp/uncaged-cookies.txt`)
- Token may have expired (15min access token) — refresh first

### Rate limited (429)
- Wait 60 seconds, rate limit resets per IP per minute

### `secret get` output looks garbled
- ANSI escape codes in output — use the cleaning pattern from the warning section above
