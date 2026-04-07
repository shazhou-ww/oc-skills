# 场景：Tool Gateway

## 前置条件
- 已登录（cookies 在 `/tmp/uncaged-cookies.txt`）
- `BASE=https://uncaged.shazhou.work/scott/doudou`

## 场景 4.1：获取 Builtin 工具列表

### 步骤
```bash
curl -s "$BASE/api/v1/tools/builtin" -b /tmp/uncaged-cookies.txt
```

### 验收标准
- HTTP 200
- 返回 JSON 数组
- 每个元素有 `slug`、`displayName`、`description`、`icon`、`category`、`schema`
- 至少包含：`sigil_query`、`create_capability`、`memory_search`
- `userInvocable` 为 true 的才会出现

### 数量检查
当前应有 8 个 userInvocable 工具。如果数量不对，检查 `packages/core/src/llm/tool-registry.ts` 的 `TOOL_REGISTRY`。

## 场景 4.2：调用 sigil_query

### 步骤
```bash
curl -s -X POST "$BASE/api/v1/tools/sigil_query/invoke" \
  -H "Content-Type: application/json" \
  -b /tmp/uncaged-cookies.txt \
  -d '{"args":{"q":"test","limit":3}}'
```

### 验收标准
- HTTP 200
- `success: true`
- `result.items` 是数组
- 每个 item 有 `capability` 字段

## 场景 4.3：调用 memory_search

### 步骤
```bash
curl -s -X POST "$BASE/api/v1/tools/memory_search/invoke" \
  -H "Content-Type: application/json" \
  -b /tmp/uncaged-cookies.txt \
  -d '{"args":{"query":"hello"}}'
```

### 验收标准
- HTTP 200
- `success: true`
- `result.entries` 是数组
- `result.total` 是数字

## 场景 4.4：调用 memory_recall

### 步骤
```bash
curl -s -X POST "$BASE/api/v1/tools/memory_recall/invoke" \
  -H "Content-Type: application/json" \
  -b /tmp/uncaged-cookies.txt \
  -d '{"args":{"hours":1,"limit":5}}'
```

### 验收标准
- HTTP 200
- `success: true`
- `result.entries` 是数组
- `result.hours` = 1

## 场景 4.5：调用 sigil_deploy（创建 capability）

### ⚠️ 会创建真实资源！

### 步骤
```bash
SLUG="e2e-test-$(date +%s)"
curl -s -X POST "$BASE/api/v1/tools/sigil_deploy/invoke" \
  -H "Content-Type: application/json" \
  -b /tmp/uncaged-cookies.txt \
  -d "{\"args\":{\"name\":\"$SLUG\",\"description\":\"E2E test cap\",\"execute\":\"return {ok:true}\"}}"
```

### 验收标准
- HTTP 200
- `success: true`
- `result.capability` 等于传入的 name

### 清理
测试后应该删除创建的 capability（目前没有删除 API，可以忽略或通过 D1 清理）。

## 场景 4.6：用户通过 UI 调用 Tool 的完整流程

### 这是无脚本的手动验证场景

### 步骤
1. 打开浏览器访问 `https://uncaged.shazhou.work/scott/doudou/`
2. 在输入框输入 `/`
3. 应该弹出工具搜索浮层，显示 builtin tools 列表
4. 选择 "🔍 搜索工具"（sigil_query）
5. Form 应该出现，有 `q` 和 `limit` 两个字段
6. 填写 q = "test"，点提交
7. 聊天流里应该出现 Tool Result 卡片

### 验收标准
- 步骤 3：浮层显示至少 3 个工具
- 步骤 5：Form 正确渲染
- 步骤 7：结果卡片显示 success，内容有 capabilities 列表

### 如果没有浏览器
用 API 模拟完整流程：
```bash
# 1. 获取工具列表
curl -s "$BASE/api/v1/tools/builtin" -b /tmp/uncaged-cookies.txt | python3 -c "
import sys,json; tools=json.load(sys.stdin)
print(f'{len(tools)} tools available')
sq = next((t for t in tools if t['slug']=='sigil_query'), None)
if sq: print(f'sigil_query schema: {json.dumps(sq[\"schema\"])[:100]}')
"

# 2. 调用
curl -s -X POST "$BASE/api/v1/tools/sigil_query/invoke" \
  -H "Content-Type: application/json" \
  -b /tmp/uncaged-cookies.txt \
  -d '{"args":{"q":"test"}}' | python3 -c "
import sys,json; d=json.load(sys.stdin)
print(f'Success: {d[\"success\"]}')
if d.get('result',{}).get('items'):
    for i in d['result']['items'][:3]:
        print(f'  {i[\"capability\"]}: {i.get(\"description\",\"\")}')
"
```
