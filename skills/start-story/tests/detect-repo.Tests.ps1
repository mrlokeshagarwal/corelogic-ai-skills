#Requires -Version 5.1
BeforeAll {
    . "$PSScriptRoot/../scripts/common.ps1"

    $script:Root = Join-Path $env:TEMP "start-story-detect-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    $script:DotnetRepo = Join-Path $script:Root "atlas-api"
    $script:NodeRepo = Join-Path $script:Root "atlas-web"
    $script:SqlRepo = Join-Path $script:Root "atlas-db"
    $script:LoneRepo = Join-Path $script:Root "lone-repo"
    New-Item -ItemType Directory -Path $script:DotnetRepo, $script:NodeRepo, $script:SqlRepo, $script:LoneRepo -Force | Out-Null
    Set-Content -Path (Join-Path $script:DotnetRepo "Atlas.Api.sln") -Value "solution"
    Set-Content -Path (Join-Path $script:NodeRepo "package.json") -Value "{}"
    Set-Content -Path (Join-Path $script:LoneRepo "Lone.sln") -Value "solution"

    $script:ConfigPath = Join-Path $script:Root "config.json"
    @{
        organization = "contoso"
        project      = "Atlas"
        repos        = @{
            "Atlas-Api"    = @{ path = $script:DotnetRepo; solution = "Atlas.Api.sln" }
            "Atlas-Web"    = @{ path = $script:NodeRepo }
            "Atlas-Db"     = @{ path = $script:SqlRepo; solution = $null }
            "Atlas-Forced" = @{
                path            = $script:DotnetRepo
                solution        = "Atlas.Api.sln"
                kind            = "custom"
                validateCommand = "make check"
            }
        }
    } | ConvertTo-Json -Depth 5 | Set-Content -Path $script:ConfigPath
}

AfterAll {
    Remove-Item -Path $script:Root -Recurse -Force -ErrorAction SilentlyContinue
}

Describe "repository kind detection" {
    It "resolves a relative solution against the repo path as dotnet" {
        $repo = Get-StartStoryRepoConfig -RepoName "Atlas-Api" -ConfigPath $script:ConfigPath
        $repo.kind | Should -Be "dotnet"
        $repo.configured | Should -BeTrue
        $repo.solution | Should -BeLike "*Atlas.Api.sln"
    }

    It "infers node from package.json" {
        (Get-StartStoryRepoConfig -RepoName "Atlas-Web" -ConfigPath $script:ConfigPath).kind | Should -Be "node"
    }

    It "treats a configured repo with no solution as manual" {
        $repo = Get-StartStoryRepoConfig -RepoName "Atlas-Db" -ConfigPath $script:ConfigPath
        $repo.kind | Should -Be "manual"
        $repo.solution | Should -BeNullOrEmpty
    }

    It "lets an explicit kind override inference" {
        $repo = Get-StartStoryRepoConfig -RepoName "Atlas-Forced" -ConfigPath $script:ConfigPath
        $repo.kind | Should -Be "custom"
        $repo.validateCommand | Should -Be "make check"
    }

    It "discovers a lone solution for an unconfigured repo" {
        Push-Location $script:LoneRepo
        try {
            $repo = Get-StartStoryRepoConfig -RepoName "Not-In-Config" -ConfigPath $script:ConfigPath
            $repo.configured | Should -BeFalse
            $repo.kind | Should -Be "dotnet"
        }
        finally {
            Pop-Location
        }
    }
}

Describe "detect-repo.ps1 script" {
    It "prints JSON with configured repository details" {
        Push-Location $script:DotnetRepo
        try {
            if (-not (Test-Path ".git")) {
                git init -b main 2>$null | Out-Null
                git remote add origin "https://dev.azure.com/contoso/Atlas/_git/Atlas-Api" 2>$null | Out-Null
            }
            $jsonText = & "$PSScriptRoot/../scripts/detect-repo.ps1" -ConfigPath $script:ConfigPath | Out-String
            $json = $jsonText | ConvertFrom-Json
            $json.repository | Should -Be "Atlas-Api"
            $json.configured | Should -BeTrue
            $json.kind | Should -Be "dotnet"
        }
        finally {
            Pop-Location
        }
    }
}
