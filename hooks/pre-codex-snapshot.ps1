#!/usr/bin/env pwsh
<#
.SYNOPSIS
Create git snapshot before Codex execution

.DESCRIPTION
When a Codex task is about to run, create a timestamped git stash
so we can easily rollback if something goes wrong.
#>

param([string]$TaskDescription = "Codex task")

if (-not (git rev-parse --git-dir 2>$null)) {
    exit 0  # Not a git repo, skip silently
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$snapshot_label = "codex-snapshot-$timestamp"

try {
    $status = git status --porcelain

    if (-not $status) {
        exit 0  # No changes to snapshot
    }

    git stash push -u -m "$snapshot_label : $TaskDescription" 2>&1 | Out-Null

    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Snapshot: $snapshot_label" -ForegroundColor Green

        # Log to memory if available
        $mem_dir = "./mem"
        if (Test-Path $mem_dir) {
            $session_file = "$mem_dir/$(Get-Date -Format 'yyyyMMdd')-session.md"
            Add-Content $session_file "`n### Snapshot`n- Label: $snapshot_label`n- Time: $(Get-Date -Format 'HH:mm:ss')" -ErrorAction SilentlyContinue
        }
        exit 0
    }
    exit 1
}
catch {
    exit 1
}
