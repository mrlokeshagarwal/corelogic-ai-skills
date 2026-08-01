# start-story tests

Automated coverage for the PowerShell workflow helpers and scripts.

## Run locally

Preferred entry point (uses Pester 5+ when installed, otherwise the self-contained runner):

```powershell
powershell -NoProfile -File skills/start-story/tests/Invoke-StartStoryTests.ps1
# or: pwsh -File skills/start-story/tests/Invoke-StartStoryTests.ps1
```

Self-contained runner (no modules required):

```powershell
powershell -NoProfile -File skills/start-story/tests/run-tests.ps1
```

Pester 5 directly:

```powershell
Install-Module Pester -Force -Scope CurrentUser -MinimumVersion 5.0.0
Invoke-Pester skills/start-story/tests/*.Tests.ps1
```

## Files

| File | Focus |
|---|---|
| `common.Tests.ps1` | Config/PAT resolution, repo vs user config priority, ignore paths, branch naming |
| `detect-repo.Tests.ps1` | Kind inference and `detect-repo.ps1` JSON output |
| `create-branch.Tests.ps1` | Dirty-tree rejection and branch reuse |
| `create-pr.Tests.ps1` | Protected-branch / work-item matching; PAT required before dry-run network calls |
| `validate.Tests.ps1` | Manual-review and failed custom validation outcomes |
| `run-tests.ps1` | Self-contained suite used when Pester is unavailable |
