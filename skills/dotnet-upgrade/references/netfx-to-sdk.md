# Legacy .NET Framework to SDK-style

Use when assessment finds `TargetFrameworkVersion`, `packages.config`, non-SDK project files, or classic ASP.NET / WCF / WebForms workloads.

## Assessment signals
- `TargetFrameworkVersion` such as `v4.6.2` or `v4.8`
- `packages.config` instead of `PackageReference`
- `packages/` restore folders, binding redirects, `app.config` / `web.config` assembly redirects
- Project types: ASP.NET MVC 5, Web API 2, WCF, WinForms, WPF on .NET Framework

## Upgrade approach
1. Prefer an incremental path: Framework non-SDK → SDK-style on the same Framework TFM → .NET (Core) LTS when compatible.
2. Convert package management from `packages.config` to `PackageReference` before or during the SDK-style migration.
3. Inventory Framework-only APIs, `System.Web`, AppDomains, remoting, Code Access Security, and Windows-only assumptions.
4. Treat binding redirects as debt to remove, not something to preserve indefinitely.
5. For ASP.NET on Framework, plan a separate application-model migration; do not assume a TFM bump alone is sufficient.

## Safety
- Keep multi-targeting only when an approved compatibility contract requires it.
- Do not remove `web.config` transforms or IIS hosting settings without an approved hosting plan.
- Stop and re-approve if the work expands from TFM/package modernization into a full rewrite.
