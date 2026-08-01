param(
    [Parameter(Mandatory = $true)]
    [int]$WorkItemId,

    [Parameter(Mandatory = $true)]
    [string]$Title,

    [string]$BaseBranch,
    [string]$ConfigPath
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\common.ps1"
if (-not $ConfigPath) { $ConfigPath = Get-StartStoryDefaultConfigPath }

$base = if ($BaseBranch) { $BaseBranch } else {
    Get-StartStoryConfigValue -Key "baseBranch" -Default "main" -ConfigPath $ConfigPath
}
$prefix = Get-StartStoryBranchPrefix -ConfigPath $ConfigPath

$current = git branch --show-current 2>$null
if ($current -match "^$([regex]::Escape($prefix))/$WorkItemId(?:-|$)") {
    [ordered]@{
        action  = "reuse"
        branch  = $current
        message = "Already on matching story branch."
    } | ConvertTo-Json
    exit 0
}

Assert-StartStoryCleanWorkingTree

$branch = Get-StartStoryBranchName -WorkItemId $WorkItemId -Title $Title -Prefix $prefix

git fetch origin 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Failed to fetch from origin."
}

git checkout $base 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Failed to checkout '$base'. Commit or stash your changes first."
}

git pull --ff-only origin $base 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Failed to update '$base' from origin. Resolve the branch state manually."
}

$existing = git branch --list $branch
if ($existing) {
    git checkout $branch 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Failed to checkout existing local branch '$branch'." }
    [ordered]@{
        action  = "checkout-existing"
        branch  = $branch
        message = "Checked out existing local branch."
    } | ConvertTo-Json
    exit 0
}

$remote = git ls-remote --heads origin $branch 2>$null
if ($LASTEXITCODE -ne 0) {
    throw "Failed to query remote heads for '$branch'."
}
if ($remote) {
    git checkout -b $branch --track "origin/$branch" 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Failed to track existing remote branch '$branch'." }
    [ordered]@{
        action  = "checkout-remote"
        branch  = $branch
        message = "Checked out existing remote branch."
    } | ConvertTo-Json
    exit 0
}

git checkout -b $branch 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Failed to create branch '$branch'." }

[ordered]@{
    action  = "created"
    branch  = $branch
    base    = $base
    message = "Created branch from $base."
} | ConvertTo-Json
