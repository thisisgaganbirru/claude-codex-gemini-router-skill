#!/usr/bin/env pwsh
<#
.SYNOPSIS
View Codex execution metrics and statistics

.DESCRIPTION
Reads memory logs (./mem/*.md) and displays:
- Task distribution by tier
- Success/failure rates
- Average execution times
- Trending complexity

.EXAMPLE
.\View-Metrics.ps1
# Shows summary of all Codex executions

.\View-Metrics.ps1 -Detailed
# Shows detailed breakdown
#>

param(
    [switch]$Detailed
)

$mem_dir = "./mem"

if (-not (Test-Path $mem_dir)) {
    Write-Host "[INFO] No memory directory found. Run a Codex task first." -ForegroundColor Yellow
    exit 0
}

# Read all session logs
$sessions = @()
Get-ChildItem $mem_dir -Filter "*-session.md" | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    $sessions += @{ Date = $_.BaseName; Content = $content }
}

if ($sessions.Count -eq 0) {
    Write-Host "[INFO] No execution logs found yet" -ForegroundColor Yellow
    exit 0
}

# Parse metrics
$metrics = @{
    total_tasks    = 0
    by_tier        = @{ LOW = 0; MEDIUM = 0; HIGH = 0; CRITICAL = 0 }
    by_status      = @{ success = 0; failed = 0 }
    by_routing     = @{ direct = 0; subagent = 0; codex = 0 }
    recent_tasks   = @()
}

foreach ($session in $sessions) {
    # Count routing decisions
    if ($session.Content -match "Task Routing.*Tier: (\w+).*Decision: (\w+)") {
        $tier = $Matches[1]
        $decision = $Matches[2]

        $metrics.total_tasks++
        $metrics.by_tier[$tier]++
        $metrics.by_routing[$decision]++
    }

    # Count Codex executions
    if ($session.Content -match "Codex Execution.*Tier: (\w+).*Status: (\w+)") {
        $tier = $Matches[1]
        $status = $Matches[2]

        $metrics.by_tier[$tier]++
        if ($status -eq "success") {
            $metrics.by_status.success++
        }
        else {
            $metrics.by_status.failed++
        }
    }

    # Get recent tasks (last 5)
    if ($session.Content -match "Task: (.+?)[\r\n]") {
        $metrics.recent_tasks += $Matches[1]
    }
}

# Display summary
Write-Host "`n═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  CODEX EXECUTION METRICS DASHBOARD" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan

Write-Host "`nTotal Tasks Analyzed: $($metrics.total_tasks)" -ForegroundColor Green

Write-Host "`nTier Distribution:" -ForegroundColor Yellow
$metrics.by_tier.GetEnumerator() | ForEach-Object {
    $pct = if ($metrics.total_tasks -gt 0) { [math]::Round(($_.Value / $metrics.total_tasks) * 100, 1) } else { 0 }
    Write-Host "  $($_.Key): $($_.Value) ($pct%)" -ForegroundColor Gray
}

Write-Host "`nRouting Distribution:" -ForegroundColor Yellow
$metrics.by_routing.GetEnumerator() | ForEach-Object {
    Write-Host "  $($_.Key): $($_.Value)" -ForegroundColor Gray
}

if ($metrics.by_status.success -gt 0 -or $metrics.by_status.failed -gt 0) {
    Write-Host "`nExecution Success Rate:" -ForegroundColor Yellow
    $total = $metrics.by_status.success + $metrics.by_status.failed
    $success_rate = [math]::Round(($metrics.by_status.success / $total) * 100, 1)
    Write-Host "  Success: $($metrics.by_status.success)/$total ($success_rate%)" -ForegroundColor Green
    Write-Host "  Failed: $($metrics.by_status.failed)/$total" -ForegroundColor Red
}

if ($Detailed -and $metrics.recent_tasks.Count -gt 0) {
    Write-Host "`nRecent Tasks:" -ForegroundColor Yellow
    $metrics.recent_tasks | Select-Object -Last 5 | ForEach-Object {
        Write-Host "  - $_" -ForegroundColor Gray
    }
}

Write-Host "`n═══════════════════════════════════════" -ForegroundColor Cyan

Write-Host "`nFor detailed logs, see: ./mem/*.md" -ForegroundColor Gray