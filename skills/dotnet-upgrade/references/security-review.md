# Focused security review

Review only issues supported by repository evidence.

## Dependency and supply chain
- Known vulnerable direct and transitive packages.
- Deprecated or abandoned dependencies.
- Insecure sources, embedded credentials, floating versions, and dependency-confusion exposure.
- Outdated build tools, SDK images, runtime images, and CI actions/tasks.

## Application code
- Hard-coded secrets and sensitive logging.
- SQL/command injection and unsafe dynamic execution.
- Path traversal and unsafe file handling.
- Unsafe deserialization or XML parsing.
- Weak cryptography or insecure random generation.
- Missing authentication/authorization checks.
- Overly permissive CORS, cookies, proxy headers, or request limits.

## Configuration and deployment
- Development exception pages or verbose errors in production.
- Secrets in committed settings files.
- Missing HTTPS or security headers where applicable.
- Containers running as root without justification.
- Unsupported base images or operating systems.

Classify each finding by severity, confidence, evidence, action, and whether it is inside the approved upgrade scope.
