#!/usr/bin/env pwsh
<#
.SYNOPSIS
Route task to Codex subprocess if complexity is HIGH or CRITICAL

.DESCRIPTION
- Analyzes task complexity (LOW/MEDIUM/HIGH/CRITICAL)
- Prompts for approval before executing HIGH/CRITICAL tasks
- Creates git snapshot (if in repo)
- Executes Codex subprocess
- Logs metrics

.PARAMETER TaskDescription
The task to evaluate and possibly route

.PARAMETER AutoApprove
If $true, execute without prompting. Use with caution.

.EXAMPLE
.\Route-ToCodex.ps1 "Refactor authentication module"
# Analyzes, suggests Codex, waits for approval

.\Route-ToCodex.ps1 "Refactor auth" -AutoApprove
# Executes immediately without prompt
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$TaskDescription,
    [switch]$AutoApprove
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# ============================================================================
# Helper Functions (defined before use)
# ============================================================================

function Log-RoutingDecision {
    param([string]$Task, [string]$Tier, [string]$Decision)

    $projectRoot = (Get-Item $scriptDir).Parent.FullName
    $mem_dir = Join-Path $projectRoot "mem"

    if (Test-Path $mem_dir) {
        $session_file = Join-Path $mem_dir "$(Get-Date -Format 'yyyyMMdd')-session.md"
        $log_entry = "`n### Task Routing - $(Get-Date -Format 'HH:mm:ss')`n- Task: $Task`n- Tier: $Tier`n- Decision: $Decision`n- Status: Processed"
        Add-Content $session_file $log_entry -ErrorAction SilentlyContinue
    }
}

function Log-ExecutionMetrics {
    param([string]$Task, [string]$Tier, [string]$Status, [string]$Output)

    $projectRoot = (Get-Item $scriptDir).Parent.FullName
    $mem_dir = Join-Path $projectRoot "mem"

    if (Test-Path $mem_dir) {
        $session_file = Join-Path $mem_dir "$(Get-Date -Format 'yyyyMMdd')-session.md"
        $snippet = ($Output -split "`n" | Select-Object -First 2) -join ' '
        $log_entry = "`n### Codex Execution - $(Get-Date -Format 'HH:mm:ss')`n- Task: $Task`n- Tier: $Tier`n- Status: $Status`n- Snippet: $snippet"
        Add-Content $session_file $log_entry -ErrorAction SilentlyContinue
    }
}

function Get-InGitRepo {
    try {
        $null = git rev-parse --git-dir 2>$null
        return $true
    }
    catch {
        return $false
    }
}

function Create-Snapshot {
    param([string]$TaskDescription)

    if (-not (Get-InGitRepo)) {
        Write-Host "[WARN] Not in a git repository - skipping snapshot" -ForegroundColor Yellow
        return $true  # Don't fail if no git
    }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $snapshot_label = "codex-snapshot-$timestamp"

    $status = git status --porcelain 2>$null
    if (-not $status) {
        Write-Host "[INFO] No changes to snapshot" -ForegroundColor Cyan
        return $true
    }

    git stash push -u -m "$snapshot_label : $TaskDescription" 2>&1 | Out-Null

    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Snapshot created: $snapshot_label" -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "[WARN] Failed to create snapshot" -ForegroundColor Yellow
        return $false
    }
}

function Invoke-CodexTask {
    param([string]$Task)

    # Use argument array for safe command construction
    $codex_args = @(
        $Task,
        '-a', 'on-request',
        '-s', 'workspace-write'
    )

    Write-Host "[ACTION] Executing: codex <task> -a on-request -s workspace-write" -ForegroundColor Cyan

    try {
        # Call codex via WSL with safe argument passing
        $output = wsl -d Ubuntu -- codex @codex_args 2>&1

        if ($LASTEXITCODE -eq 0) {
            return @{ success = $true; output = $output }
        }
        else {
            return @{ success = $false; output = $output }
        }
    }
    catch {
        return @{ success = $false; output = $_.Exception.Message }
    }
}

# ============================================================================
# Main Logic
# ============================================================================

Write-Host "[INFO] Analyzing task complexity..." -ForegroundColor Cyan
$analysis = & "$scriptDir\Analyze-TaskComplexity.ps1" $TaskDescription | ConvertFrom-Json

$tier = $analysis.tier
$confidence = $analysis.confidence
$routing = $analysis.routing

Write-Host "[INFO] Complexity: $tier ($confidence% confidence)" -ForegroundColor Cyan
Write-Host "[INFO] Reasoning: $($analysis.reasoning)" -ForegroundColor Gray

# ============================================================================
# Route LOW and MEDIUM to Claude Code
# ============================================================================

if ($tier -eq "LOW" -or $tier -eq "MEDIUM") {
    Write-Host "[OK] Task routes to: Claude Code" -ForegroundColor Green
    Write-Host "     Tier: $tier - Claude Code can handle this" -ForegroundColor Green
    Log-RoutingDecision -Task $TaskDescription -Tier $tier -Decision "direct"
    exit 0
}

# ============================================================================
# For HIGH/CRITICAL, prompt for approval
# ============================================================================

Write-Host ""
Write-Host "[SUGGEST] This task appears to be $tier complexity" -ForegroundColor Yellow
Write-Host "[SUGGEST] Recommend routing to Codex subprocess" -ForegroundColor Yellow
Write-Host ""

# Check approval
$should_execute = $AutoApprove

if (-not $should_execute) {
    $prompt = Read-Host "Route to Codex? (y/n)"
    $should_execute = $prompt -eq "y"
}

if (-not $should_execute) {
    Write-Host "[CANCEL] Task routing cancelled by user" -ForegroundColor Yellow
    Log-RoutingDecision -Task $TaskDescription -Tier $tier -Decision "user_declined"
    exit 0
}

Write-Host "[APPROVED] User approved Codex execution" -ForegroundColor Green

# ============================================================================
# Execute with Codex
# ============================================================================

# Create snapshot (graceful if not in git repo)
$snapshot_ok = Create-Snapshot -TaskDescription $TaskDescription

# Execute Codex
$result = Invoke-CodexTask -Task $TaskDescription

if ($result.success) {
    Write-Host "[OK] Codex execution completed" -ForegroundColor Green
    Log-ExecutionMetrics -Task $TaskDescription -Tier $tier -Status "success" -Output $result.output

    # Offer GitHub PR (if in repo)
    if (Get-InGitRepo) {
        Write-Host ""
        $pr_prompt = Read-Host "Create GitHub PR with results? (y/n)"
        if ($pr_prompt -eq "y") {
            & "$scriptDir\Create-PR.ps1" -Title "Codex: $TaskDescription" | Out-Null
        }
    }

    Write-Output $result.output
    exit 0
}
else {
    Write-Host "[ERROR] Codex execution failed" -ForegroundColor Red
    Write-Host $result.output -ForegroundColor Red
    Log-ExecutionMetrics -Task $TaskDescription -Tier $tier -Status "failed" -Output $result.output

    # Suggest rollback if snapshot exists
    if (Get-InGitRepo -and $snapshot_ok) {
        Write-Host ""
        Write-Host "[OPTION] Rollback available: .\scripts\Restore-Snapshot.ps1" -ForegroundColor Yellow
    }

    exit 1
}
