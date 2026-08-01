# Profile: <name>

Copy this file to `profiles/<name>.md` and set `"profile": "<name>"` in
`config.json` (or name it after the ADO project, lowercased, for auto-pickup).

A profile holds **judgment** guidance only. Mechanics — org, project, base
branch, repo paths, solutions, validation commands — belong in `config.json`.

## Repos

| ADO repo | Contains | Validation |
|----------|----------|------------|
| `<repo>` | <layers / tech> | dotnet \| node \| custom \| manual |

## Classification hints

| Story mentions | Likely repo(s) |
|----------------|----------------|
| <keyword> | `<repo>` |

## Search budget (Step 3)

1. <entry point → layer → layer trace order for this stack>
2. Max **5** targeted searches before summarizing
3. <stack-specific convention to check before changing a signature>
4. <paths to skip>

## Local conventions

- <one PR per repo? shared branch naming? deployment gotchas?>
- <files that must never be committed>
