#!/usr/bin/env pwsh
<#
.SYNOPSIS
Install Gemini integration for Claude Code

.DESCRIPTION
- Backs up existing settings.json
- Merges Gemini configuration
- Validates Gemini CLI
- Wires hooks into settings.json

.PARAMETER Uninstall
Remove Gemini integration and restore backups

.EXAMPLE
.\Install-Gemini.ps1
.\Install-Gemini.ps1 -Uninstall
#>

param(
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'

$claudeDir = "$env:USERPROFILE\.claude"
$settingsFile = "$claudeDir\settings.json"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$configDir = "$scriptDir\..\config"

function Write-Status {
    param([string]$Message, [string]$Status = "INFO")
    $colors = @{
        INFO   = "Cyan"
        OK     = "Green"
        WARN   = "Yellow"
        ERROR  = "Red"
    }
    Write-Host "[$Status] $Message" -ForegroundColor $colors[$Status]
}

function Test-GeminiCLI {
    try {
        $version = & gemini --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Status "Gemini CLI found: $version" "OK"
            return $true
        }
    }
    catch { }
    Write-Status "Gemini CLI not found. Install from: https://github.com/google-ai-sdk/generative-ai-python" "WARN"
    return $false
}

function Backup-Config {
    param([string]$File)
    if (Test-Path $File) {
        $backup = "$File.backup-$timestamp"
        Copy-Item $File $backup
        Write-Status "Backed up to: $backup" "OK"
        return $backup
    }
    return $null
}

function Merge-SettingsJson {
    Write-Status "Merging settings.json..." "INFO"

    if (Test-Path $settingsFile) {
        $existing = Get-Content $settingsFile | ConvertFrom-Json
        $template = Get-Content "$configDir\gemini-settings.json.template" | ConvertFrom-Json

        # Merge Gemini settings
        $existing.gemini_subprocess = $template.gemini_subprocess

        $existing | ConvertTo-Json -Depth 10 | Set-Content $settingsFile -Encoding UTF8
    }
    else {
        Copy-Item "$configDir\gemini-settings.json.template" "$settingsFile"
        $existing = Get-Content $settingsFile | ConvertFrom-Json
    }

    Write-Status "settings.json merged" "OK"
}

function Wire-HooksToSettings {
    Write-Status "Wiring hooks to Claude Code..." "INFO"

    $settings = Get-Content $settingsFile | ConvertFrom-Json

    # Ensure hooks object exists
    if (-not $settings.hooks) {
        $settings | Add-Member -NotePropertyName "hooks" -NotePropertyValue @{}
    }

    # Wire PreGeminiExecution snapshot hook
    if (-not $settings.hooks.PreGeminiExecution) {
        $settings.hooks | Add-Member -NotePropertyName "PreGeminiExecution" -NotePropertyValue @(
            @{
                type = "command"
                command = "pwsh $claudeDir\hooks\pre-gemini-snapshot.ps1"
            }
        )
    }

    $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsFile -Encoding UTF8
    Write-Status "Hooks wired to settings.json" "OK"
}

function Uninstall-Gemini {
    Write-Status "Uninstalling Gemini integration..." "WARN"

    $settings_backup = Get-Item "$settingsFile.backup-*" -ErrorAction SilentlyContinue | Sort-Object -Descending | Select-Object -First 1

    if ($settings_backup) {
        Copy-Item $settings_backup.FullName $settingsFile -Force
        Write-Status "Restored: settings.json" "OK"
    }

    if (-not $settings_backup) {
        Write-Status "No backups found - nothing to restore" "WARN"
    }
}

# Main
if ($Uninstall) {
    Uninstall-Gemini
    exit 0
}

Write-Status "Gemini Integration Installer" "INFO"
Write-Status "============================" "INFO"

# Create ~/.claude if not exists
New-Item -ItemType Directory -Force -Path $claudeDir | Out-Null

# Backup existing config
Write-Status "Backing up existing configuration..." "INFO"
$settings_backup = Backup-Config $settingsFile

# Merge configurations
Merge-SettingsJson

# Copy hook scripts to ~/.claude/hooks/
Write-Status "Installing hook scripts..." "INFO"
$hooksSource = "$scriptDir\..\hooks"
$hooksDest = "$claudeDir\hooks"

if (Test-Path $hooksSource) {
    New-Item -ItemType Directory -Force -Path $hooksDest | Out-Null
    Copy-Item "$hooksSource\pre-gemini-snapshot.ps1" $hooksDest -Force
    Write-Status "Hook scripts installed to: $hooksDest" "OK"
}

# Wire hooks into Claude Code settings
Wire-HooksToSettings

# Validate
Write-Status "" "INFO"
Write-Status "Validating installation..." "INFO"
Test-GeminiCLI | Out-Null

Write-Status "" "INFO"
Write-Status "╔════════════════════════════════════════╗" "OK"
Write-Status "║  GEMINI INTEGRATION INSTALLED        ║" "OK"
Write-Status "╚════════════════════════════════════════╝" "OK"

Write-Status "" "INFO"
Write-Status "✓ Hook scripts installed to: $hooksDest" "OK"
Write-Status "✓ Hooks wired into: $settingsFile" "OK"
Write-Status "✓ Approval workflow: ON-REQUEST" "OK"
Write-Status "" "INFO"

Write-Status "Backups saved:" "INFO"
if ($settings_backup) { Write-Status "  - $settings_backup" "INFO" }

Write-Status "" "INFO"
Write-Status "Ready to use! Try:" "INFO"
Write-Status "" "INFO"
Write-Status "  Analyze the API architecture and document design patterns" "CYAN"
Write-Status "" "INFO"
Write-Status "Claude Code will suggest Gemini for analysis tasks." "CYAN"
Write-Status "" "INFO"
Write-Status "To uninstall: .\Install-Gemini.ps1 -Uninstall" "WARN"
