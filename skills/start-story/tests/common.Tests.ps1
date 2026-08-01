#Requires -Version 5.1
<#
.SYNOPSIS
  Pester tests for start-story shared helpers in common.ps1.
#>
BeforeAll {
    . "$PSScriptRoot/../scripts/common.ps1"

    $script:Root = Join-Path $env:TEMP "start-story-common-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    New-Item -ItemType Directory -Path $script:Root -Force | Out-Null

    $script:ConfigPath = Join-Path $script:Root "config.json"
    @{
        organization = "contoso"
        project      = "Atlas"
        baseBranch   = "develop"
        branchPrefix = "feature"
        pat          = "SHOULD_BE_IGNORED_EVEN_IF_PRESENT"
        repos        = @{
            "Atlas-Api" = @{
                path     = (Join-Path $script:Root "api")
                solution = "Api.sln"
                kind     = "dotnet"
            }
        }
    } | ConvertTo-Json -Depth 5 | Set-Content -Path $script:ConfigPath

    New-Item -ItemType Directory -Path (Join-Path $script:Root "api") -Force | Out-Null
    Set-Content -Path (Join-Path $script:Root "api/Api.sln") -Value "solution"

    $script:SavedPat = $env:AZURE_DEVOPS_PAT
    $env:AZURE_DEVOPS_PAT = $null
}

AfterAll {
    $env:AZURE_DEVOPS_PAT = $script:SavedPat
    Remove-Item -Path $script:Root -Recurse -Force -ErrorAction SilentlyContinue
}

Describe "config resolution" {
    It "reads a scalar from config" {
        (Get-StartStoryConfigValue -Key "organization" -ConfigPath $script:ConfigPath) | Should -Be "contoso"
    }

    It "lets an ADO_ environment variable win" {
        $env:ADO_BASEBRANCH = "release/2.1"
        try {
            (Get-StartStoryConfigValue -Key "baseBranch" -ConfigPath $script:ConfigPath) | Should -Be "release/2.1"
        }
        finally {
            Remove-Item Env:ADO_BASEBRANCH -ErrorAction SilentlyContinue
        }
    }

    It "does not read a PAT from config.json" {
        Get-StartStoryPat | Should -BeNullOrEmpty
    }

    It "reads AZURE_DEVOPS_PAT from the environment" {
        $env:AZURE_DEVOPS_PAT = "env-token-for-test"
        try {
            (Get-StartStoryPat) | Should -Be "env-token-for-test"
        }
        finally {
            $env:AZURE_DEVOPS_PAT = $null
        }
    }

    It "refuses to build auth headers without a PAT" {
        { Get-StartStoryAuthHeaders -ConfigPath $script:ConfigPath } | Should -Throw
    }
}

Describe "config location priority" {
    It "exposes a user config directory outside skill installs" {
        $dir = Get-StartStoryUserConfigDir
        $dir | Should -Match "corelogic-ai-skills"
        $dir | Should -Not -Match "[/\\]skills[/\\]start-story$"
    }

    It "prefers repository config when present" {
        $repoRoot = Join-Path $script:Root "priority-repo"
        $repoCfgDir = Join-Path $repoRoot ".corelogic-ai-skills/start-story"
        New-Item -ItemType Directory -Path $repoCfgDir -Force | Out-Null
        $repoConfig = Join-Path $repoCfgDir "config.json"
        @{ organization = "repo-org"; project = "Repo" } |
            ConvertTo-Json | Set-Content $repoConfig

        Push-Location $repoRoot
        try {
            $found = Find-StartStoryRepoConfigPath
            (Resolve-Path $found).Path | Should -Be (Resolve-Path $repoConfig).Path
            $resolved = Get-StartStoryDefaultConfigPath
            (Resolve-Path $resolved).Path | Should -Be (Resolve-Path $repoConfig).Path
            (Get-StartStoryConfigValue -Key "organization" -ConfigPath $resolved) | Should -Be "repo-org"
        }
        finally {
            Pop-Location
        }
    }
}

Describe "ignore matching" {
    BeforeAll {
        $script:Patterns = Get-StartStoryIgnorePatterns -ConfigPath $script:ConfigPath
    }

    It "ignores build output at any depth" {
        (Test-StartStoryIgnored -Path "src/Web/obj/Debug/App.dll" -Patterns $script:Patterns) | Should -BeTrue
    }

    It "ignores env files by name" {
        (Test-StartStoryIgnored -Path "web/.env" -Patterns $script:Patterns) | Should -BeTrue
    }

    It "leaves source files alone" {
        (Test-StartStoryIgnored -Path "src/Web/Controllers/HomeController.cs" -Patterns $script:Patterns) | Should -BeFalse
    }
}

Describe "branch naming" {
    It "slugifies the title" {
        (Get-StartStoryBranchName -WorkItemId 1234 -Title "Fix the broken cell!") |
            Should -Be "story/1234-fix-the-broken-cell"
    }

    It "honours the configured prefix" {
        $prefix = Get-StartStoryBranchPrefix -ConfigPath $script:ConfigPath
        $prefix | Should -Be "feature"
        (Get-StartStoryBranchName -WorkItemId 9 -Title "x" -Prefix $prefix) | Should -Be "feature/9-x"
    }
}

Describe "validation status" {
    It "marks automated success as passed" {
        $r = [ordered]@{ passed = $true; requiresManualReview = $false; status = "failed" }
        Set-StartStoryValidationStatus -Result $r
        $r.status | Should -Be "passed"
    }

    It "marks manual review distinctly from failure" {
        $r = [ordered]@{ passed = $false; requiresManualReview = $true; status = "failed" }
        Set-StartStoryValidationStatus -Result $r
        $r.status | Should -Be "manual-review-required"
    }
}
