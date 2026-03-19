# Session: 2026-03-18 03:43:06 UTC

- **Session Key**: agent:main:telegram:direct:8449051145
- **Session ID**: 585a02dd-97ce-4758-bb7e-1976444d9224
- **Source**: telegram

## Conversation Summary

assistant: 现在把 `on-complete.sh` 接入 agent-manager：
assistant: 还需要一个小的 `update-agent-status.sh` 辅助脚本：
assistant: 也要在 `dispatch.sh` 里标 agent 为 busy：
assistant: 加可执行权限，做语法检查：
assistant: 内存 6.2GB 空闲，状态 OK。最后更新 SKILL.md 的 References 和 HEARTBEAT.md：
assistant: 更新 HEARTBEAT.md 加 health-check 巡检：
assistant: 搞定！总结一下今天加的东西：

**新增 6 个脚本：**

| 脚本 | 触发时机 | 作用 |
|------|---------|------|
| `check-memory.sh` | spawn 前自动调用 | 检查 RAM，`ok/warn/block` 三级，当前 6.2GB 空闲 ✅ |
| `spawn-agent.sh` | agent-manager 调用 | 按命名规则开新 tmux session + 注册 pool |
| `agent-manager.sh` | 每次任务完成自动触发 | 按任务队列决定扩容/缩容/cleanup |
| `update-agent-status.sh` | dispatch/on-complete 调用 | 维护 agent-pool.json 的 idle/busy/dead 状态 |
| `health-check.sh` | heartbeat 巡检 | 检测卡住(>15min)/已死/静默退出的 agent |
| `cleanup-agents.sh` | 全部任务完成时自动触发 | 关闭 codex-1~4 + cc-frontend-1~2，保留 cc-plan/review |

**命名规则写死在 `spawn-agent.sh` 和 `agent-pool.json` 里：**
- 动态后端：`codex-1` ~ `codex-4`（max 4）
- 动态前端：`cc-frontend-1` ~ `cc-frontend-2`（max 2）
- 固定不动：`cc-plan`、`cc-review`、`codex-review`
user: Conversation info (untrusted metadata):
```json
{
  "message_id": "880",
  "sender_id": "8449051145",
  "sender": "阿尧Plus",
  "timestamp": "Wed 2026-03-18 11:27 GMT+8"
}
```

Sender (untrusted metadata):
```json
{
  "label": "阿尧Plus (8449051145)",
  "id": "8449051145",
  "name": "阿尧Plus",
  "username": "plus_jin"
}
```

OK OK，很靠谱，同步一下文档吧。把这些改动放到 Playbook 文档里。
assistant: 好，现在精准更新几个关键位置：
assistant: 更新 Swarm 配置文件一节，加入 agent-pool.json：
assistant: 更新演进对比表，加 v4：
assistant: 最后更新配置文件体系（§14）、实战改进列表（§18）和版本号：
assistant: 加入 agent-pool.json 到配置文件体系（§14.1 层2）：
assistant: 最后更新版本号和有效做法列表：
assistant: 搞定，Playbook 更新到 **v2.3**。今天加的内容全部同步进去：

**§4.1** — Agent 命名规则固化（固定 vs 动态分开说明）

**§4.4** — 扩容规则从"手动配置"改为"agent-manager 自动管理"，含内存三级阈值

**§9.1** — 架构图升级到 v4，新增 ESLint 门禁 + agent-manager + token 追踪流

**§9.2** — 脚本表拆成"核心流水线 / 动态 Agent 管理 / 兜底"三组，共 12 个脚本

**§9.7** — 新增 agent-pool.json 配置文件说明及数据结构

**§9.8** — 演进对比表升级到 v4，新增 Agent 管理/内存保护/Session 清理/健康巡检四行

**§14.1** — scripts 目录列出所有 12 个脚本；swarm/ 加入 agent-pool.json

**§18.1** — 有效做法加入动态管理和健康巡检两条
