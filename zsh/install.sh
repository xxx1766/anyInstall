#!/bin/bash

# ==========================================================
# Zsh & Oh My Zsh 一键自动化安装脚本 (适用于 Debian/Ubuntu)
# 包含插件: git, z, zsh-autosuggestions, zsh-syntax-highlighting
# ==========================================================

echo "🚀 [1/5] 正在更新软件源并安装基础依赖 (zsh, git, curl)..."
apt-get update -y
apt-get install -y zsh git curl

echo "🧹 [2/5] 正在清理旧的 Oh My Zsh 遗留文件（如果有）..."
rm -rf ~/.oh-my-zsh
rm -f ~/.zshrc

echo "⬇️  [3/5] 正在自动化安装 Oh My Zsh..."
# 使用 RUNZSH=no 阻止安装完成后自动进入 zsh 导致脚本中断
# 使用 CHSH=yes 尝试自动更改默认 Shell
env RUNZSH=no CHSH=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

echo "🔌 [4/5] 正在下载第三方插件..."
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"

# 1. zsh-autosuggestions (历史命令自动建议)
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
  git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM}/plugins/zsh-autosuggestions
fi

# 2. zsh-syntax-highlighting (命令语法高亮)
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting
fi

echo "⚙️  [5/5] 正在配置 ~/.zshrc..."
# 替换默认的 plugins=(git) 为你需要的四个插件
sed -i 's/^plugins=(.*/plugins=(git z zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc

# 确保 zsh 被设置为当前用户的默认 shell
chsh -s $(which zsh)

echo "=========================================================="
echo "✅ 安装与配置彻底完成！"
echo "👉 请执行命令 \`zsh\` 立即体验，或者断开 SSH 重新连接服务器。"
echo "=========================================================="
