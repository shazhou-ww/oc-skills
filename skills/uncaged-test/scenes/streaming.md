# 场景：SSE 流式响应

## 前置条件
- 已登录（cookies 在 `/tmp/uncaged-cookies.txt`）
- `BASE=https://uncaged.shazhou.work/scott/doudou`

## 场景 3.1：基本流式响应

### 步骤
```bash
curl -s -N -X POST "$BASE/api/chat/stream" \
  -H "Content-Type: application/json" \
  -b /tmp/uncaged-cookies.txt \
  --max-time 30 \
  -d '{"message":"Say hello"}'
```

### 验收标准
- 返回 SSE 格式（`data: {...}\n` 行）
- 至少有一个 `{"type":"token","text":"..."}` 事件（流式文本）
- 最后有一个 `{"type":"done"}` 事件
- 所有 token 拼接起来是一段有意义的回复

### 如何判断
```bash
OUTPUT=$(curl -s -N -X POST "$BASE/api/chat/stream" \
  -H "Content-Type: application/json" \
  -b /tmp/uncaged-cookies.txt \
  --max-time 30 \
  -d '{"message":"Say OK"}')

# 检查有 token 事件
echo "$OUTPUT" | grep -c '"type":"token"'  # 应该 > 0

# 检查有 done 事件
echo "$OUTPUT" | grep -c '"type":"done"'   # 应该 = 1

# 拼接完整文本
echo "$OUTPUT" | grep '"type":"token"' | sed 's/^data: //' | \
  python3 -c "import sys,json; print(''.join(json.loads(l)['text'] for l in sys.stdin))"
```

## 场景 3.2：流式中的 Tool Call

### 步骤
发送一条会触发工具调用的消息：

```bash
curl -s -N -X POST "$BASE/api/chat/stream" \
  -H "Content-Type: application/json" \
  -b /tmp/uncaged-cookies.txt \
  --max-time 60 \
  -d '{"message":"搜索一下关于 test 的记忆"}'
```

### 验收标准
- 有 `{"type":"tool_start","name":"memory_search",...}` 事件
- 有 `{"type":"tool_result",...}` 事件
- tool_start 后有 tool_result（顺序正确）
- 最终有 token 事件或 done 事件（agent 给了最终回复）

### 注意
- 这个场景依赖 agent 的行为——它可能不一定每次都调用 tool
- 如果 agent 直接回复而没调 tool，不算失败，但需要记录
