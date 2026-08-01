# dotnet-upgrade

A portable, approval-gated AI-agent skill for assessing, upgrading, securing, and validating local .NET repositories.

## Key behavior
- Works against the repository folder opened or exposed to the agent.
- Assesses first and stops for explicit approval before editing.
- Selects a supported stable target using current official information.
- Handles public and private NuGet dependencies without exposing credentials.
- Reviews vulnerable, deprecated, and carefully verified unused packages.
- Updates code, build configuration, CI/CD, Docker, and tools when approved.
- Produces evidence from restore, build, tests, publish, startup, and rescans.

## Portability
The canonical skill is platform-neutral. See the repository-level `adapters/` directory for Claude Code/Desktop, Cursor, OpenCode, Codex, and ChatGPT installation guidance.

## Helper tools
- `scripts/inspect_repo.py` inventories projects, frameworks, packages (including CPM and `packages.config`), and solution-scoped vulnerability/outdated scans. Writes outside the repository by default.
- `scripts/compare_reports.py` diffs before/after inspection JSON for frameworks and package versions.
- Build an upload package with `python tools/package_skill.py --skill dotnet-upgrade`.
