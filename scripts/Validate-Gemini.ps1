#!/usr/bin/env pwsh
<#
.SYNOPSIS
Validate Gemini integration installation

.DESCRIPTION
Checks:
- Gemini CLI availability
- settings.json configured
- Approval workflow active

.EXAMPLE
.\Validate-Gemini.ps1
#>

param()

$ErrorActionPreference = 'Continue'

$claudeDir = "$env:USERPROFILE\.claude"
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
Write-Host "Gemini Integration Validation" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan
Write-Host ""

# 1. Check Gemini CLI
Write-Host "CLI:" -ForegroundColor Cyan
$geminiFound = $false
try {
    $version = & gemini --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Check "Gemini CLI" $true $version
        $geminiFound = $true
    }
    else {
        Write-Check "Gemini CLI" $false "Not found in PATH"
    }
}
catch {
    Write-Check "Gemini CLI" $false "Not found in PATH"
}

# 2. Check settings.json
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Cyan

$settingsOk = $false
if (Test-Path $settingsFile) {
    try {
        $settings = Get-Content $settingsFile | ConvertFrom-Json
        $settingsOk = $true
        Write-Check "settings.json" $true "Exists"

        # Check Gemini subprocess
        $geminiEnabled = $settings.gemini_subprocess.enabled -eq $true
        Write-Check "  Gemini subprocess" $geminiEnabled "$(if($geminiEnabled) { 'Enabled' } else { 'Disabled' })"

        # Check approval policy
        $approval = $settings.gemini_subprocess.approval_policy
        Write-Check "  Approval policy" ($approval -eq "on-request") $approval
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

$allOk = $geminiFound -and $settingsOk

if ($allOk) {
    Write-Host "✓ Gemini integration is properly installed and configured" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Green
    Write-Host "1. Try a task: 'Analyze the current architecture and document patterns'" -ForegroundColor Gray
    Write-Host "2. Claude Code will suggest Gemini for analysis tasks" -ForegroundColor Gray
    Write-Host "3. Approve when prompted to execute via Gemini" -ForegroundColor Gray
}
else {
    Write-Host "✗ Installation incomplete - see errors above" -ForegroundColor Red
    Write-Host ""
    Write-Host "To fix:" -ForegroundColor Red
    if (-not $geminiFound) { Write-Host "- Install Gemini CLI" -ForegroundColor Gray }
    if (-not $settingsOk) { Write-Host "- Run Install-Gemini.ps1 to setup settings.json" -ForegroundColor Gray }
}

Write-Host ""
