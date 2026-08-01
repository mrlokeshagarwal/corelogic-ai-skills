# start-story

Portable, approval-gated skill for starting Azure DevOps work items and finishing with a pull request. PowerShell scripts handle ADO/git ceremony; the coding agent implements the story.

## Key behavior

- Fetch work item → branch → implement → validate → commit/push → PR → handoff
- Human checkpoints after fetch, implement, and validate
- Never merges, auto-completes, or auto-reviews PRs
- Never runs `git add .`; stages story files only
- Auth via `AZURE_DEVOPS_PAT` only (never stored in config)

## Portability

Install with the library installer for Claude Code, Cursor, OpenCode, and Codex. Package with `tools/package_skill.py` for ChatGPT / Claude Desktop upload. Runtime still needs PowerShell (`pwsh` preferred), Git, and ADO access.

## Setup

1. Install the skill (global example):

```bash
python tools/install_skill.py --skill start-story --global --platform cursor
```

2. Create persistent config **outside** the skill folder (survives skill updates):

```text
Windows:     %USERPROFILE%\.corelogic-ai-skills\start-story\config.json
macOS/Linux: ~/.config/corelogic-ai-skills/start-story/config.json
Project:     <repo>/.corelogic-ai-skills/start-story/config.json
```

```bash
# example: user-level config on Linux/macOS
mkdir -p ~/.config/corelogic-ai-skills/start-story
cp skills/start-story/config.example.json \
  ~/.config/corelogic-ai-skills/start-story/config.json
```

```powershell
# example: user-level config on Windows
$dir = Join-Path $HOME ".corelogic-ai-skills\start-story"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
Copy-Item skills\start-story\config.example.json (Join-Path $dir "config.json")
```

3. Export `AZURE_DEVOPS_PAT` with Work Items (Read) and Code (Read & Write).

See `references/setup.md` for repo kinds, profiles, and verification commands.
