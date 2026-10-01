# Audit matrix

Use this matrix to prevent blind spots and supply evidence for the fixed concerns in `scoring.md`. Mark each applicable area as verified, finding, covered by existing work, not applicable, or blocked. Keep the supporting evidence, not just the status. The score sheet does not replace this matrix, and an `N/A` score does not permit skipping the applicability reason.

## Product and architecture

- Compare the code and roadmap with the repository's stated goal, supported platforms, and user journeys.
- Inspect module boundaries, dependency direction, public interfaces, global state, cross-layer coupling, circular dependencies, hidden side effects, and duplicated ownership.
- Look for modules that expose implementation details or force callers to coordinate multiple low-level operations.
- Identify dead code, unused exports and dependencies, duplicate implementations, excessive generated churn, and configuration split across competing sources of truth.
- Check migrations, serialization formats, IPC or API contracts, backward compatibility, and rollback behavior.
- After the tactical checks, produce the separate architecture rating and recommendations under [strategic-evaluations.md](strategic-evaluations.md).

## Tech-stack suitability

- Identify the application type, deployed component versions, workload, supported platforms, and operating constraints from current repository evidence.
- Use fresh web search and verified primary sources to compare the chosen stack with current support, security, performance, stability, and compatibility guidance for that application type.
- Produce the separate 1 to 10 tech-stack rating, criterion evidence, confidence, research source table, and recommendations under [strategic-evaluations.md](strategic-evaluations.md). Distinguish a justified patch or configuration change from a costly stack replacement.

## Correctness and resilience

- Inspect error propagation, retry limits, timeouts, cancellation, concurrency, ordering, idempotency, cache invalidation, stale writes, and partial-failure recovery.
- Check input boundaries, null and overflow handling, time zones, encoding, locale assumptions, pagination, rate limits, and resource exhaustion.
- Exercise startup, shutdown, offline, degraded dependency, interrupted update, and corrupted-state paths where relevant.
- Check whether background tasks expose failure and freshness state to users or operators.

## Maintainability and code quality

- Run compiler, formatter, linter, dead-code, duplicate-code, dependency-graph, and complexity checks across production, tests, scripts, migrations, generated-source inputs, and configuration.
- Inspect suppression files and ignore lists. Require a reason, narrow scope, and owner for each material exclusion.
- Find oversized functions and modules using measured complexity and change risk, not line count alone.
- Check API depth, naming consistency, ownership boundaries, generated-file policy, and whether documentation repeats enforceable workflow rules.
- Review dependency age, maintenance health, replacement opportunities, duplicate transitive versions, package weight, and unused direct dependencies.

## Tests and quality gates

- Map production components, domain rules, public endpoints, IPC handlers, background jobs, and critical UI journeys to tests.
- Verify unit tests assert behavior and failure paths instead of implementation details or snapshots alone.
- Inspect branch coverage and per-function complexity together. Calculate CRAP scores and identify the worst functions.
- Verify mutation testing runs meaningful production targets, excludes generated code for documented reasons, uses maintained thresholds, and fails CI below the break threshold.
- Distinguish enforced thresholds from aspirational, dashboard-only, or reporting-only targets. Do not fail a declared gate against a target the repository does not enforce.
- Compare repository-owned quality runners with workflows, manifests, configuration, and instructions. Record drift, omitted gates, stale tool pins, hidden exclusions, and fail-fast behavior.
- Treat cached status and prior audit artifacts as historical evidence. Use a fresh run for the audited revision, retain complete logs when available, and do not diagnose from an output tail alone.
- For Gherkin, count feature files and scenarios, confirm matching executable step definitions, run them, and reject undefined, pending, skipped, or tag-orphaned scenarios.
- Verify end-to-end tests cover the critical happy paths and recovery paths. Check isolation, retries, artifacts, platform coverage, and flake tracking.
- Inspect property tests, fuzzing, contract tests, accessibility tests, migration tests, and compatibility matrices where the system's risks justify them.
- Check that test discovery includes all intended files and that coverage collection does not silently omit untested production code.

## CI, release, and repository governance

- Enumerate workflow triggers, paths filters, job dependencies, conditional skips, timeouts, concurrency cancellation, artifacts, caches, permissions, and secret use.
- Confirm lint, type, unit, behavior, mutation, E2E, architecture, security, performance, memory, packaging, and build checks run when their inputs change across every supported platform, feature, and build matrix entry.
- Inspect the live default-branch ruleset or branch protection. Match required status names to the current workflow output exactly.
- Check whether an aggregate gate can pass when a required child job fails or skips unexpectedly.
- Review action pinning, least-privilege permissions, fork safety, script injection, artifact provenance, dependency review, release signing, environments, approvals, and rollback.
- Inspect release versioning, changelog generation, badge accuracy, generated workflow ownership, and documentation for required local checks.

### CI feedback latency and expensive checks

- Measure recent representative PR runs and review iterations. Record run URLs and revisions, queue time, critical-path duration, job and step timings, reruns, cancellation, and time after fast checks finish. Report sample size and variance; one slow run is evidence to investigate, not a universal regression.
- Identify serial samples, fixed warmups, redundant builds, cache overhead, and waits for slow CI that delay actionable review feedback. Compare against the repository's feedback budget; do not impose a universal duration limit.
- Assess fast checks on each update, expensive qualification after review on the final candidate, conservative change selection, isolated parallel samples, and scheduled or release backstops. Recommend only options supported by measured cost and product risk.
- Trace all production inputs, dependencies, lockfiles, packaging, test infrastructure, renames, large diffs, unknown changes, and version-only metadata through selection. Keep required workflows running; verify job skips and aggregate results cannot hide failure, cancellation, missing evidence, or stale revisions.
- Check draft-to-ready transitions, review automation, and merge queues for deadlocks or a previous green check permitting merge before final qualification. A review-feedback check must not silently replace the final merge gate.
- Preserve meaningful soak duration, budgets, baseline comparability, and sample statistics. Parallel samples need isolated comparable environments, distinct complete artifacts tied to the candidate, and the same aggregation and cleanup pairing. Do not count an individual sample as the full qualification or loosen thresholds to save time.
- Moving checks after merge changes protection. Require a stated risk decision, failure ownership, response and rollback policy, and exact release-candidate evidence. Scheduled runs may be delayed and cannot qualify a different revision.

## Security and privacy

- Run supported dependency, secret, static-analysis, container, infrastructure, and license scanners. Inspect recent GitHub security runs and unresolved alerts when authorized.
- Review authentication, authorization, tenant and account isolation, session and token storage, cryptography, trust boundaries, and privilege transitions.
- Check injection, SSRF, path traversal, unsafe deserialization, prototype pollution, XSS, CSRF, open redirects, insecure temporary files, archive extraction, and command execution where applicable.
- Review dependency confusion, lockfile integrity, install scripts, unpinned downloads, action references, SBOM or provenance, and release artifact verification.
- Inspect logging and telemetry for secrets, personal data, retention, consent, redaction, and deletion behavior.
- For desktop shells and webviews, inspect sandboxing, context isolation, navigation, CSP, permission handlers, IPC validation, update signing, and external URL handling.

Never print secrets or exploit a live service. Use safe proofs and redact sensitive evidence.

## Performance and resource use

- Identify user-visible latency budgets, throughput targets, startup and build times, bundle or binary size, network request count, database query count, and hot-path allocation.
- Run existing benchmarks against their baseline. Check statistical method, warm-up, variance, machine assumptions, and regression threshold.
- Look for blocking I/O, unbounded concurrency, N+1 work, repeated parsing, duplicate requests, excessive renders, poor batching, needless serialization, large dependency cost, and cache amplification.
- Measure before filing an optimization issue. If no repeatable benchmark exists, file the benchmark and budget as the first outcome.

## Memory and long-running stability

- Exercise repeated steady-state workloads and compare retained memory after warm-up and, where supported, forced garbage collection.
- Track the correct layers: managed heap, native or external allocations, renderer or worker processes, file descriptors or handles, threads, sockets, timers, listeners, subscriptions, caches, and queues.
- Inspect heap snapshots, allocation profiles, process metrics, and object retainers when practical.
- Check cleanup on unmount, cancellation, logout, account switching, reconnect, navigation, test teardown, and process shutdown.
- Distinguish a confirmed leak, bounded cache growth, allocation churn, delayed collection, and missing observability.

## Documentation and developer experience

- Run Markdown lint, link checking, spelling or terminology checks if declared, and metadata synchronization checks.
- Verify setup, build, test, release, architecture, troubleshooting, security, and contribution instructions against executable commands.
- Check badges against active workflow names and dynamic versions. Remove stale or decorative metadata.
- Keep agent guidance limited to durable repository-specific constraints; move generic workflow guidance into shared skills or documentation.
- Check reproducible bootstrap, tool version pinning, supported shells and platforms, environment examples, and failure messages.

## Accessibility, UX, and compatibility

- Run automated accessibility checks and inspect keyboard behavior, focus, labels, semantic markup, accessibility-tree output, contrast, reduced motion, zoom, and error recovery for critical views. Do not require a manual screen-reader pass unless the user or repository explicitly requests one.
- Check responsive layouts, localization, time and number formatting, high-DPI behavior, offline states, slow networks, and supported browser or OS matrices.
- Validate that loading, empty, stale, partial, and failure states remain distinguishable.

## Operations and data lifecycle

- Inspect structured logging, metrics, traces, health checks, alert ownership, service-level objectives, runbooks, and incident recovery.
- Check migrations, backups, restores, retention, archival, destructive operations, and disaster recovery with repeatable evidence.
- Review configuration validation, secret rotation, deployment health, rollback, feature flags, and cleanup of temporary or orphaned resources.
- Check license obligations, third-party notices, data provenance, and generated artifact provenance where applicable.
