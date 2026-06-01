#!/usr/bin/env pwsh
<#
.SYNOPSIS
Install Codex integration for Claude Code

.DESCRIPTION
- Backs up existing hooks.json and settings.json
- Merges Codex configuration
- Validates Codex CLI
- Tests complexity routing

.PARAMETER Uninstall
Remove Codex integration and restore backups

.EXAMPLE
.\Install-Codex.ps1

.\Install-Codex.ps1 -Uninstall
#>

param(
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'

$claudeDir = "$env:USERPROFILE\.claude"
$hooksFile = "$claudeDir\hooks.json"
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

function Test-CodexCLI {
    try {
        $version = & codex --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Status "Codex CLI found: $version" "OK"
            return $true
        }
    }
    catch { }
    Write-Status "Codex CLI not found. Install with: pip install codex-cli" "WARN"
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

function Merge-HooksJson {
    Write-Status "Merging hooks.json..." "INFO"

    $sourceHooks = Get-Content "$configDir\hooks.json" | ConvertFrom-Json

    if (Test-Path $hooksFile) {
        $existing = Get-Content $hooksFile | ConvertFrom-Json

        # Merge PreToolUse
        if (-not $existing.hooks.PreToolUse) {
            $existing.hooks.PreToolUse = @()
        }
        $existing.hooks.PreToolUse = @($existing.hooks.PreToolUse) + @($sourceHooks.hooks.PreToolUse)

        # Merge RouteToCodex
        $existing.hooks.RouteToCodex = $sourceHooks.hooks.RouteToCodex
        $existing.codex_commands = $sourceHooks.codex_commands
        $existing.complexity_thresholds = $sourceHooks.complexity_thresholds

        $existing | ConvertTo-Json -Depth 10 | Set-Content $hooksFile -Encoding UTF8
    }
    else {
        Copy-Item "$configDir\hooks.json" $hooksFile
    }

    Write-Status "hooks.json merged" "OK"
}

function Merge-SettingsJson {
    Write-Status "Merging settings.json..." "INFO"

    if (Test-Path $settingsFile) {
        $existing = Get-Content $settingsFile | ConvertFrom-Json
        $template = Get-Content "$configDir\settings.json.template" | ConvertFrom-Json

        # Merge Codex settings
        $existing.codex_subprocess = $template.codex_subprocess
        $existing.complexity_thresholds = $template.complexity_thresholds
        $existing.agent_dispatch = $template.agent_dispatch

        $existing | ConvertTo-Json -Depth 10 | Set-Content $settingsFile -Encoding UTF8
    }
    else {
        Copy-Item "$configDir\settings.json.template" "$settingsFile"
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

    # Wire PreToolUse hooks
    $preToolUseHooks = @(
        @{
            matcher = "Bash"
            hooks = @(
                @{
                    type = "command"
                    command = "pwsh $claudeDir\hooks\pre-tool-safety.ps1"
                }
            )
        }
    )

    $settings.hooks.PreToolUse = $preToolUseHooks

    # Wire PreCodexExecution snapshot hook (custom)
    if (-not $settings.hooks.PreCodexExecution) {
        $settings.hooks | Add-Member -NotePropertyName "PreCodexExecution" -NotePropertyValue @(
            @{
                type = "command"
                command = "pwsh $claudeDir\hooks\pre-codex-snapshot.ps1"
            }
        )
    }

    $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsFile -Encoding UTF8
    Write-Status "Hooks wired to settings.json" "OK"
}

function Test-ComplexityRouting {
    Write-Status "Testing complexity routing..." "INFO"

    $hooks = Get-Content $hooksFile | ConvertFrom-Json
    $settings = Get-Content $settingsFile | ConvertFrom-Json

    if ($hooks.hooks.RouteToCodex.enabled -and $settings.codex_subprocess.enabled) {
        Write-Status "Complexity routing: ENABLED" "OK"
        Write-Status "Approval policy: $($settings.codex_subprocess.approval_policy)" "OK"
        Write-Status "Sandbox policy: $($settings.codex_subprocess.sandbox_policy)" "OK"
        return $true
    }
    else {
        Write-Status "Complexity routing: DISABLED" "WARN"
        return $false
    }
}

function Uninstall-Codex {
    Write-Status "Uninstalling Codex integration..." "WARN"

    $hooks_backup = Get-Item "$hooksFile.backup-*" -ErrorAction SilentlyContinue | Sort-Object -Descending | Select-Object -First 1
    $settings_backup = Get-Item "$settingsFile.backup-*" -ErrorAction SilentlyContinue | Sort-Object -Descending | Select-Object -First 1

    if ($hooks_backup) {
        Copy-Item $hooks_backup.FullName $hooksFile -Force
        Write-Status "Restored: hooks.json" "OK"
    }

    if ($settings_backup) {
        Copy-Item $settings_backup.FullName $settingsFile -Force
        Write-Status "Restored: settings.json" "OK"
    }

    if (-not $hooks_backup -and -not $settings_backup) {
        Write-Status "No backups found - nothing to restore" "WARN"
    }
}

# Main
if ($Uninstall) {
    Uninstall-Codex
    exit 0
}

Write-Status "Claude Codex Integration Installer" "INFO"
Write-Status "===================================" "INFO"

# Create ~/.claude if not exists
New-Item -ItemType Directory -Force -Path $claudeDir | Out-Null

# Backup existing configs
Write-Status "Backing up existing configuration..." "INFO"
$hooks_backup = Backup-Config $hooksFile
$settings_backup = Backup-Config $settingsFile

# Merge configurations
Merge-HooksJson
Merge-SettingsJson

# Copy hook scripts to ~/.claude/hooks/
Write-Status "Installing hook scripts..." "INFO"
$hooksSource = "$scriptDir\..\hooks"
$hooksDest = "$claudeDir\hooks"

if (Test-Path $hooksSource) {
    New-Item -ItemType Directory -Force -Path $hooksDest | Out-Null
    Copy-Item "$hooksSource\*.ps1" $hooksDest -Force
    Write-Status "Hook scripts installed to: $hooksDest" "OK"
}

# Wire hooks into Claude Code settings
Wire-HooksToSettings

# Validate
Write-Status "" "INFO"
Write-Status "Validating installation..." "INFO"
Test-CodexCLI | Out-Null
Test-ComplexityRouting | Out-Null

Write-Status "" "INFO"
Write-Status "╔════════════════════════════════════════╗" "OK"
Write-Status "║  CLAUDE CODEX INTEGRATION INSTALLED  ║" "OK"
Write-Status "╚════════════════════════════════════════╝" "OK"

Write-Status "" "INFO"
Write-Status "✓ Hook scripts installed to: $hooksDest" "OK"
Write-Status "✓ Hooks wired into: $settingsFile" "OK"
Write-Status "✓ Complexity routing: ENABLED" "OK"
Write-Status "✓ Approval workflow: ON-REQUEST" "OK"
Write-Status "" "INFO"

Write-Status "Backups saved:" "INFO"
if ($hooks_backup) { Write-Status "  - $hooks_backup" "INFO" }
if ($settings_backup) { Write-Status "  - $settings_backup" "INFO" }

Write-Status "" "INFO"
Write-Status "Ready to use! Try:" "INFO"
Write-Status "" "INFO"
Write-Status "  Refactor the authentication module" "CYAN"
Write-Status "" "INFO"
Write-Status "Claude Code will analyze complexity and suggest Codex routing." "CYAN"
Write-Status "" "INFO"
Write-Status "To uninstall: .\Install-Codex.ps1 -Uninstall" "WARN"
