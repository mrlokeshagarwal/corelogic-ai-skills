# Example approval gate

The assessment is complete. No repository files have been changed.

Proposed scope:
- Upgrade `net8.0` projects to the latest supported LTS target verified from official Microsoft documentation.
- Update Microsoft and test packages first, followed by compatible third-party and private packages.
- Remediate two high-severity transitive vulnerabilities.
- Retain three packages marked as potentially unused until runtime usage is manually confirmed.
- Update the Docker runtime image and Azure DevOps SDK task.
- Run unit tests, integration tests that do not contact production, publish, startup smoke test, and vulnerability rescan.

Approval requested for this target and scope before edits begin.
