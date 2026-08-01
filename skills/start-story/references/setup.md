# Using start-story on a new project

The skill and scripts are product-agnostic. Adopting a new Azure DevOps project
means writing config, and optionally a profile.

## 1. Config (persistent, outside the skill folder)

Installer updates **replace** the installed skill directory. Keep `config.json`
outside that tree so updates do not delete your settings.

Lookup order:

1. Explicit `-ConfigPath`
2. `<repository>/.corelogic-ai-skills/start-story/config.json`
3. User-level CoreLogic config
   - Windows: `%USERPROFILE%\.corelogic-ai-skills\start-story\config.json`
   - macOS/Linux: `~/.config/corelogic-ai-skills/start-story/config.json`
4. Legacy `config.json` next to the installed skill (migration only)

Copy `config.example.json` into one of those locations and fill in:

| Key | Meaning |
|-----|---------|
| `organization`, `project` | Azure DevOps org and project (required) |
| `baseBranch` | PR target, e.g. `main`, `develop`, `development` |
| `branchPrefix` | Branch namespace, default `story` |
| `ignorePaths` | Never-commit globs surfaced separately by `status-summary.ps1` |
| `repos` | One entry per ADO repo name |

Authentication is **not** stored in config and is **not** read from it. Export a
PAT with Work Items (Read) and Code (Read & Write):

```powershell
$env:AZURE_DEVOPS_PAT = "<your-pat>"
```

For a longer-lived setup, store the token with PowerShell SecretManagement (or
another credential store) and set `AZURE_DEVOPS_PAT` from that secret in your
shell profile. The repository configuration contains no credentials; only the
environment variable is consulted.

Any scalar config key can be overridden per shell with `ADO_<KEY>`, e.g.
`$env:ADO_BASEBRANCH = "release/2.1"`.

## 2. Repo entries

Keyed by the **Azure DevOps repo name** (matched against the `origin` remote).

```json
"My-Api": { "path": "/path/to/my-api", "kind": "dotnet", "solution": "MyApi.sln" }
```

| `kind` | Validation performed |
|--------|----------------------|
| `dotnet` | `dotnet restore` → `build` → `test` (tests skipped if no `*Tests*.csproj`) |
| `node` | `buildCommand` then `testCommand` (default `npm run build/test --if-present`) |
| `custom` | `validateCommand` verbatim |
| `manual` | Nothing automated; returns `status: manual-review-required` |

Omit `kind` to infer it: a solution (configured or the single `*.sln` in the
repo) means `dotnet`, a `package.json` means `node`, otherwise `manual`.
`skipTests: true` limits a repo to build-only.

For SPA / Node test runners that default to watch mode, pass a one-shot flag
(e.g. `npm test -- --run` or `vitest run`) so validation can exit.

## 3. Profile (optional)

Create `profiles/<name>.md` from `profiles/template.md` for repo-map hints,
search strategy, and local conventions. Profiles are resolved from:

1. `<config-dir>/profiles/<name>.md` (repo or user config directory)
2. Bundled `profiles/<name>.md` inside the skill

Selected when `profile` matches in config, or when the file is named after the
project (lowercased). See `profiles/example-atlas.md` for a filled-in example.

Skip the profile for single-repo projects — the skill works without one.

## 4. Install and verify

Install from this library (example — Cursor global):

```bash
python tools/install_skill.py --skill start-story --global --platform cursor
```

Create user-level config, then verify from a repo checkout. Prefer `pwsh`; on
Windows PowerShell 5.1 use `powershell` instead:

```powershell
$dir = Join-Path $HOME ".corelogic-ai-skills\start-story"   # Windows
# Linux/macOS: ~/.config/corelogic-ai-skills/start-story
New-Item -ItemType Directory -Force -Path $dir | Out-Null
Copy-Item config.example.json (Join-Path $dir "config.json")

cd <repo>
$skill = Join-Path $HOME ".cursor/skills/start-story"
pwsh -NoProfile -File "$skill/scripts/detect-repo.ps1"
pwsh -NoProfile -File "$skill/scripts/validate.ps1" -SkipTests
```

`detect-repo.ps1` should show the right repository, `configured: true`, the
resolved solution/kind, and the profile if you created one. To confirm the ADO
side without side effects:

```powershell
pwsh -NoProfile -File "$skill/scripts/fetch-work-item.ps1" -WorkItemId <ID>
pwsh -NoProfile -File "$skill/scripts/create-pr.ps1" -WorkItemId <ID> -Title "t" -Description "d" -DryRun
```

### Validation exit codes

Exit code `0` means the validator **completed**, not that the change is green.
Inspect the JSON:

| `status` | Meaning |
|----------|---------|
| `passed` | Automated validation succeeded |
| `manual-review-required` | Expected for `kind: manual`; review by hand |
| `failed` | Build/test/command failed (exit code `1`) |

**Security note:** when validation fails, a truncated slice of command output is
returned in `errors` and may be included in the agent context. Ensure build and
test commands do not print connection strings, tokens, package-source
credentials, or other secrets.
