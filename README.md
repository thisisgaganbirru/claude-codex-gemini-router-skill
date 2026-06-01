# Claude Codex Integration

Enables Claude Code to intelligently route tasks to Codex subprocess based on complexity tier, with rollback safety, metrics tracking, and GitHub integration.

## Quick Start

```powershell
.\scripts\Install-Codex.ps1
```

## How It Works

**Tier-Based Routing:**

| Tier | Task Type | Route | Examples |
|------|-----------|-------|----------|
| **LOW** | Single file, isolated fix | Claude Code direct | "Fix login bug", "Add validation" |
| **MEDIUM** | 3-5 files, coordinated changes | Claude Code + subagents | "Implement JWT auth", "Build dashboard" |
| **HIGH** | 5+ files, architectural changes | **Codex subprocess** | "Refactor auth module", "Migrate to GraphQL" |
| **CRITICAL** | Full system redesign | Codex + manual review | "Complete rewrite", "Ground-up redesign" |

**Detection Process:**
1. Analyze task keywords (refactor, redesign, migrate, etc.)
2. Estimate file impact (git scope analysis)
3. Determine tier with confidence score
4. Suggest routing if HIGH or CRITICAL

## What You Get

✅ Intelligent complexity detection (LOW/MEDIUM/HIGH/CRITICAL tiers)  
✅ Automatic routing to Codex for heavy tasks  
✅ Git snapshots before execution (rollback safety)  
✅ Execution metrics & success tracking  
✅ GitHub PR creation from results  
✅ Safety constraints (forbidden operations blocked)  
✅ Approval workflow (on-request mode)  

## Files & Scripts

| Script | Purpose |
|--------|---------|
| `Analyze-TaskComplexity.ps1` | Analyze task & determine tier |
| `Route-ToCodex.ps1` | Main routing logic + Codex execution |
| `Restore-Snapshot.ps1` | Rollback git changes if needed |
| `View-Metrics.ps1` | Dashboard of execution history |
| `Create-PR.ps1` | Create GitHub PR from results |
| `Install-Codex.ps1` | Setup + configuration |
| `Validate-Codex.ps1` | Verify installation |

## Installation

```powershell
.\scripts\Install-Codex.ps1
```

This will:
1. Backup existing `~/.claude/` configs
2. Install hook scripts to `~/.claude/hooks/`
3. Configure Codex subprocess settings
4. Validate Codex CLI availability
5. Test complexity routing

## Usage Examples

### Example 1: Simple Task (Direct)
```
You: "Fix the login form validation"

Claude Code:
[Analyzes: LOW tier]
[Routes: Claude Code direct]
[Executes: Immediately]
```

### Example 2: Complex Task (Codex)
```
You: "Refactor authentication module for async/await"

Claude Code:
[Analyzes: HIGH tier, 95% confidence]
[Creates: Git snapshot for rollback]
[Routes: Codex subprocess]
[Executes: wsl -d Ubuntu -- codex ...]
[Logs: Metrics to ./mem/]
[Offers: Create GitHub PR?]
```

### Example 3: View Metrics
```powershell
.\scripts\View-Metrics.ps1

Output:
  Total Tasks: 12
  LOW: 7 (58%)
  MEDIUM: 3 (25%)
  HIGH: 2 (17%)
  Success Rate: 100% (2/2)
```

### Example 4: Rollback if Needed
```powershell
.\scripts\Restore-Snapshot.ps1

Available Codex snapshots:
  [0] stash@{0}: codex-snapshot-20260601-141530
  [1] stash@{1}: codex-snapshot-20260601-140145

(Select one to restore)
```

## Configuration

**Complexity Tiers** → `config/complexity-tiers.json`
- Define keywords for each tier
- Customize file count thresholds

**Keywords** → `config/complexity-keywords.txt`
- Add/remove tier keywords
- Case-insensitive matching

**Forbidden Operations** → `config/forbidden-operations.txt`
- Safety patterns (rm -rf, DROP TABLE, etc.)
- Applied before any execution

## Safety Features

1. **PreToolUse Hook** - Blocks dangerous commands before execution
2. **Git Snapshots** - Auto-snapshot before Codex runs (easy rollback)
3. **Approval Workflow** - You must approve each Codex execution
4. **Sandbox Constraints** - Codex can only read/write workspace files
5. **Execution Logging** - All Codex work recorded in `./mem/`

## See Also

- `SKILL.md` — Complete technical documentation
- `references/task-routing-guide.md` — Detailed routing explanation
- `references/approval-policies.md` — Approval workflow rules
