# Azure DevOps API Reference

Read **only if a script fails** or you need a new ADO API.

## Auth

Export `AZURE_DEVOPS_PAT` (Work Items Read + Code Read & Write). Config files
hold org/project/repo settings only. The PAT is read exclusively from the
environment — never from `config.json`.

```
Authorization: Basic base64(":" + PAT)
```

Advanced: load the PAT from PowerShell SecretManagement (or another vault) into
`AZURE_DEVOPS_PAT` in your shell profile.

## Endpoints

```
GET  .../_apis/wit/workitems/{id}?$expand=all&api-version=7.1
GET  .../_apis/git/repositories?api-version=7.1
GET  .../pullrequests?searchCriteria.sourceRefName=refs/heads/{branch}&searchCriteria.status=active&api-version=7.1
POST .../repositories/{repoId}/pullrequests?api-version=7.1
```

The PR body includes `workItemRefs: [{ "id": "<id>" }]`, and the description
ends with `AB#<id>` so Azure Boards links the work item.

## Branch naming

```
{branchPrefix}/{workItemId}-{kebab-case-title}
```

`branchPrefix` defaults to `story`; `organization`, `project`, and `baseBranch`
all come from `config.json` (see [setup.md](setup.md)).

## Common failures

| Symptom | Cause |
|---------|-------|
| `TF400813` / 401 | PAT expired, wrong org, or missing scope |
| `Repository '<name>' not found` | `origin` remote name differs from the ADO repo name |
| `Working tree contains uncommitted changes` | Dirty tree before branch create — commit, stash, or discard |
| `Failed to update '<base>' from origin` | Non-fast-forward local base — reset or reconcile manually |
| `does not match work item` | Current branch name does not include the work item id |
| `Cannot create a pull request from the target branch` | Still on `main` / configured base |
| PR created against the wrong branch | `baseBranch` in config, or pass `-TargetBranch` |
