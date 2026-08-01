# ASP.NET Core breaking-change checklist

Use when upgrading ASP.NET Core / minimal hosting / Blazor projects across major versions.

## Hosting and startup
- Review `Program.cs` / `Startup` hosting model differences for the target major version.
- Confirm Kestrel, reverse-proxy, forwarded-headers, and HTTPS defaults still match deployment.
- Revisit middleware order after framework package updates.

## Configuration and auth
- Check authentication/authorization package alignment with the target shared framework.
- Validate cookie, CORS, antiforgery, and SameSite settings after upgrades.
- Confirm configuration binding and options validation still compile and behave.

## MVC / minimal APIs / Blazor
- Search for obsolete attributes, removed APIs, and analyzer warnings introduced by the new TFM.
- Validate endpoint routing, model binding, and JSON serializer settings.
- For Blazor, confirm render mode, JS interop, and hosting model compatibility.

## Evidence
- Run the app smoke test and any existing integration tests that exercise HTTP pipelines.
- Record framework-aligned package versions in the final report.
