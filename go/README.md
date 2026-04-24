# Go 安装脚本

一键安装 Go 语言，支持选择版本（适用于 Linux）。

## 使用方法

```bash
curl -fsSL https://raw.githubusercontent.com/xxx1766/anyInstall/main/go/install.sh | bash
```

或者手动下载执行：

```bash
curl -fsSL https://raw.githubusercontent.com/xxx1766/anyInstall/main/go/install.sh -o install.sh
chmod +x install.sh
./install.sh
```

## 功能

- 自动检测系统架构（amd64 / arm64 / armv6l / 386）
- 自动获取最新版本号
- 支持手动输入指定版本（如 `1.22.3`）
- 自动写入 `PATH` 到 shell 配置文件（`.zshrc` / `.bashrc` / `.profile`）
