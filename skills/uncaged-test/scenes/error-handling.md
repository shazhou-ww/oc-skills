# 场景：异常处理

## 前置条件
- 部分场景**不需要**登录（验证未认证行为）
- `BASE=https://uncaged.shazhou.work`

## 场景 6.1：无效 Token 登录

### 步骤
```bash
curl -s -w "\n%{http_code}" -X POST "$BASE/auth/token" \
  -H "Content-Type: application/json" \
  -d '{"token":"0000000000000000000000000000000000000000000000000000000000000000"}'
```

### 验收标准
- HTTP 401
- 响应体含 error 信息

## 场景 6.2：未认证访问聊天

### 步骤
```bash
curl -s -w "\n%{http_code}" -X POST "$BASE/scott/doudou/api/chat" \
  -H "Content-Type: application/json" \
  -d '{"message":"hello"}'
```

### 验收标准
- HTTP 401
- 不返回聊天内容

## 场景 6.3：调用不存在的 Tool

### 前置
- 已登录

### 步骤
```bash
curl -s -w "\n%{http_code}" -X POST "$BASE/scott/doudou/api/v1/tools/this_tool_does_not_exist/invoke" \
  -H "Content-Type: application/json" \
  -b /tmp/uncaged-cookies.txt \
  -d '{"args":{}}'
```

### 验收标准
- HTTP 404 或 `success: false`
- 错误信息含 "not found" 之类

## 场景 6.4：空消息

### 前置
- 已登录

### 步骤
```bash
curl -s -w "\n%{http_code}" -X POST "$BASE/scott/doudou/api/chat" \
  -H "Content-Type: application/json" \
  -b /tmp/uncaged-cookies.txt \
  -d '{"message":""}'
```

### 验收标准
- HTTP 400（拒绝空消息）
- 或 HTTP 200 但 response 是合理的提示

## 场景 6.5：缺少 token 字段

### 步骤
```bash
curl -s -w "\n%{http_code}" -X POST "$BASE/auth/token" \
  -H "Content-Type: application/json" \
  -d '{}'
```

### 验收标准
- HTTP 400
- 错误信息说明缺少 token

## 场景 6.6：过期 Access Token

### 说明
Access token 有效期 15 分钟。过期后应该自动刷新或返回 401。

### 步骤
1. 登录获取 cookies
2. 等 15+ 分钟（或手动构造过期 token）
3. 用旧 cookies 发请求

### 验收标准
- 如果前端有自动刷新机制：请求成功（透明刷新）
- 如果没有：返回 401，前端应引导重新登录

### 注意
这个场景需要较长时间等待，通常跳过。可以通过 POST `/auth/refresh` 验证刷新机制是否正常（见 auth 场景 1.3）。

## 场景 6.7：不存在的 Agent 路径

### 步骤
```bash
curl -s -w "\n%{http_code}" -X POST "$BASE/scott/nonexistent_agent/api/chat" \
  -H "Content-Type: application/json" \
  -b /tmp/uncaged-cookies.txt \
  -d '{"message":"hello"}'
```

### 验收标准
- HTTP 404
- 不应该 500
