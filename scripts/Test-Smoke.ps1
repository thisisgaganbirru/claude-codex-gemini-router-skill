#!/usr/bin/env pwsh
<#
.SYNOPSIS
Run lightweight smoke tests for routing and safety behavior.
#>

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Get-Item $scriptDir).Parent.FullName

function Assert-Equal {
    param(
        [string]$Name,
        $Expected,
        $Actual
    )

    if ($Expected -ne $Actual) {
        throw "$Name failed. Expected '$Expected', got '$Actual'"
    }

    Write-Host "[OK] $Name" -ForegroundColor Green
}

function Invoke-SafetyHook {
    param([string]$Command)

    $payload = @{
        tool_name = "Bash"
        tool_input = @{
            command = $Command
        }
    } | ConvertTo-Json -Depth 5 -Compress

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = "pwsh"
    $psi.ArgumentList.Add("-NoProfile")
    $psi.ArgumentList.Add("-File")
    $psi.ArgumentList.Add((Join-Path $projectRoot "hooks\pre-tool-safety.ps1"))
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false

    $process = [System.Diagnostics.Process]::Start($psi)
    $process.StandardInput.Write($payload)
    $process.StandardInput.Close()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    return @{
        ExitCode = $process.ExitCode
        Stdout = $stdout
        Stderr = $stderr
    }
}

$low = & "$scriptDir\Analyze-TaskComplexity.ps1" "Fix login bug" | ConvertFrom-Json
Assert-Equal "LOW routing" "LOW" $low.tier
Assert-Equal "LOW keyword count text" $true ($low.reasoning -match "LOW=1")

$high = & "$scriptDir\Analyze-TaskComplexity.ps1" "Refactor authentication module" | ConvertFrom-Json
Assert-Equal "HIGH routing" "HIGH" $high.tier
Assert-Equal "Zero counts are preserved" $true ($high.reasoning -match "MEDIUM=0, LOW=0")

$blocked = Invoke-SafetyHook "rm -rf /tmp/example"
Assert-Equal "Dangerous command blocked" 1 $blocked.ExitCode
Assert-Equal "Block response emitted" $true ($blocked.Stdout -match '"decision"\s*:\s*"block"')

$allowed = Invoke-SafetyHook "Get-ChildItem"
Assert-Equal "Safe command allowed" 0 $allowed.ExitCode

Write-Host "[OK] Smoke tests passed" -ForegroundColor Green
