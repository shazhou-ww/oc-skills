# 场景：聊天

## 前置条件
- 已登录（cookies 在 `/tmp/uncaged-cookies.txt`）
- `BASE=https://uncaged.shazhou.work/scott/doudou`

## 场景 2.1：发送消息并收到回复

### 步骤
```bash
curl -s -X POST "$BASE/api/chat" \
  -H "Content-Type: application/json" \
  -b /tmp/uncaged-cookies.txt \
  -d '{"message":"请回复 PONG"}'
```

### 验收标准
- HTTP 200
- 响应体有 `response` 字段（非空字符串）
- 响应体有 `timestamp` 字段

## 场景 2.2：消息历史持久化

### 前置
- 场景 2.1 已执行（刚发过消息）

### 步骤
```bash
curl -s "$BASE/api/history" -b /tmp/uncaged-cookies.txt
```

### 验收标准
- HTTP 200
- `history` 数组非空
- 最后两条消息：一条 `role: user`（你发的），一条 `role: assistant`（回复）
- 内容跟场景 2.1 中发送和收到的一致

## 场景 2.3：清空历史

### 步骤
1. 先确认有历史：
```bash
curl -s "$BASE/api/history" -b /tmp/uncaged-cookies.txt | \
  python3 -c "import sys,json; print(len(json.load(sys.stdin)['history']))"
```

2. 清空：
```bash
curl -s -X POST "$BASE/api/clear" -b /tmp/uncaged-cookies.txt
```

3. 再查：
```bash
curl -s "$BASE/api/history" -b /tmp/uncaged-cookies.txt | \
  python3 -c "import sys,json; print(len(json.load(sys.stdin)['history']))"
```

### 验收标准
- 步骤 1 返回 > 0
- 步骤 2 返回成功
- 步骤 3 返回 0（或只有 system message）

⚠️ **注意**：清空历史会影响其他测试场景。如果后续还要测 history，需要重新发消息。

## 场景 2.4：长消息处理

### 步骤
发送一条超长消息（500+ 字符），验证不会报错：

```bash
LONG_MSG=$(python3 -c "print('测试' * 200)")
curl -s -w "\n%{http_code}" -X POST "$BASE/api/chat" \
  -H "Content-Type: application/json" \
  -b /tmp/uncaged-cookies.txt \
  -d "{\"message\": \"$LONG_MSG\"}"
```

### 验收标准
- HTTP 200
- 响应体有 `response` 字段
- 不返回 413 或 500
