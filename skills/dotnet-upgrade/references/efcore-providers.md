# EF Core and database providers

Use when the repository uses Entity Framework Core, `dotnet-ef`, or database provider packages.

## Assessment
- Identify EF Core version, provider packages, migrations assembly, and design-time factory usage.
- Check whether providers and tools are aligned with the approved target framework.
- Note production migration policy; never apply production migrations without separate approval.

## Upgrade order
1. Align Microsoft.EntityFrameworkCore.* and provider packages with the target TFM.
2. Update `dotnet-ef` local tool or CI tool install if present.
3. Build and run existing migration compile checks or repository-defined EF tests.
4. Review breaking changes for query behavior, value converters, and naming conventions only when evidence requires it.

## Safety
- Do not generate or apply migrations against shared or production databases during upgrade work.
- Call out provider gaps or unsupported target combinations as blockers in the assessment.
