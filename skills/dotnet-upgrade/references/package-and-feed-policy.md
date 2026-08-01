# Package and feed policy

## Update order
1. Microsoft framework-aligned packages.
2. Test SDK, adapters, and test frameworks.
3. Third-party packages grouped by related functionality.
4. Private packages after authentication and compatibility are known.
5. Vulnerable transitive dependencies using the narrowest safe resolution.
6. Confirmed unused packages.

## Private feeds
- Detect Azure Artifacts, GitHub Packages, Artifactory, ProGet, MyGet, local, and custom feeds.
- Use credential providers, environment-backed credentials, or interactive authentication.
- Never add clear-text credentials to `NuGet.config`.
- Preserve source mappings and package ownership.
- Report unavailable versions as unknown.

## Supply-chain checks
- Flag HTTP feeds, embedded credentials, floating versions, duplicate package identities across sources, disabled signature checks, and missing package source mapping where dependency-confusion risk exists.
- Preserve lock files when the repository intentionally uses locked restore; regenerate them through normal restore commands.

## Unused packages
Treat static usage as one signal only. Before removal inspect compile/runtime assets, build targets, analyzers, source generators, reflection, DI registration, configuration, native dependencies, content files, and test discovery. Remove in small batches and verify each batch.
