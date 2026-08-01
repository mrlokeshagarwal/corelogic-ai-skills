param(
    [Parameter(Mandatory = $true)]
    [int]$WorkItemId,

    [string]$ConfigPath
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\common.ps1"
if (-not $ConfigPath) { $ConfigPath = Get-StartStoryDefaultConfigPath }

$org = Get-StartStoryRequiredValue -Key "organization" -ConfigPath $ConfigPath
$project = Get-StartStoryRequiredValue -Key "project" -ConfigPath $ConfigPath
$headers = Get-StartStoryAuthHeaders -ConfigPath $ConfigPath

$url = "https://dev.azure.com/$org/$project/_apis/wit/workitems/${WorkItemId}?`$expand=all&api-version=7.1"
$response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get

function Convert-HtmlToText([string]$html) {
    if (-not $html) { return "" }
    # Keep list/paragraph structure so acceptance criteria stay readable.
    $text = $html -replace '(?i)<li[^>]*>', "`n- " `
        -replace '(?i)<br\s*/?>', "`n" `
        -replace '(?i)</(p|div|tr|h[1-6])>', "`n" `
        -replace '<[^>]+>', ' '
    $text = [System.Net.WebUtility]::HtmlDecode($text)
    $lines = $text -split "`n" | ForEach-Object { ($_ -replace '\s+', ' ').Trim() } | Where-Object { $_ }
    return ($lines -join "`n").Trim()
}

$fields = $response.fields
[ordered]@{
    id                 = $response.id
    url                = $response.url
    title              = $fields.'System.Title'
    state              = $fields.'System.State'
    workItemType       = $fields.'System.WorkItemType'
    description        = Convert-HtmlToText $fields.'System.Description'
    acceptanceCriteria = Convert-HtmlToText $fields.'Microsoft.VSTS.Common.AcceptanceCriteria'
    assignedTo         = $fields.'System.AssignedTo'.displayName
    areaPath           = $fields.'System.AreaPath'
    tags               = $fields.'System.Tags'
    organization       = $org
    project            = $project
} | ConvertTo-Json -Depth 4
