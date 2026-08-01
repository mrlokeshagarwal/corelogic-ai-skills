# Central package management and lock files

Use when `Directory.Packages.props`, `ManagePackageVersionsCentrally`, or `packages.lock.json` is present.

## Central package management
- Treat `Directory.Packages.props` as the source of truth for versions.
- Keep project files free of duplicate `Version` attributes unless a deliberate override is required and approved.
- Update related packages as a group when Microsoft or test SDK packages must move together.
- After edits, restore and confirm no package downgrade warnings remain unexplained.

## Lock files
- If `packages.lock.json` exists and restore uses locked mode, regenerate locks through normal restore commands rather than hand-editing.
- Preserve intentional pinning; do not delete lock files to bypass conflicts.
- Report unresolved private-feed versions as unknown when authentication is unavailable.

## Assessment output
- Merge CPM versions into the dependency inventory before proposing upgrades.
- Distinguish direct project references, centrally managed versions, and transitive vulnerabilities.
