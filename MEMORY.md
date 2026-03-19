# MEMORY.md — 小明的长期记忆

## 关于爸爸
- 叫阿尧，Telegram: @plus_jin, chat_id: 8449051145
- 喜欢中文交流，希望助手风格调皮一点
- 时区 Asia/Shanghai

## 当前项目
- **PolyGo** — Polymarket NBA 自动交易系统
  - 路径: /Users/tongyaojin/code/PolyGo
  - GitHub: github.com/ayao99315/PolyGo
  - 技术栈: TypeScript, Next.js (web-admin), Node.js daemon, PostgreSQL (pg), Recharts
  - 注意: 项目用 pg 不是 SQLite！prompt 别写错

## Agent Swarm 经验
- 2026-03-17 首次实战：18 任务 2 小时全部完成
- 推荐配置：6 agent（cc-plan + codex-1 + codex-2 + cc-frontend + cc-review + codex-review）
- 事件驱动 > cron 轮询（git hook + on-complete.sh）
- Review 分级：full(资金相关) / scan(集成) / skip(UI/脚本)
- 完整文档: docs/agent-swarm-playbook.md v2.0
- Skill: skills/coding-swarm-agent/SKILL.md

## 重要配置
- swarm/notify-target: 8449051145（Telegram 通知目标）
- swarm/project-dir: /Users/tongyaojin/code/PolyGo
- PolyGo 已安装 post-commit hook（事件驱动自动化）

## 教训（已修复）
- codex 不 commit → dispatch.sh force-commit 兜底
- system event target-none → 改用 /hooks/agent webhook
- cc-frontend 超额完成 → prompt 加 ⚠️ "只做当前任务"
- prompt 技术栈描述不准 → 铁律：引用实际代码文件
- 状态跟踪滞后 → update-task-status.sh 脚本自动更新
- 无编译检查 → post-commit hook tsc 门禁

## 关键配置（v2.1 新增）
- OpenClaw hooks.enabled: true, hooks.allowRequestSessionKey: true
- swarm/hook-token: webhook 认证 token
- post-commit hook 含 tsc 编译门禁（只查改动文件新错误）
- /hooks/agent 用 sonnet 模型自动调度（sessionKey: hook:swarm:dispatch）
