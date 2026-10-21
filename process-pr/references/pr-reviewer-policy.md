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

- `hemsoft-dev/*`: Codex is the only AI reviewer. Copilot never reviews there
  (Franz, 2026-10-19: no seats, rulesets removed); never request `@copilot` and
  never wait for it. Reviewer consent is the Codex clean review of the current
  head, or a clean cross-model review of it under "Cross-model review fallback"
  below, plus zero unresolved review threads.
- `relias-engineering/*`: GitHub Copilot PR Review is required for every current
  head. Connected Codex is not required unless the user explicitly requests it
  for the specific pull request.

## AI review and formal approval

Franz's 2026-09-30 instruction makes a clean, completed current-head review
from the selected required AI reviewer sufficient for the AI-review gate.
Do not invent a formal human-approval requirement or ask for another approval
solely because the AI reviewer uses a comment or thumbs-up instead of GitHub's
`APPROVED` review state. This rule applies to all composing PR workflows.
Where Codex is the required reviewer, a clean cross-model review of the current
head under "Cross-model review fallback" below satisfies the same gate.

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

- Make at most one request per required reviewer per unchanged head, plus the
  one re-request for a hung review under "Hung reviews" below. A composing
  workflow must reuse the same request and evidence rather than start another
  review loop.
- Outside T3 Code, poll required reviews and checks at 60-second intervals,
  continuing useful work between checks. Without a caller deadline, stop this
  wait after 10 minutes and report the pending request, head, elapsed time, and
  evidence. This is a local wait budget, not a provider SLA or proof of failure.
  Under T3, follow "Waiting under T3 Code" below instead.
- On explicit quota, plan, permission, or configuration failure, record it
  once and stop attempts. Do not try the passive products as fallbacks. When
  the failing reviewer is Codex, go straight to "Cross-model review fallback"
  below.
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
  unchanged head only after explicit user direction, a hung review under
  "Hung reviews" below, or evidence that the blocking condition changed and the
  prior request is no longer active. A hung or unavailable Codex review goes to
  "Cross-model review fallback" below instead of staying blocked.
- Every push requires fresh review evidence for the new head. Do not create
  empty commits, base updates, or label changes merely to wake a reviewer.
- Assess actionable findings from every source, including passive products.
  Fix or disprove them and resolve threads when permitted. A finding thread is
  resolved by the agent only after its fix is pushed and the reviewer's clean
  review names the current head: reply with the fixing commit, then call
  `resolveReviewThread`. Before readiness or merge, count unresolved threads
  with GraphQL `reviewThreads(first:100){nodes{isResolved}}` and require zero;
  a reply alone does not close a thread (codexbar#205/#211). Passive products
  need no clean rerun unless explicitly required. Re-fetch findings and required
  gates immediately before readiness or merge.
- Review until clean (Franz, 2026-10-21). Keep fixing and requesting a review
  of each new head until the current head's required review is clean, however
  many rounds it takes. No workflow may merge after a fixed number of rounds
  without that clean review. Never ask the user whether to stop after N rounds.
  Fix every valid finding. Only an ultra-nitpick may be declined; reply on its
  thread with the reason.

For automated callers, persist request URL, requester, head SHA, start time,
and terminal status across jobs and reruns. Use one wait owner per PR and head;
a duplicate job must reuse the original request and deadline. Explicit refusal
must end the gate immediately with the response URL and required access repair;
for Codex, the cross-model fallback below then supplies the review.
Never turn refusal or timeout into success. A skill edit does not repair a
repository's implemented gate; report any conflicting automation separately.

## Waiting under T3 Code

T3 Code wakes a thread on pull-request events. Under T3, wait for those events
the way T3 instructs: call `watch_pull_request` and end the turn. The watch
fires when required checks finish, another account comments or reviews, or the
branch conflicts. Don't start a timer, background watcher or polling loop
alongside a watch. The 60-second polling and 10-minute cap above, and any
"never end a turn to wait" rule in a composing skill, still apply outside T3.
Under T3 they apply only to the waits the watch can't see:

- **Workflow runs that aren't required checks.** The watch doesn't fire when
  they finish, so never end the turn on a watch to wait for one. Wait in-turn
  with bounded polling: `gh run watch <id> --exit-status` under a timeout, or
  `gh run view <id> --json status,conclusion` every 60 to 120 seconds. Stop
  after 30 minutes per run. Then report the run as pending, with its link, and
  go on with other work or end the turn on the watch for the PR events still
  due.
- **A hung review.** See "Hung reviews" below.

Your own account's comments don't wake your watch. The `HemSoft` account is
Franz's and the agents' account, so an agent can't wake its own thread by
commenting. The Chief's stall check
([`scripts/t3-stall-check.py`](https://github.com/hemsoft-dev/chief/blob/main/scripts/t3-stall-check.py))
wakes a stalled PR-watch thread; don't build a watcher of your own for that.
After a watch has been quiet for 3 hours, the stall check nudges once per head.
If Codex's review of the live head is stuck on "Running" or was never
requested, it posts `@codex review`, and Codex's reply wakes the thread.
Otherwise it sends the thread a direct T3 message. On waking from either,
re-read the PR state, reviews and the runs you depend on before acting.

## Hung reviews

A review is hung when it has no result about 60 minutes after the request on
the unchanged head: still "Running", or no response at all. For Codex, read
this from its `codex-review-state` summary comment. Check for it whenever you
are awake and before you end a turn on a watch. On a hung review, re-request it
once for that head (`@codex review` for Codex), without asking. A
`@codex review` already posted for that head after the first request counts as
that one re-request, including one posted by the stall check. If the review is
still hung about 60 minutes after the re-request, run "Cross-model review
fallback" below right away. Don't ask the user and don't report the PR
blocked. Franz replaced the "up to 3 re-requests" rule with this on 2026-10-21:
"if the Codex review isn't working we can always revert to using an
adversarial internal review."

## Cross-model review fallback

Use this where Codex is the required reviewer, as soon as the Codex review of
the current head is hung after its one re-request, or Codex review is
unavailable for it (quota, plan, access or configuration refusal, or the
integration is down). Don't ask first. It never replaces a required Copilot
review or a formal human approval.

1. **Pick the reviewer.** It runs on the other provider from the one whose
   agent wrote the PR's changes: a Claude-written PR gets Codex `gpt-6.1-sol`,
   and a Codex-written PR gets Claude `claude-opus-5-5`. When both wrote
   commits, go by who wrote the current head's latest commits. Read the live
   provider instance and model IDs, plus the reasoning option, from
   `orchestrator_capabilities`. Use the best model only, at `xhigh` reasoning
   (`reasoningEffort` for Codex, `effort` for Claude). Never downgrade to a
   smaller or older model. If that model isn't in the catalog or can't run a
   child task, report the PR blocked with that reason.
2. **Launch it.** Call `delegate_task` with `role: "review"`, `mode: "async"`,
   that `target`, a title like `GPT-6.1-Sol cross-model review of PR #<n> at
   <short sha> (posts to PR)`, and a `clientRequestId` that names the repo, PR,
   short head and round (`<repo>-pr<n>-xmodel-<sha7>-r<round>`), stable across
   retries of that round. Leave `isolation` shared when the child only reads
   with `git show` and `git diff`; use `worktree` if it needs to build or test.
   The child's completion wakes your thread, so end the turn (on the PR watch)
   instead of polling it. Outside T3 Code, with no `delegate_task`, report the
   PR blocked with the hung request links instead.
3. **Brief it.** The task prompt must be self-contained (the child gets no
   history):
   - repository, PR number and title, linked issue, base SHA, full head SHA,
     and the local checkout path; tell it to confirm the head with
     `gh pr view <n> --json headRefOid` and post nothing if it moved;
   - "You are the required AI reviewer for this PR, standing in for connected
     Codex, whose review of this head is hung or unavailable. Be adversarial
     and evidence-based." Use the `audit-pr` skill at the fixed head and base;
     its contract, matrix and finding rules apply. Each finding is P1, P2 or P3
     (P0 for a stop-delivery defect) with a path, line and proof;
   - a scope list of what to check: the specific risks of this change, and
     whether the PR body's claims are true;
   - for later rounds, the earlier findings, the fixing commits and replies, and
     any objection still open, so it rechecks each fix;
   - read-only rules: no edits, commits, checkouts, branch switches, worktrees,
     resets or stashes in the shared checkout; no resolving threads, approving
     or merging;
   - publication, below, as an explicit request to post (audit-pr posts only
     when asked), and a final answer with the findings or "clean" plus the URL
     and id of what it posted.
4. **Publication.** The child posts as `HemSoft` (verify `gh api user --jq
   .login`) after refreshing the head:
   - Findings: one PR review, event `COMMENT`, `commit_id` = full head SHA,
     posted with `gh api -X POST repos/<owner>/<repo>/pulls/<n>/reviews --input
     <json>`. One inline comment per finding on the exact RIGHT-side line,
     starting `**<sub><sub>![P2 Badge](https://img.shields.io/badge/P2-yellow?style=flat)</sub></sub>  <title>**`,
     a blank line, then one short paragraph with trigger, impact and fix (P0
     red, P1 orange, P3 lightgrey). A finding with no valid diff line goes in
     the review body. Body: `### 💡 Cross-model review (GPT-6.1-Sol via T3)`,
     then `Reviewed head <full sha>. GPT-6.1-Sol (xhigh) is reviewing in place
     of connected Codex, whose review of this head is hung or unavailable.` and
     a one-line summary.
   - Clean: one PR comment headed `### Cross-model review (GPT-6.1-Sol via T3)`
     with the same reviewed-head sentence, `Didn't find any major issues. 🎉`,
     and one line on what it verified and which commands it ran.
   - Name the actual model in both (`Claude Opus 5.5` for a Claude reviewer),
     read back what was posted, and confirm the head it names.
5. **Use the result.** A clean cross-model review that names the current head
   counts as that head's review for readiness and merge, the same as a clean
   Codex review. Findings are review findings: fix every meaningful one (only an
   ultra-nitpick may be declined, with the reason on its thread), push, reply
   on each thread with the fixing commit, and run a new round on the new head.
   Request Codex for it as usual, unless Codex is still unavailable. If Codex
   hung on this PR's earlier head and has no result 60 minutes after this
   head's request, skip the re-request and run this fallback again. Repeat until
   a current-head review comes back clean.
   Resolve a finding's thread only after a clean review names the fixed head.
   Codex findings that arrive later on the same head are findings like any
   others.
6. **Record it.** Keep the task ID, child thread, model, reviewed head and
   posted URL with the PR's review evidence, and report the review as
   `cross-model (<model> via T3)` wherever you report the Codex review.

The codexbar-ios sessions on air used this procedure first, as a "Codex
substitute" while Codex review quota was exhausted (hemsoft-dev/codexbar-ios
[#487](https://github.com/hemsoft-dev/codexbar-ios/pull/487) and
[#489](https://github.com/hemsoft-dev/codexbar-ios/pull/489), 2026-10-18).

Use [current-head-review-loop.md](current-head-review-loop.md) for pagination,
thread decisions, and final evidence. Product changes belong only in this file.
