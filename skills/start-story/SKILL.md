---
name: start-story
description: Start or resume Azure DevOps work-item implementation through fetch, branch, implement, validate, commit, and pull-request creation with human checkpoints. Use when the user runs /start-story, provides an ADO story or bug id or URL, or works on a branch named <prefix>/<id>-*. Never merge or auto-review pull requests.
---

# Start Story

Fetch → branch → agent implements → validate → PR.
**Manual review only** (no merge, no auto-review).

PowerShell scripts handle deterministic Azure DevOps and git operations. The coding agent performs the actual implementation using this skill and the product profile.

**Announce:** "Using the start-story skill."

Invoke with `pwsh` when available; otherwise use `powershell` on Windows. Resolve script paths from this skill folder (for example the installed copy under `~/.cursor/skills/start-story` or `.cursor/skills/start-story` in a project).

## Usage

```text
/start-story 1234
/start-story 1234 --from validate
/start-story 1234 --pr-only
```

`--from <step>` skips earlier steps. `--pr-only` = push (if needed) + create PR.

## Hard rules

- Never merge / auto-complete / auto-review PRs.
- Never commit secrets or files matching `ignorePaths` in config unless the user asks.
- Never `git add .` — stage specific story files only.
- One PR per repo. Stop and ask if AC is ambiguous or multi-repo scope is unclear.
- Commits: `git commit -m "title" -m "body"` (no bash HEREDOC).
- Auth via `AZURE_DEVOPS_PAT` only — never put a PAT in config files; the scripts do not read one from there.

## Config

Copy `config.example.json` to a **persistent** config path outside the installed skill folder (installer updates replace the skill tree and would delete in-skill config):

| Priority | Location |
|----------|----------|
| 1 | Explicit `-ConfigPath` argument |
| 2 | `<repository>/.corelogic-ai-skills/start-story/config.json` |
| 3 | User config: Windows `%USERPROFILE%\.corelogic-ai-skills\start-story\config.json`, macOS/Linux `~/.config/corelogic-ai-skills/start-story/config.json` |
| 4 | Legacy: `config.json` next to the installed skill (supported for migration only) |

Config holds organization, project, base branch, branch prefix, and per-repo paths / kind / validation. Optional profiles may live under `profiles/` beside that config, or under the skill's bundled `profiles/`. Run `scripts/detect-repo.ps1` to see what resolved.

## Checkpoints (wait for user)

| After | Show | Wait for |
|-------|------|----------|
| Step 1 | Story summary + proposed repo(s) | `continue` |
| Step 3 | Root cause + files changed | before validate/commit |
| Step 4 | Validation result | before commit/push/PR |

## Progress

```text
- [ ] 1 Fetch  - [ ] 2 Branch  - [ ] 3 Implement
- [ ] 4 Validate  - [ ] 5 Commit/push  - [ ] 6 PR  - [ ] 7 Handoff
```

### 1 — Fetch

```powershell
pwsh -NoProfile -File scripts/fetch-work-item.ps1 -WorkItemId <ID>
```

Present: ID, title, state, type, description, AC. Classify which repo(s) the story touches — read the profile named by `detect-repo.ps1` if unsure. Closed/Done → confirm first. **Checkpoint.**

### 2 — Branch

```powershell
pwsh -NoProfile -File scripts/create-branch.ps1 -WorkItemId <ID> -Title "<title>"
pwsh -NoProfile -File scripts/detect-repo.ps1
pwsh -NoProfile -File scripts/status-summary.ps1
```

Requires a clean working tree before switching. An existing local or remote `<prefix>/<id>-*` branch is reused automatically.

### 3 — Implement (agent)

Scope to the story only; match existing patterns in that repo. Follow the profile's search budget so exploration stays bounded. The scripts do **not** write application code — you do. **Checkpoint** with root cause + file list.

### 4 — Validate

```powershell
pwsh -NoProfile -File scripts/validate.ps1
```

Dispatches on the repo's `kind` (dotnet / node / custom / manual). Fix until `status` is `passed`. If `status` is `manual-review-required`, state what you reviewed by hand. Exit code 0 means the validator finished — always read `status` / `passed` / `requiresManualReview`. Do not dump full build logs — use the script JSON. **Checkpoint.**

### 5 — Commit / push

Only after user approval (or an explicit full end-to-end run):

```powershell
git add <story-files>
git commit -m "fix: <summary> (#<id>)" -m "<why>"
git push -u origin HEAD
```

### 6 — PR

```powershell
pwsh -NoProfile -File scripts/create-pr.ps1 -WorkItemId <ID> -Title "<title>" -Description "<summary + test plan>"
```

Add `-DryRun` to preview without creating anything. The script rejects PRs from the target/`main`/`master` branch and from branches that do not match the work item id. It skips duplicates if an active PR already exists.

### 7 — Handoff

```text
Story #<id>: <title>
Branch: <branch>
PR(s): <url(s)>
Validation: status from validate.ps1
Ready for manual review. NOT merged.
```

## Resources (read only when needed)

- Product profile: `profiles/<name>.md` (path comes from `detect-repo.ps1`)
- New project setup: `references/setup.md`
- ADO API (script failures only): `references/ado-api.md`
- Slash-command example: `examples/slash-command.md`
