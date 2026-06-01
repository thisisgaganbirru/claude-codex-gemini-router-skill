# Claude Task Router

Smart routing from Claude Code to Codex and Gemini for lower token usage, safer execution, and better task specialization.

## Overview

Claude Task Router is a Claude Code skill that intelligently routes complex tasks to specialized AI agents:
- **Codex** — Code execution, refactoring, implementation
- **Gemini** — Analysis, design, documentation, reasoning

Instead of doing everything in Claude Code (expensive in tokens), this skill analyzes each task and routes it to the most appropriate agent, with safety gates, approval workflows, and complete rollback capability.

## Features

**Smart Routing**
- Claude Code analyzes task complexity and type
- Recommends best agent (Codex for code, Gemini for analysis)
- User can accept recommendation or override

**Safety First**
- Pre-execution checks block dangerous operations (rm -rf, DROP TABLE, git push --force, etc.)
- Git snapshots before execution for easy rollback
- Sandbox constraints limit agent access to workspace

**Lower Token Usage**
- Route to specialized agents instead of doing everything in Claude Code
- Each agent optimized for its domain
- Significant token savings on complex tasks

**Complete Tracking**
- Execution metrics logged to `./mem/`
- Git snapshots labeled by agent (codex-snapshot-*, gemini-snapshot-*)
- Session history with task complexity and routing decisions

## Installation

### Automatic (Recommended)

```powershell
/install claude-codex-gemini-router-skill
```

The skill will:
1. Copy hook scripts to `~/.claude/hooks/`
2. Wire hooks into `~/.claude/settings.json`
3. Validate Codex and Gemini CLIs
4. Enable routing immediately

### Manual

**For Codex only:**
```powershell
.\scripts\Install-Codex.ps1
```

**For Gemini only:**
```powershell
.\scripts\Install-Gemini.ps1
```

**For both (recommended):**
```powershell
.\scripts\Install-Codex.ps1
.\scripts\Install-Gemini.ps1
```

## How It Works

### 1. Task Analysis

```
You: "Refactor the authentication module"
    ↓
Claude Code analyzes complexity (HIGH tier, 75% confidence)
```

### 2. Agent Recommendation

```
Claude Code: "This is a code execution task.
             I recommend routing to Codex for implementation.
             Proceed? (y/n)"
```

### 3. Approval & Execution

```
You: "y"
    ↓
Safety check
Git snapshot created (codex-snapshot-20260601-153045)
Codex executes via WSL Ubuntu
Results logged to ./mem/
```

### 4. Rollback Available

```
If something goes wrong, restore anytime:
  git stash list
  git stash pop codex-snapshot-20260601-153045
```

## Agent Selection Logic

### Route to Codex

Best for code execution tasks:
- refactor, rewrite, implement, migrate
- fix, debug, patch, update
- build, enhance, integrate, connect

### Route to Gemini

Best for analysis and reasoning tasks:
- analyze, review, assess, evaluate
- document, explain, understand
- design, architect, plan, research

## Requirements

- Claude Code (latest)
- Codex CLI (optional - for code execution)
  - Install: `pip install codex-cli`
- Gemini CLI (optional - for analysis/reasoning)
  - See: https://github.com/google-ai-sdk/generative-ai-python
- Git (for snapshots)
- PowerShell 7+
- WSL Ubuntu (for agent execution)

At least one agent (Codex or Gemini) required for routing.

## Quick Start

1. Install the skill: `/install claude-codex-gemini-router-skill`
2. Give Claude Code a complex task
3. Claude Code will recommend Codex or Gemini
4. Approve or override the recommendation
5. Watch execution with safety gates and rollback capability

## Project Structure

```
scripts/
├─ Route-ToCodex.ps1           (execute via Codex)
├─ Route-ToGemini.ps1          (execute via Gemini)
├─ Install-Codex.ps1           (setup Codex)
├─ Install-Gemini.ps1          (setup Gemini)
├─ Validate-Codex.ps1          (check Codex)
├─ Validate-Gemini.ps1         (check Gemini)
├─ Analyze-TaskComplexity.ps1  (tier detection)
├─ Restore-Snapshot.ps1        (git rollback)
└─ View-Metrics.ps1            (execution history)

hooks/
├─ pre-tool-safety.ps1         (safety checks)
├─ pre-codex-snapshot.ps1      (git backup)
└─ pre-gemini-snapshot.ps1     (git backup)

config/
├─ hooks.json                  (safety patterns)
├─ complexity-tiers.json       (tier definitions)
├─ settings.json.template      (Codex config)
└─ gemini-settings.json.template (Gemini config)
```

## Troubleshooting

### Codex CLI not found

```powershell
codex --version

# Install if needed:
pip install codex-cli
```

### Gemini CLI not found

Check Gemini CLI installation guide: https://github.com/google-ai-sdk/generative-ai-python

### Hooks not running

Verify installation:
```powershell
.\scripts\Validate-Codex.ps1
.\scripts\Validate-Gemini.ps1
```

### Git snapshot failed

Ensure you're in a git repository:
```powershell
git status
```

## Metrics and History

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
.\scripts\Install-Gemini.ps1 -Uninstall
```

Restores backed-up `~/.claude/settings.json`.

## Support

- GitHub Issues: Report bugs and feature requests
- Documentation: See SKILL.md for technical details
- Validation: Run `Validate-Codex.ps1` and `Validate-Gemini.ps1`

## License

MIT
