---
name: claude-codex-integration
title: Claude Codex Integration
description: Route heavy tasks from Claude Code to Codex subprocess with automatic complexity detection, safety constraints, and approval workflows
version: 1.0.0
author: Claude Code
license: MIT
installable: true
autoInstall: true
---

# Claude Codex Integration Skill

## Overview

Intelligently routes complex tasks from Claude Code to Codex subprocess based on tier detection. Includes safety gating, git snapshots for rollback, and metrics tracking.

## Installation

### Automatic (Recommended)

```powershell
/install claude-codex-integration
```

The skill will:
1. Copy hook scripts to `~/.claude/hooks/`
2. Wire hooks into `~/.claude/settings.json`
3. Configure complexity tiers
4. Validate Codex CLI
5. Enable routing immediately

### Manual

```powershell
cd /path/to/claude-codex-integration
.\scripts\Install-Codex.ps1
```

## How It Works

### Tier-Based Routing

Tasks are automatically classified:

| Tier | Files | Route | Example |
|------|-------|-------|---------|
| **LOW** | 1-2 | Claude Code direct | "Fix login bug" |
| **MEDIUM** | 3-5 | Claude Code + agents | "Implement auth" |
| **HIGH** | 5+ | Codex subprocess | "Refactor auth module" |
| **CRITICAL** | 10+ | Codex + review | "Complete rewrite" |

### Detection

Analyzes task keywords + file impact:
```
"Refactor authentication module"
  ↓
Keywords: "refactor" (HIGH tier)
Files: 7+ estimated (auth, login, session, etc.)
  ↓
Route: Codex subprocess with approval
```

### Safety & Approval

**Before Codex executes:**
1. ✅ Safety check — blocks dangerous operations
2. ✅ Git snapshot — creates rollback point
3. ✅ User approval — you confirm before execution
4. ✅ Sandbox constraints — Codex limited to workspace

**After execution:**
- Metrics logged to `./mem/`
- Results shown with suggestions

### Available Commands

Once installed, use:

```powershell
# Route a task to Codex (analyzes & prompts)
.\scripts\Route-ToCodex.ps1 "Your task description"

# Analyze complexity without routing
.\scripts\Analyze-TaskComplexity.ps1 "Your task"

# Restore from git snapshot if needed
.\scripts\Restore-Snapshot.ps1

# View execution history
.\scripts\View-Metrics.ps1

# Validate installation
.\scripts\Validate-Codex.ps1

# Uninstall
.\scripts\Install-Codex.ps1 -Uninstall
```

## Requirements

- **Claude Code** (latest)
- **Codex CLI** (installed in WSL Ubuntu or native)
- **Git** (for snapshots)
- **PowerShell 7+**

## What Gets Installed

```
~/.claude/
├─ hooks/
│  ├─ pre-tool-safety.ps1      (blocks dangerous ops)
│  └─ pre-codex-snapshot.ps1   (git backup)
└─ settings.json               (updated with hooks config)
```

Plus project files:
```
scripts/
├─ Route-ToCodex.ps1           (main router)
├─ Analyze-TaskComplexity.ps1  (tier detection)
├─ Restore-Snapshot.ps1        (rollback)
└─ View-Metrics.ps1            (tracking)

config/
├─ hooks.json                  (safety patterns)
└─ complexity-tiers.json       (tier definitions)
```

## Safety Features

### Pre-Execution Checks

Blocks dangerous operations:
- `rm -rf`, `DROP TABLE`, `git push --force`
- `git reset --hard`, `TRUNCATE TABLE`
- `chmod 777`, `sudo`, `reboot`
- Shell injection patterns

### Rollback Safety

Creates git snapshot before Codex runs:
```
codex-snapshot-20260601-153045: Refactor auth module
```

Restore anytime:
```powershell
.\Restore-Snapshot.ps1
```

### Approval Workflow

All HIGH/CRITICAL tasks require your approval:
```
[SUGGEST] This task is HIGH complexity
Route to Codex? (y/n)
```

## Example Usage

### Simple Task (Direct)

```powershell
.\scripts\Route-ToCodex.ps1 "Fix the login form validation"

[INFO] Complexity: LOW (85% confidence)
[OK] Task routes to: Claude Code
     Tier: LOW - Claude Code can handle this
```

### Complex Task (Codex)

```powershell
.\scripts\Route-ToCodex.ps1 "Refactor auth module for async/await"

[INFO] Complexity: HIGH (95% confidence)
[SUGGEST] This task appears to be HIGH complexity
Route to Codex? (y/n)
y
[OK] Snapshot created: codex-snapshot-20260601-153045
[ACTION] Executing: codex <task> ...
[OK] Codex execution completed
```

## Configuration

### Customize Tiers

Edit `config/complexity-tiers.json`:
```json
{
  "HIGH": {
    "keywords": ["refactor", "redesign", "migrate"],
    "file_count": "5+"
  }
}
```

### Customize Safety Patterns

Edit `config/hooks.json` → `hooks.PreToolUse[].forbidden_patterns`

### Disable/Enable Snapshots

Edit `hooks/pre-codex-snapshot.ps1` → comment out `git stash` lines

## Troubleshooting

### Codex not found

```powershell
codex --version

# If not installed:
pip install codex-cli
# OR
wsl -d Ubuntu -- sudo apt install codex
```

### Hooks not running

Verify installation:
```powershell
.\scripts\Validate-Codex.ps1
```

Check `~/.claude/settings.json` has hooks configured.

### Git snapshot failed

Ensure in git repo:
```powershell
git status
```

## Metrics & History

View execution history:
```powershell
.\scripts\View-Metrics.ps1
```

Shows:
- Total tasks by tier
- Success/failure rates
- Recent task list

Detailed logs in: `./mem/YYYYMMDD-session.md`

## Uninstall

```powershell
.\scripts\Install-Codex.ps1 -Uninstall
```

Restores backed-up configs.

## Support

- **Issues:** Report at project repository
- **Docs:** See SKILL.md (this file)
- **Status:** Run `Validate-Codex.ps1` to verify setup

## License

MIT

---

**Status: Ready to install** ✅

Install via: `/install claude-codex-integration`
