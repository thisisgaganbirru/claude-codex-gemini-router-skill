#!/usr/bin/env pwsh
<#
.SYNOPSIS
Intelligent agent routing - Claude Code decides between Codex and Gemini

.DESCRIPTION
- Analyzes task complexity
- Recommends appropriate agent (Codex for code execution, Gemini for analysis/reasoning)
- Asks user to confirm, override, or cancel
- Routes to selected agent with auto-approval

.PARAMETER TaskDescription
The task to evaluate and route

.EXAMPLE
.\Route-ToAgent.ps1 "Refactor the authentication module"
.\Route-ToAgent.ps1 "Analyze API design patterns and document findings"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$TaskDescription
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Analyze complexity
Write-Host "[INFO] Analyzing task complexity..." -ForegroundColor Cyan
$analysis = & "$scriptDir\Analyze-TaskComplexity.ps1" $TaskDescription | ConvertFrom-Json

$tier = $analysis.tier
$confidence = $analysis.confidence

Write-Host "[INFO] Complexity: $tier ($confidence% confidence)" -ForegroundColor Cyan
Write-Host "[INFO] Reasoning: $($analysis.reasoning)" -ForegroundColor Gray

# If LOW or MEDIUM, route to Claude Code directly
if ($tier -eq "LOW" -or $tier -eq "MEDIUM") {
    Write-Host "[OK] Task routes to: Claude Code (direct execution)" -ForegroundColor Green
    exit 0
}

# For HIGH/CRITICAL, decide which agent is best
Write-Host ""

# Decision logic: code execution vs analysis/reasoning
$codeExecutionKeywords = @(
    'refactor', 'rewrite', 'implement', 'migrate', 'fix', 'debug', 'patch',
    'add feature', 'build', 'update', 'enhance', 'integrate', 'connect'
)

$analysisKeywords = @(
    'analyze', 'review', 'document', 'explain', 'understand', 'design',
    'architecture', 'plan', 'evaluate', 'compare', 'assess', 'research'
)

$taskLower = $TaskDescription.ToLower()
$isCodeTask = $false
$isAnalysisTask = $false

foreach ($kw in $codeExecutionKeywords) {
    if ($taskLower -match "\b$kw\b") {
        $isCodeTask = $true
        break
    }
}

foreach ($kw in $analysisKeywords) {
    if ($taskLower -match "\b$kw\b") {
        $isAnalysisTask = $true
        break
    }
}

# Determine recommendation
$recommended = if ($isAnalysisTask -and -not $isCodeTask) { "Gemini" } `
               elseif ($isCodeTask -and -not $isAnalysisTask) { "Codex" } `
               elseif ($tier -eq "CRITICAL") { "Gemini" } `
               else { "Codex" }

# Determine reason
$reason = if ($recommended -eq "Codex") {
    "code execution task (refactor/implement/fix)"
} else {
    "analysis/reasoning task (analyze/design/review)"
}

Write-Host "[SUGGEST] Recommended agent: $recommended" -ForegroundColor Yellow
Write-Host "          Reason: $reason" -ForegroundColor Gray
Write-Host ""

# Prompt user
if ($recommended -eq "Codex") {
    $prompt = Read-Host "Proceed with Codex? (y = Codex / g = Gemini / n = Cancel)"
    $choice = $prompt.ToLower()

    if ($choice -eq "y" -or $choice -eq "") {
        & "$scriptDir\Route-ToCodex.ps1" $TaskDescription -AutoApprove
    }
    elseif ($choice -eq "g") {
        & "$scriptDir\Route-ToGemini.ps1" $TaskDescription -AutoApprove
    }
    else {
        Write-Host "[CANCEL] Task cancelled by user" -ForegroundColor Yellow
        exit 0
    }
}
else {
    $prompt = Read-Host "Proceed with Gemini? (y = Gemini / c = Codex / n = Cancel)"
    $choice = $prompt.ToLower()

    if ($choice -eq "y" -or $choice -eq "") {
        & "$scriptDir\Route-ToGemini.ps1" $TaskDescription -AutoApprove
    }
    elseif ($choice -eq "c") {
        & "$scriptDir\Route-ToCodex.ps1" $TaskDescription -AutoApprove
    }
    else {
        Write-Host "[CANCEL] Task cancelled by user" -ForegroundColor Yellow
        exit 0
    }
}
