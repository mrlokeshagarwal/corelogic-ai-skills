# Verification matrix

Run applicable checks in repository-defined configuration and order.

| Check | Typical evidence | Required handling |
|---|---|---|
| Restore | successful restore and feed access | report inaccessible private feeds |
| Build | zero unexplained errors | separate pre-existing warnings |
| Unit tests | passed/failed/skipped counts | do not hide skipped tests |
| Integration tests | results and dependency requirements | state unavailable services |
| Publish | successful artifacts for relevant RIDs | verify runtime assets |
| Startup/smoke | process starts and critical endpoint responds | avoid production systems |
| Vulnerability scan | direct and transitive scan | document unresolved advisories |
| Static analysis | repository analyzers/format checks | do not introduce unrelated rule churn |
| Docker | image builds and starts when safe | check base image and non-root behavior |
| CI/CD | syntax/configuration review or local validation | do not trigger deployment without approval |

Always include exact commands and exit results in the final report.
