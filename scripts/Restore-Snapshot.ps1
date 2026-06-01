#!/usr/bin/env pwsh
<#
.SYNOPSIS
Restore git snapshot (rollback Codex changes)

.DESCRIPTION
Lists available git stashes and allows restoring to a previous snapshot.
Useful if a Codex execution went wrong.

.EXAMPLE
.\Restore-Snapshot.ps1
# Lists available snapshots and prompts to restore

.\Restore-Snapshot.ps1 -SnapshotLabel "codex-snapshot-20260601-141530"
# Restores specific snapshot
#>

param(
    [string]$SnapshotLabel
)

if (-not (git rev-parse --git-dir 2>$null)) {
    Write-Host "[ERROR] Not a git repository" -ForegroundColor Red
    exit 1
}

Write-Host "Available Codex snapshots:" -ForegroundColor Cyan
Write-Host ""

# List stashes
$stashes = git stash list | Where-Object { $_ -match "codex-snapshot" }

if (-not $stashes) {
    Write-Host "[INFO] No Codex snapshots found" -ForegroundColor Yellow
    exit 0
}

$stash_array = @($stashes)
for ($i = 0; $i -lt $stash_array.Count; $i++) {
    Write-Host "  [$i] $($stash_array[$i])" -ForegroundColor Green
}

Write-Host ""

if (-not $SnapshotLabel) {
    $choice = Read-Host "Enter snapshot number to restore (or press Enter to cancel)"
    if (-not $choice -or $choice -eq "") {
        Write-Host "[INFO] Cancelled" -ForegroundColor Yellow
        exit 0
    }

    if ($choice -match "^\d+$" -and $choice -lt $stash_array.Count) {
        $stash_to_restore = $stash_array[$choice]
    }
    else {
        Write-Host "[ERROR] Invalid selection" -ForegroundColor Red
        exit 1
    }
}
else {
    $stash_to_restore = $stashes | Where-Object { $_ -match $SnapshotLabel } | Select-Object -First 1
}

if (-not $stash_to_restore) {
    Write-Host "[ERROR] Snapshot not found" -ForegroundColor Red
    exit 1
}

Write-Host "[ACTION] Restoring snapshot: $stash_to_restore" -ForegroundColor Cyan

try {
    # Extract stash index from "stash@{0}: ..."
    $stash_index = $stash_to_restore -match "stash@\{(\d+)\}" | ForEach-Object { $Matches[1] }

    git stash pop "stash@{$stash_index}"

    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Snapshot restored successfully" -ForegroundColor Green
        Write-Host "" -ForegroundColor Cyan
        Write-Host "Git status:" -ForegroundColor Cyan
        git status --short
    }
    else {
        Write-Host "[ERROR] Failed to restore snapshot" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "[ERROR] $_" -ForegroundColor Red
    exit 1
}