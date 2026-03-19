# Cross-Review Prompt Template

Use this template for both cc-review (reviewing Codex output) and codex-review (reviewing CC output).

## 调用命令格式

```bash
claude --permission-mode bypassPermissions --no-session-persistence --print 'PROMPT'
```

---

```
## Review Task
Review the following code changes and provide structured feedback.

## Diff
[Paste git diff output or describe the commits to review]

## Task Context
[What was the original task? What was the expected outcome?]

## Review Checklist
Rate each finding as one of:
- **Critical**: Security vulnerability, data loss risk, crash-causing bug → MUST fix
- **High**: Logic error, missing edge case, performance issue → MUST fix
- **Low**: Code style, naming, minor improvement → record but don't block
- **Suggestion**: Optional enhancement → record but don't block

## Output Format
{
  "verdict": "pass" | "fail",
  "critical": [],
  "high": [],
  "low": [],
  "suggestions": [],
  "summary": "One paragraph overall assessment"
}

## Rules
- Verdict is "fail" if any Critical or High issues exist
- Verdict is "pass" if only Low and Suggestion issues exist
- Be specific: include file path, line number, and what's wrong
- Suggest concrete fixes, not vague concerns
- Don't flag style issues as High
- Don't flag "consider adding tests" as High unless the change is clearly risky
```
