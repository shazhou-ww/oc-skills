# 场景：输入框工具搜索

## 前置条件
- 已登录
- `BASE=https://uncaged.shazhou.work/scott/doudou`

## 场景 5.1：Builtin 工具列表加载

### 说明
前端在页面加载时从 API 获取 builtin tools，作为本地搜索的基础数据。

### 步骤
```bash
curl -s "$BASE/api/v1/tools/builtin" -b /tmp/uncaged-cookies.txt | python3 -c "
import sys,json
tools = json.load(sys.stdin)
print(f'Total: {len(tools)} tools')
for t in tools:
    print(f'  {t[\"icon\"]} {t[\"slug\"]} — {t[\"displayName\"]}')
"
```

### 验收标准
- 返回 8 个 userInvocable 工具
- 每个有 slug、displayName、description、icon、schema
- schema 是有效的 JSON Schema（有 type、properties）

## 场景 5.2：从聊天历史提取动态工具

### 说明
前端解析聊天历史中的 `sigil_query` 结果和 `sigil_deploy` 调用，提取动态工具加入本地列表。

### 步骤
1. 先触发一次 sigil_query（让历史里有工具数据）：
```bash
curl -s -X POST "$BASE/api/chat" \
  -H "Content-Type: application/json" \
  -b /tmp/uncaged-cookies.txt \
  -d '{"message":"搜索一下有什么 capabilities"}' --max-time 30
```

2. 查看历史，确认有 sigil_query 的 tool result：
```bash
curl -s "$BASE/api/history" -b /tmp/uncaged-cookies.txt | python3 -c "
import sys,json
msgs = json.load(sys.stdin)['history']
tool_msgs = [m for m in msgs if m['role'] == 'tool']
for m in tool_msgs[-3:]:
    content = str(m.get('content',''))[:100]
    print(f'  [tool] {content}')
"
```

### 验收标准
- 历史中有 role=tool 的消息
- tool 消息的 content 包含 `items` 数组（sigil_query 结果）
- 前端应该从这些结果中提取出动态工具，合并到搜索列表

### 注意
这个场景验证的是**数据是否正确**。前端的实际渲染需要在浏览器里看。

## 场景 5.3：搜索过滤（无脚本，描述性验证）

### 步骤（浏览器操作）
1. 打开 `https://uncaged.shazhou.work/scott/doudou/`
2. 在输入框输入 `/` → 应该显示全部 builtin tools
3. 继续输入 `mem` → 列表应该只剩 memory 相关的工具
4. 清空输入框 → 浮层消失
5. 输入 `#search` → 应该匹配到 sigil_query 和 memory_search
6. 选中一个工具 → 输入框变成 Form

### 验收标准
- `/` 显示全部工具（8 个）
- 输入关键词后实时过滤（无网络请求，纯本地）
- ESC 关闭浮层
- 方向键导航 + Enter 选中
- 选中后 Form 正确渲染
