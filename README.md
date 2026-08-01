# CoreLogic AI Skills

Portable, production-focused skills for AI coding agents.

CoreLogic AI Skills keeps one canonical definition for each workflow and supplies thin discovery adapters for Claude Code, Claude Desktop, Cursor, OpenCode, Codex, and ChatGPT.

## Available skills

| Skill | Status | Purpose |
|---|---|---|
| [`dotnet-upgrade`](skills/dotnet-upgrade/) | Beta | Assess, plan, upgrade, secure, and validate a local .NET repository. Repository changes require explicit approval after assessment. |

## How `dotnet-upgrade` behaves

The skill follows a mandatory two-stage workflow:

1. **Assessment stage** — inspect the selected repository, record the current state, identify the recommended supported .NET target, analyse packages and risks, and present an upgrade plan.
2. **Execution stage** — modify files only after the user explicitly approves the target and proposed scope.

The skill must not deploy an application, expose private-feed credentials, apply production database migrations, or claim success without build and test evidence.

## Prerequisites

The selected agent must be able to access the local repository and, for full execution, run commands inside it.

Recommended local prerequisites:

- Git
- Python 3.10 or later for the included helper tools
- An installed .NET SDK suitable for assessing the current solution
- Access to any required private NuGet feeds through the platform's normal credential provider

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
  --skill another-skill \
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

Official documentation: https://code.claude.com/docs/en/slash-commands

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

Official documentation: https://support.claude.com/en/articles/12512180-use-skills-in-claude

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

Official documentation: https://opencode.ai/docs/skills

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

Official documentation: https://cursor.com/docs/skills

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

Official documentation: https://help.openai.com/en/articles/20001066

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
Claude Code: ~/.claude/skills/dotnet-upgrade
Cursor:      ~/.cursor/skills/dotnet-upgrade
OpenCode:    ~/.config/opencode/skills/dotnet-upgrade
Codex:       ~/.agents/skills/dotnet-upgrade
```

For Codex, also remove the `## .NET upgrade workflow` section from `~/.agents/AGENTS.md` if it is no longer needed.

### Project installs

Remove the installed skill folder for each platform:

```text
Claude Code: <repository>/.claude/skills/dotnet-upgrade
Cursor:      <repository>/.cursor/skills/dotnet-upgrade
             <repository>/.cursor/rules/dotnet-upgrade.mdc
OpenCode:    <repository>/.opencode/skills/dotnet-upgrade
Codex:       <repository>/.agents/skills/dotnet-upgrade
```

For Codex, also remove the `## .NET upgrade workflow` section from the repository `AGENTS.md` if it was added only for this skill.

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
| Claude Code | `.claude/skills/dotnet-upgrade` |
| Cursor | `.cursor/skills/dotnet-upgrade` plus optional `.cursor/rules/dotnet-upgrade.mdc` |
| OpenCode | `.opencode/skills/dotnet-upgrade` |
| Codex | `.agents/skills/dotnet-upgrade` plus an `AGENTS.md` discovery note |
| ChatGPT | Upload packaged `dist/dotnet-upgrade/skill.zip`; no project-folder installation |

# Repository layout

```text
corelogic-ai-skills/
├── skills/                 # canonical skill definitions
│   └── dotnet-upgrade/
├── adapters/               # thin platform discovery adapters
├── tools/                  # validation, installation, and packaging helpers
├── docs/                   # architecture and authoring guidance
├── requirements.txt        # optional third-party deps for future tooling
├── dist/                   # generated packages (gitignored; created by package_skill.py)
└── .github/workflows/      # continuous validation
```

# Design principles

- Keep one canonical source per skill.
- Assess before modifying.
- Require explicit approval for risky or behaviour-changing work.
- Use platform-neutral capability language.
- Use deterministic scripts for repeatable inspection.
- Complete with evidence and state limitations transparently.

# Validate the library

From the repository root:

```bash
python tools/validate_library.py
python skills/dotnet-upgrade/tests/test_inspect_repo.py
python skills/dotnet-upgrade/tests/test_compare_reports.py
python tools/package_skill.py --all
python tools/smoke_install_paths.py
```

On Windows, if needed:

```powershell
py -3 tools\validate_library.py
py -3 skills\dotnet-upgrade\tests\test_inspect_repo.py
py -3 skills\dotnet-upgrade\tests\test_compare_reports.py
py -3 tools\package_skill.py --all
py -3 tools\smoke_install_paths.py
```

These checks confirm skill frontmatter and references, inspection/compare helpers, the generated `skill.zip`, and installer destinations for Claude, Cursor, OpenCode, and Codex. They do not exercise live agent UIs or an end-to-end .NET upgrade.

CI runs the same validation on Ubuntu and Windows.

# Security

Review third-party skills before installing them. Skills can contain executable scripts and instructions that cause an agent to modify files or run commands. Use source control, inspect proposed changes, protect credentials, and keep the approval gate enabled.

Inspection reports from `scripts/inspect_repo.py` may include feed URLs or restore diagnostics. Keep them outside the repository, or in a gitignored path with `--inside-repo`, and do not commit them.

# Licence

See [`LICENSE`](LICENSE).
