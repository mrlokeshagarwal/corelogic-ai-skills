param(
    [string]$ConfigPath
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\common.ps1"
if (-not $ConfigPath) { $ConfigPath = Get-StartStoryDefaultConfigPath }

$repoName = Get-GitRepoName
if (-not $repoName) {
    throw "Not in a git repo with an origin remote."
}

$repo = Get-StartStoryRepoConfig -RepoName $repoName -ConfigPath $ConfigPath
$storyProfile = Get-StartStoryProfile -ConfigPath $ConfigPath

$validate = switch ($repo.kind) {
    "manual" { "manual-review" }
    "node" { if ($repo.buildCommand) { $repo.buildCommand } else { "npm run build --if-present" } }
    "custom" { $repo.validateCommand }
    default { if ($repo.solution) { "dotnet build $($repo.solution)" } else { "not-configured" } }
}

[ordered]@{
    repository   = $repoName
    configured   = $repo.configured
    kind         = $repo.kind
    solution     = $repo.solution
    localPath    = $repo.path
    configPath   = $ConfigPath
    baseBranch   = Get-StartStoryConfigValue -Key "baseBranch" -Default "main" -ConfigPath $ConfigPath
    branchPrefix = Get-StartStoryBranchPrefix -ConfigPath $ConfigPath
    organization = Get-StartStoryConfigValue -Key "organization" -ConfigPath $ConfigPath
    project      = Get-StartStoryConfigValue -Key "project" -ConfigPath $ConfigPath
    profile      = if ($storyProfile) { $storyProfile.name } else { $null }
    profilePath  = if ($storyProfile) { $storyProfile.path } else { $null }
    validate     = $validate
} | ConvertTo-Json -Depth 3
