<#
.SYNOPSIS
    Self-contained test suite for the start-story helper functions.

.DESCRIPTION
    No test framework required - run it anywhere PowerShell runs. Covers the
    pure logic: config resolution, repo/kind inference, ignore matching,
    branch naming, and profile lookup. Nothing here touches the network.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\scripts\common.ps1"

$script:Passed = 0
$script:Failed = 0
$script:CurrentGroup = ""

function Describe {
    param([string]$Name, [scriptblock]$Body)
    $script:CurrentGroup = $Name
    Write-Host ""
    Write-Host $Name -ForegroundColor Cyan
    & $Body
}

function It {
    param([string]$Name, [scriptblock]$Body)
    try {
        & $Body
        $script:Passed++
        Write-Host "  [pass] $Name" -ForegroundColor Green
    }
    catch {
        $script:Failed++
        Write-Host "  [FAIL] $Name" -ForegroundColor Red
        Write-Host "         $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Because)
    if ($Expected -ne $Actual) {
        throw "expected '$Expected' but got '$Actual'. $Because"
    }
}

function Assert-SamePath {
    param([string]$Expected, [string]$Actual, [string]$Because)
    # Normalize so Windows 8.3 TEMP paths (e.g. RUNNER~1) match long forms.
    function Get-CanonicalPath([string]$Path) {
        if (Test-Path -LiteralPath $Path) {
            return (Get-Item -LiteralPath $Path).FullName
        }
        return [System.IO.Path]::GetFullPath($Path)
    }
    $left = Get-CanonicalPath $Expected
    $right = Get-CanonicalPath $Actual
    if ($left -ne $right) {
        throw "expected path '$left' but got '$right'. $Because"
    }
}

function Assert-True {
    param($Condition, [string]$Because)
    if (-not $Condition) { throw "expected true. $Because" }
}

function Assert-Throws {
    param([scriptblock]$Body, [string]$MatchPattern)
    try {
        & $Body
    }
    catch {
        if ($MatchPattern -and $_.Exception.Message -notmatch $MatchPattern) {
            throw "threw, but message '$($_.Exception.Message)' did not match '$MatchPattern'"
        }
        return
    }
    throw "expected an exception, none was thrown"
}

# --- fixtures ---------------------------------------------------------------

$root = Join-Path $env:TEMP "start-story-tests-$([guid]::NewGuid().ToString('N').Substring(0,8))"
$dotnetRepo = Join-Path $root "atlas-api"
$nodeRepo = Join-Path $root "atlas-web"
$sqlRepo = Join-Path $root "atlas-db"
$loneRepo = Join-Path $root "lone-repo"

New-Item -ItemType Directory -Path $dotnetRepo, $nodeRepo, $sqlRepo, $loneRepo -Force | Out-Null
Set-Content -Path (Join-Path $dotnetRepo "Atlas.Api.sln") -Value "solution"
Set-Content -Path (Join-Path $nodeRepo "package.json") -Value "{}"
Set-Content -Path (Join-Path $loneRepo "Lone.sln") -Value "solution"

$configPath = Join-Path $root "config.json"
@{
    organization = "contoso"
    project      = "Atlas"
    baseBranch   = "develop"
    branchPrefix = "feature"
    pat          = "SHOULD_BE_IGNORED_EVEN_IF_PRESENT"
    repos        = @{
        "Atlas-Api"    = @{ path = $dotnetRepo; solution = "Atlas.Api.sln" }
        "Atlas-Web"    = @{ path = $nodeRepo }
        "Atlas-Db"     = @{ path = $sqlRepo; solution = $null }
        "Atlas-Forced" = @{ path = $dotnetRepo; solution = "Atlas.Api.sln"; kind = "custom"; validateCommand = "make check" }
    }
} | ConvertTo-Json -Depth 5 | Set-Content -Path $configPath

$emptyConfig = Join-Path $root "empty.json"
"{}" | Set-Content -Path $emptyConfig

$savedPat = $env:AZURE_DEVOPS_PAT
$env:AZURE_DEVOPS_PAT = $null

# --- tests ------------------------------------------------------------------

try {
    Describe "config resolution" {
        It "reads a scalar from config" {
            Assert-Equal "contoso" (Get-StartStoryConfigValue -Key "organization" -ConfigPath $configPath)
        }

        It "falls back to the supplied default" {
            Assert-Equal "fallback" (Get-StartStoryConfigValue -Key "nope" -Default "fallback" -ConfigPath $configPath)
        }

        It "lets an ADO_ environment variable win" {
            $env:ADO_BASEBRANCH = "release/2.1"
            try {
                Assert-Equal "release/2.1" (Get-StartStoryConfigValue -Key "baseBranch" -ConfigPath $configPath)
            }
            finally {
                Remove-Item Env:ADO_BASEBRANCH -ErrorAction SilentlyContinue
            }
        }

        It "throws an actionable error for a missing required value" {
            Assert-Throws { Get-StartStoryRequiredValue -Key "organization" -ConfigPath $emptyConfig } "Missing 'organization'"
        }

        It "does not read a PAT from config.json" {
            Assert-Equal $null (Get-StartStoryPat)
        }

        It "reads AZURE_DEVOPS_PAT from the environment" {
            $env:AZURE_DEVOPS_PAT = "env-token-for-test"
            try {
                Assert-Equal "env-token-for-test" (Get-StartStoryPat)
            }
            finally {
                $env:AZURE_DEVOPS_PAT = $null
            }
        }

        It "refuses to build auth headers without a PAT" {
            Assert-Throws { Get-StartStoryAuthHeaders -ConfigPath $configPath } "PAT not configured"
        }
    }

    Describe "config location priority" {
        It "exposes a user config directory outside skill installs" {
            $dir = Get-StartStoryUserConfigDir
            Assert-True ($dir -match "corelogic-ai-skills")
            Assert-equal $false ($dir -match '[/\\]skills[/\\]start-story$')
        }

        It "prefers repository config when present" {
            $repoRoot = Join-Path $root "priority-repo"
            $repoCfgDir = Join-Path $repoRoot ".corelogic-ai-skills\start-story"
            New-Item -ItemType Directory -Path $repoCfgDir -Force | Out-Null
            $repoConfig = Join-Path $repoCfgDir "config.json"
            @{ organization = "repo-org"; project = "Repo" } |
                ConvertTo-Json | Set-Content $repoConfig

            Push-Location $repoRoot
            try {
                Assert-SamePath $repoConfig (Find-StartStoryRepoConfigPath)
                Assert-SamePath $repoConfig (Get-StartStoryDefaultConfigPath)
                Assert-Equal "repo-org" (Get-StartStoryConfigValue -Key "organization" -ConfigPath (Get-StartStoryDefaultConfigPath))
            }
            finally {
                Pop-Location
            }
        }
    }

    Describe "repo and kind resolution" {
        It "resolves a relative solution against the repo path" {
            $repo = Get-StartStoryRepoConfig -RepoName "Atlas-Api" -ConfigPath $configPath
            Assert-SamePath (Join-Path $dotnetRepo "Atlas.Api.sln") $repo.solution
            Assert-Equal "dotnet" $repo.kind
            Assert-True $repo.configured
        }

        It "infers node from package.json" {
            Assert-Equal "node" (Get-StartStoryRepoConfig -RepoName "Atlas-Web" -ConfigPath $configPath).kind
        }

        It "treats a configured repo with no solution as manual" {
            $repo = Get-StartStoryRepoConfig -RepoName "Atlas-Db" -ConfigPath $configPath
            Assert-Equal "manual" $repo.kind
            Assert-Equal $null $repo.solution
        }

        It "lets an explicit kind override inference" {
            $repo = Get-StartStoryRepoConfig -RepoName "Atlas-Forced" -ConfigPath $configPath
            Assert-Equal "custom" $repo.kind
            Assert-Equal "make check" $repo.validateCommand
        }

        It "discovers a lone solution for an unconfigured repo" {
            Push-Location $loneRepo
            try {
                $repo = Get-StartStoryRepoConfig -RepoName "Not-In-Config" -ConfigPath $configPath
                Assert-Equal $false $repo.configured
                Assert-Equal "dotnet" $repo.kind
                Assert-SamePath (Join-Path $loneRepo "Lone.sln") $repo.solution
            }
            finally { Pop-Location }
        }
    }

    Describe "ignore matching" {
        $patterns = Get-StartStoryIgnorePatterns -ConfigPath $configPath

        It "uses the built-in defaults when config says nothing" {
            Assert-True ($patterns -contains "**/obj/**")
        }

        It "ignores build output at the repo root" {
            Assert-True (Test-StartStoryIgnored -Path "obj/Debug/App.dll" -Patterns $patterns)
        }

        It "ignores build output at any depth" {
            Assert-True (Test-StartStoryIgnored -Path "src/Web/obj/Debug/App.dll" -Patterns $patterns)
            Assert-True (Test-StartStoryIgnored -Path "src/Web/bin/App.dll" -Patterns $patterns)
        }

        It "ignores local settings and env files by file name" {
            Assert-True (Test-StartStoryIgnored -Path "src/Web/appsettings.Development.json" -Patterns $patterns)
            Assert-True (Test-StartStoryIgnored -Path "web/.env" -Patterns $patterns)
        }

        It "leaves real source files alone" {
            Assert-Equal $false (Test-StartStoryIgnored -Path "src/Web/Controllers/HomeController.cs" -Patterns $patterns)
            Assert-Equal $false (Test-StartStoryIgnored -Path "wwwroot/js/app.js" -Patterns $patterns)
        }

        It "handles windows-style separators" {
            Assert-True (Test-StartStoryIgnored -Path "src\Web\obj\App.dll" -Patterns $patterns)
        }
    }

    Describe "branch naming" {
        It "slugifies the title" {
            Assert-Equal "story/1234-fix-the-broken-cell" (Get-StartStoryBranchName -WorkItemId 1234 -Title "Fix the broken cell!")
        }

        It "collapses punctuation and trims separators" {
            Assert-Equal "story/7-a-b" (Get-StartStoryBranchName -WorkItemId 7 -Title "  --A & B--  ")
        }

        It "honours the configured prefix" {
            $prefix = Get-StartStoryBranchPrefix -ConfigPath $configPath
            Assert-Equal "feature" $prefix
            Assert-Equal "feature/9-x" (Get-StartStoryBranchName -WorkItemId 9 -Title "x" -Prefix $prefix)
        }

        It "truncates long titles without a trailing dash" {
            $name = Get-StartStoryBranchName -WorkItemId 5 -Title ("word " * 40)
            Assert-True ($name.Length -le ("story/5-".Length + 60))
            Assert-Equal $false $name.EndsWith("-")
        }

        It "survives a title with nothing sluggable" {
            Assert-Equal "story/42" (Get-StartStoryBranchName -WorkItemId 42 -Title "!!!")
        }
    }

    Describe "profile lookup" {
        It "finds a profile named in config" {
            $withProfile = Join-Path $root "profile.json"
            @{ project = "Atlas"; profile = "example-atlas" } | ConvertTo-Json | Set-Content $withProfile
            Assert-Equal "example-atlas" (Get-StartStoryProfile -ConfigPath $withProfile).name
        }

        It "falls back to a profile named after the project" {
            $byProject = Join-Path $root "byproject.json"
            @{ project = "Template" } | ConvertTo-Json | Set-Content $byProject
            Assert-Equal "template" (Get-StartStoryProfile -ConfigPath $byProject).name
        }

        It "returns nothing when no profile file exists" {
            Assert-Equal $null (Get-StartStoryProfile -ConfigPath $configPath)
        }
    }

    Describe "PR source branch guards" {
        It "rejects the target branch" {
            Assert-Throws {
                Assert-StartStoryPrSourceBranch -SourceBranch "main" -BaseBranch "main" -WorkItemId 9 -Prefix "story"
            } "target branch"
        }

        It "rejects main even when the base is elsewhere" {
            Assert-Throws {
                Assert-StartStoryPrSourceBranch -SourceBranch "main" -BaseBranch "develop" -WorkItemId 9 -Prefix "story"
            } "protected branch"
        }

        It "rejects a branch that does not match the work item" {
            Assert-Throws {
                Assert-StartStoryPrSourceBranch -SourceBranch "story/99-other" -BaseBranch "main" -WorkItemId 9 -Prefix "story"
            } "does not match work item"
        }

        It "accepts a matching story branch" {
            Assert-StartStoryPrSourceBranch -SourceBranch "story/9-fix-login" -BaseBranch "main" -WorkItemId 9 -Prefix "story"
        }
    }

    Describe "validation status" {
        It "marks automated success as passed" {
            $r = [ordered]@{ passed = $true; requiresManualReview = $false; status = "failed" }
            Set-StartStoryValidationStatus -Result $r
            Assert-Equal "passed" $r.status
        }

        It "marks manual review distinctly from failure" {
            $r = [ordered]@{ passed = $false; requiresManualReview = $true; status = "failed" }
            Set-StartStoryValidationStatus -Result $r
            Assert-Equal "manual-review-required" $r.status
        }

        It "marks a failed custom/build path as failed" {
            $r = [ordered]@{ passed = $false; requiresManualReview = $false; status = "passed" }
            Set-StartStoryValidationStatus -Result $r
            Assert-Equal "failed" $r.status
        }
    }

    Describe "git working tree and branch reuse" {
        $gitRoot = Join-Path $root "git-repo"
        New-Item -ItemType Directory -Path $gitRoot | Out-Null
        Push-Location $gitRoot
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            git init -b main 2>&1 | Out-Null
            git config user.email "test@example.com"
            git config user.name "Test"
            Set-Content -Path "README.md" -Value "seed"
            git add README.md 2>&1 | Out-Null
            git commit -m "seed" 2>&1 | Out-Null
            $ErrorActionPreference = $prevEap

            It "rejects a dirty working tree before branching" {
                Set-Content -Path "dirty.txt" -Value "nope"
                Assert-Throws { Assert-StartStoryCleanWorkingTree } "uncommitted changes"
                Remove-Item "dirty.txt" -Force
            }

            It "allows a clean working tree" {
                Assert-StartStoryCleanWorkingTree
            }

            It "reuses an existing local story branch via create-branch.ps1" {
                $ErrorActionPreference = "Continue"
                git checkout -b "story/55-existing" 2>&1 | Out-Null
                $ErrorActionPreference = $prevEap

                $cfg = Join-Path $root "git-config.json"
                @{ organization = "contoso"; project = "Atlas"; baseBranch = "main" } |
                    ConvertTo-Json | Set-Content $cfg

                $outFile = Join-Path $root "branch-result.json"
                $scriptPath = (Resolve-Path "$PSScriptRoot\..\scripts\create-branch.ps1").Path
                $runner = Join-Path $root "run-create-branch.ps1"
                @"
Set-Location -LiteralPath '$gitRoot'
& '$scriptPath' -WorkItemId 55 -Title 'Existing' -ConfigPath '$cfg' |
    Set-Content -LiteralPath '$outFile' -Encoding utf8
"@ | Set-Content -LiteralPath $runner -Encoding utf8

                & powershell -NoProfile -File $runner
                if ($LASTEXITCODE -ne 0) { throw "create-branch.ps1 exited with $LASTEXITCODE" }
                if (-not (Test-Path $outFile)) { throw "create-branch produced no output file" }

                $json = Get-Content -LiteralPath $outFile -Raw | ConvertFrom-Json
                Assert-Equal "reuse" $json.action
                Assert-Equal "story/55-existing" $json.branch
            }
        }
        finally {
            $ErrorActionPreference = $prevEap
            Pop-Location
        }
    }

    Describe "validate.ps1 outcomes" {
        function Invoke-ValidateInRepo {
            param([string]$RepoDir, [string]$RemoteName, [hashtable]$RepoEntry)
            $ErrorActionPreference = "Continue"
            if (-not (Test-Path (Join-Path $RepoDir ".git"))) {
                Push-Location $RepoDir
                try {
                    git init -b main 2>&1 | Out-Null
                    git remote add origin "https://dev.azure.com/contoso/Atlas/_git/$RemoteName" 2>&1 | Out-Null
                }
                finally { Pop-Location }
            }

            $cfg = Join-Path $root "validate-$RemoteName.json"
            @{
                organization = "contoso"
                project      = "Atlas"
                repos        = @{ $RemoteName = $RepoEntry }
            } | ConvertTo-Json -Depth 5 | Set-Content $cfg

            $outFile = Join-Path $root "validate-$RemoteName-out.json"
            $scriptPath = (Resolve-Path "$PSScriptRoot\..\scripts\validate.ps1").Path
            $runner = Join-Path $root "run-validate-$RemoteName.ps1"
            @"
Set-Location -LiteralPath '$RepoDir'
& '$scriptPath' -ConfigPath '$cfg' | Set-Content -LiteralPath '$outFile' -Encoding utf8
exit `$LASTEXITCODE
"@ | Set-Content -LiteralPath $runner -Encoding utf8

            & powershell -NoProfile -File $runner
            $code = $LASTEXITCODE
            $json = Get-Content -LiteralPath $outFile -Raw | ConvertFrom-Json
            return [pscustomobject]@{ ExitCode = $code; Result = $json }
        }

        It "returns manual-review-required without claiming pass" {
            $run = Invoke-ValidateInRepo -RepoDir $sqlRepo -RemoteName "Atlas-Db" -RepoEntry @{
                path = $sqlRepo; kind = "manual"; solution = $null
            }
            Assert-Equal 0 $run.ExitCode
            Assert-Equal "manual-review-required" $run.Result.status
            Assert-Equal $false $run.Result.passed
            Assert-True $run.Result.requiresManualReview
        }

        It "fails a custom validateCommand that exits non-zero" {
            $run = Invoke-ValidateInRepo -RepoDir $dotnetRepo -RemoteName "Atlas-Forced" -RepoEntry @{
                path = $dotnetRepo; kind = "custom"; validateCommand = "cmd /c exit 7"
            }
            Assert-equal 1 $run.ExitCode
            Assert-Equal "failed" $run.Result.status
            Assert-Equal $false $run.Result.passed
        }

        It "fails when a dotnet repo has no solution" {
            $empty = Join-Path $root "no-sln"
            New-Item -ItemType Directory -Path $empty -Force | Out-Null
            $run = Invoke-ValidateInRepo -RepoDir $empty -RemoteName "No-Sln" -RepoEntry @{
                path = $empty; kind = "dotnet"; solution = $null
            }
            Assert-Equal 1 $run.ExitCode
            Assert-Equal "failed" $run.Result.status
        }
    }
}
finally {
    $env:AZURE_DEVOPS_PAT = $savedPat
    Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "$script:Passed passed, $script:Failed failed" -ForegroundColor $(if ($script:Failed) { "Red" } else { "Green" })
if ($script:Failed -gt 0) { exit 1 }
exit 0
