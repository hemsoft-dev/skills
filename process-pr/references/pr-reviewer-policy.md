# PR reviewer policy

This is the single source of truth for external PR review products, selection,
request methods, and retry limits. All PR workflows must read it before
requesting reviews or deciding readiness. Update this file when products change;
do not copy its roster or owner rules into other skills.

Franz's 2026-09-16 policy selects connected Codex as the default reviewer and
GitHub Copilot PR Review as the required reviewer for `relias-engineering/*`.
Other optional products use unstable free-tier access. Their installation or
past activity does not justify discovery, requests, retries, or waiting.

Franz reaffirmed on 2026-10-05 that `HemSoft/*` uses connected Codex for PR
reviews. It is the only required AI reviewer for those repositories. Older
multi-product rosters and trigger examples must not cause agents to request or
wait for other products. Assess actionable findings already present without
turning an optional integration's refusal into a merge blocker. A later direct
user instruction can select an additional reviewer; preserve effective GitHub
status-check and formal-approval requirements separately.

## Product registry

These are workflow choices, not a claim that every product is currently
installed or available in every repository.

| Product | Selection | Request behavior |
| --- | --- | --- |
| Connected Codex | Default required AI reviewer for all owners | Use the request procedure below |
| Cubic | Passive only | Read findings already present; do not trigger or wait for optional runs |
| CodeRabbit | Passive only | Read findings already present; do not probe availability or request |
| Macroscope | Passive only | Read findings already present; do not probe availability or request |
| Greptile | Passive only | Read findings already present; do not probe availability or request |
| GitHub Copilot PR Review | Required for `relias-engineering/*`; explicit requirement only elsewhere | Use the request procedure below |

An unlisted product is passive only until the user changes this registry or an
explicit repository requirement puts it in scope. Passive means findings are
still assessed, but a missing, pending, failed, or quota-limited optional run
does not become an AI-review gate.

## Select the required reviewers

1. Resolve the canonical repository owner and current PR head. Start with the
   default in the registry. The active login does not select a reviewer.
2. Read applicable repository instructions and required checks. Add only
   reviewers explicitly required there or by the user. Mere configuration,
   installation, automatic activity, or historical PR use is not a requirement.
3. A repository restriction that forbids the default takes precedence. Use its
   explicitly mandated reviewer only with user direction if it would replace
   Codex. Report the conflict and leave the gate blocked in the meantime.
4. Do not scan recent PRs, app installations, labels, billing, or vendor docs to
   discover optional reviewers. Inspect product-specific configuration only to
   satisfy a named requirement or explain a concrete required-gate failure.

Repository-required checks and human approvals still apply. Do not disable or
bypass them. If older skill text or memory recommends more products, this
policy supersedes that recommendation. Record any owner exceptions here.

### Owner exceptions

- `relias-engineering/*`: GitHub Copilot PR Review is required for every current
  head. Connected Codex is not required unless the user explicitly requests it
  for the specific pull request.

## AI review and formal approval

Franz's 2026-09-30 instruction makes a clean, completed current-head review
from the selected required AI reviewer sufficient for the AI-review gate.
Do not invent a formal human-approval requirement or ask for another approval
solely because the AI reviewer uses a comment or thumbs-up instead of GitHub's
`APPROVED` review state. This rule applies to all composing PR workflows.

Before deciding readiness, record whether formal approvals are required by
applicable instructions, explicit user direction, effective base-branch
protection, or active repository and organization rulesets. Keep required
human approval counts, code-owner approvals and change-request rules intact.
An inaccessible or ambiguous requirement remains a blocker, not proof that no
approval is required. Never change protections, impersonate a reviewer or
manufacture an approval to satisfy a status column.

When no formal approval is required, `Rev -` or a comment-only review state is
acceptable if the required AI reviewer is current-head clean, all other gates
pass and no live change request remains. Report the actual formal review state
and the evidence that formal approval is not required. An AI-clean receipt is
not a formal GitHub approval and does not supply merge authority by itself.
GitHub documents formal review and code-owner requirements in its
[protected-branch policy](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches).

| Evidence | Review gate |
| --- | --- |
| Current-head required AI review clean; no formal approval required; `Rev -` | Pass, subject to all other gates |
| Current-head required AI review clean; required formal approval missing | Blocked |
| Required AI review pending, refused, ambiguous or tied to an older head | Blocked |
| Live change request or unresolved actionable finding | Blocked |
| Review clean but required CI failed or pending | Overall readiness incomplete |

## Request connected Codex

Verify the effective API identity with `gh api user --jq .login`, not only
`gh auth status`. For `HemSoft/*` and `hemsoft-dev/*`, use `HemSoft` for reads and requests. The
requesting account must be connected to Codex with access to the repository.
Do not assume `GITHUB_TOKEN`, an installation token, or `github-actions[bot]`
inherits a human's Codex connection. Never post from a bot identity known to
lack that access.

Capture the head SHA, request time, and evidence URL. Refresh PR issue comments,
reviews, threads, checks, and reactions before requesting. Reuse an existing
request, active run, or clean result for the unchanged head, including an
automatic review. Otherwise post exactly once:

```powershell
gh pr comment <pr> --repo <owner/repo> --body "@codex review"
```

For long or concurrent runs, verify identity immediately before each review
request and other PR write; an earlier preflight login can become stale. If
another session changes the shared `gh` login, bind the already-stored required
account credential per process and verify `gh api user` under that binding.
Do not print or persist tokens, initiate a login, or overwrite the other
session's shared account selection. If identity drift produced an accepted
current-head request, preserve its actual requester and reuse the accepted run;
do not post a duplicate merely to correct the requester recorded in a receipt.
Explicit refusals still follow the access-correction limits below.

The repository must have connected Codex code review enabled. The exact comment
trigger and automatic review setup are documented in
[OpenAI's GitHub integration guide](https://learn.chatgpt.com/docs/third-party/github).

Require a completed clean signal attributable to the current head, plus no
unresolved actionable findings. Inspect ordinary PR comments as well as formal
reviews. A bot-authored clean receipt or documented thumbs-up on the request
can count only when the request and result can be tied to this head. For an
automatic review, a completed summary naming the current SHA and a bot
thumbs-up on the PR can qualify when both belong to that review. An old
reaction alone never qualifies. Ambiguous head association is pending evidence,
not a pass.

A trigger comment, eyes reaction, silence, or disappearing reaction is not
completion. Refresh issue comments before concluding that a review failed.
Never call a clean comment or reaction a formal GitHub approval.

## Request GitHub Copilot PR Review

For required Copilot, including every `relias-engineering/*` pull request, reuse
a current-head request or result; when absent, request once with:

```powershell
gh pr edit <pr> --repo <owner/repo> --add-reviewer "@copilot"
```

Verify that GitHub retained or acted on the request. Require a completed
current-head review with no actionable findings or unresolved threads; report
the actual review state rather than assuming formal approval. After a fix is
pushed, request one fresh Copilot review for the new head unless an automatic
current-head review is already active or complete. A review of an older head
cannot satisfy the gate.

## Other required exceptions

For any other explicitly required product, read that repository's documented
trigger and completion contract. Allow an existing automatic run to finish.
Never invent a trigger or reuse another repository's workflow inputs. A broken
required integration is a blocker, not permission to install, repair, or
replace it.

## Wait and failure limits

- Make at most one request per required reviewer per unchanged head. A composing
  workflow must reuse the same request and evidence rather than start another
  review loop.
- Poll required reviews and checks at 60-second intervals, continuing useful
  work between checks. Without a caller deadline, stop this wait after
  10 minutes and report the pending request, head, elapsed time, and evidence.
  This is a local wait budget, not a provider SLA or proof of failure.
- On explicit quota, plan, permission, or configuration failure, record it
  once and stop attempts. Do not try the passive products as fallbacks.
  Treat messages such as "create a Codex account and connect to github" as
  terminal access refusals for that requester, not queued reviews. Attribute
  refusals to the request and head; an old refusal does not invalidate a later
  accepted request from a connected account.
- If an earlier bot request was explicitly refused and a connected authorized
  human account is available, one replacement request from that account is a
  meaningful access correction. Verify its author and response. Do not repeat
  the rejected bot request or change credentials, secrets, or repository
  integrations without authority.
- A pending or unavailable required review leaves readiness blocked. Preserve
  the request so a resumed run checks it instead of posting again. Retry an
  unchanged head only after explicit user direction or evidence that the
  blocking condition changed and the prior request is no longer active.
- Every push requires fresh review evidence for the new head. Do not create
  empty commits, base updates, or label changes merely to wake a reviewer.
- Assess actionable findings from every source, including passive products.
  Fix or disprove them and resolve threads when permitted. Passive products
  need no clean rerun unless explicitly required. Re-fetch findings and required
  gates immediately before readiness or merge.

For automated callers, persist request URL, requester, head SHA, start time,
and terminal status across jobs and reruns. Use one wait owner per PR and head;
a duplicate job must reuse the original request and deadline. Explicit refusal
must end the gate immediately with the response URL and required access repair.
Never turn refusal or timeout into success. A skill edit does not repair a
repository's implemented gate; report any conflicting automation separately.

Use [current-head-review-loop.md](current-head-review-loop.md) for pagination,
thread decisions, and final evidence. Product changes belong only in this file.
