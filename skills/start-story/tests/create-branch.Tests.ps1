#Requires -Version 5.1
BeforeAll {
    . (Join-Path $PSScriptRoot "_dotSourceCommon.ps1")

    $script:Root = Join-Path $env:TEMP "start-story-branch-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    $script:GitRoot = Join-Path $script:Root "git-repo"
    New-Item -ItemType Directory -Path $script:GitRoot -Force | Out-Null

    Push-Location $script:GitRoot
    try {
        git init -b main 2>$null | Out-Null
        git config user.email "test@example.com"
        git config user.name "Test"
        Set-Content -Path "README.md" -Value "seed"
        git add README.md 2>$null | Out-Null
        git commit -m "seed" 2>$null | Out-Null
    }
    finally {
        Pop-Location
    }

    $script:ConfigPath = Join-Path $script:Root "config.json"
    @{
        organization = "contoso"
        project      = "Atlas"
        baseBranch   = "main"
        branchPrefix = "story"
    } | ConvertTo-Json | Set-Content -Path $script:ConfigPath
}

AfterAll {
    Remove-Item -Path $script:Root -Recurse -Force -ErrorAction SilentlyContinue
}

Describe "working tree guards" {
    It "rejects a dirty working tree before branching" {
        Push-Location $script:GitRoot
        try {
            Set-Content -Path "dirty.txt" -Value "nope"
            { Assert-StartStoryCleanWorkingTree } | Should -Throw
            Remove-Item "dirty.txt" -Force
        }
        finally {
            Pop-Location
        }
    }

    It "allows a clean working tree" {
        Push-Location $script:GitRoot
        try {
            { Assert-StartStoryCleanWorkingTree } | Should -Not -Throw
        }
        finally {
            Pop-Location
        }
    }
}

Describe "create-branch.ps1 reuse" {
    It "reuses an existing local story branch" {
        Push-Location $script:GitRoot
        try {
            git checkout -b "story/55-existing" 2>$null | Out-Null
            $jsonText = & "$PSScriptRoot/../scripts/create-branch.ps1" `
                -WorkItemId 55 `
                -Title "Existing" `
                -ConfigPath $script:ConfigPath | Out-String
            $json = $jsonText | ConvertFrom-Json
            $json.action | Should -Be "reuse"
            $json.branch | Should -Be "story/55-existing"
        }
        finally {
            Pop-Location
        }
    }
}
