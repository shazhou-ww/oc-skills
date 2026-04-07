---
name: uncaged-dev
version: 1.1.0
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
│   ├── core/          # 共享核心：LLM、Memory、Sigil、Tool Registry、E2B
│   ├── worker/        # CF Worker（后端 API + routing）
│   ├── web/           # React 19 + Tailwind v4 前端（SPA）
│   ├── runner/        # Runner 客户端（连设备到 Agent）
│   └── health/        # Health monitoring worker
├── tests/e2e/         # 场景化测试用例
├── scripts/           # 部署脚本
└── .github/workflows/ # CI/CD
```

**仓库：** `oc-xiaoju/uncaged`
**线上：** `https://uncaged.shazhou.work`
**CI/CD：** push main → GitHub Actions 自动部署

## 开发流程

**原则：Issue 驱动，协调者不写代码，subagent 干活。**

```
需求/Bug → 开 Issue → Spawn subagent → 验证（build + diff）→ 
Commit（closes #N）→ push main → 自动部署
```

### 1. 开 Issue

```bash
gh issue create --repo oc-xiaoju/uncaged \
  --title "fix/feat: 简短描述" \
  --body "## Problem\n...\n## Plan\n...\n## Acceptance\n..."
```

### 2. Spawn subagent 编码

给 subagent 的任务包含：
- Issue 链接
- 仓库路径：`~/repos/uncaged`
- 要改的文件列表和具体改法
- 验证命令
- commit message（含 `closes #N`）
- **不要 push**，由协调者 review 后推

### 3. 验证

```bash
# Build core（必须先 build，其他包依赖它）
cd packages/core && rm -rf dist && npx tsc

# Build web
cd ../web && npx vite build

# Type check worker（有预存在的 sigil-routes 类型错误，忽略）
cd ../worker && npx tsc --noEmit
```

### 4. 提交 + 推送

```bash
git add -A
git commit -m "fix: description (closes #N)"
git push origin main    # 触发 CI/CD 自动部署
```

## Build & Deploy

### 线上（自动）
Push main → GitHub Actions → build core → build web → wrangler deploy

### 开发环境（手动）

每人一个独立 Worker：

```bash
bash scripts/deploy-dev.sh xingyue    # → uncaged-xingyue.shazhou.work
bash scripts/deploy-dev.sh xiaoju     # → uncaged-xiaoju.shazhou.work
```

### 手动部署线上（紧急）

```bash
cd packages/core && rm -rf dist && npx tsc
cd ../web && npx vite build
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
| 路由 404 | `normalizeApiPath` strip 了 `/api/` | 路由匹配用 strip 后路径 |
| worker tsc 报 sigil-routes 类型错误 | 预存在的，不影响部署 | 忽略 |

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
cd ~/repos/uncaged/packages/worker
CF_TOKEN=$(secret get CLOUDFLARE_API_TOKEN)
CF_ACCOUNT=$(secret get CLOUDFLARE_ACCOUNT_ID)
CLOUDFLARE_API_TOKEN="$CF_TOKEN" CLOUDFLARE_ACCOUNT_ID="$CF_ACCOUNT" \
  npx wrangler tail --format pretty
```

### D1 查询

```bash
CLOUDFLARE_API_TOKEN="$CF_TOKEN" CLOUDFLARE_ACCOUNT_ID="$CF_ACCOUNT" \
  npx wrangler d1 execute uncaged-memory --remote --json \
  --command "SELECT * FROM users LIMIT 10;"
```

### KV 查询

```bash
CLOUDFLARE_API_TOKEN="$CF_TOKEN" CLOUDFLARE_ACCOUNT_ID="$CF_ACCOUNT" \
  npx wrangler kv key list --namespace-id 84a3ac3b64c846bd9e6c2b8632dc2499 --prefix "e2b:"
```

### 前端状态

```bash
# Session
curl -s https://uncaged.shazhou.work/auth/session -b /tmp/uncaged-cookies.txt | python3 -m json.tool
# History
curl -s https://uncaged.shazhou.work/scott/doudou/api/history -b /tmp/uncaged-cookies.txt | python3 -c "
import sys,json; msgs=json.load(sys.stdin)['history']
for m in msgs[-5:]: print(f'  [{m[\"role\"]:10s}] ts={m.get(\"timestamp\",\"?\")} {str(m.get(\"content\",\"\"))[:60]}')"
# Clear history
curl -s -X POST https://uncaged.shazhou.work/scott/doudou/api/clear -b /tmp/uncaged-cookies.txt
```

## 架构速查

### API 路由

路由经过 `normalizeApiPath` 处理，会 strip `/api/` 和 `/api/v1/` 前缀。下表中"路由匹配"是 strip 后的内部路径。

| 外部路径 | 内部匹配 | 方法 | 说明 |
|:-----|:-----|:-----|:-----|
| `/auth/token` | — | POST | Token 登录 |
| `/auth/session` | — | GET | Session 检查 |
| `/:o/:a/api/chat` | `/chat` | POST | 发消息 |
| `/:o/:a/api/chat/stream` | `/chat/stream` | POST | SSE 流式 |
| `/:o/:a/api/history` | `/history` | GET | 聊天历史 |
| `/:o/:a/api/clear` | `/clear` | POST | 清空历史 |
| `/:o/:a/api/v1/tools/builtin` | `/tools/builtin` | GET | Builtin 工具列表 |
| `/:o/:a/api/v1/tools/:slug/invoke` | `/tools/:slug/invoke` | POST | 直接调用工具 |
| `/:o/:a/hook/telegram` | `/hook/telegram` | POST | Telegram webhook |

### 关键文件

| 文件 | 作用 |
|:-----|:-----|
| `core/src/llm/tool-registry.ts` | **SSOT** — 所有 builtin tool 定义 |
| `core/src/llm/agent-loop.ts` | LLM agent loop + tool execution + 每条消息打 timestamp |
| `core/src/pipeline.ts` | contextCompressor — 按逻辑单元压缩（保持 tool_call 配对完整） |
| `core/src/chat-handler.ts` | 聊天命令处理（/new /clear /help /soul /start） |
| `core/src/chat-store.ts` | ChatMessage 接口（含 timestamp 字段）+ KV 存储 |
| `core/src/e2b-provider.ts` | E2B sandbox 管理（create/resume/exec） |
| `core/src/runner-hub.ts` | RunnerHub DO — E2B exec 调度（含 resume fallback） |
| `worker/src/index.ts` | 主路由 + Worker entry |
| `worker/src/services/capability-service.ts` | Tool Gateway 执行层 |
| `web/src/hooks/use-chat.ts` | 前端聊天状态 |
| `web/src/components/chat/chat-input.tsx` | 输入框 + 斜杠命令 + 工具搜索 overlay |
| `web/src/components/chat/tool-search-overlay.tsx` | 命令/工具搜索 overlay（含 slash commands） |
| `worker/wrangler.toml` | CF 配置（bindings + routes + envs） |

### E2B Sandbox（代码执行）

| 文件 | 作用 |
|:-----|:-----|
| `core/src/e2b-provider.ts` | API 封装：createSandbox / getSandbox / resumeSandbox / execCommand |
| `core/src/runner-hub.ts` | 调度逻辑：KV 缓存 sandbox ID → getSandbox 检查状态 → resume 或新建 |

**E2B 注意事项：**
- `SandboxInfo` 字段是 `state`（不是 `status`）、`sandboxID`（大写 ID）
- `resumeSandbox()` 必须传 `body: JSON.stringify({ timeout })` 否则 400
- Resume 失败时 fallback 到 `createSandbox()`
- 全链路有 `[E2B]` 和 `[RunnerHub]` 前缀的 console.log

### Context Compressor

`contextCompressor` 在 `core/src/pipeline.ts`：
- 按**逻辑单元**分组：tool-call 单元 = assistant(tool_calls) + 所有 tool(result)
- 压缩时整组保留或整组丢弃，不会拆散 tool_call 配对
- 孤立的 tool_result 直接 drop
- 压缩后的 tool 单元在 summary 里显示 `[Called {tool_name} → {result preview}]`

### 消息时间戳

每条 `ChatMessage` 都有 `timestamp?: number`（epoch ms）：
- 在创建时打 `Date.now()`（agent-loop、chat-handler）
- History API 返回 `msg.timestamp || Date.now()`（旧消息兼容）

### 斜杠命令

在 `chat-handler.ts` 的 `handleCommand()` 中：

| 命令 | 作用 |
|:-----|:-----|
| `/new` | 清空历史，开始新 session |
| `/clear` | 清空聊天记录 |
| `/help` | 查看可用命令 |
| `/soul` | 查看 AI 人格设定 |
| `/start` | 重置对话 |

前端输入 `/` 时弹出命令提示 overlay（`chat-input.tsx` + `tool-search-overlay.tsx`）。

### Tool Registry（SSOT）

添加新 builtin tool 只需改 `core/src/llm/tool-registry.ts` 的 `TOOL_REGISTRY` 数组，LLM / Gateway / 前端自动同步。

## Secrets

```bash
secret get CLOUDFLARE_API_TOKEN       # CF 部署
secret get CLOUDFLARE_ACCOUNT_ID      # CF 账户
secret get UNCAGED_AGENT_TOKEN_XINGYUE # 测试登录 token
secret get DOUDOU_TELEGRAM_BOT_TOKEN  # 豆豆 Telegram Bot
secret get E2B_API_KEY                # E2B sandbox（在 wrangler secrets 中）
```
