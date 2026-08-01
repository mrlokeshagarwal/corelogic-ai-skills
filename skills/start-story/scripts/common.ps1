# Shared helpers for start-story scripts. Dot-source from other scripts.
# No product-specific values live here - everything comes from config.json
# (see config.example.json) or is inferred from the repo on disk.

$script:StartStorySkillRoot = Split-Path -Parent $PSScriptRoot

function Get-StartStoryHome {
    if ($env:HOME) { return $env:HOME }
    if ($env:USERPROFILE) { return $env:USERPROFILE }
    return [Environment]::GetFolderPath("UserProfile")
}

function Test-StartStoryWindowsHost {
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        return [bool]$IsWindows
    }
    return $env:OS -match 'Windows'
}

function Get-StartStoryUserConfigDir {
    # Persistent user config outside replaceable skill installs.
    $userHome = Get-StartStoryHome
    if (Test-StartStoryWindowsHost) {
        return (Join-Path $userHome ".corelogic-ai-skills\start-story")
    }
    $xdg = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $userHome ".config" }
    return (Join-Path $xdg "corelogic-ai-skills/start-story")
}

function Find-StartStoryRepoConfigPath {
    $dir = (Get-Location).ProviderPath
    while ($dir) {
        $candidate = Join-Path $dir ".corelogic-ai-skills/start-story/config.json"
        if (Test-Path $candidate) { return $candidate }
        $parent = Split-Path -Parent $dir
        if (-not $parent -or $parent -eq $dir) { break }
        $dir = $parent
    }
    return $null
}

function Get-StartStoryDefaultConfigPath {
    # Lookup order:
    # 1. Explicit -ConfigPath (handled by callers)
    # 2. Repository .corelogic-ai-skills/start-story/config.json
    # 3. User-level CoreLogic config
    # 4. Legacy config next to installed skill / old skill install paths
    $repoConfig = Find-StartStoryRepoConfigPath
    if ($repoConfig) { return $repoConfig }

    $userConfig = Join-Path (Get-StartStoryUserConfigDir) "config.json"
    if (Test-Path $userConfig) { return $userConfig }

    $legacyBesideSkill = Join-Path $script:StartStorySkillRoot "config.json"
    if (Test-Path $legacyBesideSkill) { return $legacyBesideSkill }

    $userHome = Get-StartStoryHome
    $legacyCandidates = @(
        (Join-Path $userHome ".cursor/skills/start-story/config.json"),
        (Join-Path $userHome ".claude/skills/start-story/config.json"),
        (Join-Path $userHome ".agents/skills/start-story/config.json"),
        (Join-Path $userHome ".config/opencode/skills/start-story/config.json")
    )
    foreach ($candidate in $legacyCandidates) {
        if (Test-Path $candidate) { return $candidate }
    }

    # Preferred path for new setups / error messages.
    return $userConfig
}

$script:StartStoryDefaultConfig = Get-StartStoryDefaultConfigPath

function Get-StartStoryConfig {
    param([string]$ConfigPath = $script:StartStoryDefaultConfig)
    if (Test-Path $ConfigPath) {
        return Get-Content $ConfigPath -Raw | ConvertFrom-Json
    }
    return $null
}

function Get-StartStoryConfigValue {
    param(
        [string]$Key,
        [string]$Default,
        [string]$ConfigPath = $script:StartStoryDefaultConfig
    )
    $envName = "ADO_$($Key.ToUpper())"
    if (Get-Item -Path "Env:$envName" -ErrorAction SilentlyContinue) {
        return (Get-Item "Env:$envName").Value
    }
    $cfg = Get-StartStoryConfig -ConfigPath $ConfigPath
    if ($cfg -and $cfg.$Key) { return $cfg.$Key }
    return $Default
}

function Get-StartStoryRequiredValue {
    param(
        [string]$Key,
        [string]$ConfigPath = $script:StartStoryDefaultConfig
    )
    $value = Get-StartStoryConfigValue -Key $Key -ConfigPath $ConfigPath
    if (-not $value) {
        throw "Missing '$Key'. Set it in $ConfigPath (copy config.example.json) or export ADO_$($Key.ToUpper())."
    }
    return $value
}

function Get-StartStoryPat {
    if ($env:AZURE_DEVOPS_PAT) { return $env:AZURE_DEVOPS_PAT }
    return $null
}

function Get-StartStoryAuthHeaders {
    param([string]$ConfigPath = $script:StartStoryDefaultConfig)
    $pat = Get-StartStoryPat
    if (-not $pat) {
        throw "PAT not configured. Export AZURE_DEVOPS_PAT (Work Items Read + Code Read & Write)."
    }
    $base64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat"))
    return @{
        Authorization  = "Basic $base64"
        "Content-Type" = "application/json"
    }
}

function Get-GitRepoName {
    $remoteUrl = git remote get-url origin 2>$null
    if (-not $remoteUrl) { return $null }
    # Azure DevOps: .../_git/<repo>   GitHub/GitLab/SSH: .../<repo>[.git]
    if ($remoteUrl -match '/_git/([^/?]+)') { return $Matches[1] }
    if ($remoteUrl -match '[/:]([^/:]+?)(\.git)?/?$') { return $Matches[1] }
    return $null
}

function Get-StartStoryProfile {
    param([string]$ConfigPath = $script:StartStoryDefaultConfig)
    $name = Get-StartStoryConfigValue -Key "profile" -ConfigPath $ConfigPath
    if (-not $name) {
        # Fall back to a profile named after the ADO project, if one exists.
        $project = Get-StartStoryConfigValue -Key "project" -ConfigPath $ConfigPath
        if ($project) { $name = $project.ToLower() }
    }
    if (-not $name) { return $null }

    $candidates = @(
        (Join-Path (Join-Path (Get-StartStoryUserConfigDir) "profiles") "$name.md"),
        (Join-Path (Join-Path $script:StartStorySkillRoot "profiles") "$name.md")
    )
    $repoConfig = Find-StartStoryRepoConfigPath
    if ($repoConfig) {
        $repoProfiles = Join-Path (Split-Path -Parent $repoConfig) "profiles"
        $candidates = @((Join-Path $repoProfiles "$name.md")) + $candidates
    }
    foreach ($path in $candidates) {
        if (Test-Path $path) {
            return [ordered]@{ name = $name; path = $path }
        }
    }
    return $null
}

function Resolve-StartStoryRepoKind {
    param([string]$Path, [string]$Solution)
    # A configured repo with no solution is deliberate (e.g. SQL-only) - callers
    # pass the already-resolved solution, so never re-discover one here.
    if ($Solution) { return "dotnet" }
    if ($Path -and (Test-Path (Join-Path $Path "package.json"))) { return "node" }
    return "manual"
}

function Get-StartStoryRepoConfig {
    param(
        [string]$RepoName,
        [string]$ConfigPath = $script:StartStoryDefaultConfig
    )
    $cfg = Get-StartStoryConfig -ConfigPath $ConfigPath
    $repo = $null
    if ($cfg -and $cfg.repos -and $RepoName -and
        ($cfg.repos.PSObject.Properties.Name -contains $RepoName)) {
        $repo = $cfg.repos.$RepoName
    }

    $path = if ($repo -and $repo.path) { $repo.path } else { (Get-Location).Path }

    $solution = if ($repo) { $repo.solution } else { $null }
    if (-not $solution -and -not $repo) {
        # Unconfigured repo: use the single solution in the working tree, if any.
        $found = Get-ChildItem -Path $path -Filter "*.sln" -ErrorAction SilentlyContinue
        if ($found.Count -eq 1) { $solution = $found[0].Name }
    }
    if ($solution -and -not [System.IO.Path]::IsPathRooted($solution)) {
        $candidate = Join-Path $path $solution
        if (Test-Path $candidate) { $solution = $candidate }
    }

    $kind = if ($repo -and $repo.kind) { $repo.kind } else { Resolve-StartStoryRepoKind -Path $path -Solution $solution }

    return [ordered]@{
        name            = $RepoName
        configured      = [bool]$repo
        path            = $path
        solution        = $solution
        kind            = $kind
        buildCommand    = if ($repo) { $repo.buildCommand } else { $null }
        testCommand     = if ($repo) { $repo.testCommand } else { $null }
        validateCommand = if ($repo) { $repo.validateCommand } else { $null }
        skipTests       = if ($repo -and $repo.skipTests) { [bool]$repo.skipTests } else { $false }
    }
}

function Get-StartStoryIgnorePatterns {
    param([string]$ConfigPath = $script:StartStoryDefaultConfig)
    $cfg = Get-StartStoryConfig -ConfigPath $ConfigPath
    if ($cfg -and $cfg.ignorePaths) { return @($cfg.ignorePaths) }
    return @("appsettings*.json", "*.env", "**/bin/**", "**/obj/**")
}

function Test-StartStoryIgnored {
    param([string]$Path, [string[]]$Patterns)
    $normalized = $Path -replace '\\', '/'
    foreach ($pattern in $Patterns) {
        if ($normalized -like $pattern) { return $true }

        # A directory pattern such as **/obj/** matches that folder at any depth.
        $dir = $pattern.Trim('*', '/')
        if ($pattern -match '\*\*' -and ($normalized -like "$dir/*" -or $normalized -like "*/$dir/*")) {
            return $true
        }

        # A pattern without a separator matches the file name at any depth.
        if ($pattern -notmatch '/' -and (Split-Path $normalized -Leaf) -like $pattern) { return $true }
    }
    return $false
}

function Get-StartStoryBranchPrefix {
    param([string]$ConfigPath = $script:StartStoryDefaultConfig)
    return (Get-StartStoryConfigValue -Key "branchPrefix" -Default "story" -ConfigPath $ConfigPath)
}

function Get-StartStoryBranchName {
    param(
        [Parameter(Mandatory = $true)][int]$WorkItemId,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Title,
        [string]$Prefix = "story",
        [int]$MaxSlugLength = 60
    )
    $slug = ($Title.ToLower() `
            -replace '[^a-z0-9]+', '-' `
            -replace '-+', '-' `
            -replace '^-|-$', '')
    if ($slug.Length -gt $MaxSlugLength) {
        $slug = $slug.Substring(0, $MaxSlugLength).TrimEnd('-')
    }
    if (-not $slug) { return "$Prefix/$WorkItemId" }
    return "$Prefix/$WorkItemId-$slug"
}

function Assert-StartStoryCleanWorkingTree {
    $dirty = git status --porcelain 2>$null
    if ($dirty) {
        throw "Working tree contains uncommitted changes. Commit, stash, or discard them before starting a story."
    }
}

function Assert-StartStoryPrSourceBranch {
    param(
        [Parameter(Mandatory = $true)][string]$SourceBranch,
        [Parameter(Mandatory = $true)][string]$BaseBranch,
        [Parameter(Mandatory = $true)][int]$WorkItemId,
        [Parameter(Mandatory = $true)][string]$Prefix
    )
    if ($SourceBranch -eq $BaseBranch) {
        throw "Cannot create a pull request from the target branch '$BaseBranch'."
    }
    if ($SourceBranch -match '^(main|master)$') {
        throw "Cannot create a pull request from protected branch '$SourceBranch'."
    }
    $escaped = [regex]::Escape($Prefix)
    if ($SourceBranch -notmatch "^$escaped/$WorkItemId(?:-|$)") {
        throw "Current branch '$SourceBranch' does not match work item #$WorkItemId (expected '$Prefix/$WorkItemId-...')."
    }
}

function Set-StartStoryValidationStatus {
    param($Result)
    if ($Result.requiresManualReview) {
        $Result['status'] = "manual-review-required"
    }
    elseif ($Result.passed) {
        $Result['status'] = "passed"
    }
    else {
        $Result['status'] = "failed"
    }
}

function Complete-StartStoryValidationResult {
    param($Result)

    Set-StartStoryValidationStatus -Result $Result

    # Exit 0 means the validator finished cleanly, not that validation passed.
    # Consumers must inspect status / passed / requiresManualReview.
    $Result | ConvertTo-Json -Depth 4
    if ($Result.passed -or $Result.requiresManualReview) { exit 0 }
    exit 1
}
