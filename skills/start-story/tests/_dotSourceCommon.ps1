# Shared bootstrap for start-story tests. Dot-source this file first.
$script:StartStoryCommonPath = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot "../scripts/common.ps1")
)
if (-not (Test-Path -LiteralPath $script:StartStoryCommonPath)) {
    throw @"
Missing start-story helper script:
  $script:StartStoryCommonPath

Ensure skills/start-story/scripts/*.ps1 are committed.
On Windows, a bare 'Scripts/' entry in .gitignore also matches 'scripts/'.
Use '/Scripts/' (repo-root only) instead.
"@
}
. $script:StartStoryCommonPath
