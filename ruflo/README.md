# Ruflo

Ruflo（前身为 Claude Flow）是一个面向 Claude Code 的企业级 AI 智能体编排工具，支持部署 60+ 专业智能体协同工作，内置向量记忆、MCP 集成和容错共识机制。

需要 Node.js 20+ 和 npm。

官方仓库：https://github.com/ruvnet/ruflo

## 安装方式

### 方式一：npx 按需使用（无需安装）

```bash
npx ruflo@latest init --wizard
```

### 方式二：全局安装

```bash
curl -fsSL https://cdn.jsdelivr.net/gh/ruvnet/claude-flow@main/scripts/install.sh | bash -s -- --global
```

### 方式三：完整安装（全局 + MCP + 初始化）

```bash
curl -fsSL https://cdn.jsdelivr.net/gh/ruvnet/claude-flow@main/scripts/install.sh | bash -s -- --full
```

## 安装后常用命令

```bash
# 系统诊断
ruflo doctor

# 注册为 Claude Code MCP 服务
claude mcp add ruflo -- ruflo mcp start
```
