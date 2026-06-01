#!/usr/bin/env pwsh
<#
.SYNOPSIS
Analyze task complexity and determine routing tier

.DESCRIPTION
Reads task description and determines if it should be routed to:
- Direct (Claude Code only)
- Subagent (Claude Code + agents)
- Codex (Codex subprocess)
- Critical (Codex + manual review)

.PARAMETER TaskDescription
The task/prompt to analyze

.EXAMPLE
.\Analyze-TaskComplexity.ps1 "Refactor the authentication module"
# Output: HIGH

.\Analyze-TaskComplexity.ps1 "Fix the login bug"
# Output: LOW
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$TaskDescription
)

$ErrorActionPreference = 'Stop'

# Load tier configuration
$configPath = Join-Path $PSScriptRoot "..\config\complexity-tiers.json"
$tiers = Get-Content $configPath | ConvertFrom-Json

function Get-KeywordMatches {
    param([string]$Text)

    $keywordCounts = [ordered]@{}
    foreach ($tierName in @("LOW", "MEDIUM", "HIGH", "CRITICAL")) {
        $tier = $tiers.tiers.$tierName
        $count = 0

        foreach ($keyword in $tier.keywords) {
            $escapedKeyword = [regex]::Escape($keyword)
            if ($Text -match "\b$escapedKeyword\b") {
                Set-Variable -Name count -Value ($count + 1)
            }
        }

        [void]$keywordCounts.Add($tierName, $count)
    }

    [pscustomobject]$keywordCounts
}

function Get-FileDamageEstimate {
    param([string]$TaskText)

    try {
        if (-not (git rev-parse --git-dir 2>$null)) {
            return 0  # Not in git repo
        }

        # Try to estimate files affected by task keywords
        $estimate = 0

        # HIGH impact keywords suggest many files
        if ($TaskText -match '\b(refactor|redesign|rewrite|migrate|restructure|overhaul)\b') {
            $estimate += 5
        }

        # MEDIUM impact keywords
        if ($TaskText -match '\b(implement|feature|build|extend|enhance|integrate)\b') {
            $estimate += 3
        }

        # Try to match task terms to actual directories/files
        $common_dirs = @('src', 'lib', 'components', 'modules', 'services', 'api', 'auth', 'db')
        foreach ($dir in $common_dirs) {
            if (Test-Path $dir) {
                $files_in_dir = @(Get-ChildItem $dir -Recurse -File -ErrorAction SilentlyContinue)
                if ($TaskText -match "\b$dir\b" -and $files_in_dir.Count -gt 0) {
                    $estimate += [Math]::Min($files_in_dir.Count, 5)
                }
            }
        }

        # Get file count from recent changes as baseline
        $recent_changes = @(git diff --name-only HEAD~5..HEAD 2>$null)
        if ($recent_changes.Count -gt 0) {
            # If task is general refactor, assume similar scope to recent work
            if ($TaskText -match '\b(refactor|optimize|improve)\b') {
                $estimate = [Math]::Max($estimate, $recent_changes.Count)
            }
        }

        # Ensure reasonable bounds
        return [Math]::Max([Math]::Min($estimate, 20), 0)
    }
    catch {
        return 3  # Safe default on error
    }
}


function Determine-Tier {
    param(
        [object]$KeywordMatches,
        [int]$FileEstimate
    )

    # Score based on keyword matches
    $scores = @{
        "CRITICAL" = $KeywordMatches.CRITICAL
        "HIGH"     = $KeywordMatches.HIGH
        "MEDIUM"   = $KeywordMatches.MEDIUM
        "LOW"      = $KeywordMatches.LOW
    }

    # CRITICAL overrides everything
    if ($scores["CRITICAL"] -gt 0) {
        return "CRITICAL"
    }

    # HIGH tier: multiple high keywords OR file estimate 5+
    if ($scores["HIGH"] -gt 0 -or $FileEstimate -ge 5) {
        return "HIGH"
    }

    # MEDIUM tier: medium keywords OR file estimate 3-4
    if ($scores["MEDIUM"] -gt 0 -or ($FileEstimate -ge 3 -and $FileEstimate -lt 5)) {
        return "MEDIUM"
    }

    # Default to LOW
    return "LOW"
}

# Analyze
$keywords = Get-KeywordMatches $TaskDescription
$fileEstimate = Get-FileDamageEstimate $TaskDescription
$tier = Determine-Tier $keywords $fileEstimate

# Build confidence level
$highCount = $keywords.HIGH
$mediumCount = $keywords.MEDIUM
$lowCount = $keywords.LOW
$totalMatches = $highCount + $mediumCount + $lowCount

$confidence = 0
if ($totalMatches -gt 2) { $confidence = 95 }
elseif ($totalMatches -gt 1) { $confidence = 85 }
elseif ($totalMatches -gt 0) { $confidence = 75 }
else { $confidence = 60 }

# Output result
$result = @{
    tier           = $tier
    confidence     = $confidence
    file_estimate  = $fileEstimate
    routing        = $tiers.tiers.$tier.routing
    reasoning      = "Keywords found: HIGH=$highCount, MEDIUM=$mediumCount, LOW=$lowCount. Estimated files: $fileEstimate"
}

$resultJson = $result | ConvertTo-Json
Write-Output $resultJson
