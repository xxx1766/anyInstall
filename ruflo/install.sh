
#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# ==========================================
# Terminal Colors Setup
# ==========================================
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}====================================================${NC}"
echo -e "${GREEN}    Ruflo & Claude Code 官方一键安装脚本 (加强版)    ${NC}"
echo -e "${BLUE}====================================================${NC}"
echo ""

# ==========================================
# Step 1: Pre-flight Checks
# ==========================================
echo -e "${YELLOW}[1/3] 环境预检...${NC}"

if ! command -v curl &> /dev/null; then
    echo -e "${RED}错误: 未检测到 curl，请先安装 curl。${NC}"
    exit 1
fi

if ! command -v claude &> /dev/null; then
    echo -e "${YELLOW}警告: 未检测到全局的 Claude Code (claude)。${NC}"
    echo -e "如果没有安装，挂载 MCP 的步骤将会失败。"
    echo -e "你可以按 ${GREEN}Enter${NC} 强制继续，或按 ${RED}Ctrl+C${NC} 退出并先运行 npm install -g @anthropic-ai/claude-code"
    read -r
else
    echo -e "✅ Claude Code 已就绪。"
fi

echo ""

# ==========================================
# Step 2: Execute Official Installation
# ==========================================
echo -e "${YELLOW}[2/3] 调用 Ruflo 官方脚本执行全量安装 (--full)...${NC}"
echo -e "💡 包含任务: 全局安装 ➜ 初始化项目 ➜ 挂载 Claude MCP ➜ 运行自检 (Doctor)\n"

# 此处直接调用官方脚本，并传入 --full 参数 (约 340MB, 包含向量搜索模型)
# 如果你网速很慢想极速安装，可以把后面的 '--full' 改成 '--global --minimal --setup-mcp'
curl -fsSL https://cdn.jsdelivr.net/gh/ruvnet/ruflo@main/scripts/install.sh | bash -s -- --full

echo ""

# ==========================================
# Step 3: Initialize Ruflo & Start Daemons
# ==========================================
echo -e "${YELLOW}[3/4] 初始化 Ruflo 运行环境及后台服务 (记忆库、Swarm)...${NC}"
echo -e "正在生成 .claude 和相关配置，并启动守护进程..."

# 使用修正后的 ruflo 命令代替有 bug 的 claude-flow
ruflo init --start-all

echo -e "✅ 目录初始化及后台服务启动完成。\n"

# ==========================================
# Step 4: Add to Claude MCP
# ==========================================
echo -e "${YELLOW}[4/4] 将 Ruflo 挂载为 Claude Code MCP 服务器...${NC}"

# 执行核心 MCP 绑定指令
claude mcp add ruflo -- ruflo mcp start

echo -e "✅ MCP 服务添加成功。\n"

# ==========================================
# Finish & Verification
# ==========================================
echo -e "${BLUE}====================================================${NC}"
echo -e "${GREEN}🎉 安装与集成全部完成！${NC}"
echo -e "${BLUE}====================================================${NC}"
echo -e "当前目录已成功配置为 Ruflo 智能体工作区。"
echo ""
echo -e "你可以通过以下命令验证状态："
echo -e "  1. 运行 ${YELLOW}ruflo doctor${NC} 检查后台服务与智能体健康状态"
echo -e "  2. 运行 ${YELLOW}claude mcp list${NC} 确认 'ruflo' 已在运行列表中"
echo ""
echo -e "🚀 接下来怎么做？"
echo -e "直接输入 ${GREEN}claude${NC} 开启对话，并尝试说："
echo -e "${YELLOW}\"帮我调用 coder 智能体写一段 Python 代码，并存入你的 memory 中。\"${NC}"
