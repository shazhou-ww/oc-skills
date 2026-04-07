---
name: uncaged-dev
version: 1.0.0
description: >
  Uncaged 项目的完整开发 skill。涵盖：项目架构、开发流程、build/deploy、
  测试验证、调试排查。装这一个 skill 就获得所有 Uncaged 开发能力。
metadata:
  requiredTools: ["secret", "gh"]
---

# Uncaged Dev

Uncaged 项目开发的一站式 skill。

## 项目概览

**Uncaged** — Sigil-native AI Agent 平台，运行在 Cloudflare Workers 上。

```
uncaged/
├── packages/
│   ├── core/          # 共享核心：LLM、Memory、Sigil、Tool Registry
│   ├── worker/        # CF Worker（后端 API + routing）
│   ├── web/           # React 19 + Tailwind v4 前端（SPA）
│   └── runner/        # Runner 客户端（连设备到 Agent）
├── tests/e2e/         # 场景化测试用例
├── scripts/           # 部署脚本
└── .github/workflows/ # CI/CD
```

**仓库：** `oc-xiaoju/uncaged`
**线上：** `https://uncaged.shazhou.work`
**CI/CD：** push main → GitHub Actions 自动部署

## 开发流程

**原则：Issue 驱动，协调者不写代码，Cursor Agent 干活。**

```
需求/Bug → 开 Issue → 创建分支 → Cursor Agent 编码 → 
验证（build + diff）→ Commit（closes #N）→ 合并 main → 自动部署
```

### 1. 开 Issue

```bash
gh issue create --repo oc-xiaoju/uncaged \
  --title "fix/feat: 简短描述" \
  --body "## Problem\n...\n## Plan\n...\n## Acceptance\n..."
```

### 2. 创建分支

```bash
cd <uncaged-repo>
git checkout main && git pull
git checkout -b fix/descriptive-name   # 或 feat/
```

### 3. 用 Cursor Agent 编码

```bash
CURSOR_API_KEY="$(secret get CURSOR_API_KEY)" \
  bash ~/.openclaw/workspace/skills/cursor-agent-cn/scripts/run.sh \
  <uncaged-repo> "<任务描述>" auto ask    # 先 review
# 确认后
  ... auto write                          # 再 apply
```

中国区必须用 `auto` model。两步走：先 `ask` review，再 `write` apply。

### 4. 验证

```bash
# Build（三步）
cd packages/core && rm -rf dist && npx tsc
cd ../web && npm run build
cd ../worker && npx tsc --noEmit

# Diff 检查
git diff --stat
```

### 5. 提交 + 合并

```bash
git add -A
git commit -m "fix: description (closes #N)"
git checkout main && git merge <branch> --no-ff
git push origin main    # 触发 CI/CD 自动部署
```

## Build & Deploy

### 线上（自动）
Push main → GitHub Actions → build core → build web → wrangler deploy

### 开发环境（手动）

每人一个独立 Worker，互不影响：

```bash
bash scripts/deploy-dev.sh xingyue    # → uncaged-xingyue.shazhou.work
bash scripts/deploy-dev.sh xiaoju     # → uncaged-xiaoju.shazhou.work
bash scripts/deploy-dev.sh xiaomooo   # → uncaged-xiaomooo.shazhou.work
bash scripts/deploy-dev.sh aobing     # → uncaged-aobing.shazhou.work
```

脚本自动：build core → build web → wrangler deploy --env <name>

### 手动部署线上（紧急）

```bash
cd packages/core && rm -rf dist && npx tsc
cd ../web && npm run build
cd ../worker
CLOUDFLARE_API_TOKEN="$(secret get CLOUDFLARE_API_TOKEN)" \
CLOUDFLARE_ACCOUNT_ID="$(secret get CLOUDFLARE_ACCOUNT_ID)" \
  npx wrangler deploy
```

### 常见 Build 问题

| 问题 | 原因 | 解决 |
|:-----|:-----|:-----|
| core dist 为空 | tsconfig 缺 `noEmitOnError: false` | 检查 `packages/core/tsconfig.json` |
| wrangler can't resolve @uncaged/core/* | core 没 build | 先 `cd packages/core && npx tsc` |
| POST 请求返回 SPA HTML | wrangler.toml 缺 `run_worker_first = true` | 检查 `[assets]` 配置 |
| 路由 404 | `normalizeApiPath` strip 了 `/api/v1/` | 路由匹配用 strip 后路径 |

## 测试

### Playwright UI 测试（9 个用例，28 秒）

```bash
cd <uncaged-repo>
npx playwright test                    # 跑全部
npx playwright test -g "tool search"   # 跑单个
npx playwright test --reporter=html    # 生成 HTML 报告
```

覆盖：token 登录、聊天发消息、工具搜索浮层、ESC 关闭、主题切换、JS 错误检测、手机端布局。

**首次使用需安装浏览器：** `npx playwright install chromium`

**指定目标环境：** `UNCAGED_URL=https://uncaged-xingyue.shazhou.work npx playwright test`

**指定 token：** `TOKEN_NAME=UNCAGED_AGENT_TOKEN_XIAOJU npx playwright test`

### API 回归（12 个用例，curl 脚本）

```bash
bash tests/e2e/scripts/run-tests.sh UNCAGED_AGENT_TOKEN_XINGYUE
```

### 场景验证（给 subagent 用）

场景文件在 `tests/e2e/scenes/`：

| 场景 | 文件 |
|:-----|:-----|
| 认证 | `scenes/auth.md` |
| 聊天 | `scenes/chat.md` |
| 流式 | `scenes/streaming.md` |
| Tool Gateway | `scenes/tool-gateway.md` |
| 工具搜索 | `scenes/tool-search.md` |
| 异常处理 | `scenes/error-handling.md` |

派 subagent 验证：
```
读 <uncaged-repo>/tests/e2e/scenes/tool-gateway.md，按描述验证。
失败了收集 logs 开 bug issue。
```

### Token 登录（测试用）

```bash
TOKEN=$(secret get UNCAGED_AGENT_TOKEN_XINGYUE)
curl -s -X POST "https://uncaged.shazhou.work/auth/token" \
  -H "Content-Type: application/json" \
  -d "{\"token\": \"$TOKEN\"}" \
  -c /tmp/uncaged-cookies.txt
```

## 调试

### Worker 日志

```bash
CF_TOKEN=$(secret get CLOUDFLARE_API_TOKEN)
CF_ACCOUNT=$(secret get CLOUDFLARE_ACCOUNT_ID)
cd <uncaged-repo>/packages/worker
CLOUDFLARE_API_TOKEN="$CF_TOKEN" CLOUDFLARE_ACCOUNT_ID="$CF_ACCOUNT" \
  npx wrangler tail --format pretty
```

### D1 查询

```bash
CLOUDFLARE_API_TOKEN="$CF_TOKEN" CLOUDFLARE_ACCOUNT_ID="$CF_ACCOUNT" \
  npx wrangler d1 execute uncaged-memory --remote --json \
  --command "SELECT * FROM users LIMIT 10;"
```

### 前端状态

```bash
# Session
curl -s https://uncaged.shazhou.work/auth/session -b /tmp/uncaged-cookies.txt | python3 -m json.tool
# History
curl -s https://uncaged.shazhou.work/scott/doudou/api/history -b /tmp/uncaged-cookies.txt | python3 -c "
import sys,json; [print(f'  [{m[\"role\"]}] {str(m.get(\"content\",\"\"))[:80]}') for m in json.load(sys.stdin)['history'][-5:]]"
```

## 架构速查

### API

| 端点 | 方法 | 说明 |
|:-----|:-----|:-----|
| `/auth/token` | POST | Token 登录 |
| `/auth/session` | GET | Session 检查 |
| `/:o/:a/api/chat` | POST | 发消息（⚠️ 不是 /api/v1/chat） |
| `/:o/:a/api/chat/stream` | POST | SSE 流式 |
| `/:o/:a/api/history` | GET | 聊天历史 |
| `/:o/:a/api/v1/tools/builtin` | GET | Builtin 工具列表 |
| `/:o/:a/api/v1/tools/:slug/invoke` | POST | 直接调用工具 |

### 关键文件

| 文件 | 作用 |
|:-----|:-----|
| `core/src/llm/tool-registry.ts` | **SSOT** — 所有 builtin tool 定义 |
| `core/src/llm/agent-loop.ts` | LLM agent loop + tool execution |
| `worker/src/index.ts` | 主路由 + Worker entry |
| `worker/src/services/capability-service.ts` | Tool Gateway 执行层 |
| `web/src/hooks/use-chat.ts` | 前端聊天状态 |
| `web/src/components/chat/chat-input.tsx` | 输入框 + 工具搜索 |
| `web/src/components/chat/message-bubble.tsx` | 消息气泡渲染 |
| `worker/wrangler.toml` | CF 配置（bindings + routes + envs） |

### 路由注意事项

- `normalizeApiPath` 会 strip `/api/v1/` 前缀
- 新路由要用 strip 后的路径匹配（如 `/tools/:slug/invoke` 不是 `/api/v1/tools/...`）
- `[assets] run_worker_first = true` 确保 POST 请求到 Worker

### Tool Registry（SSOT）

添加新 builtin tool 只需改 `core/src/llm/tool-registry.ts` 的 `TOOL_REGISTRY` 数组，LLM / Gateway / 前端自动同步。

## Secrets

```bash
secret get CLOUDFLARE_API_TOKEN       # CF 部署
secret get CLOUDFLARE_ACCOUNT_ID      # CF 账户
secret get CURSOR_API_KEY             # Cursor Agent
secret get UNCAGED_AGENT_TOKEN_XINGYUE # 测试登录 token
```
