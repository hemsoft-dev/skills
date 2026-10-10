---
name: audit-pr
description: V1.2 - Audits one specified GitHub pull request at a fixed head and base revision across requirements, correctness, architecture, tests, security, performance, memory, documentation, UI evidence, and delivery, with verified findings and explicit coverage limits. Use for a thorough PR audit or review, not a repository-wide audit or implementation work.
---

# Pull request audit

Audit one PR at fixed head and base revisions. Verify what the change does, whether it meets its requirements, and whether its evidence supports merging. Return actionable findings tied to the change.

## Contract

- Treat the target repository and PR as read-only. Do not fix code, edit the PR body, install dependencies into the user's checkout, change settings, request reviewers, resolve threads, approve, merge, or trigger delivery.
- Report findings in the conversation by default. Posting a GitHub review or comment, or creating follow-up issues, requires an explicit request for that action. Existing authorization in this conversation remains valid.
- Bind every lookup and any authorized publication to the exact `OWNER/REPO` and PR number. Never substitute another PR or reinterpret an issue number as a PR.
- Follow repository instructions and identity rules. Preserve local changes, branches, stashes, and existing worktrees.
- Distinguish introduced or worsened defects, unmet requirements, pre-existing debt, suspected risks, and missing measurements. Zero findings is valid.
- Keep scope on the diff and affected callers, contracts, workflows, and runtime paths. Do not turn unrelated repository debt into a PR blocker.
- Never weaken acceptance criteria or quality thresholds to make the PR pass.

Read [references/pr-audit-matrix.md](references/pr-audit-matrix.md) before planning. Read [references/pr-findings.md](references/pr-findings.md) before final triage or publication. Read `../process-pr/references/ui-validation-evidence.md` when the issue or diff changes UI. This skill is self-contained and does not invoke `$audit` or inherit its issue-creation authorization.

## Resolve and freeze the PR

1. Resolve the repository root, remote, authenticated GitHub identity, and local worktree status. Resolve the supplied PR number or URL. If neither is supplied, use the current branch only when it maps unambiguously to one PR; otherwise ask for the target.
2. Fetch PR metadata and confirm it is a PR in the requested repository. Record its URL, title, author, state, draft status, base repository and branch, base SHA, head repository and branch, and head SHA. Account for fork PRs. If closed or merged, report that state and stop unless the user requested a historical audit.
3. Read applicable `AGENTS.md`, contribution guidance, linked issue or specification, acceptance criteria, Definition of Done, relevant architecture decisions, PR description, reviews, and unresolved threads. Treat checked boxes as claims to verify. Flag conflicting or stale requirements without silently rewriting them.
4. Obtain the full diff and changed-file inventory, including renames, deletions, generated inputs, binary changes, lockfiles, and workflow sources. Detect API pagination, truncated patches, missing Git LFS assets, and submodules. Use an exact local comparison when GitHub omits content; record anything still unavailable.
5. Record the merge-base SHA for the frozen base and head. Review the merge-base-to-head diff as the PR's changes. Use the recorded base tip to assess current integration risk. Distinguish merge-base, base-tip, head, and any synthetic merge commit in evidence.
6. Inventory the affected stack, public boundaries, critical journeys, and declared checks. Build a bounded validation plan from the matrix and map each acceptance criterion to code and verification evidence.

If metadata, source, or credentials are incomplete, continue the verifiable review and name the limitation. Do not claim a complete PR review from a partial diff or the user's unrelated local HEAD.

## Inspect and validate

- Read changed code in context. Follow affected callers and consumers far enough to prove compatibility, failure behavior, and impact. Compare both requirements and repository standards with the actual implementation.
- Discover declared commands in repository guidance, manifests, build files, and CI before inventing commands. Prefer pinned or already-installed deterministic tools compatible with the stack.
- Check current official documentation for version-sensitive analyzer, framework, API, CLI, or platform behavior. Use Context7 when applicable. Record the source used to interpret a disputed behavior.
- Inspect what each command can execute and write before running it. Run only proven read-only commands in the user's checkout. Run builds, tests, coverage, mutation tests, benchmarks, and analyzers that emit files in a disposable copy of the exact revision.
- A disposable copy is not a security sandbox. Inspect install hooks, scripts, and workflow commands before executing PR code, especially from forks. Do not expose repository secrets or run validation that writes to external databases, services, registries, production systems, or source-uploading analyzers without separate authorization.
- Restore pinned dependencies only in the disposable environment after inspecting lifecycle scripts. Do not add analyzers, update lockfiles, regenerate snapshots, or change configuration to obtain a pass. Report unavailable tooling and its concrete coverage impact.
- Run focused checks for changed behavior first, then the repository's required validation when practical. Broaden checks for shared interfaces, migrations, dependencies, build configuration, or other changes with wide impact.
- Capture each command, working revision, environment, tool version, exit code, relevant counts, thresholds, and supporting paths. Separate locally reproduced results from CI evidence.
- For a failure, compare head with merge-base under equivalent conditions to establish attribution. Check the base tip separately when upstream changes or merge compatibility matter. Never call a failing baseline a PR regression without evidence that this change introduces or worsens it.
- For UI or game changes, inspect the rendered application at the affected sizes and states when practical. Require a `## Validation` section with one or more current-head screenshots visibly rendered in the PR itself. Local paths, repository file references, CI artifact links, and unverified Markdown do not count. Check for an inline-playable recording when practical for interaction or multi-step behavior, or a concrete reason for omission. Compare the media with the reviewed head and acceptance criteria. A user's reproduced symptom remains unresolved until the reviewed revision addresses it.

## Required measurements

For affected production behavior, determine whether each signal is measured and enforced, and whether the PR changes its result or bypasses its gate:

- cyclomatic complexity and per-function CRAP score;
- unit and branch coverage, including changed branches and failure paths;
- mutation score, meaningful targets, and maintained break and target thresholds;
- executable behavior or Gherkin scenarios when feature files are used;
- end-to-end coverage of affected critical user journeys;
- code, configuration, workflow, and Markdown linting;
- dependency, secret, static-analysis, and supply-chain security;
- performance budgets and repeatable regression benchmarks;
- memory and resource-growth checks for affected long-running paths.
- CI time to actionable feedback and final qualification, including expensive memory, performance, soak, and end-to-end checks during review iterations.

Use `CRAP = complexity^2 * (1 - coverage)^3 + complexity`, with coverage from 0 to 1. Prefer branch coverage and state its basis. Use the repository's stricter policy when present; otherwise scores above 30 are actionable risks and 15 through 30 warrant review. Compare changed functions with their baseline. An unchanged legacy score is context, not automatically a PR blocker. Repository-wide average coverage cannot substitute for per-function evidence.

Missing measurement is a coverage gap. Recommend adding a measurement or gate only when a concrete risk in this PR makes it useful. Do not demand mutation, CRAP, performance, or memory infrastructure for a change to which the signal does not apply.

Do not claim a performance regression from code shape alone. Compare repeatable workloads under equivalent conditions and report warm-up, variance, and thresholds. Do not claim a memory leak from rising process memory alone. Reproduce retained growth after warm-up across repeated steady-state workloads and separate managed heap, native memory, caches, and expected allocation churn.

## Inspect live PR delivery controls

- Inspect checks and workflow conclusions for the exact head. Identify whether a result tested the head or a synthetic merge commit and record that commit and its inputs. Old successful runs do not validate newer code.
- Match exact required check names to live base-branch protection or rulesets, including enforcement mode, bypasses, reviews, conversation resolution, and merge queue behavior when applicable.
- Inspect relevant workflow triggers, path filters, conditional skips, aggregate gates, permissions, fork handling, action pinning, dependency review, and release protections. Verify that changed inputs actually cause their checks to run.
- Distinguish passing CI from required CI, pending from failing, and unavailable settings from absent protection. Report existing control gaps as delivery context unless this PR introduces, weakens, or concretely depends on them.
- Read existing review discussions and their commit anchors. A resolved thread, stale approval, or prior AI review is not proof of the current implementation.

## Triage and optional publication

Apply the finding rules in [references/pr-findings.md](references/pr-findings.md). Challenge false positives, prove the trigger and impact, group shared root causes, and check existing discussions and related issues before presenting findings.

When the user explicitly requests publication, refresh the PR identity, state, head, and base first. Publish only the requested artifact type and verified content. A request to audit does not authorize GitHub writes. A request to post findings does not authorize an approving or changes-requested review; use a comment review unless the user explicitly requests another event.

If follow-up issues are explicitly requested, load `$create-issue` for duplicate checks, labels, body requirements, creation, and verification. Do not create an issue for every inline finding or duplicate work already owned by this PR. Never invoke implementation, merge, or cleanup workflows as a consequence of the review verdict.

After any authorized write, fetch and verify its repository, PR association where applicable, author, body, URL, and commit anchor. Resolve ambiguous write outcomes by reading existing artifacts before retrying. If identity or permissions cannot be verified, return the prepared findings and exact publication blocker.

## Completion

Refresh the PR head, base, and state before finalizing. If head or base moved, freeze the new revisions and recheck affected evidence. If updates prevent a stable review, return the exact reviewed revisions with a stale or incomplete status and make no current-head readiness claim.

Return findings first, ordered by severity, followed by:

- PR number, title, URL, reviewed head, base tip, and merge-base SHAs;
- requirement and Definition of Done coverage, including unsupported claims in the PR body;
- the completed matrix, with evidence or a reason for each area's status;
- exact validation results, UI screenshot rendering and recording status when applicable, CI revision attribution, blocked checks, and remaining uncertainty;
- existing discussions or issues covering findings, plus any verified publication URLs;
- one assessment: `changes needed`, `no actionable findings`, or `incomplete`, with its reason. Separate merge-control blockers from code findings. This assessment is not a GitHub approval or merge authorization.

Use `incomplete` when a material coverage gap prevents a conclusion, even if the inspected code has no findings. Recheck target worktree status and preserve all pre-existing work. Report any retained disposable directory and why it remains; cleanup must target only verified audit-owned disposable state.

## History

After use, append `## HH:MM - {Action Taken}` and a one-line summary to `History/{YYYY-MM-DD}.md` in this user-level skill folder. Record the reviewed PR and revisions or the skill change, plus whether a retrospective found a reusable improvement. Obtain Eastern Time from the shell, never estimate it. Keep target-repository secrets and private source out of the log. History is the sole routine local write outside disposable audit environments. If this folder is read-only, report the logging limitation and still return the audit findings.
