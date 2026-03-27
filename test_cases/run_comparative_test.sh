#!/bin/bash
# ─────────────────────────────────────────────────────────────────
# 比较级绘本测试用例 - API 调用脚本
# 目标：8岁小女生 | 单词：beautiful → more beautiful
# 前置：后端运行在 localhost:3001，登录获取 token
# ─────────────────────────────────────────────────────────────────

BASE_URL="${API_BASE_URL:-http://localhost:3001}"

# ── 1. 登录获取 token（Mock user）───────────────────────────────
echo "🔐 获取访问令牌..."
TOKEN=$(curl -s -X POST "$BASE_URL/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"test_user","password":"test123"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))" 2>/dev/null)

if [ -z "$TOKEN" ]; then
  echo "⚠️  Token 获取失败，尝试 anonymous 模式..."
  AUTH_HEADER=""
else
  AUTH_HEADER="Authorization: Bearer $TOKEN"
fi

# ── 2. 生成绘本 ────────────────────────────────────────────────
echo "🎨 生成比较级绘本 beautiful..."

RESPONSE=$(curl -s -X POST "$BASE_URL/api/v1/picturebook/generate" \
  -H "Content-Type: application/json" \
  ${AUTH_HEADER:+"$AUTH_HEADER"} \
  -d '{
    "wordId": "word_beautiful_001",
    "word": "beautiful",
    "explanation": "One day, a cute girl named Lily went to a beautiful garden. She saw many pretty flowers. \"This flower is beautiful!\" said Lily. Then she saw a bigger red rose. \"Oh! This one is MORE BEAUTIFUL than that one!\" \"Beautiful\" is an adjective. When we compare two things, we can say \"more beautiful\". That\'s the comparative form! Lily learned something new today!",
    "async": false
  }')

echo "📦 原始响应:"
echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"

# ── 3. 提取 bookId ──────────────────────────────────────────────
BOOK_ID=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('bookId','') or d.get('jobId',''))" 2>/dev/null)

if [ -n "$BOOK_ID" ]; then
  echo ""
  echo "✅ 绘本生成成功！"
  echo "   Book ID: $BOOK_ID"
  echo "   访问绘本: GET $BASE_URL/api/v1/picturebook/$BOOK_ID"
  echo "   访问帧:   GET $BASE_URL/api/v1/picturebook/$BOOK_ID/frames"
  echo "   访问音频: GET $BASE_URL/api/v1/picturebook/$BOOK_ID/audio"

  # ── 4. 拉取绘本详情 ──────────────────────────────────────────
  echo ""
  echo "📖 拉取绘本详情..."
  DETAIL=$(curl -s "$BASE_URL/api/v1/picturebook/$BOOK_ID" \
    -H "Content-Type: application/json" \
    ${AUTH_HEADER:+"$AUTH_HEADER"})

  echo "$DETAIL" | python3 -m json.tool 2>/dev/null | head -60
else
  echo "❌ 绘本生成失败，请检查后端是否运行"
  echo "   启动后端: cd backend && npm install && node src/index.js"
fi
