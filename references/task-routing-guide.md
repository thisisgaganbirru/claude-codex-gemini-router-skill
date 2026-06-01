# Task Routing Guide

How tasks are routed between Claude Code and Codex.

## Effort Scoring System

Every task gets an effort score: **5-20**

### Score Breakdown

| Range | Action | AI | Example |
|-------|--------|----|-----------| 
| 5-10 | Direct | Claude Code | "Fix the login bug" |
| 11-15 | Subagent | Claude Code + agents | "Build JWT authentication" |
| 16+ | Codex | Codex subprocess | "Refactor the auth system" |

### How Scoring Works

Claude Code estimates effort based on:
1. **Task scope** — Single file? Multiple? System-wide?
2. **Complexity** — One change or many coordinated changes?
3. **Keywords** — Does it say "refactor" (high) or "fix" (low)?
4. **Dependencies** — Does it affect other systems?
5. **Testing** — How much testing is needed?

**Example scoring:**

```
"Fix the login bug"
  - Scope: Single file (low)
  - Complexity: One function (low)
  - Keywords: "fix" (low)
  - Effort: 7/10 → Claude Code direct
```

```
"Refactor the authentication module for async/await"
  - Scope: Multiple files (high)
  - Complexity: Many coordinated changes (high)
  - Keywords: "refactor" (high)
  - Dependencies: Affects payment, dashboard (high)
  - Testing: Extensive (high)
  - Effort: 19/10 → Route to Codex
```

## Keyword Detection

Certain keywords **trigger heavy-task detection**:

### High-Effort Keywords
- **refactor** — Rewrite existing code
- **redesign** — Rethink structure
- **rewrite** — Complete rewrite
- **migrate** — Move to new system
- **optimize** — Improve performance

When Claude Code sees these + effort score 16+, it suggests Codex routing.

### Medium-Effort Keywords
- implement, feature, build, add, enhance

### Low-Effort Keywords
- fix, debug, patch, adjust, modify

## Routing Decision Tree

```
[Task given to Claude Code]
         ↓
[Analyze effort: 5-20]
         ↓
  ┌─────┴──────┬─────────┐
  ↓            ↓         ↓
5-10        11-15      16+
  ↓            ↓         ↓
Direct      Subagent   Check
  ↓            ↓      Keywords
Execute      Execute      ↓
Return        ↓       ┌────┴────┐
           Return     ↓         ↓
                     Yes        No
                      ↓         ↓
                    Route      Execute
                  to Codex     Direct
                      ↓         ↓
                    Approve   Return
                      ↓
                   Execute
                      ↓
                    Return
```

## Step-by-Step: Routing to Codex

### 1. Give Claude Code a Complex Task

```
"Refactor the payment processing module for concurrent requests"
```

### 2. Claude Code Analyzes

```
[Analyzing...]
Task: "Refactor the payment processing module for concurrent requests"
Estimated effort: 18/10 (HEAVY)
Keywords detected: "refactor" (high-effort indicator)
Files likely affected: 5+ 
Testing impact: High (financial transactions)

✓ Recommendation: Route to Codex
```

### 3. You Approve or Decline

```
Route this to Codex? (y/n)
```

**If you say "Yes":**
- Claude Code creates Codex task
- Codex executes with workspace-write sandbox
- Safety checks apply (forbidden operations blocked)
- Result returned and logged

**If you say "No":**
- Claude Code handles it directly (slower)
- Or asks for more specific subtasks

### 4. Codex Executes

Codex runs with:
- Safety constraints (forbidden-operations blocked)
- Approval workflow (on-request mode)
- Workspace sandbox (read/write files only)

### 5. Result Logged

If memory system installed:
```markdown
### 14:30 - Refactor Payment Processing
- Task: Refactor payment module for concurrent requests
- Routed to: Codex
- Status: Completed
- Files touched: src/payment/processor.ts, src/payment/service.ts
- Time: 12 minutes
```

## When Codex Is Better

Codex is better when:

✅ **Complex refactoring** — Touching many files at once  
✅ **System redesign** — Architectural changes  
✅ **Large migrations** — Moving to new tech (REST → GraphQL, etc.)  
✅ **Performance optimization** — Requires rethinking design  
✅ **Infrastructure setup** — CI/CD, deployment, etc.  

## When Claude Code Is Better

Claude Code is better when:

✅ **Single-file changes** — Isolated fixes  
✅ **Bug fixes** — Targeted patches  
✅ **Small features** — Well-scoped additions  
✅ **One-off tasks** — Non-repeating work  

## Manual Routing (Advanced)

Force routing to Codex manually:

```powershell
wsl -d Ubuntu -- bash -ic "codex 'your task here' -a on-request -s workspace-write"
```

This bypasses automatic scoring and sends directly to Codex.

## Tuning Effort Scores

If you disagree with Claude Code's effort score:

1. **Too low** (gave score 8, you think it's 15):
   - Tell Claude Code: "This is actually more complex"
   - Provide more context
   - Claude Code recalculates

2. **Too high** (gave score 18, you think it's 12):
   - Tell Claude Code: "Actually this is simpler"
   - Clarify constraints
   - Claude Code recalculates

## Complexity Thresholds

Edit in `config/complexity-keywords.txt` to customize:
- Which keywords trigger high-effort
- Which phrases indicate medium-effort
- Custom detection patterns
