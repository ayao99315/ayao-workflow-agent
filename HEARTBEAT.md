# HEARTBEAT.md

## Agent Swarm Check (fallback — primary is event-driven via git hooks)
If `swarm/active-tasks.json` has tasks with status "running" or "reviewing":
1. Read `/tmp/agent-swarm-signals.jsonl` for unprocessed signals (check timestamps vs last processed)
2. For any completed task signal: verify commit scope → dispatch cross-review → update task status
3. For any completed review signal: check pass/fail → mark done or return for fixes
4. Auto-unblock and dispatch next pending tasks
5. Run health check: `~/.openclaw/workspace/skills/coding-swarm-agent/scripts/health-check.sh`
   - Detects stuck agents (>15min no update), dead tmux sessions, silent exits
   - Auto-notifies via Telegram if issues found

If no active swarm tasks, skip this check.
