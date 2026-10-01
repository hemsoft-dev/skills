# Deterministic repository score sheet

Use this reference for every full audit and for `score` mode. The score describes the audited revision and live controls checked during that audit. It is not a forecast and must not reuse an old score as current evidence.

## Fixed concern catalog

Every score sheet must contain these rows. Do not add, remove, merge, or rename rows for a particular repository. Repository-specific checks belong in the evidence for the closest concern.

| ID | Concern | Includes |
| --- | --- | --- |
| PA | Product fit and architecture | Stated goals, supported platforms and journeys, boundaries, dependency direction, interfaces, ownership, compatibility, migrations, and rollback design |
| CR | Correctness and resilience | Error handling, retries, timeouts, cancellation, concurrency, edge inputs, degraded states, recovery, and visible freshness or failure state |
| MQ | Maintainability and dependency health | Compiler and analyzer results, dead or duplicate code, dependency shape and age, suppressions, naming, generated-code policy, and sources of truth |
| CX | Complexity and CRAP | Per-function cyclomatic complexity, branch coverage basis, CRAP calculation, thresholds, and worst-function regression control |
| UC | Unit and branch coverage | Behavioral unit tests, failure paths, branch coverage, production-code inclusion, and maintained coverage gates |
| MT | Mutation testing | Production targets, exclusions, break and target thresholds, current mutation score, and CI enforcement |
| BS | Executable behavior specifications | Feature files, scenario and step matching, undefined or skipped scenarios, tags, execution, and maintained behavior gates |
| EJ | End-to-end critical journeys | Critical happy and recovery paths, isolation, retries, artifacts, supported platforms, and flake tracking |
| LQ | Lint and static quality | Code, configuration, workflow, and Markdown linting, formatting, type checks, warnings, and enforced exclusions |
| ST | Specialized test coverage | Property, fuzz, contract, accessibility, migration, architecture, compatibility, and other risk-driven tests, including test discovery |
| CG | CI, release, and repository governance | Workflow coverage, aggregate gates, required checks, rulesets, permissions, action pinning, provenance, release controls, and rollback |
| CL | CI feedback latency | Queue and critical-path time, representative samples, reruns, change selection, fast feedback, final qualification, and expensive checks |
| SP | Security, privacy, and supply chain | Dependency, secret, static, container, infrastructure, and license scanning; trust boundaries; data handling; workflow and artifact supply chain |
| PF | Performance and efficiency | Budgets and benchmarks for latency, throughput, startup, build, size, requests, queries, allocation, and hot paths |
| MR | Memory and long-running stability | Retained growth, heap and native memory, processes, descriptors, threads, listeners, queues, caches, cleanup, and leak evidence |
| DD | Documentation and developer experience | Setup, build, test, release, architecture, troubleshooting, links, metadata, reproducible tools, supported environments, and failure messages |
| UX | Accessibility, UX, and compatibility | Semantics, keyboard and focus behavior, contrast, motion, zoom, responsive states, localization, offline behavior, and supported clients |
| OD | Operations and data lifecycle | Logs, metrics, traces, health, alerts, runbooks, migrations, backup and restore, retention, deployment, rollback, flags, and cleanup |

The catalog covers every section of `audit-matrix.md`. The required measurement list in `SKILL.md` maps to CX, UC, MT, BS, EJ, LQ, SP, PF, MR, and CL.

## Four evidence dimensions

Grade each applicable concern on the same four dimensions. Use only the tokens `P`, `F`, `B`, and `N/A`.

| Dimension | `P` | `F` | `B` | `N/A` |
| --- | --- | --- | --- | --- |
| Expectations | The repository has a clear applicable behavior, boundary, budget, threshold, or policy. | An applicable expectation is missing, contradictory, or stale. | The source that defines the expectation cannot be inspected. | A separate declared expectation has no meaning for this concern. |
| Controls | Appropriate checks, tests, design controls, or operating controls cover the relevant boundaries. | A required control is absent, materially incomplete, bypassed, or hidden by an unjustified exclusion. | The control exists but cannot be inspected or exercised. | A separate control has no meaning for this concern. |
| Current evidence | Fresh evidence for the audited revision satisfies the applicable expectations and has no validated finding. | A command fails, a target is missed, or inspection confirms a defect or policy gap. | Credentials, services, platform, tool, or runtime limits prevent current evidence. | No current execution or inspection can meaningfully apply. |
| Enforcement | Repeatable regression controls run at the correct review, merge, release, or operating stage. | An applicable repeatable control is advisory, skippable, missing, or attached to the wrong stage. | Live enforcement state cannot be inspected. | Repeatable enforcement has no meaningful form for this concern. |

A verified absence is `F`, not `B`. Use `B` only when evidence cannot be obtained. A declared tool that does not run against the audited revision is not current evidence.

## Applicability rules

Decide applicability from repository contents, runtime boundaries, delivery path, and stated goals before looking at whether a tool is configured.

- Mark a whole concern `N/A` only when the repository has no relevant asset, behavior, delivery path, or risk. Set all four dimensions to `N/A` and give a specific reason.
- Missing implementation never makes a concern `N/A`. If the risk applies and the control is missing, use `F`.
- A documentation-only repository can mark CX, UC, MT, BS, EJ, PF, and MR `N/A` when it has no executable source or runtime matching those concerns.
- Do not mark SP `N/A` merely because there is no application code. Dependencies, workflow actions, publishing, downloaded tools, credentials, generated sites, and release artifacts make supply-chain security applicable. A repository with none of those and no sensitive data or executable content may mark SP `N/A`.
- Mark BS `N/A` when the repository has no feature files and does not claim executable behavior specifications.
- Mark MT `N/A` only when there is no nontrivial executable behavior for which mutants would test the suite.
- Mark MR `N/A` when the repository has no long-running process, worker, interactive application, retained in-process state, or managed native resource.
- Mark UX `N/A` only when the repository produces no user-facing interface, rendered documentation, interactive output, or supported-client behavior.
- A missing CI, release, security, or test control is usually `F` when contributors or users depend on that control. It is not evidence that the concern is unavailable.

If applicability remains uncertain after inventorying the repository, use `B` and state what evidence would settle it. Do not use `N/A` to improve the score.

## Score calculation

Calculate each concern independently.

1. If all four dimensions are `N/A`, set the concern score to `N/A`.
2. If any applicable dimension is `B`, set the concern score to `Blocked`. Do not assign a number.
3. Otherwise, count `P` as 1 and `F` as 0. Exclude `N/A` dimensions from the denominator.
4. Calculate `100 * P / (P + F)` and round to the nearest whole number. Round an exact half upward.

This produces a 0 to 100 score without severity weights or invented repository targets. Keep severity separate. The concern score reflects control maturity and current evidence, while severity describes the worst validated impact.

Calculate the repository score as the unweighted arithmetic mean of all numeric concern scores, rounded the same way. Exclude `N/A` and `Blocked` rows. Equal weighting prevents a large codebase or a tool with many findings from dominating the result.

Calculate evidence coverage as:

```text
numeric applicable concerns / all applicable concerns * 100
```

Exclude `N/A` rows from both terms. If any concern is `Blocked`, label the repository score `Provisional` and show evidence coverage. If no concern has a numeric score, report `Not scored`. Never convert `Blocked` or `N/A` to zero.

Do not map the result to letter grades, maturity names, colors, or pass/fail labels. The repository's declared gates decide pass or fail. The score is a compact comparison of the evidence, not a replacement for the evidence.

## Ranking and table

Sort numeric concerns from lowest score to highest. Break ties by worst validated severity in this order: Critical, High, Medium, Low, None. Break remaining ties by concern ID. List `Blocked` rows next by concern ID, then `N/A` rows by concern ID. Number only numeric rows in the `Rank` column. Use `Not ranked` for the rest.

Render this table without omitting rows:

| Rank | ID | Concern | Expectations | Controls | Current evidence | Enforcement | Score | Worst severity | Evidence or N/A reason |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |

Use `None` when a scored concern has no validated finding. Existing issues and accepted risks do not erase a current finding or raise the score. Link or cite the strongest evidence in the last column.

## Score-only report

When the invocation's sole argument is `score`, write `audit/audit-score.html` with only:

1. repository and audited commit;
2. `Repository score`, `Evidence coverage`, and whether the score is provisional;
3. the complete ranked table;
4. short notes for blockers and `N/A` decisions that need more context than the table can hold.

Follow `html-report.md` for the document shell, fixed destination, accessibility, and validation. Do not include issue drafts, publication sections, the full narrative audit, or recommendations in score-only output. Evidence collection remains as rigorous as a full audit. A shorter report does not permit estimated metrics or skipped applicable checks.
