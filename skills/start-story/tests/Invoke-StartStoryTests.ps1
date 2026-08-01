#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Run start-story tests via Pester when available, otherwise the self-contained runner.
#>
[CmdletBinding()]
param(
    [string]$Path = $PSScriptRoot
)

$ErrorActionPreference = "Stop"

$pester = Get-Module -ListAvailable -Name Pester |
    Where-Object { $_.Version -ge [version]"5.0.0" } |
    Select-Object -First 1

if ($pester) {
    Import-Module Pester -MinimumVersion 5.0.0
    $config = New-PesterConfiguration
    $config.Run.Path = $Path
    $config.Run.Exit = $true
    $config.Output.Verbosity = "Detailed"
    # Prefer explicit *.Tests.ps1 files when using Pester.
    $config.Run.Path = @(
        Join-Path $Path "common.Tests.ps1"
        Join-Path $Path "detect-repo.Tests.ps1"
        Join-Path $Path "create-branch.Tests.ps1"
        Join-Path $Path "create-pr.Tests.ps1"
        Join-Path $Path "validate.Tests.ps1"
    )
    Invoke-Pester -Configuration $config
    return
}

Write-Host "Pester 5+ not available; running self-contained skills/start-story/tests/run-tests.ps1" -ForegroundColor Yellow
& (Join-Path $Path "run-tests.ps1")
exit $LASTEXITCODE
