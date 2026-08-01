# CoreLogic AI Skills

Portable, production-focused skills for AI coding agents.

CoreLogic AI Skills keeps one canonical definition for each workflow and supplies thin discovery adapters for Claude Code, Claude Desktop, Cursor, OpenCode, Codex, and ChatGPT.

## Available skills


| Skill                                      | Status | Purpose                                                                                                                             |
| ------------------------------------------ | ------ | ----------------------------------------------------------------------------------------------------------------------------------- |
| `[dotnet-upgrade](skills/dotnet-upgrade/)` | Beta   | Assess, plan, upgrade, secure, and validate a local .NET repository. Repository changes require explicit approval after assessment. |
| `[start-story](skills/start-story/)`       | Beta   | Fetch an Azure DevOps work item, branch, implement with checkpoints, validate, and open a pull request without merging.             |




## How `dotnet-upgrade` behaves

The skill follows a mandatory two-stage workflow:

1. **Assessment stage** — inspect the selected repository, record the current state, identify the recommended supported .NET target, analyse packages and risks, and present an upgrade plan.
2. **Execution stage** — modify files only after the user explicitly approves the target and proposed scope.

The skill must not deploy an application, expose private-feed credentials, apply production database migrations, or claim success without build and test evidence.

## How `start-story` behaves

The skill follows a checkpointed work-item workflow:

1. **Fetch** — load the Azure DevOps work item and propose repo scope.
2. **Branch / implement / validate** — create or reuse the story branch, implement only the story, and run repo-kind validation.
3. **PR / handoff** — commit named files, open a PR linked to the work item, and stop for manual review.

It must not merge, auto-complete, or auto-review pull requests, and must not run `git add .`. Persistent `config.json` (from `config.example.json`) lives **outside** the installed skill folder so updates do not delete it — see `skills/start-story/README.md`. Auth is `AZURE_DEVOPS_PAT` only.

## Prerequisites

The selected agent must be able to access the local repository and, for full execution, run commands inside it.

Recommended local prerequisites:

- Git
- Python 3.10 or later for the included helper tools
- For `dotnet-upgrade`: an installed .NET SDK suitable for assessing the current solution, and access to any required private NuGet feeds
- For `start-story`: PowerShell 7+ (`pwsh`) preferred, or Windows PowerShell 5.1+; Azure DevOps PAT in `AZURE_DEVOPS_PAT` with Work Items (Read) and Code (Read & Write)

On Windows, if `python` is not on `PATH`, use the Python launcher (`py -3`) in place of `python` in the commands below.

Clone the library once:

```bash
git clone https://github.com/<your-account>/corelogic-ai-skills.git
cd corelogic-ai-skills
```

Replace `<your-account>` with the final GitHub owner before publishing.

# Global installation

Global installation makes skills available across repositories for platforms that support personal or user-level skill directories.

The library includes an installer. Supported `--platform` values: `claude`, `cursor`, `opencode`, `codex`, and `chatgpt` (upload guidance only).

Install one skill:

```bash
python tools/install_skill.py --skill dotnet-upgrade --global --platform <platform>
```

Install several skills and platforms in one command by repeating `--skill` and `--platform`:

```bash
python tools/install_skill.py \
  --skill dotnet-upgrade \
  --skill start-story \
  --global \
  --platform claude \
  --platform cursor \
  --platform opencode \
  --platform codex
```

Install every skill under `skills/`:

```bash
python tools/install_skill.py \
  --all \
  --global \
  --platform claude \
  --platform cursor \
  --platform opencode \
  --platform codex
```

On Windows PowerShell:

```powershell
py -3 .\tools\install_skill.py `
  --all `
  --global `
  --platform claude `
  --platform cursor `
  --platform opencode `
  --platform codex
```



## Claude Code

Claude Code supports personal skills under:

```text
~/.claude/skills/<skill-name>/SKILL.md
```

Install globally:

```bash
python tools/install_skill.py \
  --skill dotnet-upgrade \
  --global \
  --platform claude
```

The resulting location is:

```text
~/.claude/skills/dotnet-upgrade/
```

Start Claude Code from the .NET repository root:

```bash
cd /path/to/my-dotnet-application
claude
```

Example prompt:

```text
Use the dotnet-upgrade skill to assess this repository for an upgrade to the
latest supported .NET LTS version. Do not modify files yet. Present the
assessment and plan, then wait for my approval.
```

The skill can also be invoked directly when supported:

```text
/dotnet-upgrade
```

Official documentation: [https://code.claude.com/docs/en/slash-commands](https://code.claude.com/docs/en/slash-commands)

## Claude Desktop / Claude web

Claude Desktop and Claude web use account-installed skills rather than the local `~/.claude/skills` folder used by Claude Code.

Build and upload the packaged skill. `dist/` is generated locally and is not committed to git:

```bash
python tools/package_skill.py --skill dotnet-upgrade
# or package every skill:
# python tools/package_skill.py --all
```

Then:

1. Open **Customize > Skills**.
2. Enable code execution and file creation when required by the account or workspace.
3. Upload `dist/dotnet-upgrade/skill.zip`.
4. Enable the installed skill.

To work on a local repository, Claude Desktop must also have an approved filesystem or development integration that exposes the repository. Installing a skill does not grant filesystem or terminal access by itself.

Official documentation: [https://support.claude.com/en/articles/12512180-use-skills-in-claude](https://support.claude.com/en/articles/12512180-use-skills-in-claude)

## OpenCode

OpenCode supports global skills under:

```text
~/.config/opencode/skills/<skill-name>/SKILL.md
```

Install globally:

```bash
python tools/install_skill.py \
  --skill dotnet-upgrade \
  --global \
  --platform opencode
```

The resulting location is:

```text
~/.config/opencode/skills/dotnet-upgrade/
```

Open the target repository:

```bash
cd /path/to/my-dotnet-application
opencode
```

Example prompt:

```text
Use the dotnet-upgrade skill. Assess the current solution and prepare an
upgrade plan. Do not change repository files until I approve the plan.
```

OpenCode also discovers compatible global skills from `~/.claude/skills` and `~/.agents/skills`. Installing separately under `~/.config/opencode/skills` avoids relying on compatibility paths and makes ownership explicit.

Official documentation: [https://opencode.ai/docs/skills](https://opencode.ai/docs/skills)

## Codex

Install the canonical skill globally under the Agent Skills-compatible directory:

```bash
python tools/install_skill.py \
  --skill dotnet-upgrade \
  --global \
  --platform codex
```

The resulting location is:

```text
~/.agents/skills/dotnet-upgrade/
```

The installer also creates or updates a user-level `~/.agents/AGENTS.md` discovery note. A repository's own `AGENTS.md` can still provide project-specific instructions.

Start Codex from the repository root and use an approval-aware mode:

```bash
cd /path/to/my-dotnet-application
codex
```

Example prompt:

```text
Use the dotnet-upgrade skill to assess this repository. Produce the target
recommendation, compatibility risks, package plan, security findings, and
verification plan. Stop before making changes.
```

The skill's internal approval gate applies regardless of the Codex client approval mode.

## Cursor

Cursor discovers Agent Skills from `.cursor/skills/` and `~/.cursor/skills/` (plus compatibility paths such as `.agents/skills/` and `.claude/skills/`).

### Global install

```bash
python tools/install_skill.py \
  --skill dotnet-upgrade \
  --global \
  --platform cursor
```

The resulting location is:

```text
~/.cursor/skills/dotnet-upgrade/
```



### Project install

```bash
python tools/install_skill.py \
  --skill dotnet-upgrade \
  --target /path/to/my-dotnet-application \
  --platform cursor
```

This creates:

```text
<repository>/.cursor/skills/dotnet-upgrade/
<repository>/.cursor/rules/dotnet-upgrade.mdc
```

The skill folder is the canonical install. The optional `.mdc` rule reinforces discovery when the agent is asked about .NET upgrades.

Official documentation: [https://cursor.com/docs/skills](https://cursor.com/docs/skills)

## ChatGPT

ChatGPT skills are installed through the Skills interface rather than a local global directory.

Build the upload package from this repository. `dist/` is generated locally and is not committed to git:

```bash
python tools/package_skill.py --skill dotnet-upgrade
# or: python tools/package_skill.py --all
```

This writes:

```text
dist/dotnet-upgrade/skill.zip
```

Then:

1. Open **Plugins** from the ChatGPT sidebar.
2. Open the **Skills** tab.
3. Select **Create** and then **Upload from your computer**.
4. Upload `dist/dotnet-upgrade/skill.zip`.
5. Review the skill and install or enable it.

Personal skills may need to be installed separately on desktop and web/mobile surfaces. Workspace availability can depend on plan and administrator settings.

A ChatGPT skill does not automatically gain access to a repository open in VS Code. The repository must be uploaded, mounted, connected through an approved app, or exposed by the execution environment.

Official documentation: [https://help.openai.com/en/articles/20001066](https://help.openai.com/en/articles/20001066)

# Updating a global installation

Pull the latest library changes:

```bash
cd /path/to/corelogic-ai-skills
git pull
```

Rerun the relevant installer command. Existing installed skill folders are replaced with the current canonical copy.

Example:

```bash
python tools/install_skill.py \
  --all \
  --global \
  --platform claude \
  --platform cursor \
  --platform opencode \
  --platform codex
```

For project-level installs, rerun the `--target` command for each repository and platform. For ChatGPT and Claude Desktop/web, rebuild zips with `python tools/package_skill.py --all` and replace or update the installed skills through the product interface.

# Uninstalling



### Global installs

Remove the relevant folder:

```text
Claude Code: ~/.claude/skills/<skill>
Cursor:      ~/.cursor/skills/<skill>
OpenCode:    ~/.config/opencode/skills/<skill>
Codex:       ~/.agents/skills/<skill>
```

For Codex, also remove the managed `<!-- corelogic-ai-skills:start:<skill> -->` … `end` block from `~/.agents/AGENTS.md` if it is no longer needed. User-level `start-story` config under `.corelogic-ai-skills/` or `~/.config/corelogic-ai-skills/` is separate and is not removed by uninstalling the skill folder.

### Project installs

Remove the installed skill folder for each platform:

```text
Claude Code: <repository>/.claude/skills/<skill>
Cursor:      <repository>/.cursor/skills/<skill>
             <repository>/.cursor/rules/<skill>.mdc
OpenCode:    <repository>/.opencode/skills/<skill>
Codex:       <repository>/.agents/skills/<skill>
```

For Codex, also remove the managed `<!-- corelogic-ai-skills:start:<skill> -->` … `end` block from the repository `AGENTS.md` if it was added only for this skill.

### Account-installed skills

For ChatGPT or Claude Desktop/web, remove the skill from the product's Skills management interface.

# Repository-level installation

Use repository-level installation when a team wants the skill versioned with the application:

```bash
python tools/install_skill.py \
  --all \
  --target /path/to/my-dotnet-application \
  --platform claude \
  --platform cursor \
  --platform opencode \
  --platform codex
```

To install a subset, repeat `--skill` instead of using `--all`.

Project destinations:


| Platform | Destination |
|---|---|
| Claude Code | `.claude/skills/<skill>` |
| Cursor | `.cursor/skills/<skill>` plus optional `.cursor/rules/<skill>.mdc` |
| OpenCode | `.opencode/skills/<skill>` |
| Codex | `.agents/skills/<skill>` plus a managed `AGENTS.md` discovery block |
| ChatGPT | Upload packaged `dist/<skill>/skill.zip`; no project-folder installation |




# Repository layout

```text
corelogic-ai-skills/
├── skills/                 # canonical skill definitions
│   ├── dotnet-upgrade/
│   └── start-story/
├── adapters/               # thin platform discovery adapters
├── tools/                  # validation, installation, and packaging helpers
├── docs/                   # architecture and authoring guidance
├── requirements.txt        # optional third-party deps for future tooling
├── dist/                   # generated packages (gitignored)
└── .github/workflows/      # continuous validation
```

# Design principles

- Keep one canonical source per skill.
- Assess before modifying.
- Require explicit approval for risky or behaviour-changing work.
- Use platform-neutral capability language.
- Use deterministic scripts for repeatable inspection.
- Complete with evidence and state limitations transparently.
- Keep user configuration outside replaceable installed skill trees.

# Validate the library

From the repository root:

```bash
python tools/validate_library.py
python -m unittest discover -s skills/dotnet-upgrade/tests -p 'test_*.py' -v
python -m unittest discover -s tools -p 'test_*.py' -v
python tools/package_skill.py --all
python tools/package_repo.py
python tools/smoke_install_paths.py
```

`start-story` PowerShell tests (Windows PowerShell or `pwsh`):

```powershell
powershell -NoProfile -File skills/start-story/tests/Invoke-StartStoryTests.ps1
```

On Windows, if `python` is missing from `PATH`:

```powershell
py -3 tools\validate_library.py
py -3 -m unittest discover -s skills\dotnet-upgrade\tests -p 'test_*.py' -v
py -3 -m unittest discover -s tools -p 'test_*.py' -v
py -3 tools\package_skill.py --all
py -3 tools\package_repo.py
py -3 tools\smoke_install_paths.py
```

CI runs Python validation on Ubuntu and Windows, and runs the start-story Pester suite on Windows.

# Packaging a clean repository ZIP

**Do not** manually zip the repository folder in Explorer, Finder, or with an unfiltered `zip -r`. That commonly includes `.git/`, `dist/`, and `__pycache__/`, and it is easy to ship an incomplete tree.

Before publishing, generate the public archive with the packaging tool only:

```bash
python tools/package_repo.py
```

Publish only this file after the command reports completeness checks passed:

```text
dist/corelogic-ai-skills.zip
```

Behavior:

- Default: filtered **working-tree** ZIP (includes skill `scripts/` even if not yet committed)
- Excludes `.git/`, `dist/`, `__pycache__/`, and similar junk
- Fails if required skill/tool files are missing (“incomplete and must not be published”)
- Optional: `python tools/package_repo.py --git-archive` packs `HEAD` only when the working tree is clean

# Security

Review third-party skills before installing them. Skills can contain executable scripts and instructions that cause an agent to modify files or run commands. Use source control, inspect proposed changes, protect credentials, and keep approval gates enabled.

For `start-story`, keep PATs in the environment only. Keep inspection/validation output that may include feed URLs or restore diagnostics out of commits.

# Licence

See [`LICENSE`](LICENSE).

