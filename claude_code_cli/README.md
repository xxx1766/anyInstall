# Claude Code CLI 一键安装

安装内容：
- 通过 npm 全局安装 `@anthropic-ai/claude-code`
- 交互式配置 `ANTHROPIC_BASE_URL` 和 `ANTHROPIC_API_KEY`（自动写入 `.bashrc` 或 `.zshrc`）
- 写入 `~/.claude.json` 跳过 Onboarding 登录验证

需要 Node.js 18+ 和 npm，脚本不需要 root 权限。

## 使用方法

```bash
sh <(curl -fsSL https://raw.githubusercontent.com/xxx1766/anyInstall/main/claude_code_cli/install.sh)
```

> 安装完成后执行 `source ~/.bashrc`（或 `~/.zshrc`），然后运行 `claude` 启动。
