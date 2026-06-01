#!/usr/bin/env pwsh
<#
.SYNOPSIS
Pre-execution safety check - blocks forbidden operations

.DESCRIPTION
Reads forbidden patterns from config/forbidden-operations.txt
Checks incoming commands, blocks if dangerous, allows if safe.

Hook input JSON:
{
  "tool_name": "Bash",
  "tool_input": {
    "command": "rm -rf /"
  }
}

Exit with 0 = allow
Exit with 1 + JSON = block
#>

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Get-Item $scriptDir).Parent.FullName
$hooksConfigPath = Join-Path $projectRoot "config\hooks.json"

# Load forbidden regex patterns from machine-readable hook config.
if (-not (Test-Path $hooksConfigPath)) {
    Write-Error "Hooks config not found: $hooksConfigPath"
    exit 0  # Allow on config error (don't block everything)
}

try {
    $hooksConfig = Get-Content $hooksConfigPath -Raw | ConvertFrom-Json
    $bashRule = @($hooksConfig.hooks.PreToolUse) |
        Where-Object { $_.matcher -eq "Bash" -and $_.enabled -eq $true } |
        Select-Object -First 1
    $forbidden_patterns = @($bashRule.forbidden_patterns)
}
catch {
    Write-Error "Failed to load forbidden patterns: $_"
    exit 0
}

if ($forbidden_patterns.Count -eq 0) {
    Write-Error "No forbidden patterns loaded from hooks config"
    exit 0  # Allow on config error
}

# Read hook input from stdin
$input_json = [Console]::In.ReadToEnd()

try {
    $hookInput = $input_json | ConvertFrom-Json
    $command = $hookInput.tool_input.command
}
catch {
    # Invalid JSON input, allow
    exit 0
}

# Check against patterns
$blocked = $false
$matched_pattern = ""

foreach ($pattern in $forbidden_patterns) {
    try {
        if ($command -match $pattern) {
            $blocked = $true
            $matched_pattern = $pattern
            break
        }
    }
    catch {
        # Invalid regex, skip
        continue
    }
}

if ($blocked) {
    $response = @{
        decision = "block"
        reason   = "Forbidden operation detected: $matched_pattern"
    } | ConvertTo-Json
    Write-Output $response
    exit 1
}

# Safe to execute
exit 0
