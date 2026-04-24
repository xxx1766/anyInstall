#!/usr/bin/env bash
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}====================================================${NC}"
echo -e "${GREEN}          Go 语言一键安装脚本                       ${NC}"
echo -e "${BLUE}====================================================${NC}"
echo ""

# 检测系统架构
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    armv6l) ARCH="armv6l" ;;
    i386|i686) ARCH="386" ;;
    *)
        echo -e "${RED}不支持的架构: $ARCH${NC}"
        exit 1
        ;;
esac

# 获取最新版本号
echo -e "${YELLOW}正在获取 Go 最新版本信息...${NC}"
LATEST=$(curl -fsSL "https://go.dev/VERSION?m=text" | head -1)
LATEST_VERSION="${LATEST#go}"

echo ""
echo -e "检测到最新版本: ${GREEN}${LATEST_VERSION}${NC}"
echo -e "请输入要安装的版本号（直接回车安装最新版 ${LATEST_VERSION}）："
read -r INPUT_VERSION < /dev/tty

if [ -z "$INPUT_VERSION" ]; then
    VERSION="$LATEST_VERSION"
else
    VERSION="$INPUT_VERSION"
fi

echo ""
echo -e "${YELLOW}准备安装 Go ${VERSION} (${OS}/${ARCH})...${NC}"

TARBALL="go${VERSION}.${OS}-${ARCH}.tar.gz"
DOWNLOAD_URL="https://go.dev/dl/${TARBALL}"

# 下载
echo -e "${YELLOW}下载中: ${DOWNLOAD_URL}${NC}"
curl -fsSL -o "/tmp/${TARBALL}" "$DOWNLOAD_URL" || {
    echo -e "${RED}下载失败，请检查版本号是否正确: ${VERSION}${NC}"
    exit 1
}

# 安装
echo -e "${YELLOW}安装中...${NC}"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "/tmp/${TARBALL}"
rm -f "/tmp/${TARBALL}"

# 配置 PATH
SHELL_RC=""
if [ -f "$HOME/.zshrc" ]; then
    SHELL_RC="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
    SHELL_RC="$HOME/.bashrc"
elif [ -f "$HOME/.profile" ]; then
    SHELL_RC="$HOME/.profile"
fi

GO_PATH_LINE='export PATH=$PATH:/usr/local/go/bin'
if [ -n "$SHELL_RC" ] && ! grep -q '/usr/local/go/bin' "$SHELL_RC"; then
    echo "$GO_PATH_LINE" >> "$SHELL_RC"
    echo -e "${GREEN}已将 Go 路径写入 ${SHELL_RC}${NC}"
fi

export PATH=$PATH:/usr/local/go/bin

echo ""
echo -e "${BLUE}====================================================${NC}"
echo -e "${GREEN}🎉 Go ${VERSION} 安装完成！${NC}"
echo -e "${BLUE}====================================================${NC}"
echo ""
/usr/local/go/bin/go version
echo ""
echo -e "重新打开终端或运行以下命令使环境变量生效："
echo -e "  ${YELLOW}source ${SHELL_RC:-~/.bashrc}${NC}"
