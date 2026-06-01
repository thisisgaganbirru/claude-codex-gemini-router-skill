---
name: claude-codex-gemini-router
title: Claude Task Router
description: Smart routing from Claude Code to Codex and Gemini for lower token usage, safer execution, and better task specialization
version: 2.0.0
author: Claude Code
license: MIT
installable: true
autoInstall: true
---

# Claude Task Router

## Overview

Intelligently routes complex tasks from Claude Code to **Codex** (code execution) or **Gemini** (analysis/reasoning) based on task analysis. Claude Code analyzes each task and recommends the best agent, then executes with safety gates, git snapshots for rollback, and complete metrics tracking.

**Benefits:**
- 🎯 **Lower token usage** — Route to specialized agents instead of doing everything in Claude Code
- 🔒 **Safer execution** — Pre-execution safety checks block dangerous operations  
- 🧠 **Better specialization** — Each agent does what it's best at (Codex for code, Gemini for analysis)
- ↩️ **Easy rollback** — Git snapshots before execution, restore anytime

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

### How Claude Code Routes Tasks

When you give Claude Code a task:

1. **Claude Code analyzes complexity** — Is this LOW, MEDIUM, HIGH, or CRITICAL?
2. **Claude Code recommends agent** — For HIGH/CRITICAL:
   - Code execution tasks (refactor, implement, fix) → suggests **Codex**
   - Analysis tasks (analyze, design, review) → suggests **Gemini**
3. **You confirm or override** — Accept the suggestion or choose the other agent
4. **Claude Code executes** — Routes to selected agent with approval workflow

### Manual Commands (if needed)

```powershell
# Direct routing to Codex (bypasses Claude Code analysis)
.\scripts\Route-ToCodex.ps1 "Your code execution task"

# Direct routing to Gemini (bypasses Claude Code analysis)
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

**HIGH/CRITICAL tasks require your approval:**

Claude Code analyzes the task and recommends an agent based on the work type:

```
[SUGGEST] This is a code task → I recommend Codex
[SUGGEST] This is analysis work → I recommend Gemini
```

**You have 3 options:**
1. **Accept** (y) — Route to recommended agent
2. **Override** (use other agent) — Route to the alternative
3. **Decline** (n) — Cancel routing, handle it yourself

**Before execution:**
- Safety check — blocks dangerous operations
- Git snapshot — creates rollback point
- Approval — you confirm before running

## Example Usage

### Simple Task (Claude Code Direct)

**You:** "Fix the login form validation"

Claude Code analyzes and responds:
```
[INFO] Complexity: LOW (85% confidence)
[OK] Claude Code handles this directly.
```

---

### Complex Code Task (Claude Code → Codex)

**You:** "Refactor auth module for async/await"

Claude Code analyzes and responds:
```
[SUGGEST] This is a code execution task (refactor, async/await).
          I recommend routing to Codex for implementation.
          
Route to Codex? (y/n)
```

**You:** "y"

```
[OK] Snapshot created: codex-snapshot-20260601-153045
[ACTION] Executing: codex -p "Refactor auth module..."
[OK] Codex execution completed
```

---

### Complex Analysis Task (Claude Code → Gemini)

**You:** "Analyze API design patterns and document findings"

Claude Code analyzes and responds:
```
[SUGGEST] This is an analysis/reasoning task (analyze, document).
          I recommend routing to Gemini for detailed reasoning.
          
Route to Gemini? (y/n)
```

**You:** "y"

```
[OK] Snapshot created: gemini-snapshot-20260601-154532
[ACTION] Executing: gemini -p "Analyze API design patterns..."
[OK] Gemini execution completed
```

---

### Override Claude Code's Recommendation

**You:** "Analyze the code and suggest refactoring opportunities"

Claude Code:
```
[SUGGEST] This looks like an analysis task.
          I recommend Gemini for deep analysis.
          
Route to Gemini? (y/n/codex)
```

**You:** "codex" (override to use Codex instead)

```
[OK] Using Codex as requested.
[OK] Snapshot created: codex-snapshot-20260601-155612
[ACTION] Executing: codex...
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
- ✅ Claude Code makes intelligent recommendations
- ✅ Safety gates and approval workflows
- ✅ Git snapshots for rollback
- ✅ Metrics and execution tracking
- ✅ Lower token usage, safer execution, better specialization

Install via: `/install claude-codex-gemini-router`
