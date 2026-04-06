---
name: uncaged-test
version: 1.0.0
description: >
  Test and interact with the Uncaged Web UI (uncaged.shazhou.work). Use when
  you need to: log in to the Uncaged web interface for testing, verify deployment
  after code changes, check if the chat UI / streaming / tool calls work correctly,
  or run end-to-end tests against the live Uncaged instance. Covers agent token
  auto-login, session verification, and common test scenarios.
metadata:
  requiredTools: ["browser", "secret"]
---

# Uncaged Test

How to test the Uncaged Web UI as an AI Agent.

## Quick Start — Agent Token Login

Each agent has a secret token stored in Infisical. Use it to log in without Google OAuth.

### Step 1: Get your token

```bash
TOKEN=$(secret get UNCAGED_AGENT_TOKEN_XIAOJU | head -1)
```

Token naming convention: `UNCAGED_AGENT_TOKEN_<NAME>` (e.g., `_XIAOJU`, `_XIAOMOOO`, `_AOBING`, `_XINGYUE`).

If your token doesn't exist yet, ask 小橘 to generate one, or create it yourself:

```bash
TOKEN=$(openssl rand -hex 32)
HASH=$(echo -n "$TOKEN" | sha256sum | cut -d' ' -f1)
secret set UNCAGED_AGENT_TOKEN_<YOUR_NAME> "$TOKEN"
# Then insert into D1 (need wrangler access):
# INSERT INTO agent_tokens (id, user_id, agent_id, token_hash, label, created_at)
# VALUES (lower(hex(randomblob(8))), '<user_id>', '<agent_id>', '<HASH>', '<label>', unixepoch());
```

### Step 2: Login via URL hash

Open this URL in browser (the hash fragment is stripped immediately for security):

```
https://uncaged.shazhou.work/login#<your-token>
```

Or via the browser tool:

```
browser open https://uncaged.shazhou.work/login#<token>
```

The page will:
1. Read the `#hash`
2. Immediately clear it from the URL bar
3. POST to `/auth/token` for verification
4. On success: set JWT cookies and redirect to your agent's chat page
5. On failure: show error and fall back to normal login

### Step 3: Verify login

After redirect, you should land on `/<ownerSlug>/<agentSlug>/` (e.g., `/scott/doudou/`).

To verify programmatically:

```bash
# Using the cookies from login
curl -s https://uncaged.shazhou.work/auth/session \
  -b "access_token=<jwt>" | head -20
```

## API Reference

### POST /auth/token

Agent token login endpoint.

**Request:**
```json
{ "token": "<64-char hex string>" }
```

**Success (200):**
```json
{
  "userId": "owner-scott",
  "ownerSlug": "scott",
  "agentSlug": "doudou"
}
```
Also sets `access_token` and `refresh_token` as HttpOnly cookies.

**Errors:**
- `400` — Missing token
- `401` — Invalid or revoked token
- `429` — Rate limited (max 5 attempts/minute/IP)

## Common Test Scenarios

### 1. Chat basic flow
- Login → send a message → verify assistant response appears
- Check message persists after page refresh (history API)

### 2. Streaming
- Send a message → observe tokens streaming in real-time
- Verify no "flash" or full-replace behavior

### 3. Tool calls
- Trigger a message that causes tool use → verify tool call card renders
- Expand/collapse tool call details
- Verify multi-round tool calls stream correctly (Issue #45 fix)

### 4. Mobile
- Test on mobile viewport (375px width)
- Keyboard should not push layout; input stays visible

### 5. Auth token refresh
- Wait 15+ minutes → send a message → should auto-refresh without logout
- Or manually: POST `/auth/refresh` with refresh_token cookie

## Architecture Notes

- **Domain**: `uncaged.shazhou.work` (single domain, path-based routing)
- **Stack**: Cloudflare Worker + D1 + KV + Durable Objects
- **Frontend**: React 19 + Tailwind v4, served as SPA via Worker `[assets]` binding
- **Auth**: JWT (access 15min + refresh 7d), cookie-based
- **CI/CD**: GitHub Actions → auto deploy on push to main

## Current Test Accounts

| Owner | Slug | Agent | Notes |
|-------|------|-------|-------|
| owner-scott | scott | doudou | 主人的豆豆，主要测试 agent |

## Troubleshooting

### Token login returns 401
- Check token hasn't been revoked (`revoked=0` in D1)
- Verify the token hash matches: `echo -n "<token>" | sha256sum`
- Check the `agent_tokens` table has the correct `user_id` and `agent_id`

### Rate limited (429)
- Wait 60 seconds, rate limit resets per IP per minute
- Or test from a different IP

### Login redirects to wrong page
- Check `/auth/session` returns correct `agents` array
- Verify the user has at least one agent in the `agents` table
