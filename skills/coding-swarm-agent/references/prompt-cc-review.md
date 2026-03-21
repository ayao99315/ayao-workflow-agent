# Cross-Review Prompt Template

Use this template for both cc-review (reviewing Codex output) and codex-review (reviewing CC output).

## 调用命令格式

```bash
PROMPT_FILE=/tmp/cc-review-prompt.txt

cat > "$PROMPT_FILE" << 'PROMPT'
[完整 review prompt]
PROMPT

scripts/dispatch.sh cc-review T005 --prompt-file "$PROMPT_FILE" \
  claude --permission-mode bypassPermissions --no-session-persistence \
  --print --output-format json
```

> 推荐统一用 `dispatch.sh --prompt-file`，不要把整段 prompt 直接塞进 shell 引号里。

---

```
## Review Task
Review the following code changes and provide structured feedback.

## Diff
[Paste git diff output or describe the commits to review]

## Task Context
[What was the original task? What was the expected outcome?]

## 认知模式（审查时应用）

1. **Root Cause First**：不要只指出表面问题，追问：这个 bug/缺陷的根本原因是什么？同类问题还有哪些？
2. **Pattern Recognition**：同类问题往往成群出现。发现一个问题后，主动搜索是否有其他同类问题。
3. **Fix vs Warn**：能直接修的小问题（typo、简单 bug、明显的遗漏）直接修并 commit。需要讨论的架构问题才写 WARN/CRITICAL。
4. **Completeness Check**：检查任务是否做完整了——edge case 是否处理、错误路径是否覆盖、相关测试是否存在。

## Completeness Principle（完整性原则）

Review 时不只检查"有没有 bug"，也检查"是否做完整了"：

- 任务要求的功能是否全部实现？
- 错误路径是否有处理（not just happy path）？
- 能看到的 edge case 是否已处理，还是留了 TODO？
- 新增代码是否有对应的测试？（若项目有测试框架）
- 修改是否更新了相关文档/注释？

**结论格式：** 如果发现 completeness 问题，在 review 结论中用 `INCOMPLETE: ` 前缀标注。

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
