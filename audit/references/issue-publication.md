# Finding triage and issue publication

Read this reference after the evidence pass and before loading `$create-issue`.

## Decide what deserves an issue

Create an issue only when all of these are true:

- the evidence applies to the audited revision or live repository setting;
- the impact is concrete;
- the desired outcome is independently deliverable and testable;
- no open issue or active pull request already owns the outcome;
- the finding is not merely a tool preference or an unverified optimization idea.

Closed issues and merged pull requests block publication only when their resolution still applies to the audited revision. Reopen or create follow-up work when current evidence proves that the resolved outcome has regressed or no longer covers the finding.

When evidence proves only that measurement is missing, create an issue only if the signal is applicable and a concrete repository-specific regression risk exists. Name the issue after adding that measurement and its maintained gate. Do not title it as a defect that has not been reproduced.

## Group findings

Use one issue for findings with the same root cause and acceptance test. Split work when findings have different risk, owners, rollout paths, or verification.

Good grouping examples:

- one issue for a CI job and its missing required-status rule when both are needed to enforce the same gate;
- one issue for adopting mutation testing with targets, thresholds, CI integration, and documentation;
- separate issues for a confirmed runtime leak and for unrelated missing memory regression infrastructure.

Avoid a broad "improve quality" issue, one issue per linter warning, or an umbrella issue that restates all child issues.

## Prioritize

Use repository labels when they exist. Otherwise describe severity in the body without inventing taxonomy.

- Critical: exploitable compromise, irreversible data loss, or a release path that must stop now.
- High: likely security, correctness, or availability impact with a practical trigger.
- Medium: material maintainability, test, performance, or delivery risk that can cause regressions.
- Low: bounded hygiene, documentation, metadata, or developer-experience debt.

Tool severity is an input. Confirm reachability, exposure, and mitigations before preserving it.

## Supply evidence to `$create-issue`

For each issue, provide the issue workflow with:

- audited commit and relevant live-setting timestamp;
- exact files, symbols, workflow jobs, status names, or settings;
- commands, tool versions, exit codes, counts, and thresholds;
- a short reproduction or inspection path;
- user, security, maintenance, or delivery impact;
- observable acceptance criteria;
- repository-native validation commands and expected results;
- supported type, area, priority, and risk labels.

Let `$create-issue` perform its own duplicate search and final verification. If it finds an existing issue, record that mapping and do not create another.

In report-only or publication-blocked mode, do not invoke `$create-issue`. Render drafts using that skill's required headings, but omit unverifiable created-artifact metadata and state the publication blocker.

## Publication order and stopping rules

Publish highest risk first. Continue through the validated list unless authentication fails, the repository identity changes, permissions are missing, GitHub rejects the issue, or new evidence invalidates the remaining batch.

Do not retry an ambiguous write blindly. Fetch the repository's issues to determine whether creation succeeded. Stop and report the exact state if it cannot be resolved safely.

After publication, fetch each issue and verify its number, title, body sections, labels, author, state, and URL. Return a concise finding-to-issue list plus duplicates and blocked findings.
