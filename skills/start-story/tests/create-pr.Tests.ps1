#Requires -Version 5.1
BeforeAll {
    . (Join-Path $PSScriptRoot "_dotSourceCommon.ps1")
}

Describe "PR source branch guards" {
    It "rejects the target branch" {
        {
            Assert-StartStoryPrSourceBranch `
                -SourceBranch "main" `
                -BaseBranch "main" `
                -WorkItemId 9 `
                -Prefix "story"
        } | Should -Throw
    }

    It "rejects protected main even when the base is elsewhere" {
        {
            Assert-StartStoryPrSourceBranch `
                -SourceBranch "main" `
                -BaseBranch "develop" `
                -WorkItemId 9 `
                -Prefix "story"
        } | Should -Throw
    }

    It "rejects a branch that does not match the work item id" {
        {
            Assert-StartStoryPrSourceBranch `
                -SourceBranch "story/99-other" `
                -BaseBranch "main" `
                -WorkItemId 9 `
                -Prefix "story"
        } | Should -Throw
    }

    It "accepts a matching story branch" {
        {
            Assert-StartStoryPrSourceBranch `
                -SourceBranch "story/9-fix-login" `
                -BaseBranch "main" `
                -WorkItemId 9 `
                -Prefix "story"
        } | Should -Not -Throw
    }
}

Describe "create-pr.ps1 dry-run prerequisites" {
    It "fails fast without AZURE_DEVOPS_PAT before any network call" {
        $root = Join-Path $env:TEMP "start-story-pr-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
        $repo = Join-Path $root "repo"
        New-Item -ItemType Directory -Path $repo -Force | Out-Null
        $config = Join-Path $root "config.json"
        @{
            organization = "contoso"
            project      = "Atlas"
            baseBranch   = "main"
        } | ConvertTo-Json | Set-Content $config

        Push-Location $repo
        $savedPat = $env:AZURE_DEVOPS_PAT
        $env:AZURE_DEVOPS_PAT = $null
        try {
            git init -b main 2>$null | Out-Null
            git config user.email "test@example.com"
            git config user.name "Test"
            Set-Content README.md "seed"
            git add README.md 2>$null | Out-Null
            git commit -m "seed" 2>$null | Out-Null
            git checkout -b "story/9-dry-run" 2>$null | Out-Null
            git remote add origin "https://dev.azure.com/contoso/Atlas/_git/Atlas-Api" 2>$null | Out-Null

            {
                & "$PSScriptRoot/../scripts/create-pr.ps1" `
                    -WorkItemId 9 `
                    -Title "t" `
                    -Description "d" `
                    -ConfigPath $config `
                    -DryRun
            } | Should -Throw
        }
        finally {
            $env:AZURE_DEVOPS_PAT = $savedPat
            Pop-Location
            Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
