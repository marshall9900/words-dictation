#!/bin/bash
# 安全设置 API Key 脚本
# 用法: ./set-api-key.sh MINIMAX_API_KEY "your_key_here"
# 或者交互式: ./set-api-key.sh (无参数)

set -e

ENV_FILE="/opt/words-dictation/backend/.env"

if [ -f "$ENV_FILE" ]; then
    chmod 600 "$ENV_FILE"
fi

if [ $# -ge 2 ]; then
    KEY_NAME=$1
    KEY_VALUE=$2
elif [ $# -eq 1 ]; then
    KEY_NAME=$1
    echo -n "请输入 $1 的值: "
    read -s KEY_VALUE
    echo
else
    echo "用法:"
    echo "  ./set-api-key.sh MINIMAX_API_KEY \"your_key_here\""
    echo "  ./set-api-key.sh MINIMAX_API_KEY  (交互式输入)"
    exit 1
fi

# 移除旧值（如果存在）
grep -v "^${KEY_NAME}=" "$ENV_FILE" > "${ENV_FILE}.tmp" 2>/dev/null || touch "${ENV_FILE}.tmp"

# 添加新值
echo "${KEY_NAME}=${KEY_VALUE}" >> "${ENV_FILE}.tmp"
mv "${ENV_FILE}.tmp" "$ENV_FILE"
chmod 600 "$ENV_FILE"

echo "✅ $KEY_NAME 已设置成功"
