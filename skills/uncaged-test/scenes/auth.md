# 场景：认证

## 前置条件
- `secret` CLI 可用
- Infisical 里有 `UNCAGED_AGENT_TOKEN_XINGYUE`（或你自己的 token）

## 场景 1.1：Token 登录

### 步骤
1. 获取 token：`TOKEN=$(secret get UNCAGED_AGENT_TOKEN_XINGYUE)`
2. POST 登录：
```bash
curl -s -w "\n%{http_code}" -X POST "https://uncaged.shazhou.work/auth/token" \
  -H "Content-Type: application/json" \
  -d "{\"token\": \"$TOKEN\"}" \
  -c /tmp/uncaged-cookies.txt
```

### 验收标准
- HTTP 200
- 响应体包含 `userId`、`ownerSlug`、`agentSlug`
- cookies 文件里有 `access_token` 和 `refresh_token`

## 场景 1.2：Session 检查

### 前置
- 场景 1.1 完成（cookies 已保存）

### 步骤
```bash
curl -s -w "\n%{http_code}" "https://uncaged.shazhou.work/auth/session" \
  -b /tmp/uncaged-cookies.txt
```

### 验收标准
- HTTP 200
- 响应体有 `user` 对象（含 id、displayName、slug）
- 响应体有 `agents` 数组（至少 1 个 agent）

## 场景 1.3：Token 刷新

### 前置
- 场景 1.1 完成

### 步骤
```bash
curl -s -w "\n%{http_code}" -X POST "https://uncaged.shazhou.work/auth/refresh" \
  -b /tmp/uncaged-cookies.txt -c /tmp/uncaged-cookies.txt
```

### 验收标准
- HTTP 200
- cookies 文件里的 `access_token` 已更新（值跟之前不同）

## 场景 1.4：创建新 Token（首次使用）

### 什么时候需要
- Infisical 里没有你的 token
- 需要一个新的测试账号

### 步骤
1. 生成 token 和 hash：
```bash
TOKEN=$(openssl rand -hex 32)
HASH=$(echo -n "$TOKEN" | shasum -a 256 | cut -d' ' -f1)
```

2. 存入 Infisical：
```bash
secret set UNCAGED_AGENT_TOKEN_<YOUR_NAME> "$TOKEN"
```

3. 查询 D1 获取 user_id 和 agent_id：
```bash
CF_TOKEN=$(secret get CLOUDFLARE_API_TOKEN)
CF_ACCOUNT=$(secret get CLOUDFLARE_ACCOUNT_ID)
cd <UNCAGED_DIR>/packages/worker
CLOUDFLARE_API_TOKEN="$CF_TOKEN" CLOUDFLARE_ACCOUNT_ID="$CF_ACCOUNT" \
  npx wrangler d1 execute uncaged-memory --remote --json \
  --command "SELECT id, slug FROM users;"
CLOUDFLARE_API_TOKEN="$CF_TOKEN" CLOUDFLARE_ACCOUNT_ID="$CF_ACCOUNT" \
  npx wrangler d1 execute uncaged-memory --remote --json \
  --command "SELECT id, slug FROM agents;"
```

4. 插入 token 到 D1：
```bash
CLOUDFLARE_API_TOKEN="$CF_TOKEN" CLOUDFLARE_ACCOUNT_ID="$CF_ACCOUNT" \
  npx wrangler d1 execute uncaged-memory --remote \
  --command "INSERT INTO agent_tokens (id, user_id, agent_id, token_hash, label, created_at) VALUES (lower(hex(randomblob(8))), '<user_id>', '<agent_id>', '${HASH}', '<label>', unixepoch());"
```

### 验收标准
- `secret get UNCAGED_AGENT_TOKEN_<YOUR_NAME>` 返回 64 位 hex
- POST `/auth/token` 返回 200
