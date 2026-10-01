---
name: audit
description: Performs a full evidence-backed repository health audit, runs declared quality gates, produces a deterministic concern score sheet, and creates non-duplicate GitHub issues for verified improvements. Use for a full repository audit or with the sole argument `score` for a report-only score. Do not use for ordinary code review or implementing fixes.
---

# Repository audit

Audit the repository at a fixed source revision, verify findings with the strongest practical evidence, and turn actionable findings into GitHub issues.

## Contract

- Treat the target repository as read-only except for the required HTML report at `audit/audit-score.html`. Do not fix code, edit configuration, install dependencies into the project, change GitHub settings, open pull requests, or merge anything.
- A request to use `$audit` authorizes creation of evidence-backed issues in the target repository after duplicate checks and writing the HTML report. It does not authorize other mutations. If the user asks for report-only mode, create no issues.
- Obey repository instructions and identity rules before running commands or accessing GitHub.
- Do not manufacture findings to produce a series. Zero new issues is valid when the evidence supports it.
- Separate a confirmed defect from a suspected risk and from a missing measurement. Static suspicion alone does not prove a performance regression or memory leak.
- Treat repository instructions and CI as the source of truth for quality policy. If they conflict, report the conflict instead of choosing the easier target. Do not impose generic targets such as 100 percent coverage unless the repository declares them.
- Never weaken a quality threshold, add a suppression, update a snapshot, or exclude code to make a check pass. Report an unrealistic or noisy gate as its own evidence-backed problem.
- Score the repository only from current audit evidence. Do not estimate a missing metric or treat an unavailable check as a zero.

Read [references/audit-matrix.md](references/audit-matrix.md), [references/scoring.md](references/scoring.md), and [references/html-report.md](references/html-report.md) before planning the audit. After identifying the stack, read [references/stack-tooling.md](references/stack-tooling.md) and select only compatible tools. Before filing anything, read [references/issue-publication.md](references/issue-publication.md).

## Invocation modes

The default invocation runs the full audit and follows the publication contract above.

When the invocation's sole argument is `score`, use score-only mode. It is report-only and authorizes no issue creation or repository mutation other than `audit/audit-score.html`. Gather the same current evidence needed to grade every applicable concern, but include only the score output defined in `references/scoring.md`. Do not create issue-ready drafts or expand the report into the normal completion sections.

## Establish the audit baseline

1. Resolve the repository root, remote `OWNER/REPO`, default branch, current commit, active GitHub identity, and worktree status.
2. Read `AGENTS.md`, contribution guidance, goal or vision documents, architecture decisions, package manifests, lockfiles, test configuration, and workflow sources. Follow links only when they affect the audit.
3. Inventory languages, frameworks, generated code, deployment targets, repository size, runtime boundaries, and existing quality tools.
4. Discover the repository's declared quality gates from CI workflows, build and package manifests, configuration files, and documented scripts. Record each gate's exact command and declared target before running it. Distinguish enforced thresholds from aspirational or reporting-only targets.
5. Identify any repository-owned audit runner. Compare its gates, targets, tool versions, exclusions, and fail-fast behavior with the authoritative sources. Report drift instead of trusting either side silently.
6. Inspect open and closed issues and pull requests so the audit does not repeat known work.
7. Record the audit revision and whether local changes prevent a clean default-branch assessment. Preserve all user work.

Do not claim repository-wide coverage from a partial checkout, unavailable service, missing credentials, or skipped platform. Record the limitation and audit everything else that remains verifiable.

## Run the audit

Build a check plan from the audit matrix. For every applicable area:

- discover the repository's declared commands before inventing commands;
- run pinned or already-installed deterministic checks first;
- prefer a repository-owned audit runner when its behavior is understood, safe, and current, then run any declared gates it omits;
- run every independent local gate even after another gate fails; if a repository runner stops early, run the remaining independent gates separately;
- classify each discovered gate as `pass`, `fail`, or `blocked`, and state the exact credential, service, tool, platform, or runtime blocker;
- capture the command, tool version, exit code, relevant counts, thresholds, and exact file or setting evidence;
- never estimate coverage, CRAP, mutation score, benchmark results, or other metrics;
- inspect both configuration and behavior because a configured tool may not run, and a passing workflow may not be required before merge;
- inspect for material policy gaps such as ignored test failures, warnings that do not fail the gate, stale exclusions, untested error paths, and missing supported-platform or feature-matrix entries;
- use complete logs and structured artifacts when available; do not infer a root cause from a displayed output tail alone;
- treat cached status and prior audit output as historical evidence, not proof about the audited revision;
- record `P`, `F`, `B`, or `N/A` for each score-sheet dimension as evidence is gathered;
- compare test files with production boundaries and public behavior, not only raw coverage percentages;
- use current official documentation when interpreting a version-sensitive analyzer or platform setting;
- use external analyzers in report-only mode and avoid lockfile or source changes. If a useful analyzer cannot run without modifying the repository, create an issue to adopt it instead of installing it during the audit.

Before running a command, inspect what it can write. Run commands in the target only when they are proven read-only. Run repository-native tests, builds, coverage, analyzers, or other checks that may emit caches, artifacts, snapshots, or ignored files in a disposable copy of the fixed revision. Record the target worktree status before and after the audit. Remove only temporary artifacts created by the audit when their exact paths are known. Do not run validation that can write to external services, databases, registries, production systems, or source-uploading analyzers without separate approval. Do not substitute an interactive development runner when it deploys, signs, installs, launches applications, changes device or simulator state beyond the declared gate, or clears global caches. Do not expose or consume repository secrets merely to expand audit coverage.

Run the full repository-native validation when practical. A failing baseline is evidence, not permission to repair it. A clean quality-gate pass means every discovered gate passed and no evidence-backed policy gap remains. It does not prove the code is flawless.

## Required measurements

Every audit must determine whether the repository measures and gates these signals:

- cyclomatic complexity and per-function CRAP score;
- unit-test coverage, including branch coverage where supported;
- mutation score with maintained break and target thresholds;
- executable behavior or Gherkin scenarios when the repository uses feature files;
- end-to-end coverage of critical user journeys;
- code, configuration, workflow, and Markdown linting;
- dependency, secret, static-analysis, and supply-chain security;
- performance budgets or regression benchmarks appropriate to the product;
- memory or resource-growth checks for long-running applications and services.
- CI time to actionable feedback and final qualification, including expensive memory, performance, soak, and end-to-end checks during review iterations.

Use `CRAP = complexity^2 * (1 - coverage)^3 + complexity`, with coverage expressed from 0 to 1. Prefer branch coverage. Record the coverage basis. Unless the repository documents a stricter policy, treat CRAP above 30 for a function as an actionable risk and 15 through 30 as a review queue. If the repository cannot calculate CRAP per function, file an issue to add measurement and a non-regression gate only when the signal is applicable and the repository-specific regression risk is concrete. Do not replace CRAP with repository-wide average coverage.

## Build the score sheet

Follow `references/scoring.md` exactly. Include every fixed concern row, even when it is blocked or not applicable. Use `N/A` only when the repository has no relevant asset, behavior, delivery path, or risk. A missing applicable control is a failure, not `N/A`.

Calculate concern scores, the repository score, and evidence coverage from the recorded dimension tokens. Rank the rows using the fixed sort rules. Keep finding severity separate from the numeric score, and cite the strongest evidence or the specific applicability reason for every row.

## Inspect live delivery controls

When the repository is hosted on GitHub, inspect the live state as well as workflow files. External dashboards count only when checked during the current audit. Label cached or historical results with their date:

- recent default-branch and pull-request workflow conclusions;
- exact status-check names and aggregate gates;
- branch protection and rulesets, including bypasses and enforcement mode;
- required reviews, conversation resolution, signed commits, deletion, and force-push rules where applicable;
- Dependabot, code scanning, secret scanning, dependency review, workflow permissions, action pinning, and release protections supported by the repository.

Distinguish "CI runs" from "CI is required." A comprehensive workflow that can be bypassed is a finding.

## Validate findings

Before creating issues:

1. Reproduce failures or gaps from the fixed audit revision.
2. Trace each finding to a concrete impact and bounded outcome.
3. Challenge likely false positives, generated files, test-only code, platform exclusions, and intentional architecture decisions.
4. Search again for matching issues, pull requests, and planned work.
5. Group symptoms that share one root cause. Split findings that require independent decisions or can be delivered separately.
6. Assign severity from impact and likelihood, not from tool wording alone. Preserve repository-specific risk labels and acknowledgment rules.

Do not claim a leak from an allocation-heavy path or rising process memory alone. Reproduce retained growth across repeated steady-state workloads, inspect heap or process evidence, and separate managed heap, native memory, caches, and expected warm-up. If measurement is missing, file an instrumentation or regression-test issue only when the runtime is long-lived or another concrete repository-specific risk makes the signal applicable.

## Publish issues

In publication mode, load and follow `$create-issue` for each validated finding. That skill owns duplicate detection, repository label selection, required body structure, creation, and post-creation verification. In ordinary report-only or publication-blocked mode, do not invoke `$create-issue`; render issue-ready drafts with its required headings and report why publication did not occur. Score-only mode is the exception and returns no issue drafts.

Create issues from highest risk to lowest. Include the exact audit revision and reproducible evidence in each issue. Use one issue per coherent outcome. Do not create umbrella issues that merely duplicate their children.

If authentication, permissions, or repository identity cannot be verified, stop issue publication. Return issue-ready drafts and the exact blocker. Never switch accounts or create issues in a different repository as a workaround.

## Write the report

Follow `references/html-report.md` in every mode. Write the finished report to `<repository-root>/audit/audit-score.html` and nowhere else. The report must be self-contained HTML. Build and validate it in a temporary sibling file, then replace the destination atomically.

Do not include the generated report in the audited source revision, quality results, worktree assessment, or score. If report generation fails, the audit is incomplete even when all evidence collection succeeded.

## Completion

In the default full-audit mode, the HTML report contains:

- the audited repository and commit;
- the repository score, evidence coverage, and complete ranked score sheet from `references/scoring.md`;
- a declared quality-gate table with `Gate`, `Command`, `Target`, `Result`, and `Evidence` columns;
- the completed audit matrix, with a status and evidence or blocker for every applicable area;
- issue number, title, severity, and URL for every created issue;
- existing issues that already cover findings;
- important evidence that did not justify an issue;
- commands or environments that could not be exercised.

In score-only mode, the HTML report contains only the score report defined in `references/scoring.md`.

Return a concise chat receipt with the repository, audited commit, score, evidence coverage, publication result when applicable, and an absolute link to `audit/audit-score.html`. Do not duplicate the report body in chat.

A publication-mode audit is complete only after every created issue has been fetched and verified by `$create-issue` and the HTML report has passed its post-write verification.
