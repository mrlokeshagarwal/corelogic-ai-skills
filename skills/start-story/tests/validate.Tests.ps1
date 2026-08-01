#Requires -Version 5.1
BeforeAll {
    $script:Root = Join-Path $env:TEMP "start-story-validate-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    $script:SqlRepo = Join-Path $script:Root "atlas-db"
    $script:CustomRepo = Join-Path $script:Root "atlas-custom"
    New-Item -ItemType Directory -Path $script:SqlRepo, $script:CustomRepo -Force | Out-Null
}

AfterAll {
    Remove-Item -Path $script:Root -Recurse -Force -ErrorAction SilentlyContinue
}

function Invoke-ValidateInRepo {
    param(
        [string]$RepoDir,
        [string]$RemoteName,
        [hashtable]$RepoEntry
    )

    if (-not (Test-Path (Join-Path $RepoDir ".git"))) {
        Push-Location $RepoDir
        try {
            git init -b main 2>$null | Out-Null
            git remote add origin "https://dev.azure.com/contoso/Atlas/_git/$RemoteName" 2>$null | Out-Null
        }
        finally {
            Pop-Location
        }
    }

    $cfg = Join-Path $script:Root "validate-$RemoteName.json"
    @{
        organization = "contoso"
        project      = "Atlas"
        repos        = @{ $RemoteName = $RepoEntry }
    } | ConvertTo-Json -Depth 5 | Set-Content $cfg

    Push-Location $RepoDir
    try {
        $jsonText = & "$PSScriptRoot/../scripts/validate.ps1" -ConfigPath $cfg | Out-String
        $code = $LASTEXITCODE
        $json = $jsonText | ConvertFrom-Json
        return [pscustomobject]@{ ExitCode = $code; Result = $json }
    }
    finally {
        Pop-Location
    }
}

Describe "validate.ps1 outcomes" {
    It "returns manual-review-required without claiming pass" {
        $run = Invoke-ValidateInRepo -RepoDir $script:SqlRepo -RemoteName "Atlas-Db" -RepoEntry @{
            path     = $script:SqlRepo
            kind     = "manual"
            solution = $null
        }
        $run.ExitCode | Should -Be 0
        $run.Result.status | Should -Be "manual-review-required"
        $run.Result.passed | Should -BeFalse
        $run.Result.requiresManualReview | Should -BeTrue
    }

    It "fails a custom validateCommand that exits non-zero" {
        $onWindows = ($PSVersionTable.PSVersion.Major -lt 6) -or $IsWindows
        $failCmd = if ($onWindows) { "cmd /c exit 7" } else { "sh -c 'exit 7'" }
        $run = Invoke-ValidateInRepo -RepoDir $script:CustomRepo -RemoteName "Atlas-Forced" -RepoEntry @{
            path            = $script:CustomRepo
            kind            = "custom"
            validateCommand = $failCmd
        }
        $run.ExitCode | Should -Be 1
        $run.Result.status | Should -Be "failed"
        $run.Result.passed | Should -BeFalse
    }
}
