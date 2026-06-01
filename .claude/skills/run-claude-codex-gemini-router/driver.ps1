#!/usr/bin/env pwsh
<#
.SYNOPSIS
Claude Task Router Skill — Validation & Smoke Test Driver

.DESCRIPTION
Agent-facing driver for validating and testing the claude-codex-gemini-router-skill.
Tests:
  - Skill installation (hooks, config, prerequisites)
  - Complexity analysis (task tier detection)
  - Routing logic (Codex vs Gemini recommendations)
  - Config file parsing (JSON validation)
  - Git snapshot creation (rollback capability)

Exit codes:
  0 = all tests passed
  1 = one or more tests failed
  2 = prerequisites missing (cannot proceed)

.PARAMETER Action
The test action to run: validate, install, test, full (default: full)

.PARAMETER Verbose
Show detailed output

.EXAMPLE
.\driver.ps1 -Action validate
.\driver.ps1 -Action test -Verbose
#>

param(
    [ValidateSet('validate', 'install', 'test', 'smoke', 'full')]
    [string]$Action = 'full',
    [switch]$Verbose
)

$ErrorActionPreference = 'Continue'
$WarningPreference = 'SilentlyContinue'

# ============================================================================
# Globals
# ============================================================================

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Get-Item $scriptDir).Parent.Parent.Parent.FullName
$claudeDir = "$env:USERPROFILE\.claude"
$settingsFile = "$claudeDir\settings.json"

$testResults = @{
    passed = 0
    failed = 0
    warnings = 0
}

# ============================================================================
# Logging
# ============================================================================

function Write-Result {
    param([string]$Message, [string]$Status = "INFO")
    $colors = @{
        PASS = "Green"
        FAIL = "Red"
        WARN = "Yellow"
        INFO = "Cyan"
        SKIP = "Gray"
    }

    $icon = @{
        PASS = "✓"
        FAIL = "✗"
        WARN = "⚠"
        INFO = "ℹ"
        SKIP = "○"
    }

    $symbol = $icon[$Status] ?? "•"
    Write-Host "$symbol $Message" -ForegroundColor $colors[$Status]
}

function Write-Test {
    param([string]$TestName, [bool]$Result, [string]$Detail)

    if ($Result) {
        Write-Result "$TestName" "PASS"
        $script:testResults.passed++
    }
    else {
        Write-Result "$TestName — $Detail" "FAIL"
        $script:testResults.failed++
    }
}

# ============================================================================
# Validation Functions
# ============================================================================

function Test-Prerequisites {
    Write-Host ""
    Write-Host "Prerequisites Check" -ForegroundColor Cyan
    Write-Host "===================" -ForegroundColor Cyan

    $allOk = $true

    # PowerShell version
    $psVersion = $PSVersionTable.PSVersion.Major
    $psOk = $psVersion -ge 7
    Write-Test "PowerShell 7+" $psOk "Current: $psVersion"
    $allOk = $allOk -and $psOk

    # Git
    $gitOk = (git --version 2>$null) -match "git version"
    Write-Test "Git installed" $gitOk "Cannot create snapshots without git"
    $allOk = $allOk -and $gitOk

    # Git repo (warning, not failure)
    if ($gitOk) {
        $inGitRepo = (git rev-parse --git-dir 2>$null) -ne $null
        if (-not $inGitRepo) {
            Write-Result "Git repository" "WARN"
            $script:testResults.warnings++
        }
        else {
            Write-Test "Git repository initialized" $true
        }
    }

    return $allOk
}

function Test-ConfigFiles {
    Write-Host ""
    Write-Host "Configuration Files" -ForegroundColor Cyan
    Write-Host "===================" -ForegroundColor Cyan

    $allOk = $true

    # hooks.json
    $hooksPath = "$projectRoot\config\hooks.json"
    if (Test-Path $hooksPath) {
        try {
            $hooks = Get-Content $hooksPath | ConvertFrom-Json
            $hasCodex = $hooks.hooks.RouteToCodex.enabled -eq $true
            $hasGemini = $hooks.hooks.RouteToGemini.enabled -eq $true

            Write-Test "hooks.json valid JSON" $true
            Write-Test "RouteToCodex enabled" $hasCodex
            Write-Test "RouteToGemini enabled" $hasGemini

            $allOk = $allOk -and $hasCodex -and $hasGemini
        }
        catch {
            Write-Test "hooks.json parsing" $false $_.Exception.Message
            $allOk = $false
        }
    }
    else {
        Write-Test "hooks.json exists" $false "Not found at $hooksPath"
        $allOk = $false
    }

    # complexity-tiers.json
    $tiersPath = "$projectRoot\config\complexity-tiers.json"
    if (Test-Path $tiersPath) {
        try {
            $tiers = Get-Content $tiersPath | ConvertFrom-Json
            $hasLow = $tiers.tiers.LOW -ne $null
            $hasHigh = $tiers.tiers.HIGH -ne $null

            Write-Test "complexity-tiers.json valid" $true
            Write-Test "Tier definitions present" ($hasLow -and $hasHigh)

            $allOk = $allOk -and $hasLow -and $hasHigh
        }
        catch {
            Write-Test "complexity-tiers.json parsing" $false $_.Exception.Message
            $allOk = $false
        }
    }
    else {
        Write-Test "complexity-tiers.json exists" $false "Not found"
        $allOk = $false
    }

    return $allOk
}

function Test-Scripts {
    Write-Host ""
    Write-Host "Script Files" -ForegroundColor Cyan
    Write-Host "============" -ForegroundColor Cyan

    $scripts = @(
        "Install-Codex.ps1"
        "Install-Gemini.ps1"
        "Validate-Codex.ps1"
        "Validate-Gemini.ps1"
        "Route-ToCodex.ps1"
        "Route-ToGemini.ps1"
        "Analyze-TaskComplexity.ps1"
    )

    $allOk = $true
    foreach ($script in $scripts) {
        $path = "$projectRoot\scripts\$script"
        $exists = Test-Path $path
        Write-Test "scripts\$script exists" $exists
        $allOk = $allOk -and $exists
    }

    return $allOk
}

function Test-ComplexityAnalysis {
    Write-Host ""
    Write-Host "Complexity Analysis" -ForegroundColor Cyan
    Write-Host "===================" -ForegroundColor Cyan

    $analyzerPath = "$projectRoot\scripts\Analyze-TaskComplexity.ps1"

    if (-not (Test-Path $analyzerPath)) {
        Write-Test "Complexity analyzer exists" $false
        return $false
    }

    $allOk = $true

    # Test LOW complexity
    try {
        $result = & $analyzerPath "fix a typo" | ConvertFrom-Json
        $isLow = $result.tier -eq "LOW"
        Write-Test "Detects LOW complexity" $isLow "Task: 'fix a typo', Got: $($result.tier)"
        $allOk = $allOk -and $isLow
    }
    catch {
        Write-Test "LOW complexity detection" $false $_.Exception.Message
        $allOk = $false
    }

    # Test HIGH complexity
    try {
        $result = & $analyzerPath "refactor authentication module to support oauth2 with proper token management" | ConvertFrom-Json
        $isHigh = $result.tier -in @("HIGH", "CRITICAL")
        Write-Test "Detects HIGH/CRITICAL complexity" $isHigh "Task: 'refactor...', Got: $($result.tier)"
        $allOk = $allOk -and $isHigh
    }
    catch {
        Write-Test "HIGH complexity detection" $false $_.Exception.Message
        $allOk = $false
    }

    return $allOk
}

function Test-RoutingLogic {
    Write-Host ""
    Write-Host "Routing Logic" -ForegroundColor Cyan
    Write-Host "=============" -ForegroundColor Cyan

    $allOk = $true

    # Verify Route-ToCodex exists and is callable
    $codexPath = "$projectRoot\scripts\Route-ToCodex.ps1"
    if (Test-Path $codexPath) {
        try {
            $content = Get-Content $codexPath -Raw
            $hasTaskParam = $content -match "param.*TaskDescription"
            Write-Test "Route-ToCodex has TaskDescription param" $hasTaskParam
            $allOk = $allOk -and $hasTaskParam
        }
        catch {
            Write-Test "Route-ToCodex callable" $false
            $allOk = $false
        }
    }
    else {
        Write-Test "Route-ToCodex exists" $false
        $allOk = $false
    }

    # Verify Route-ToGemini exists and is callable
    $geminiPath = "$projectRoot\scripts\Route-ToGemini.ps1"
    if (Test-Path $geminiPath) {
        try {
            $content = Get-Content $geminiPath -Raw
            $hasTaskParam = $content -match "param.*TaskDescription"
            Write-Test "Route-ToGemini has TaskDescription param" $hasTaskParam
            $allOk = $allOk -and $hasTaskParam
        }
        catch {
            Write-Test "Route-ToGemini callable" $false
            $allOk = $false
        }
    }
    else {
        Write-Test "Route-ToGemini exists" $false
        $allOk = $false
    }

    return $allOk
}

function Test-GitSnapshot {
    Write-Host ""
    Write-Host "Git Snapshot Capability" -ForegroundColor Cyan
    Write-Host "======================" -ForegroundColor Cyan

    # Check if git is available
    $gitOk = (git --version 2>$null) -match "git version"
    if (-not $gitOk) {
        Write-Result "Git required for snapshots" "WARN"
        $script:testResults.warnings++
        return $true
    }

    # Check if in git repo
    $inRepo = (git rev-parse --git-dir 2>$null) -ne $null
    if (-not $inRepo) {
        Write-Result "Git repository required" "WARN"
        $script:testResults.warnings++
        return $true
    }

    # Check pre-codex-snapshot.ps1
    $preCodexPath = "$projectRoot\hooks\pre-codex-snapshot.ps1"
    Write-Test "hooks\pre-codex-snapshot.ps1 exists" (Test-Path $preCodexPath)

    # Check pre-gemini-snapshot.ps1
    $preGeminiPath = "$projectRoot\hooks\pre-gemini-snapshot.ps1"
    Write-Test "hooks\pre-gemini-snapshot.ps1 exists" (Test-Path $preGeminiPath)

    return $true
}

function Test-InstallScripts {
    Write-Host ""
    Write-Host "Installation Scripts" -ForegroundColor Cyan
    Write-Host "====================" -ForegroundColor Cyan

    $allOk = $true

    # Test Install-Codex.ps1
    $codexInstallPath = "$projectRoot\scripts\Install-Codex.ps1"
    if (Test-Path $codexInstallPath) {
        try {
            $content = Get-Content $codexInstallPath -Raw
            $hasUninstall = $content -match "param.*Uninstall"
            Write-Test "Install-Codex.ps1 has Uninstall parameter" $hasUninstall
            $allOk = $allOk -and $hasUninstall
        }
        catch {
            Write-Test "Install-Codex.ps1 valid" $false
            $allOk = $false
        }
    }

    # Test Install-Gemini.ps1
    $geminiInstallPath = "$projectRoot\scripts\Install-Gemini.ps1"
    if (Test-Path $geminiInstallPath) {
        try {
            $content = Get-Content $geminiInstallPath -Raw
            $hasUninstall = $content -match "param.*Uninstall"
            Write-Test "Install-Gemini.ps1 has Uninstall parameter" $hasUninstall
            $allOk = $allOk -and $hasUninstall
        }
        catch {
            Write-Test "Install-Gemini.ps1 valid" $false
            $allOk = $false
        }
    }

    return $allOk
}

# ============================================================================
# Summary
# ============================================================================

function Write-Summary {
    Write-Host ""
    Write-Host "Test Summary" -ForegroundColor Cyan
    Write-Host "============" -ForegroundColor Cyan

    $total = $testResults.passed + $testResults.failed
    $percent = if ($total -gt 0) { [int]($testResults.passed / $total * 100) } else { 0 }

    Write-Host ""
    Write-Host "Passed:  $($testResults.passed)" -ForegroundColor Green
    Write-Host "Failed:  $($testResults.failed)" -ForegroundColor Red
    Write-Host "Warnings: $($testResults.warnings)" -ForegroundColor Yellow
    Write-Host "Total:   $total"
    Write-Host "Pass Rate: $percent%"
    Write-Host ""

    if ($testResults.failed -eq 0) {
        Write-Host "Status: All tests passed ✓" -ForegroundColor Green
        return 0
    }
    else {
        Write-Host "Status: Some tests failed ✗" -ForegroundColor Red
        return 1
    }
}

# ============================================================================
# Main
# ============================================================================

Write-Host ""
Write-Host "Claude Task Router — Driver Validation" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host "Project: $projectRoot" -ForegroundColor Gray
Write-Host "Action: $Action" -ForegroundColor Gray
Write-Host ""

switch ($Action) {
    'validate' {
        Test-Prerequisites | Out-Null
        Test-ConfigFiles | Out-Null
        Test-Scripts | Out-Null
    }
    'install' {
        Test-Prerequisites | Out-Null
        Test-InstallScripts | Out-Null
    }
    'test' {
        Test-ComplexityAnalysis | Out-Null
        Test-RoutingLogic | Out-Null
    }
    'smoke' {
        Test-ComplexityAnalysis | Out-Null
    }
    'full' {
        Test-Prerequisites | Out-Null
        Test-ConfigFiles | Out-Null
        Test-Scripts | Out-Null
        Test-ComplexityAnalysis | Out-Null
        Test-RoutingLogic | Out-Null
        Test-GitSnapshot | Out-Null
        Test-InstallScripts | Out-Null
    }
}

$exitCode = Write-Summary
exit $exitCode
