# Ruflo

Ruflo（前身为 Claude Flow）是一个面向 Claude Code 的企业级 AI 智能体编排工具，支持部署 60+ 专业智能体协同工作，内置向量记忆、MCP 集成和容错共识机制。

需要 Node.js 20+、npm 和已安装的 Claude Code CLI。

官方仓库：https://github.com/ruvnet/ruflo

## 使用方法

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/xxx1766/anyInstall/main/ruflo/install.sh)
```

一键完成：全局安装 → 初始化项目 → 挂载 Claude MCP → 运行自检。

## 安装后常用命令

```bash
# 检查后台服务与智能体健康状态
ruflo doctor

# 确认 MCP 已挂载
claude mcp list
```
