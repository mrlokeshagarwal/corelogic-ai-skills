param(
    [Parameter(Mandatory = $true)]
    [int]$WorkItemId,

    [Parameter(Mandatory = $true)]
    [string]$Title,

    [Parameter(Mandatory = $true)]
    [string]$Description,

    [string]$TargetBranch,
    [string]$ConfigPath,

    # Resolve everything and report what would be created, without calling POST.
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\common.ps1"
if (-not $ConfigPath) { $ConfigPath = Get-StartStoryDefaultConfigPath }

$org = Get-StartStoryRequiredValue -Key "organization" -ConfigPath $ConfigPath
$project = Get-StartStoryRequiredValue -Key "project" -ConfigPath $ConfigPath
$baseBranch = if ($TargetBranch) { $TargetBranch } else {
    Get-StartStoryConfigValue -Key "baseBranch" -Default "main" -ConfigPath $ConfigPath
}
$prefix = Get-StartStoryBranchPrefix -ConfigPath $ConfigPath
$headers = Get-StartStoryAuthHeaders -ConfigPath $ConfigPath

$repoName = Get-GitRepoName
if (-not $repoName) { throw "Not in a git repository with an origin remote." }

$sourceBranch = git branch --show-current
if (-not $sourceBranch) { throw "Could not determine current branch." }

Assert-StartStoryPrSourceBranch `
    -SourceBranch $sourceBranch `
    -BaseBranch $baseBranch `
    -WorkItemId $WorkItemId `
    -Prefix $prefix

$reposUrl = "https://dev.azure.com/$org/$project/_apis/git/repositories?api-version=7.1"
$repos = Invoke-RestMethod -Uri $reposUrl -Headers $headers -Method Get
$repo = $repos.value | Where-Object { $_.name -eq $repoName } | Select-Object -First 1
if (-not $repo) { throw "Repository '$repoName' not found in $org/$project." }

# Never open a second PR for a branch that already has one open.
$searchUrl = "https://dev.azure.com/$org/$project/_apis/git/repositories/$($repo.id)/pullrequests?searchCriteria.sourceRefName=refs/heads/$sourceBranch&searchCriteria.targetRefName=refs/heads/$baseBranch&searchCriteria.status=active&api-version=7.1"
$existing = Invoke-RestMethod -Uri $searchUrl -Headers $headers -Method Get
if ($existing.count -gt 0) {
    $pr = $existing.value[0]
    [ordered]@{
        pullRequestId = $pr.pullRequestId
        title         = $pr.title
        url           = $pr.url
        webUrl        = "https://dev.azure.com/$org/$project/_git/$repoName/pullrequest/$($pr.pullRequestId)"
        sourceBranch  = $sourceBranch
        targetBranch  = $baseBranch
        workItemId    = $WorkItemId
        repository    = $repoName
        created       = $false
        message       = "Existing active PR found - not creating a duplicate."
    } | ConvertTo-Json -Depth 4
    exit 0
}

$fullDescription = $Description + "`n`n---`nLinked work item: AB#$WorkItemId"

if ($DryRun) {
    [ordered]@{
        dryRun       = $true
        created      = $false
        repository   = $repoName
        sourceBranch = $sourceBranch
        targetBranch = $baseBranch
        title        = $Title
        description  = $fullDescription
        workItemId   = $WorkItemId
        message      = "Dry run - no pull request was created."
    } | ConvertTo-Json -Depth 4
    exit 0
}

$body = @{
    sourceRefName = "refs/heads/$sourceBranch"
    targetRefName = "refs/heads/$baseBranch"
    title         = $Title
    description   = $fullDescription
    workItemRefs  = @(@{ id = "$WorkItemId" })
} | ConvertTo-Json -Depth 4

$prUrl = "https://dev.azure.com/$org/$project/_apis/git/repositories/$($repo.id)/pullrequests?api-version=7.1"
$pr = Invoke-RestMethod -Uri $prUrl -Headers $headers -Method Post -Body $body

[ordered]@{
    pullRequestId = $pr.pullRequestId
    title         = $pr.title
    url           = $pr.url
    webUrl        = "https://dev.azure.com/$org/$project/_git/$repoName/pullrequest/$($pr.pullRequestId)"
    sourceBranch  = $sourceBranch
    targetBranch  = $baseBranch
    workItemId    = $WorkItemId
    repository    = $repoName
    created       = $true
} | ConvertTo-Json -Depth 4
