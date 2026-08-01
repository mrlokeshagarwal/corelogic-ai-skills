# Profile: Atlas (example)

A filled-in example for a fictional three-repo product. Copy the shape, not the
content. Selected when `"profile": "example-atlas"` is set in `config.json`.

## Repos

| ADO repo | Contains | Validation |
|----------|----------|------------|
| `Atlas-Api` | Controllers, business layer, data layer, stored proc calls | `dotnet` build/test |
| `Atlas-Web` | Razor views, `wwwroot/js`, CSS | `node` build |
| `Atlas-Db` | SQL scripts and stored procedures | Manual review |

## Classification hints

| Story mentions | Likely repo(s) |
|----------------|----------------|
| endpoint, controller, DTO, stored proc call | `Atlas-Api` (± `Atlas-Db`) |
| screen, view, button, client-side validation | `Atlas-Web` |
| migration, index, stored procedure body | `Atlas-Db` |
| mobile app | Out of scope unless the story says otherwise |
| feature spanning UI + API | Multi-repo → ask once, then one PR per repo |

## Search budget (Step 3)

1. Keywords from the title → controller action → client-side caller → data layer
2. Max **5** targeted searches before summarizing findings
3. Check a sibling endpoint for the binding convention before changing a
   controller signature
4. Skip build output, lockfiles, and environment config unless the story is about them
5. Prefer `git log -S "<symbol>"` over broad directory scans

## Local conventions

- One PR per repo; never mix API and Web changes in a single PR.
- Client scripts live under `src/wwwroot/js` — check the real casing on disk.
- Environment files carry machine-local paths and must never be committed.
- Database changes ship as forward-only scripts; no in-place edits to applied migrations.
