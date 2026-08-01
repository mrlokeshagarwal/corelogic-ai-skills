param(
    [string]$ConfigPath,
    [switch]$SkipTests
)

$ErrorActionPreference = "Continue"
. "$PSScriptRoot\common.ps1"
if (-not $ConfigPath) { $ConfigPath = Get-StartStoryDefaultConfigPath }

function Get-Tail {
    param([string]$Text, [int]$Lines = 20, [string]$Filter)
    $all = $Text -split "`n"
    if ($Filter) {
        $matched = $all | Where-Object { $_ -match $Filter }
        if ($matched) { $all = $matched }
    }
    return (($all | Select-Object -Last $Lines) -join "`n").Trim()
}

function Invoke-ValidateCommand {
    param([string]$Command)
    # Prefer a cross-platform shell. Windows PowerShell often has cmd; pwsh/Linux use sh.
    if ($IsWindows -or $env:OS -match 'Windows') {
        if (Get-Command cmd.exe -ErrorAction SilentlyContinue) {
            $output = & cmd.exe /c "$Command 2>&1" | Out-String
            return [pscustomobject]@{ exitCode = $LASTEXITCODE; output = $output }
        }
    }
    $output = & /bin/sh -c "$Command 2>&1" | Out-String
    return [pscustomobject]@{ exitCode = $LASTEXITCODE; output = $output }
}

$repoName = Get-GitRepoName

if (-not $repoName) {
    $result = [ordered]@{
        repository           = $null
        kind                 = $null
        solution             = $null
        status               = "failed"
        restore              = "skipped"
        build                = "skipped"
        test                 = "skipped"
        passed               = $false
        requiresManualReview = $false
        errors               = @("Not in a git repository with an origin remote.")
    }
    Complete-StartStoryValidationResult -Result $result
}

$repo = Get-StartStoryRepoConfig -RepoName $repoName -ConfigPath $ConfigPath

$result = [ordered]@{
    repository           = $repoName
    kind                 = $repo.kind
    solution             = $repo.solution
    status               = "failed"
    restore              = "skipped"
    build                = "skipped"
    test                 = "skipped"
    passed               = $false
    requiresManualReview = $false
    errors               = @()
}

Push-Location $repo.path
try {
    switch ($repo.kind) {

        "manual" {
            $result.build = "n/a"
            $result.test = "n/a"
            $result.requiresManualReview = $true
            $result.errors += "No automated validation for this repo kind - perform a manual review (e.g. SQL scripts) and report what you checked."
            break
        }

        "node" {
            $buildCmd = if ($repo.buildCommand) { $repo.buildCommand } else { "npm run build --if-present" }
            $testCmd = if ($repo.testCommand) { $repo.testCommand } else { "npm test --if-present" }

            $build = Invoke-ValidateCommand -Command $buildCmd
            if ($build.exitCode -ne 0) {
                $result.build = "failed"
                $result.errors += Get-Tail -Text $build.output -Lines 20
                break
            }
            $result.build = "passed"

            if ($SkipTests -or $repo.skipTests) { $result.passed = $true; break }

            $test = Invoke-ValidateCommand -Command $testCmd
            if ($test.exitCode -ne 0) {
                $result.test = "failed"
                $result.errors += Get-Tail -Text $test.output -Lines 20
                break
            }
            $result.test = "passed"
            $result.passed = $true
            break
        }

        "custom" {
            if (-not $repo.validateCommand) {
                $result.errors += "kind 'custom' requires 'validateCommand' in config for repo '$repoName'."
                break
            }
            $run = Invoke-ValidateCommand -Command $repo.validateCommand
            if ($run.exitCode -ne 0) {
                $result.build = "failed"
                $result.errors += Get-Tail -Text $run.output -Lines 20
                break
            }
            $result.build = "passed"
            $result.passed = $true
            break
        }

        default {
            if ($repo.validateCommand) {
                $run = Invoke-ValidateCommand -Command $repo.validateCommand
                if ($run.exitCode -ne 0) {
                    $result.build = "failed"
                    $result.errors += Get-Tail -Text $run.output -Lines 20
                    break
                }
                $result.build = "passed"
                $result.passed = $true
                break
            }

            if (-not $repo.solution) {
                $result.errors += "No solution found for '$repoName'. Set repos.$repoName.solution (or kind/validateCommand) in $ConfigPath."
                break
            }
            if (-not (Test-Path $repo.solution)) {
                $result.errors += "Solution not found: $($repo.solution)"
                break
            }

            $restoreOut = & dotnet restore $repo.solution --nologo 2>&1 | Out-String
            if ($LASTEXITCODE -ne 0) {
                $result.restore = "failed"
                $result.errors += Get-Tail -Text $restoreOut -Lines 15
                break
            }
            $result.restore = "passed"

            $buildOut = & dotnet build $repo.solution --no-restore -v q --nologo /clp:ErrorsOnly 2>&1 | Out-String
            if ($LASTEXITCODE -ne 0) {
                $result.build = "failed"
                $errLines = Get-Tail -Text $buildOut -Lines 20 -Filter "error|Build FAILED"
                if (-not $errLines) { $errLines = Get-Tail -Text $buildOut -Lines 20 }
                $result.errors += $errLines
                break
            }
            $result.build = "passed"

            $testProjects = Get-ChildItem -Recurse -Filter "*Tests*.csproj" -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -notmatch '\\obj\\|\\bin\\' }

            if ($SkipTests -or $repo.skipTests -or -not $testProjects) {
                $result.passed = $true
                break
            }

            $testOut = & dotnet test $repo.solution --no-build --nologo -v q 2>&1 | Out-String
            if ($LASTEXITCODE -ne 0) {
                $result.test = "failed"
                $result.errors += Get-Tail -Text $testOut -Lines 20
                break
            }
            $result.test = "passed"
            $result.passed = $true
        }
    }
}
finally {
    Pop-Location
}

Complete-StartStoryValidationResult -Result $result
