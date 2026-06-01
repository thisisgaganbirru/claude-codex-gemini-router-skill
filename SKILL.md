---
name: claude-codex-integration
title: Claude Codex & Gemini Integration
description: Route heavy tasks from Claude Code to Codex (code execution) or Gemini (analysis/reasoning) with automatic complexity detection, agent selection, safety constraints, and approval workflows
version: 2.0.0
author: Claude Code
license: MIT
installable: true
autoInstall: true
---

# Claude Codex & Gemini Integration Skill

## Overview

Intelligently routes complex tasks from Claude Code to either **Codex** (for code execution) or **Gemini** (for analysis/reasoning) based on tier detection and task type. Includes automatic agent recommendation, safety gating, git snapshots for rollback, and metrics tracking.

## Installation

### Automatic (Recommended)

```powershell
/install claude-codex-integration
```

The skill will:
1. Copy hook scripts to `~/.claude/hooks/`
2. Wire hooks into `~/.claude/settings.json`
3. Configure complexity tiers
4. Validate CLI tools
5. Enable routing immediately

### Manual Installation

**For Codex integration:**
```powershell
cd /path/to/claude-codex-integration
.\scripts\Install-Codex.ps1
```

**For Gemini integration:**
```powershell
cd /path/to/claude-codex-integration
.\scripts\Install-Gemini.ps1
```

**For both (recommended):**
```powershell
.\scripts\Install-Codex.ps1
.\scripts\Install-Gemini.ps1
```

## How It Works

### Tier-Based Routing

Tasks are automatically classified and routed:

| Tier | Files | Route | Route Decision |
|------|-------|-------|---|
| **LOW** | 1-2 | Claude Code direct | Direct execution |
| **MEDIUM** | 3-5 | Claude Code + agents | Subagents available |
| **HIGH** | 5+ | Codex OR Gemini | Claude Code recommends best agent |
| **CRITICAL** | 10+ | Codex OR Gemini | Claude Code recommends best agent |

**Agent Selection (HIGH/CRITICAL):**
- **Codex** recommended for: refactor, rewrite, implement, fix, build, debug (code execution)
- **Gemini** recommended for: analyze, review, document, explain, design, architect, plan (reasoning/analysis)

### Detection & Agent Selection

Analyzes task keywords + file impact + task type:

**Code Execution Task:**
```
"Refactor authentication module"
  ↓
Keywords: "refactor" (HIGH tier)
Files: 7+ estimated
Task type: code execution
  ↓
Recommended: Codex subprocess with approval
```

**Analysis/Reasoning Task:**
```
"Analyze API design patterns and document findings"
  ↓
Keywords: "analyze", "document" (HIGH tier)
Files: 5+ estimated
Task type: analysis/reasoning
  ↓
Recommended: Gemini subprocess with approval
```

### Safety & Approval

**Before Codex/Gemini executes:**
1. ✅ Complexity analysis — automatic task classification
2. ✅ Agent recommendation — Claude Code suggests Codex or Gemini
3. ✅ Safety check — blocks dangerous operations
4. ✅ Git snapshot — creates rollback point (Codex only)
5. ✅ User approval — you confirm recommended agent or choose alternative
6. ✅ Sandbox constraints — execution limited to workspace

**After execution:**
- Metrics logged to `./mem/`
- Results shown with suggestions
- Rollback point available if needed

### Available Commands

Once installed, use:

```powershell
# Smart routing: Claude Code recommends agent (Codex/Gemini)
.\scripts\Route-ToAgent.ps1 "Your task description"

# Direct routing to Codex (analyzes & prompts)
.\scripts\Route-ToCodex.ps1 "Your code execution task"

# Direct routing to Gemini (analyzes & prompts)
.\scripts\Route-ToGemini.ps1 "Your analysis/reasoning task"

# Analyze complexity without routing
.\scripts\Analyze-TaskComplexity.ps1 "Your task"

# Restore from git snapshot if needed
.\scripts\Restore-Snapshot.ps1

# View execution history
.\scripts\View-Metrics.ps1

# Validate installation
.\scripts\Validate-Codex.ps1
.\scripts\Validate-Gemini.ps1

# Uninstall
.\scripts\Install-Codex.ps1 -Uninstall
.\scripts\Install-Gemini.ps1 -Uninstall
```

## Requirements

- **Claude Code** (latest)
- **Codex CLI** (optional, for code execution - WSL Ubuntu or native)
- **Gemini CLI** (optional, for analysis/reasoning - WSL Ubuntu or native)
- **Git** (for snapshots)
- **PowerShell 7+**

At least one CLI (Codex or Gemini) is required for task execution.

## What Gets Installed

**Global hooks (`~/.claude/`):**
```
~/.claude/
├─ hooks/
│  ├─ pre-tool-safety.ps1         (blocks dangerous ops)
│  ├─ pre-codex-snapshot.ps1      (git backup before Codex)
│  └─ pre-gemini-snapshot.ps1     (git backup before Gemini)
└─ settings.json                  (updated with hooks config)
```

**Project scripts:**
```
scripts/
├─ Route-ToAgent.ps1             (smart routing: recommends agent)
├─ Route-ToCodex.ps1             (direct Codex router)
├─ Route-ToGemini.ps1            (direct Gemini router)
├─ Analyze-TaskComplexity.ps1    (tier detection)
├─ Install-Codex.ps1             (Codex installer)
├─ Install-Gemini.ps1            (Gemini installer)
├─ Validate-Codex.ps1            (Codex validator)
├─ Validate-Gemini.ps1           (Gemini validator)
├─ Restore-Snapshot.ps1          (rollback)
└─ View-Metrics.ps1              (tracking)

config/
├─ hooks.json                    (safety patterns)
├─ complexity-tiers.json         (tier definitions)
├─ gemini-settings.json.template (Gemini config)
└─ settings.json.template        (Codex config)
```

## Safety Features

### Pre-Execution Checks

Blocks dangerous operations:
- `rm -rf`, `DROP TABLE`, `git push --force`
- `git reset --hard`, `TRUNCATE TABLE`
- `chmod 777`, `sudo`, `reboot`
- Shell injection patterns

### Rollback Safety

Creates git snapshot before execution:
```
codex-snapshot-20260601-153045: Refactor auth module
gemini-snapshot-20260601-154532: Analyze API design
```

Different prefixes let you identify which agent ran. Restore anytime:
```powershell
git stash list          # View all snapshots
.\Restore-Snapshot.ps1  # Interactive restore
```

### Approval Workflow

All HIGH/CRITICAL tasks show agent recommendation:
```
[SUGGEST] Recommended agent: Codex
          Reason: code execution task (refactor/implement/fix)

Proceed with Codex? (y = Codex / g = Gemini / n = Cancel)
```

Or for analysis tasks:
```
[SUGGEST] Recommended agent: Gemini
          Reason: analysis/reasoning task (analyze/design/review)

Proceed with Gemini? (y = Gemini / c = Codex / n = Cancel)
```

You can accept the recommendation or choose the alternative agent.

## Example Usage

### Simple Task (Direct)

```powershell
.\scripts\Route-ToAgent.ps1 "Fix the login form validation"

[INFO] Complexity: LOW (85% confidence)
[OK] Task routes to: Claude Code (direct execution)
```

### Complex Code Task (Codex Recommended)

```powershell
.\scripts\Route-ToAgent.ps1 "Refactor auth module for async/await"

[INFO] Complexity: HIGH (95% confidence)
[SUGGEST] Recommended agent: Codex
          Reason: code execution task (refactor/implement/fix)

Proceed with Codex? (y = Codex / g = Gemini / n = Cancel)
y
[OK] Snapshot created: codex-snapshot-20260601-153045
[ACTION] Executing: codex -p "Refactor auth module..."
[OK] Codex execution completed
```

### Complex Analysis Task (Gemini Recommended)

```powershell
.\scripts\Route-ToAgent.ps1 "Analyze API design patterns and document findings"

[INFO] Complexity: HIGH (95% confidence)
[SUGGEST] Recommended agent: Gemini
          Reason: analysis/reasoning task (analyze/design/review)

Proceed with Gemini? (y = Gemini / c = Codex / n = Cancel)
y
[OK] Snapshot created: gemini-snapshot-20260601-154532
[ACTION] Executing: gemini -p "Analyze API design patterns..."
[OK] Gemini execution completed
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
# OR install in WSL Ubuntu
wsl -d Ubuntu -- sudo apt install codex
```

### Gemini not found

```powershell
gemini --version

# If not installed, refer to Google Gemini CLI documentation
# Visit: https://github.com/google-ai-sdk/generative-ai-python
```

### Hooks not running

Verify installation:
```powershell
.\scripts\Validate-Codex.ps1
.\scripts\Validate-Gemini.ps1
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
- **Status:** Run `Validate-Codex.ps1` and `Validate-Gemini.ps1` to verify setup
- **Smart Routing:** Use `Route-ToAgent.ps1` for automatic agent selection

## License

MIT

---

**Status: Ready to install** ✅

**Features:**
- ✅ Smart agent routing (Codex for code, Gemini for analysis)
- ✅ Automatic complexity detection
- ✅ Safety gates and approval workflows
- ✅ Git snapshots for rollback
- ✅ Metrics and execution tracking

Install via: `/install claude-codex-integration`
