# Approval Policies

How Codex execution approval works.

## Current Policy: On-Request

```
Approval policy: "on-request"
```

**What it means:**
You must manually approve before Codex executes ANY task.

**Flow:**

```
[Task detected as heavy (16+)]
         ↓
[Suggest routing to Codex]
         ↓
["Route to Codex? (y/n)"]
         ↓
  ┌──────┴──────┐
  ↓             ↓
 Yes            No
  ↓             ↓
Execute       Use Claude
  ↓            Code
Return        Return
```

## Security Operations Requiring Approval

Even within approved Codex tasks, certain operations require EXTRA approval:

- **Database schema changes** — ALTER TABLE, DROP COLUMN, etc.
- **Breaking API changes** — Changing endpoints, response format
- **Git operations** — Force push, reset, etc.
- **File deletions** — rm, unlink, delete
- **Database migrations** — New schemas, data movement
- **Environment variables** — Adding/changing config
- **Security-related changes** — Auth, encryption, credentials

These are defined in `settings.json.template`:
```json
"require_manual_approval": [
  "database schema changes",
  "breaking API changes",
  "git operations",
  "file deletions",
  ...
]
```

## Policy Options (Future)

Could be changed to:

### Option 1: "full-auto"
No approval needed. Codex executes automatically.

**Risk:** Could break things without review  
**Use:** Development mode, trusted environments  

### Option 2: "on-request"
Current policy. You approve each heavy task.

**Risk:** Slower (requires manual intervention)  
**Safety:** High (you review before execution)  

### Option 3: "sandbox-only"
Codex can execute anything in workspace, but no git/database operations.

**Risk:** File system only, no external changes  
**Safety:** Medium (prevents system damage)  

## Changing Approval Policy

To change from `on-request` to `full-auto`:

```json
"codex_subprocess": {
  "approval_policy": "full-auto"
}
```

**Risks:**
- Codex might make mistakes without review
- Breaking changes deploy automatically
- No chance to review before execution
- Hard to undo

**When safe:**
- Development only (not production)
- Trusted codebase
- Comprehensive test suite
- Monitoring in place

## Best Practices

1. **Keep `on-request` for critical systems**
   - Database (production)
   - Payments
   - Authentication
   - Anything customer-facing

2. **Use `full-auto` for safe areas**
   - Tests
   - Configuration
   - Documentation
   - Non-critical features

3. **Manual approval for**
   - Deployments
   - Schema changes
   - API changes
   - Security updates

4. **Override when needed**
   ```powershell
   # Force Codex to execute without asking
   codex 'task here' -a full-auto
   ```

## Audit Trail

All Codex approvals (or denials) are logged:

If memory system installed:
```markdown
### Approvals Log
- 14:30: Approved "Refactor payment module" → Completed
- 15:15: Declined "Drop old users table" → Safety blocked
- 16:00: Approved "Add OAuth2" → Completed
```

Manual check:
```powershell
grep -r "Codex" /mem/*.md
```

## When Approval Is Denied

```
"Route to Codex? (y/n)"
→ You type: "n"

Claude Code:
✓ Understood. Handling this in Claude Code instead.
  (May take longer or require more specific instructions)
```

Options:
1. Claude Code handles it directly (slower)
2. Break it into smaller subtasks
3. Do it manually outside Claude Code
4. Ask for more specific requirements (help Claude Code understand the scope)

## Overriding Approval

If you always approve certain task types:

```json
"auto_approve_patterns": [
  "add tests for *",
  "fix typos in *",
  "update documentation for *"
]
```

Then those patterns auto-route without asking.

**Use carefully** — this bypasses your review.

## Integration with Git Hooks

If your repo has pre-commit hooks:

**Before approval:** Git hook runs, may prevent commit if memory entries missing  
**After approval:** Codex executes, result committed  
**Logging:** Execution logged to `/mem/YYYYMMDD-session.md`

Example:
```markdown
### 14:30 - Refactor Payment Processing
- Task: Refactor for concurrent requests
- Routing: Approved → Codex
- Execution: Success (8 min)
- Files: src/payment/processor.ts, src/payment/service.ts
- Status: Ready to commit
```

Then you commit:
```powershell
git add .
git commit -m "refactor(payment): async/await support"
```

Pre-commit hook checks: Memory entry exists? ✓ Commit proceeds.
