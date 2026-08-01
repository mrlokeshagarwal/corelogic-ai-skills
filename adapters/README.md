# Platform adapters

The canonical source is `skills/dotnet-upgrade`. Adapters only make that workflow discoverable in each agent.

- Claude Code/Desktop: install the canonical folder under `.claude/skills/dotnet-upgrade`. Claude Desktop also needs an approved filesystem/development connector exposing the selected repository.
- Cursor: install the canonical folder under `.cursor/skills/dotnet-upgrade` (or globally under `~/.cursor/skills/dotnet-upgrade`). An optional `.cursor/rules/dotnet-upgrade.mdc` reinforces discovery.
- OpenCode: install under `.opencode/skills/dotnet-upgrade` or use its compatible skill search path.
- Codex: install the canonical folder under `.agents/skills/<skill>` and merge `adapters/codex/<skill>.snippet.md` into `AGENTS.md` when present.
- ChatGPT: build `dist/dotnet-upgrade/skill.zip` with `tools/package_skill.py` and upload it. Local-repository execution requires an environment or connector that exposes the repository files and command execution.
