# Platform adapters

Canonical skills live under `skills/<skill-name>`. Adapters only make those workflows discoverable in each agent.

Current skills: `dotnet-upgrade`, `start-story`.

- Claude Code/Desktop: install under `.claude/skills/<skill>` (global `~/.claude/skills/<skill>`). Claude Desktop also needs an approved filesystem/development connector for local repos; upload `dist/<skill>/skill.zip` for account skills.
- Cursor: install under `.cursor/skills/<skill>` (or globally under `~/.cursor/skills/<skill>`). Optional `.cursor/rules/<skill>.mdc` from `adapters/cursor/` reinforces discovery.
- OpenCode: install under `.opencode/skills/<skill>` or use a compatible skill search path.
- Codex: install under `.agents/skills/<skill>` and merge `adapters/codex/<skill>.snippet.md` into `AGENTS.md` when present.
- ChatGPT: build `dist/<skill>/skill.zip` with `tools/package_skill.py` and upload it. Local-repository execution requires an environment or connector that exposes the repository and shell.
