# Assessment checklist

## Repository and solution
- Locate solution (`.sln` / `.slnx`), project, props, targets, package management, lock, tool-manifest, configuration, Docker, and pipeline files.
- Detect ASP.NET Core, worker, console, class library, test, Blazor, WPF, WinForms, MAUI, Azure Functions, legacy .NET Framework, and mixed solutions.
- Detect `TargetFramework`, `TargetFrameworks`, and legacy `TargetFrameworkVersion`.
- Detect runtime identifiers, nullable settings, implicit usings, language version, trimming, AOT, and multi-targeting.
- When legacy Framework, ASP.NET, CPM/lock files, or EF Core are present, read the matching playbook under `references/`.
- Read repository-specific instructions and supported operating systems.

## Baseline
- Capture `dotnet --info` and installed SDKs.
- Run restore, build, tests, publish, and application startup only when safe.
- Record existing failures separately from upgrade regressions.
- Record warning counts, test counts, project counts, and target frameworks.

## Dependencies
- Locate all package sources and central package management.
- List direct and transitive packages.
- Identify outdated, vulnerable, deprecated, prerelease, locally referenced, and private packages.
- Detect `packages.lock.json`, floating versions, version overrides, and package downgrade warnings.

## Environment
- Inspect CI/CD SDK setup, agent images, caches, test and publish steps.
- Inspect Docker SDK/runtime images, Linux distribution, native libraries, non-root execution, health checks, and ports.
- Inspect EF Core providers, migrations, `dotnet-ef`, and database compatibility constraints.
- Inspect local tools, source generators, analyzers, OpenAPI generators, and code coverage tools.
