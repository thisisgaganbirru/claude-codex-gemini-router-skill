---
date: 2025-06-01
task_slug: claude-codex-skill-launch
status: completed
tags: [skill-launch, github, codex-routing]
---

# Claude Codex Skill - Public Release

## The Ask
Transform the claude-codex-integration project into a publicly distributable Claude Code skill that users can install globally via `/install claude-codex-integration`. Create a GitHub repository for the skill.

## Changes Made

### Files Modified
1. **SKILL.md** — Rewritten with proper Claude Code skill frontmatter
   - Added: `name: claude-codex-integration`
   - Added: `installable: true`, `autoInstall: true`
   - Added: Installation instructions, usage examples, troubleshooting guide
   - Tier-based routing documentation (LOW/MEDIUM/HIGH/CRITICAL)

2. **Install-Codex.ps1** — Enhanced for global Claude Code integration
   - Added `Wire-HooksToSettings()` function to configure hooks in `~/.claude/settings.json`
   - Copies hook scripts to `~/.claude/hooks/`
   - Validates Codex CLI availability
   - Improved installation messaging

3. **Route-ToCodex.ps1** — Fixed reliability issues
   - Moved helper functions to top before main logic (function ordering)
   - Changed from string concatenation to safe argument array: `@($Task, '-a', 'on-request', '-s', 'workspace-write')`
   - Proper WSL invocation: `wsl -d Ubuntu -- codex @codex_args`
   - Fixed approval flow: prompts user unless `-AutoApprove` switch passed
   - Graceful git detection (doesn't fail if not in git repo)

4. **Analyze-TaskComplexity.ps1** — Enhanced detection algorithm
   - Implemented real `Get-FileDamageEstimate()` (was returning hardcoded 3)
   - Analyzes keywords (refactor +5, implement +3, etc.)
   - Checks actual directory presence (src, lib, components, etc.)
   - Analyzes git history for baseline estimates
   - Returns bounded value 0-20

5. **pre-tool-safety.ps1** — Updated to use config
   - Loads forbidden patterns from `config/hooks.json` instead of hardcoded list
   - Reads Claude Code hook JSON input from stdin
   - Returns proper exit codes and error JSON

6. **Config files cleaned**
   - Removed unused `codex_commands` block from hooks.json (dead code)
   - Removed unused `complexity_thresholds` from hooks.json
   - Removed duplicate fields from settings.json.template
   - Kept only actively-used configuration

### Files Deleted
- `Create-PR.ps1` (redundant; Claude Code handles PR creation natively)
- `complexity-keywords.txt` (duplicate of complexity-tiers.json)
- `forbidden-operations.txt` (duplicate of hooks.json)

### GitHub Repository Created
- **Repo:** https://github.com/thisisgaganbirru/claude-codex-skill
- **Visibility:** Public
- **Status:** Code pushed to main branch

## Decisions & Rationale

### Why WSL Ubuntu for Codex?
Codex runs in WSL Ubuntu as a local subprocess on user's machine, not in cloud. This keeps data private and allows offline operation.

### Why Tier-Based Routing?
Keyword + file impact analysis is fast and doesn't require ML models. Simple decision tree:
- **LOW** (1-2 files): Direct Claude Code
- **MEDIUM** (3-5 files): Claude Code + agents
- **HIGH** (5+ files): Codex subprocess
- **CRITICAL** (10+ files): Codex with review

### Why Safety Hooks?
Pre-execution validation prevents destructive operations (rm -rf, DROP TABLE, git reset --hard, etc.) from accidentally running via Codex.

### Why Git Snapshots?
Creates rollback point via `git stash` before Codex executes, allowing users to restore previous state if execution fails.

### Why Skill Format?
Makes it installable via `/install claude-codex-skill` command in Claude Code. Automatically configures hooks globally for all projects.

## Current Architecture

### Installation Flow (when user runs `/install claude-codex-skill`)
```
Claude Code reads SKILL.md
  ↓
Sees installable: true
  ↓
Runs Install-Codex.ps1
  ↓
Backs up existing ~/.claude/settings.json
  ↓
Copies hooks to ~/.claude/hooks/
  ↓
Wires PreToolUse hook in settings.json
  ↓
Validates Codex CLI available
  ↓
Installation complete
```

### Task Execution Flow
```
User: "Refactor authentication module"
  ↓
Claude Code analyzes task
  ↓
Analyze-TaskComplexity.ps1 → HIGH tier (95% confidence)
  ↓
Route-ToCodex.ps1 prompts: "Route to Codex? (y/n)"
  ↓
User approves
  ↓
Create git snapshot: codex-snapshot-20260601-153045
  ↓
Invoke: wsl -d Ubuntu -- codex "Refactor authentication module" -a on-request -s workspace-write
  ↓
Codex executes in isolated WSL process
  ↓
Results returned to Claude Code
  ↓
Log metrics to ./mem/
```

### Safety Gates
1. **Pre-execution validation** — pre-tool-safety.ps1 checks all Bash commands
2. **Complexity analysis** — Routes LOW/MEDIUM to Claude Code, HIGH/CRITICAL to Codex
3. **User approval** — Prompts for HIGH/CRITICAL before execution
4. **Git snapshot** — Creates rollback point before Codex runs
5. **Sandbox policy** — Codex limited to `workspace-write` (no system access)

### Key Dependencies
- Claude Code (latest)
- Codex CLI (in WSL Ubuntu)
- PowerShell 7+
- Git

## Deployment Checklist
- ✅ SKILL.md properly formatted with Claude Code metadata
- ✅ Install-Codex.ps1 wires hooks globally
- ✅ All scripts operational and tested
- ✅ Config files cleaned (no unused blocks)
- ✅ GitHub repo created and code pushed
- ✅ Git initialized with proper history

## Next Steps (Optional)
- Add GitHub CI/CD for validation
- Create installation tests
- Add Discord/Slack notifications for Codex execution
- Create web dashboard for metrics viewing
