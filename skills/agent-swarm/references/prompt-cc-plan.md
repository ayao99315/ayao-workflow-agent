# CC Plan Prompt Template

Use this template when asking cc-plan to decompose a requirement into atomic tasks.

## 调用命令格式

```bash
claude --permission-mode bypassPermissions --no-session-persistence --print 'PROMPT'
```

---

```
## Project
[Project name] — [one-line description]
Working directory: [path]

## Requirement
[Full description of what the user wants]

## Current State
[Relevant context: what exists, what's missing, recent changes]

## Output Format
Produce a JSON array of tasks. Each task must include:

[
  {
    "id": "T001",
    "name": "Short task name",
    "domain": "backend" | "frontend",
    "scope": {
      "create": ["file paths"],
      "modify": ["file paths"],
      "delete": ["file paths"]
    },
    "description": "What this task does in 1-2 sentences",
    "technical_notes": "Key technical details the coding agent needs",
    "depends_on": ["T00X"],
    "estimated_minutes": 30
  }
]

## Rules
- Each task = one atomic commit
- Task scope must not overlap with other tasks' file paths
- Frontend tasks (pages, components, UI) marked domain: "frontend"
- Backend tasks (API, logic, DB, infra) marked domain: "backend"
- Shared type files: assign to the task that creates/changes the type, other tasks depend on it
- Order tasks by dependency chain
- Keep tasks small enough for one commit but large enough to be meaningful
```
