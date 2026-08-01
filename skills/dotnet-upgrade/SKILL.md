---
name: dotnet-upgrade
description: Assess, plan, upgrade, secure, and validate a local .NET repository. Use when an AI coding agent is asked to modernize a .NET solution or project, select a supported stable target framework, update public or private NuGet dependencies, remediate vulnerable or deprecated packages, remove confirmed unused packages, resolve compatibility and security issues, update build or deployment configuration, run builds and tests, or produce an evidence-based upgrade report. Always assess first and require explicit user approval before modifying repository files.
---

# .NET Upgrade

Modernize a local .NET repository safely. Treat preservation of application behavior, supply-chain integrity, rollback ability, and verifiable evidence as primary requirements.

## Operating contract

Follow two mandatory phases.

### Phase 1: Assess and propose

1. Confirm the repository root and inspect repository instructions such as `AGENTS.md`, `CLAUDE.md`, `.cursor/rules`, contribution guides, and build documentation.
2. Check Git status. Do not overwrite unrelated user changes.
3. Run the inspection helper when Python is available:
   ```text
   python scripts/inspect_repo.py --root <repository-root>
   ```
   The script writes JSON under the system temp directory by default. To keep a copy near the repo, use a gitignored path with `--inside-repo`, for example:
   ```text
   python scripts/inspect_repo.py --root <repository-root> --output <repository-root>/.dotnet-upgrade/before.json --inside-repo
   ```
   Do not write inspection reports into tracked source paths. Command output may include feed URLs or restore diagnostics; treat the report as sensitive. If Python is unavailable, perform the equivalent inspection manually.
4. Record the baseline before changing files:
   - installed SDKs and `dotnet --info`;
   - restore, build, test, and publish status where safe;
   - target frameworks and project types;
   - package sources, central package management, lock files, and private feeds;
   - direct, transitive, vulnerable, deprecated, and outdated dependencies;
   - CI/CD, Docker, runtime, database provider, and tool manifests;
   - current warnings and test counts.
5. If assessment is incomplete because private feeds are inaccessible, restore failed, or baseline build status is unknown, state those gaps explicitly. Do not proceed to execution until the user accepts the uncertainty or access is restored.
6. Determine the target version from current official .NET support information. Default to the latest stable LTS release unless repository constraints or the user require a different supported stable version. Never select preview, release-candidate, or unsupported versions without explicit approval.
7. Read the relevant reference files before proposing changes:
   - `references/assessment-checklist.md`
   - `references/upgrade-strategy.md`
   - `references/package-and-feed-policy.md`
   - `references/security-review.md`
   - `references/verification-matrix.md`
   - after detecting project type, also read matching playbooks such as `references/netfx-to-sdk.md`, `references/aspnet-breaking-changes.md`, `references/cpm-and-lockfiles.md`, or `references/efcore-providers.md`
8. Produce an assessment and an ordered upgrade plan using `references/report-template.md`.
9. Stop and request explicit approval. Do not edit source, project, pipeline, Docker, configuration, lock, or package files before approval.

Approval must cover at least:

- target framework or SDK;
- direct versus incremental upgrade strategy;
- whether package major-version upgrades are allowed;
- whether security fixes may include behavior-changing code changes;
- which test suites and external services are safe to run.

### Phase 2: Execute after approval

1. Recheck Git status and baseline assumptions. Recommend an upgrade branch or rollback commit, but do not commit or push unless requested.
2. Apply the smallest coherent changes in controlled batches:
   1. SDK, `global.json`, target frameworks, and shared build properties;
   2. Microsoft framework-aligned dependencies and tooling;
   3. test infrastructure;
   4. third-party packages in compatibility groups;
   5. private NuGet packages after authentication is available;
   6. vulnerable and deprecated direct or transitive dependencies;
   7. confirmed unused packages, one logical group at a time;
   8. source compatibility and security fixes;
   9. CI/CD, Docker, deployment manifests, and documentation.
3. Restore, build, and run the relevant verification after every meaningful batch. Revert or isolate a batch that introduces unexplained regressions.
4. Preserve intentional multi-targeting and compatibility contracts unless removal is approved.
5. Use existing repository tools and conventions before introducing new analyzers, formatters, or test frameworks.
6. Finish with the complete verification matrix and rerun the dependency vulnerability scan.
7. Capture an after-state report with `scripts/inspect_repo.py`, then compare with `scripts/compare_reports.py <before.json> <after.json>` when both reports exist.
8. Produce a final report and concise pull-request summary. Clearly separate completed work, pre-existing failures, unresolved risks, and manual actions.

## Required safety rules

- Never expose, print, persist, or commit private-feed credentials, tokens, passwords, certificates, or connection secrets.
- Never commit inspection reports that may contain feed URLs or restore diagnostics.
- Never replace a private package with a similarly named public package.
- Never disable a feed, signature check, vulnerability warning, analyzer, or test merely to make verification pass.
- Never suppress a security advisory without documenting applicability, owner, rationale, and expiry.
- Never remove a package solely because text search finds no direct type usage. Check MSBuild assets, analyzers, source generators, reflection, DI registration, runtime loading, native assets, test discovery, and configuration.
- Never apply production database migrations, deploy an application, rotate secrets, or change infrastructure state without separate explicit approval.
- Never claim success from compilation alone. Report exactly which build, test, publish, startup, container, and scan checks ran.
- Never silently broaden framework, package, or security scope beyond the approved plan.
- Never make unrelated formatting or refactoring changes during an upgrade.

## Package and feed handling

Use official CLI capabilities when available, but verify output and compatibility. Inspect `NuGet.config`, `Directory.Packages.props`, package lock files, `Directory.Build.*`, tool manifests, and project-specific sources. For authenticated feeds, use the platform credential provider or interactive authentication. If access is unavailable, report private-package status as unknown rather than guessing.

Classify dependency findings as:

- required update;
- security remediation;
- deprecated or abandoned;
- compatibility blocker;
- likely unused, manual verification required;
- retained intentionally.

## Security scope

Review dependency, source, configuration, and deployment risks relevant to the changed application. Focus on high-confidence issues such as secrets in source, insecure package sources, dependency-confusion exposure, weak cryptography, unsafe deserialization, injection risks, path traversal, missing authorization, unsafe CORS or cookies, sensitive logging, production error leakage, insecure headers, and outdated container images. Do not perform speculative rewrites.

## Verification outcome

A successful completion requires evidence for all applicable items:

- restore;
- build;
- unit tests;
- integration or architecture tests;
- publish;
- application startup or smoke test;
- dependency vulnerability rescan;
- static analysis or formatting checks already used by the repository;
- Docker or deployment artifact build when present.

If a check cannot run, state why and provide the exact command or manual validation needed.

## Output

Use the report format in `references/report-template.md`. Include before-and-after metrics, files changed, package decisions, security findings, verification commands and results, unresolved risks, rollback guidance, and manual follow-up.
