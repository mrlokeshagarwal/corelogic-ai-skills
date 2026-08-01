param(
    [string[]]$IgnorePatterns,
    [string]$ConfigPath
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\common.ps1"
if (-not $ConfigPath) { $ConfigPath = Get-StartStoryDefaultConfigPath }

if (-not $IgnorePatterns) {
    $IgnorePatterns = Get-StartStoryIgnorePatterns -ConfigPath $ConfigPath
}

$branch = git branch --show-current 2>$null
$repoName = Get-GitRepoName
$status = git status --porcelain 2>$null

$dirty = @()
$ignoredDirty = @()

foreach ($line in ($status -split "`n")) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $path = $line.Substring(3).Trim()
    if (Test-StartStoryIgnored -Path $path -Patterns $IgnorePatterns) {
        $ignoredDirty += $path
    }
    else {
        $dirty += $path
    }
}

$aheadBehind = ""
git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
    $counts = git rev-list --left-right --count 'HEAD...@{u}' 2>$null
    if ($counts) {
        $parts = $counts -split '\s+'
        $aheadBehind = "ahead=$($parts[0]) behind=$($parts[1])"
    }
}

[ordered]@{
    repository   = $repoName
    branch       = $branch
    tracking     = $aheadBehind
    dirtyFiles   = $dirty
    ignoredDirty = $ignoredDirty
    dirtyCount   = $dirty.Count
    ignoredCount = $ignoredDirty.Count
} | ConvertTo-Json -Depth 3
