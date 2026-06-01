---
name: run-claude-codex-gemini-router
title: Run Claude Task Router
description: Validate and test the Claude Task Router skill — smoke tests for installation, routing logic, complexity analysis, and configuration
version: 1.0.0
installable: false
---

# Run Claude Task Router

This skill provides programmatic validation and testing for the claude-codex-gemini-router-skill. Use it to verify the skill is properly configured, all components work correctly, and the routing/analysis logic functions as expected.

## Prerequisites

- PowerShell 7+ (required for WSL integration)
- Git (required for snapshot tests; warning only if missing)
- Project directory with all config and script files in place

## Driver

The driver is a PowerShell validation harness: **`.claude/skills/run-claude-codex-gemini-router/driver.ps1`**

It runs in-process (no external dependencies) and performs comprehensive checks across five layers:

1. **Prerequisites** — OS/runtime requirements (PowerShell 7+, Git)
2. **Config Files** — JSON validation (hooks.json, complexity-tiers.json)
3. **Script Files** — Existence of all routing, installation, and validation scripts
4. **Complexity Analysis** — Task tier detection logic (LOW, HIGH, CRITICAL)
5. **Routing Logic** — Codex vs Gemini routing parameters and callable entry points
6. **Git Snapshots** — Rollback capability via pre-execution hooks
7. **Install Scripts** — Codex and Gemini installer validation

## Run: Agent Path

### Full Validation (all tests)

```powershell
pwsh .\.claude\skills\run-claude-codex-gemini-router\driver.ps1
```

Output: Comprehensive test report with pass/fail status per layer.

Exit codes:
- `0` = all tests passed
- `1` = one or more tests failed
- `2` = prerequisites missing (cannot proceed)

### Quick Checks

**Validate configuration only:**
```powershell
pwsh .\.claude\skills\run-claude-codex-gemini-router\driver.ps1 -Action validate
```

**Test routing logic:**
```powershell
pwsh .\.claude\skills\run-claude-codex-gemini-router\driver.ps1 -Action test
```

**Test complexity analysis:**
```powershell
pwsh .\.claude\skills\run-claude-codex-gemini-router\driver.ps1 -Action smoke
```

**Validate installer scripts:**
```powershell
pwsh .\.claude\skills\run-claude-codex-gemini-router\driver.ps1 -Action install
```

**Verbose output:**
```powershell
pwsh .\.claude\skills\run-claude-codex-gemini-router\driver.ps1 -Verbose
```

## Run: Human Path

Same as agent path — this is a CLI validation script. No GUI, no long-running process.

```bash
cd /path/to/claude-codex-gemini-router-skill
pwsh .\.claude\skills\run-claude-codex-gemini-router\driver.ps1
```

## What Gets Tested

### Layer 1: Prerequisites
- ✓ PowerShell 7+ installed (blocking)
- ✓ Git available (warning if missing, snapshots won't work)
- ✓ Git repository initialized (warning if not, snapshots require a repo)

### Layer 2: Configuration Files
- ✓ `config/hooks.json` parses as valid JSON
- ✓ `config/hooks.json` has RouteToCodex enabled
- ✓ `config/hooks.json` has RouteToGemini enabled
- ✓ `config/complexity-tiers.json` parses as valid JSON
- ✓ `config/complexity-tiers.json` defines LOW and HIGH tiers

### Layer 3: Script Files
- ✓ `scripts/Install-Codex.ps1` exists
- ✓ `scripts/Install-Gemini.ps1` exists
- ✓ `scripts/Validate-Codex.ps1` exists
- ✓ `scripts/Validate-Gemini.ps1` exists
- ✓ `scripts/Route-ToCodex.ps1` exists
- ✓ `scripts/Route-ToGemini.ps1` exists
- ✓ `scripts/Analyze-TaskComplexity.ps1` exists

### Layer 4: Complexity Analysis
- ✓ LOW complexity detected for simple task ("fix a typo")
- ✓ HIGH/CRITICAL complexity detected for complex task ("refactor authentication module...")
- ✓ Confidence percentages calculated
- ✓ Reasoning provided for each classification

### Layer 5: Routing Logic
- ✓ `Route-ToCodex.ps1` callable with TaskDescription parameter
- ✓ `Route-ToGemini.ps1` callable with TaskDescription parameter
- ✓ Both scripts have proper parameter definitions

### Layer 6: Git Snapshots
- ✓ `hooks/pre-codex-snapshot.ps1` exists (creates `codex-snapshot-*` labels)
- ✓ `hooks/pre-gemini-snapshot.ps1` exists (creates `gemini-snapshot-*` labels)

### Layer 7: Install Scripts
- ✓ `Install-Codex.ps1` has Uninstall parameter
- ✓ `Install-Gemini.ps1` has Uninstall parameter

## Expected Output

**When all tests pass:**

```
✓ PowerShell 7+
✓ Git installed
✓ Git repository initialized
✓ hooks.json valid JSON
✓ RouteToCodex enabled
✓ RouteToGemini enabled
✓ complexity-tiers.json valid
✓ Tier definitions present
... (more tests)

Test Summary
============
Passed:  28
Failed:  0
Warnings: 0
Total:   28
Pass Rate: 100%

Status: All tests passed ✓
```

**When a test fails:**

```
✗ RouteToCodex enabled — JSON key missing or false
```

The driver continues running all tests even after failures, so you see the full picture.

## Gotchas

### "Git repository required" warning
This is a WARNING, not a failure. Git snapshots require an initialized repository with at least one commit. If you're in a fresh clone or sandbox:
```powershell
git init
git add .
git commit -m "Initial commit"
```

The driver continues; snapshots just won't work in the actual skill until git is set up.

### "Complexity analysis test failed"
If `Analyze-TaskComplexity.ps1` doesn't detect complexity correctly:
- Check `config/complexity-tiers.json` for keyword definitions
- Verify the script loads the config file correctly
- Re-run the full driver: `driver.ps1 -Action test`

### PowerShell 7+ required
If you get "PowerShell X.Y not supported," you're running PowerShell 5 (Windows default). Install PowerShell 7+:
```powershell
# In admin PowerShell:
iex "& { $(irm https://aka.ms/install-powershell.ps1) } -UseMSI"
```

Then re-run the driver with `pwsh` (not `powershell`).

## Troubleshooting

| Symptom | Fix |
|---|---|
| All tests pass, but skill fails in Claude Code | The driver tests config; Claude Code uses hooks. Reinstall: `.\scripts\Install-Codex.ps1` |
| "hooks.json parsing failed" | Check `config/hooks.json` for syntax errors (`JSON linter` online) |
| Complexity analysis returns wrong tier | Task keywords may not match your `config/complexity-tiers.json`; check keyword definitions |
| "Route-ToCodex callable" fails | Script may have syntax errors; run `pwsh -File scripts/Route-ToCodex.ps1` directly to see error |
| "Git repository required" blocking tests | Not a blocker; it's a warning. Snapshots won't work until you init git |

## Direct Invocation

For use in agent scripts, the driver returns structured JSON-parseable output when invoked with `-Action` flags:

```powershell
# Get results as structured text (lines like "✓ Test Name")
$result = & pwsh .\.claude\skills\run-claude-codex-gemini-router\driver.ps1 -Action smoke

# Check exit code
if ($LASTEXITCODE -eq 0) {
    Write-Host "Skill is healthy"
} else {
    Write-Host "Skill has issues"
}
```

## Next Steps

Once the driver reports all tests passed:

1. **Install the skill in Claude Code:**
   ```powershell
   /install claude-codex-gemini-router-skill
   ```

2. **Validate installation:**
   ```powershell
   .\scripts\Validate-Codex.ps1
   .\scripts\Validate-Gemini.ps1
   ```

3. **Give Claude Code a complex task** to trigger routing.

## Support

- **Validation fails?** Run `driver.ps1 -Verbose` for detailed output.
- **Still broken?** Check Troubleshooting above.
- **Driver has a bug?** The driver is in `.claude/skills/run-claude-codex-gemini-router/driver.ps1` — edit it or report the issue.
