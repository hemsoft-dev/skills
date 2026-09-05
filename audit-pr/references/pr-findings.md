# PR finding rules

## Evidence threshold

A PR finding needs all of these:

- a defect introduced or worsened by the diff, an unmet requirement, or a concrete risk created by the change;
- an exact path and the smallest useful line range at the reviewed revision;
- a reachable trigger, affected caller, violated contract, or reproducible check;
- an explanation of impact and a bounded correction outcome;
- evidence that the behavior is unintended and not already fixed at the reviewed head.

For a delivery-setting finding, identify the exact setting or check and its causal relationship to this PR instead of inventing a file anchor. A clear code proof can establish a defect without runtime execution; label it as inspection evidence and do not invent test results.

Compare baseline and head before blaming the PR. Include requirements that the implementation omitted even when no changed line represents the missing behavior. Anchor those to the relevant changed entry point and requirement, or use a summary finding when no accurate inline anchor exists.

Keep tool preferences, stylistic tastes, hypothetical optimizations, and unrelated repository debt out of actionable PR findings. Put significant pre-existing risks and measurement gaps in a separate context section, with their effect on confidence. Do not equate a missing analyzer with a confirmed defect.

## Challenge and deduplicate

1. Recheck the full function, callers, tests, supported configuration, and version-specific behavior. Account for intentional design, generated code, exclusions, mitigations, and unreachable paths.
2. Read existing PR reviews, inline threads, linked issues, and relevant open or closed issues and PRs. Follow pagination. A resolved discussion suppresses a finding only if its resolution still applies at the reviewed head.
3. Group symptoms with the same root cause and correction. Split independently actionable defects. Avoid one finding per repeated warning.
4. Retain unresolved findings already raised by others in the assessment, link to the existing thread, and avoid posting duplicate comments. Explain new evidence when a supposedly resolved issue remains reproducible.
5. Assign severity from impact and likelihood. Report uncertainty separately; severe tool wording does not replace proof.

## Severity

Use the repository's established severity scale when present. Otherwise:

| Severity | Meaning |
| --- | --- |
| Critical | Reachable compromise, irreversible data loss, or another verified condition that requires stopping delivery immediately. |
| High | Likely correctness, security, or availability failure with a practical trigger. |
| Medium | Material behavior, testing, performance, maintainability, or delivery risk introduced or worsened by the PR. |
| Low | Bounded documentation, usability, or developer-experience defect with concrete impact. |

## Finding format

Keep each finding concise:

- severity and an action-oriented title;
- permalink to the reviewed commit and smallest relevant line range;
- trigger and observed behavior, followed by the expected behavior and impact;
- proof, such as a reproduction command and result, test failure, baseline comparison, or traced code path;
- bounded correction and how to verify it;
- existing discussion or issue link when one already owns the finding.

Do not claim a command ran when it is only a proposed verification step. Preserve exact identifiers, check names, commands, paths, and results when editing prose.

## Authorized review publication

Before posting, verify the repository, PR number, current state, head SHA, base SHA, identity, and existing comments. Revalidate findings if either revision changed. Anchor inline comments to the reviewed commit and valid diff lines; use a summary comment for findings that cannot be accurately anchored.

Post one coherent review when possible. Default to a comment review when posting findings was authorized. Approving or requesting changes needs an explicit request for that review event. Do not publish on a closed or merged PR unless the authorization explicitly covers that state. Do not resolve threads or edit other people's comments.

Fetch the resulting review or comment and verify its body, author, PR, commit anchor, event, and URL. If a write returns an ambiguous result, look for the artifact before retrying. An authentication, permission, or identity failure leaves a prepared report, not permission to switch repositories or identities as a workaround.
