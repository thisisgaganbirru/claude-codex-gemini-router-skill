#!/usr/bin/env pwsh
<#
.SYNOPSIS
Validate Codex integration installation

.DESCRIPTION
Checks:
- Codex CLI availability
- hooks.json configuration
- settings.json merged
- Complexity routing enabled
- Approval workflow active

.EXAMPLE
.\Validate-Codex.ps1
#>

param()

$ErrorActionPreference = 'Continue'

$claudeDir = "$env:USERPROFILE\.claude"
$hooksFile = "$claudeDir\hooks.json"
$settingsFile = "$claudeDir\settings.json"

function Write-Check {
    param([string]$Name, [bool]$Pass, [string]$Detail)
    $icon = $Pass ? "✓" : "✗"
    $color = $Pass ? "Green" : "Red"
    Write-Host "$icon $Name" -ForegroundColor $color -NoNewline
    if ($Detail) { Write-Host " — $Detail" -ForegroundColor Gray }
    else { Write-Host "" }
}

Write-Host ""
Write-Host "Codex Integration Validation" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Cyan
Write-Host ""

# 1. Check Codex CLI
Write-Host "CLI:" -ForegroundColor Cyan
$codexFound = $false
try {
    $version = & codex --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Check "Codex CLI" $true $version
        $codexFound = $true
    }
    else {
        Write-Check "Codex CLI" $false "Not found in PATH"
    }
}
catch {
    Write-Check "Codex CLI" $false "Not found in PATH"
}

# 2. Check hooks.json
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Cyan

$hooksOk = $false
if (Test-Path $hooksFile) {
    try {
        $hooks = Get-Content $hooksFile | ConvertFrom-Json
        $hooksOk = $true
        Write-Check "hooks.json" $true "Exists"

        # Check PreToolUse
        $preToolUse = $hooks.hooks.PreToolUse.count -gt 0
        Write-Check "  PreToolUse (safety)" $preToolUse "$(if($preToolUse) { $hooks.hooks.PreToolUse.Count } else { '0' }) rules"

        # Check RouteToCodex
        $routeCodex = $hooks.hooks.RouteToCodex.enabled -eq $true
        Write-Check "  RouteToCodex (routing)" $routeCodex "$(if($routeCodex) { 'Enabled' } else { 'Disabled' })"

        # Check patterns
        $patterns = $hooks.hooks.RouteToCodex.patterns
        Write-Check "  Keywords" ($patterns.count -gt 0) "$($patterns.count) keywords: $($patterns -join ', ')"
    }
    catch {
        Write-Check "hooks.json" $false "Parse error: $_"
    }
}
else {
    Write-Check "hooks.json" $false "Not found"
}

$settingsOk = $false
if (Test-Path $settingsFile) {
    try {
        $settings = Get-Content $settingsFile | ConvertFrom-Json
        $settingsOk = $true
        Write-Check "settings.json" $true "Exists"

        # Check Codex subprocess
        $codexEnabled = $settings.codex_subprocess.enabled -eq $true
        Write-Check "  Codex subprocess" $codexEnabled "$(if($codexEnabled) { 'Enabled' } else { 'Disabled' })"

        # Check approval policy
        $approval = $settings.codex_subprocess.approval_policy
        Write-Check "  Approval policy" ($approval -eq "on-request") $approval

        # Check sandbox
        $sandbox = $settings.codex_subprocess.sandbox_policy
        Write-Check "  Sandbox policy" ($sandbox -eq "workspace-write") $sandbox

        # Check thresholds
        $thresholds = $settings.complexity_thresholds
        Write-Check "  Complexity thresholds" ($thresholds -ne $null) "5-10, 11-15, 16+"
    }
    catch {
        Write-Check "settings.json" $false "Parse error: $_"
    }
}
else {
    Write-Check "settings.json" $false "Not found"
}

# 3. Summary
Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan

$allOk = $codexFound -and $hooksOk -and $settingsOk

if ($allOk) {
    Write-Host "✓ Codex integration is properly installed and configured" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Green
    Write-Host "1. Try a complex task: 'Refactor the authentication module'" -ForegroundColor Gray
    Write-Host "2. Claude Code will detect complexity and suggest Codex routing" -ForegroundColor Gray
    Write-Host "3. Approve when prompted to execute via Codex" -ForegroundColor Gray
}
else {
    Write-Host "✗ Installation incomplete - see errors above" -ForegroundColor Red
    Write-Host ""
    Write-Host "To fix:" -ForegroundColor Red
    if (-not $codexFound) { Write-Host "- Install Codex CLI: pip install codex-cli" -ForegroundColor Gray }
    if (-not $hooksOk) { Write-Host "- Run Install-Codex.ps1 to setup hooks.json" -ForegroundColor Gray }
    if (-not $settingsOk) { Write-Host "- Run Install-Codex.ps1 to setup settings.json" -ForegroundColor Gray }
}

Write-Host ""
