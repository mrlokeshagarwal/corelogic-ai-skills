# Upgrade strategy

## Target selection
Prefer the latest stable LTS release supported by the application and deployment environment. Verify current support status from official Microsoft documentation at execution time. Do not hard-code a version in the skill.

Choose a specific supported stable version when:
- hosting or vendor support limits the target;
- a critical private package is not compatible with the latest LTS;
- Azure Functions, MAUI, WPF, or another workload imposes constraints;
- the user explicitly approves a different target.

## Direct versus incremental
Use a direct upgrade when project type, dependencies, and breaking-change review show low risk. Use incremental major-version steps when the repository is old, mixed, heavily dependent on framework-specific behavior, or has weak tests.

For each step:
1. update SDK and framework declarations;
2. align framework packages;
3. restore and compile;
4. resolve documented breaking changes;
5. run tests and publish;
6. record evidence before continuing.

## Scope control
Do not combine modernization with broad architecture refactoring. Split optional improvements into follow-up work unless required for compatibility or security.
