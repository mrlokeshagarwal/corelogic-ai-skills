# Example checkpoint after fetch

Using the start-story skill.

Story #1234 — Add retry policy to payment client  
Type: User Story · State: Active

Acceptance criteria:
- Retries transient HTTP 408/429/5xx up to 3 times with backoff
- Non-transient errors fail fast
- Unit tests cover success, retry, and permanent failure

Proposed repo: `Payments-Api` (dotnet)

Reply `continue` to create/reuse the story branch, or correct the repo scope first.
