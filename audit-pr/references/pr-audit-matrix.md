# PR audit matrix

For every area below, record `verified`, `finding`, `covered by existing work`, `not applicable`, or `blocked`, with evidence or a reason. Existing work covers an outcome but does not make an unfixed defect pass. Scale depth to the affected behavior and risk. Inspect adjacent unchanged code when necessary to understand impact.

| Area | PR review questions and evidence |
| --- | --- |
| Requirements and scope | Does the diff satisfy the linked issue, acceptance criteria, and PR-specific Definition of Done? Are checked claims supported by current code or verification? Are deferrals explicitly accepted? Does unrelated scope create a concrete risk? |
| Architecture and contracts | Do changed interfaces preserve dependency direction, ownership, caller expectations, API or IPC schemas, serialization, compatibility, and rollback? Do new abstractions simplify callers or expose implementation coordination? Trace affected consumers. |
| Correctness and resilience | Exercise relevant boundaries, null and overflow cases, encoding, time zones, pagination, ordering, concurrency, idempotency, cancellation, retry limits, stale writes, partial failures, startup, shutdown, and recovery. Identify a reachable trigger for each defect. |
| Maintainability | Run applicable compiler, formatter, linter, complexity, duplicate-code, and dependency checks. Inspect new suppressions, exclusions, dead code, global state, generated churn, and competing configuration sources. Require concrete maintenance impact for findings about design or naming. |
| Unit and integration tests | Map changed branches and failure paths to behavioral assertions. Check discovery, isolation, coverage omissions, contract tests, migrations, compatibility, and race or property tests where relevant. Tests that reproduce the implementation's mistake do not establish correctness. |
| Complexity and CRAP | Compare per-function cyclomatic complexity and coverage for changed functions with baseline. State coverage basis and thresholds. Separate a new or worsened risk from an unchanged legacy score or missing reporter. |
| Mutation testing | Check meaningful changed production targets, surviving mutants, generated-code exclusions, break and target thresholds, and actual gate execution. Missing infrastructure needs a PR-specific reason before it becomes a recommendation. |
| Behavior and end-to-end tests | Verify affected critical journeys and recovery paths. For Gherkin, confirm executable matching steps and detect undefined, pending, skipped, or tag-orphaned scenarios. Inspect retries, flake evidence, artifacts, and supported platforms. |
| CI and delivery | Match live checks to reviewed commits and base rules. Inspect triggers, path filters, skipped jobs, aggregate gates, caches, artifacts, permissions, fork safety, required reviews, unresolved conversations, release steps, and rollback. Distinguish code defects from pre-existing merge-control gaps. |
| CI feedback latency | Measure representative head and baseline PR runs where available: queue time, job and step timings, critical path, repeated review waits, reruns, and sample size. Inspect expensive memory, performance, soak, and E2E placement; selective execution; isolated parallel samples; cancellation; fast review feedback; and final-candidate qualification. Apply the detailed checks below. Attribute new or worsened delay to this PR; unchanged costs are context. |
| Security and privacy | Trace changed trust boundaries, authentication, authorization, tenant isolation, input validation, injection, file and URL handling, secret storage, logging, telemetry, retention, and deletion. Use safe proofs and redacted evidence. Never exploit a live service. |
| Dependencies and supply chain | Inspect manifests and lockfiles together, supported engines, transitive consumers, API and module compatibility, advisories, install scripts, provenance, action pinning, licenses, and notices. A clean vulnerability scan does not prove runtime compatibility. |
| Performance | Compare affected latency, throughput, startup, bundle or binary size, request or query count, rendering, batching, serialization, and allocation against a repeatable baseline. Record budgets, workload, warm-up, variance, and environment. |
| Memory and resources | Exercise affected repeated workloads and lifecycle cleanup. Inspect retained heap and native memory, handles, sockets, listeners, subscriptions, timers, threads, caches, and queues. Separate leaks, bounded caching, churn, and missing evidence. |
| UX, accessibility, and compatibility | Inspect affected rendered states, keyboard access, focus, semantics, contrast, zoom, reduced motion, responsive layout, localization, high-DPI behavior, loading, empty, stale, partial, and failure states. Cover relevant browser and OS differences. |
| Documentation and developer experience | Check changed setup, commands, configuration examples, API documentation, migration notes, troubleshooting, generated-file ownership, badges, links, and Markdown. Verify that the PR title and body describe the final diff and actual validation. |
| Operations and data lifecycle | Inspect changed health checks, logs, metrics, traces, alerts, feature flags, configuration validation, migrations, backfills, backups, restores, destructive operations, deployment ordering, rollback, and resource cleanup. Use isolated test data and report untested operational paths. |

## Tool selection

Choose tools from the repository's declared stack and pinned versions. Start with compiler or type checks, lint, existing tests, and existing reports. Use available coverage and complexity reporters, mutation runners, security scanners, profilers, accessibility checks, and benchmarks only when they answer a concrete PR question.

Confirm current compatibility and command syntax in official documentation. Prefer structured reports and stable exit codes. Avoid redundant analyzers and subjective scores. Run tools that emit caches or artifacts only in the disposable environment. If an analyzer needs new project dependencies or configuration, report the missing evidence instead of adopting it during the audit.

## Expensive CI qualification

For affected CI or delivery behavior, verify:

- Fast feedback can drive review corrections before expensive qualification finishes. Draft promotion and merge queues cannot deadlock or reuse a stale green check to bypass qualification of the final candidate.
- Change selection includes transitive runtime inputs, dependencies, lockfiles, packaging, test infrastructure, renamed paths, and unknown changes. Distinguish version-only metadata where relevant. Workflow-level path skips must not strand required checks; job and aggregate logic must reject failures, cancellations, missing evidence, and unexpected skips.
- Parallel samples remain isolated and comparable, retain meaningful warmup and soak duration, use distinct complete artifacts from the same candidate, and preserve the original statistics and paired cleanup calculations. Budget changes or shorter tests need separate measurement and baseline justification.
- Scheduled and release coverage complement the PR policy. Moving a check after merge requires an explicit risk decision, failure ownership, response and rollback arrangements, and exact release-candidate validation.

Recommend improvements from measured delay and repository risk, not a universal
minutes limit or the mere presence of a long test. Do not demand new CI machinery
for unrelated PRs. If representative timings are unavailable, record the gap
instead of inventing a speedup or calling an unchanged cost a PR regression.
