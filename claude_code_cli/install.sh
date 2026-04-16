
#!/bin/sh

echo "🚀 开始安装与配置 Claude Code CLI (基于 NPM)..."

# ==========================================
# 尝试加载 Node.js 环境管理器配置
# ==========================================
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

[ -s "$HOME/.volta/env" ] && . "$HOME/.volta/env"

if command -v fnm > /dev/null 2>&1; then 
    eval "$(fnm env)"
fi

# ==========================================
# 检查 npm 是否安装
# ==========================================
if ! command -v npm > /dev/null 2>&1; then
    echo "❌ 错误: 未检测到 npm 命令。"
    echo "👉 诊断建议："
    echo "   1. 请确认是否已安装 Node.js。"
    echo "   2. 如果您使用了 'sudo' 执行此脚本，请去掉 sudo 重新运行。"
    exit 1
fi

# 检查 Node.js 版本
NODE_VERSION=$(node -v 2>/dev/null | grep -oE '[0-9]+' | head -n 1)
if [ -n "$NODE_VERSION" ] && [ "$NODE_VERSION" -lt 18 ]; then
    echo "⚠️ 警告: 您的 Node.js 主版本为 v$NODE_VERSION，Claude Code 官方推荐使用 Node.js 18+。"
    echo "         如果后续运行报错，请考虑升级 Node.js。"
    echo ""
fi

# 2. 安装 Claude Code
echo "📦 [1/4] 正在通过 npm 全局安装 @anthropic-ai/claude-code..."
npm install -g @anthropic-ai/claude-code

# 3. 交互式获取 URL 和 API Key
echo ""
echo "⚙️  [2/4] 配置环境变量"

# 使用跨平台兼容的 printf + read 代替 read -p
printf "🔗 请输入 ANTHROPIC_BASE_URL (直接回车默认使用 https://code.ai.cs.ac.cn): "
read INPUT_URL
BASE_URL=${INPUT_URL:-https://code.ai.cs.ac.cn}

while true; do
    printf "🔑 请输入您的 ANTHROPIC_API_KEY: "
    read API_KEY
    if [ -n "$API_KEY" ]; then
        break
    else
        echo "⚠️ API Key 不能为空，请重新输入！"
    fi
done

# ==========================================
# 动态判断并写入正确的 Shell 配置文件 (纯 POSIX 写法)
# ==========================================
SHELL_CONFIG="$HOME/.bashrc"

# 使用 grep 检查环境变量 $SHELL 中是否包含 zsh
if echo "$SHELL" | grep -q "zsh"; then
    SHELL_CONFIG="$HOME/.zshrc"
fi

echo "📝 正在将环境变量写入 $SHELL_CONFIG ..."

# 安全清理旧配置
if [ -f "$SHELL_CONFIG" ]; then
    grep -v "export ANTHROPIC_BASE_URL=" "$SHELL_CONFIG" | grep -v "export ANTHROPIC_API_KEY=" > "${SHELL_CONFIG}.tmp"
    mv "${SHELL_CONFIG}.tmp" "$SHELL_CONFIG"
fi

# 写入新配置
echo "export ANTHROPIC_BASE_URL=\"$BASE_URL\"" >> "$SHELL_CONFIG"
echo "export ANTHROPIC_API_KEY=\"$API_KEY\"" >> "$SHELL_CONFIG"

# 4. 跳过登录配置
echo "📝 [3/4] 配置 ~/.claude.json 以跳过 Onboarding 登录验证..."
CLAUDE_JSON_PATH="$HOME/.claude.json"

cat <<EOF > "$CLAUDE_JSON_PATH"
{
  "hasCompletedOnboarding": true
}
EOF

# 5. 完成提示
echo ""
echo "=========================================================="
echo "✅ 安装与配置彻底完成！"
echo "👉 1. 请执行以下命令让环境变量立即生效："
echo "      source $SHELL_CONFIG"
echo "👉 2. 然后运行以下命令启动 Claude Code："
echo "      claude"
echo "=========================================================="
