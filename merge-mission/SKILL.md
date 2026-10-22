---
name: merge-mission
description: V1.75 - Resolve every open issue and pull request in a repository, processing existing PRs first and then oldest-first issues. Runs as a persistent goal with current-head review, validation, guarded merges, delivery verification, cleanup, and one-time notifications. Repairs CI and delivery failures, preserves evidence and recovery state, proves remaining hard blocks, and records retrospective lessons. Manual invocation only.
compatibility: Requires git, GitHub CLI, network access, permission to push branches and open pull requests, mergepr on PATH, the issue-to-pr, process-pr, repo-cleanup, and slack-dm skills, and a runtime that honors the /goal director. Without /goal, the state file alone carries resumption.
---

# Merge mission

One job: resolve every open issue and pull request in the target repository.
An issue normally ends as a merged pull request. An existing pull request ends
merged or closed with evidence that it is superseded or not actionable.
Invoking this skill is the user's standing authority to do whatever that
requires, without asking first. Read
`../process-pr/references/ui-validation-evidence.md` before processing any UI
issue or PR. Work the whole queue in one run. A run that merges one item and
reports back while another stays open is a failed run.

## Standing authority

The invocation grants all of the following for the target repository without
further approval:

- Select and order the combined issue and pull-request queue.
- Create branches, worktrees, commits, and pull requests; rebase and
  force-push mission-owned branches.
- Implement any change the issues require, including tests, workflows, CI
  configuration, dependencies, and documentation.
- Comment on, label, close, and reopen issues to keep the record truthful.
- Merge through the guarded gate. Never bypass branch protection: no `--admin`,
  no rule edits, no dismissed reviews. A protection refusal is a finding about
  the pull request, and an unresolved review thread is a reviewer saying no.
- Make scope and design decisions for ambiguous issues, recorded in the
  pull-request body.

Do not ask "should I continue", do not pause to report progress, and do not
hand back a plan when action is possible. When you would normally stop and
ask, decide, record the decision in the state file and the relevant issue or
pull request, and act.

This authority stops at: repositories other than the target, secrets and
credentials outside the repository, spending money, deleting or altering
production data, and anything with legal weight. Those are hard blocks, not
questions.

Distinguish the local work machine from CI runner policy. A direction to build
and test locally on a named machine does not by itself waive or prohibit
documented hosted release gates. Preserve required statuses and the local
machine restriction separately. Ask only when the user explicitly creates
a conflict; never infer a CI waiver from the local machine choice.

## Desktop workspace ownership

When the user reserves a monitor or assigns one for agent work, record that
restriction in the state file and honor it for every test app, browser, dialog,
screenshot, and recording. Discover monitor bounds with per-monitor DPI awareness
before placing windows. Launch on the assigned monitor where supported; otherwise
use a hidden launch and position the task window before showing it. Prefer headless
browsers for public-page verification. Do not move user-owned windows or activate
a task window unnecessarily. Mixed-DPI logical coordinates are not placement
proof: verify the actual task window bounds and derive capture coordinates from
that window. Never record the reserved display.

Before choosing native resize or DPI fixtures, inspect the host's tracking limits
and distinguish client size from outer size, including frame or decoration
insets. Fit the complete transition sequence within those limits while retaining
the app's supported minimum. Assert the actual resulting bounds after every
transition. A clamped request is a failed qualification, not permission to waive
the assertion or infer success from a later cleanup/upload phase.

In an isolated headless compositor, account for missing physical input devices.
Removing the last transient virtual keyboard can drop seat focus between
actions. Keep an owned input device attached for the full app exercise when
needed, reap it on success and failure, and assert menu/zoom results. Successful
input-tool exits alone do not prove that the app received the sequence.

When UI evidence uses synthetic fixtures, isolate every local collector's home
or profile as well as the remote fixture source. Assert that no unrelated real
records reach the rendered fixture. After changing a fixture phase, wait for its
specific values through every background cache before capturing it. A visible
row from the previous phase does not prove readiness. Keep the fixture harness's
owned processes and bounded readiness probes in the evidence directory.

An explicit user restriction against browser, UI, or desktop automation
overrides the mission's normal current-head UI evidence requirement. Stop all
such automation immediately. Preserve already-published evidence, label its
exact commit provenance, disclose the current-head evidence gap, and use only
allowed non-UI validation. Do not treat the missing rerun as a hard block and do
not violate the restriction to satisfy a generic evidence rule.

When the user has said to ask before testing on their machine, ask once during
inventory, not when the first PR is ready. Offer the validation tiers the queue
needs (headless build and tests, app windows for screenshots, input-driving UI
tests) with a recommended option, record the answer in the state file, and
follow it for the whole run. In the same step, check that any self-hosted runner
the required checks depend on is online, and ask for it then if it is not. Both
asks came too late on survival-shelter#50; asking them at inventory kept #52
moving.

## Goal director

The mission runs as one persistent goal so it survives turn and session
boundaries. Create the goal as the first action, before any repository work:

```text
/goal $merge-mission {OWNER/REPO}
```

If the user invokes with a leading `/goal`, that goal is the mission's
carrier; do not create a second one. On a bare invocation, create the goal
first as above. Set the objective to: the resolved repository, the open-work
queue frozen at snapshot with issue and pull-request numbers and titles, the
contract that each queued item ends resolved or proven hard-blocked, the
incomplete-run report requirement, and the stop conditions. Freeze the queue
at snapshot. Unrelated issues and pull requests opened later are recorded in
the state file as NEW-AFTER-SNAPSHOT and belong to a later run. A replacement
for a queued pull request and any release or changelog pull request generated
by a mission merge inherit the original item and remain in this mission.

While the goal is active:

- Update its status at every state-file update.
- Never mark the goal blocked merely because one turn is waiting on CI or a
  reviewer. Waiting is parked work under the waiting discipline, and the
  goal stays active.
- On a resumed turn, read the active goal, the state file, live GitHub
  state via `gh x status`, and local checkout state before acting, then
  state what changed since the last incomplete-run report.
- Complete the goal only when the stop conditions in "The only ways to stop"
  hold, including the written incomplete-run report.
- If a different unfinished goal exists, preserve it and consult
  `../precedent/SKILL.md` before asking a coordination question. Precedent is
  advisory and supplies no authority. Current explicit instructions win. When
  the user delegates coordination and the existing goal covers compatible work
  in this same repository, edit that carrier rather than create a competing
  goal. Preserve its ID, original scope, receipts, recovery state and one-time
  notification accounting; record the expanded objective and ordering. Do not
  absorb unrelated goals or take over another session's active ownership. If a
  genuine authority or ownership conflict remains, ask once to edit, pause or
  clear it. That and target resolution are the only mid-run questions.
- A direct user instruction to continue the mission in this thread resolves
  the ownership question. Do not ask it again on the same evidence. Preserve
  the existing queue, files, receipts and one-time request accounting. If an
  overlapping agent run is still live, use the supported interruption control
  to establish one writer, verify its terminal state, and continue here. A stale
  paused goal with no supported resume operation uses this skill's state-file
  fallback; it is not a reason to stop authorized work.

If the runtime offers no goal director, proceed anyway; the state file is
the fallback carrier and every rule above applies to it.

## The only ways to stop

1. The queue is empty: every queued issue has a merged pull request or is
   closed as already satisfied or not actionable with evidence, and every
   queued pull request has merged or closed with equivalent evidence. No
   inherited replacement or merge-generated follow-up pull request remains
   open. Delivery workflows triggered by mission merges, such as release or
   deployment, have reached their expected successful or intentionally skipped
   terminal state.
2. Every remaining item is hard-blocked, and every one of those blocks is
   proven under "Earning a hard-block" below, with the incomplete-run report
   written. A block you cannot prove is work you have not finished.
3. The environment is broken after recovery attempts, for example `gh` cannot
   authenticate at all.
4. The user says stop.

Tool-output truncation, context compaction, or a long-running session is not a
broken environment. Persist the current evidence, resume from the state file,
and keep working.

Anything else is work. Ambiguity, an ugly diff, a flaky test, a merge
conflict, a missing document, and a scary workflow file are work items, not
stop reasons. "I was not sure" is not a stop reason; decide and record.

## The loop

1. Create or resume the goal under "Goal director" as the first action, then
   inventory. Resolve the target repository from the current checkout's
   origin remote, or from the repository named in the invocation. If the
   invocation lands outside any checkout and names no repository, ask once
   which `OWNER/REPO` to run against, then continue without further
   questions. Resolve identity and repository instructions, then run
   `gh x status`, the command behind the user's `gs` shortcut, before selecting
   work. Inspect current PR checks and the latest default-branch CI and delivery
   runs. An old failure superseded by a successful run is history, not a new
   repair item. Run both `gh issue list` and `gh pr list`; neither command is a
   substitute for the other. Link issue-backed pull requests to their issues
   as one queue item, and queue standalone pull requests in their own right.
   Verify each issue still applies to the default branch; classify
   already-satisfied or not-actionable issues and close them with an evidence
   comment. Build the queue in two phases: existing open pull
   requests first, then issues without an open pull request. Sort each phase by
   its artifact's `createdAt` ascending, then number ascending. An issue-backed
   pull request belongs to the PR phase, ordered by the PR's creation time.
   Record any dependency, security, explicit label, or user-directed exception
   to age order with its concrete reason. Write the state file.
2. Pick. Drain the existing-PR phase before starting the issue backlog. An
   existing PR leaves that phase only after it merges, closes with evidence,
   or earns a proven hard block. CI or reviewer waiting is not a drained item.
   Among runnable items in the active phase, take the first one not owned by
   a human. After the PR phase, repair any current default-branch CI failure
   before starting ordinary backlog work, then process issues oldest-first.
   Reuse a queued issue or PR for that repair when it already covers the cause;
   otherwise create a mission-owned repair item and record why it inherits the
   mission despite being created after the snapshot. Do not take over a human's
   in-flight branch or push to it without explicit permission. You may still review, validate, and merge a human pull request
   when it needs no branch changes. If it needs author changes, follow the
   blockage ladder and leave a precise review comment before parking it.
3. Drive the item to completion. For an issue without a pull request, compose
   `issue-to-pr` sections 1 through 5 for identity, resume detection,
   worktree, implementation, and pull request. For an existing pull request,
   start with its live head and existing review state. In both cases, use
   `process-pr` for the current-head review loop. Keep driving fixes, tests,
   pushes, fresh-head reviews, and thread resolution until no actionable AI
   feedback remains and required reviewers have completed clean reviews of
   that exact head. Silence is not a clean review, and optional pending runs
   do not add a wait gate. Reviewer consent is mechanical: before any merge,
   query the pull request's review threads (GraphQL `reviewThreads`, paginated)
   and require zero unresolved. Resolve a thread yourself only after its fix is
   pushed and the reviewer's clean review names the current head, with
   `resolveReviewThread` and a reply citing the fixing commit; a reply alone
   leaves the thread open and the merge blocked. Diagnose failing CI from its
   logs and fix the cause rather than handing back a red or waiting PR. Then use
   the guarded merge gate,
   `mergepr`, cleanup, and notification from `issue-to-pr-merge` phases 3 and
   4. When `mergepr` is not on PATH (Linux hosts), run it as `pwsh ~/bin/mergepr.ps1 <PR>`
   from the clean primary checkout; it is the same guarded helper. Read `../process-pr/references/pr-reviewer-policy.md` before reviewer
   work. For protocol or serialized-artifact changes, pair hostile/mutated
   fixtures with a positive artifact from the actual pinned producer or real
   transport. Hand-built examples can repeat the consumer's mistaken field or
   framing assumptions. Use authorized no-auth runs, local transports or fake
   backends and preserve exact provenance. Never invent a captured artifact or
   cross a live credential/inference gate to obtain it. If the actual producer
   cannot run, keep that qualification gap explicit while completing source work.
   When a review exposes an ingress or transport bypass, enumerate every route
   using that mechanism and its alternate entry paths before fixing one endpoint.
   Record mixed transport requirements explicitly in trusted policy. Test each
   restricted route class through both permitted and denied paths, alongside
   positive cases for intentionally permitted entry paths. A regression for the
   first reported endpoint does not prove that sibling routes enforce the same
   boundary.
   For machine-readable CLI changes, test every early exit through global
   option extraction, command flags, positional arguments, acquisition,
   cancellation and output failure. Put the JSON flag before and after failing
   arguments; include repeated booleans, `--` boundaries and flags consumed as
   values. Compare non-JSON terminal bytes with the prior producer on equivalent
   inputs, including failures. Continuing a scan must not apply terminal state
   from arguments that the previous parser never reached.
   For a generated dependency update, update its authoritative source or
   action lock and regenerate with the documented compiler and explicit intended
   action version. Verify metadata and every runtime reference agree, then prove
   a second generation is stable. Do not merge a `uses:`-only edit that the next
   compile would undo. For handwritten workflows with no generator or lock,
   update the authoritative YAML directly and verify the action's immutable SHA,
   recorded release tag, and installed tool version together. When a paired-pin
   mismatch recurs, add a regression check to the repository's existing CI suite.
   Prove that it fails on the original mismatch and passes on the corrected pins;
   another one-off version edit is not root-cause prevention. Treat compiler-driven
   permission, secret, telemetry, or container changes as a wider diff to review,
   not incidental regeneration.
   Preserve an unchanged reviewed head after an unrelated base-branch advance
   when effective rules allow it. Verify current mergeability and that the
   combined changes preserve both branches' intended behavior. Rebase when
   required up-to-date checks, a conflict, an actionable finding, or a verified
   integration failure calls for it. Keep the head's review and check receipts
   otherwise, and verify delivery on the resulting published main revision.
   Bind cleanup or cancellation to the original captured resource instance.
   A metadata check followed by stopping a reusable unit, job or container name
   is still a race. Use an original kernel handle or a provider operation with
   an instance/revision precondition. If neither exists, do not mutate a possible
   replacement: use the already-authorized bounded lifecycle, require fresh stop
   evidence and retain an unknown result when proof is missing. Test replacement
   between observation and the proposed action.
   For documentation that changes completion or readiness claims, inspect full
   paragraphs in linked component and overview documents, including wrapped
   future-work statements. Reconcile their scope against the actual source;
   distinguish implemented mechanisms from unpassed physical, account or live
   qualification. Valid links and keyword matches alone do not prove consistent
   status. Preserve dated observations and gate failures.
   Before a guarded merge whose cleanup deletes the source branch, retarget
   every open child PR that uses that branch to the intended surviving base.
   GitHub can close stacked children when their base branch is deleted. Record
   the old/new bases and preserve child head SHAs. After a squash merge, rebase
   only the child-owned commit range onto the merged parent; a plain rebase may
   replay the already-squashed parent and create add/add conflicts.
   Review requests must branch on the refreshed evidence. Do not append an
   unconditional trigger to a command that only prints comments or reactions.
   If an automatic review is running or complete for the current head, reuse it
   and record its receipt. Persist the head-specific request decision before any
   later polling loop can issue another trigger.
   If the user supplies a mission-specific hung-review retry limit or cadence,
   preserve that exact direction in mission state and use it without asking
   again. Track accepted retries by PR and full head SHA, including requests
   from other agents, with URLs and times. Reconcile an uncertain send before
   another request. Do not turn a mission exception into a global reviewer
   policy change or relax the current-head clean-review gate.
   Poll the complete review comments, reviews and threads, including edited
   summary comments. A reviewer may update an early comment in place, so the
   latest ordinary post is not proof of silence. Late feedback on an earlier
   head can contain distinct findings; compare full bodies and cited locations
   before treating anything as a duplicate. A review the reviewer itself
   reports as failed ("Something went wrong, try again by commenting …") is
   neither clean nor silence: re-request it once per failure, counted against
   the retry cap, and treat the earlier findings as the latest word meanwhile.
   Before merging release-bearing work, compare its `Unreleased` notes
   with the automatic release/changelog path, including issue-to-PR links whose
   numbers differ. Reconcile notes that would repeat the generated release
   entry on the source branch, then repeat current-head review and checks. If
   the duplicate is discovered only in a generated PR, correct it before
   merging; do not bypass its guarded gate. For UI work, require current-head
   screenshots visibly rendered in the PR's `## Validation` section and a
   recording when practical or a concrete reason for omission. Look at every
   capture yourself before publishing it, enlarged where detail matters, and
   treat it as a review: captures caught layout defects that every test passed
   over, twice (codexbar#205, #214). When the issue states a measurable visual
   criterion, such as a contrast ratio, measure it from the capture with a
   script and put the numbers in the PR. Compare two builds' captures only
   when they were rendered back to back: renders minutes apart differ in clock
   text, pace markers and time-seeded demo history. List every capture that
   differs, not the top few, and classify each region before calling a change
   visual or none. A diff that looked like a regression vanished when both
   heads were rendered together (codexbar#228, #232).
4. Verify done. GitHub must report each merged pull request `MERGED`. For an
   issue-backed item, GitHub must also report the issue closed. For UI work,
   inspect the rendered PR and verify its current-head screenshots are visible;
   local paths, repository file references, CI artifacts, and unverified
   Markdown are not evidence. The pull-request body carries `Closes #<n>`; if
   the issue did not auto-close, close it with a
   one-line comment linking the merge commit. If Dependabot or another system
   replaces a queued pull request, add the replacement to the same queue item
   and keep going. Process every release or changelog pull request generated by
   the merge before marking that item complete. Inspect the exact current-head
   check suites when generated PRs have blocked or unstable native merge state.
   Latest passing contexts can hide an original bot-event CI run awaiting
   execution approval. When the workflow and unchanged same-repository diff
   are verified and execution is authorized, approve that exact pending run
   once; do not fabricate review approval, weaken settings, reset reviewer
   deadlines or race an existing auto-merge owner. Wait for release, deployment,
   and other delivery workflows triggered by the merge to reach their expected
   terminal result. A failed delivery run is inherited mission work: diagnose
   it, merge the fix, and verify a successful replacement run. Re-run
   `gh x status`, inspect the exact item's fields rather than the command's
   exit code, then run the hygiene gate and update the state file before the
   next item.

   Before invoking a merge helper that removes worktrees, inspect their ignored
   content and preserve identified evidence or retained work outside the tree.
   A clean tracked status does not establish that ignored files are disposable.

   If worktree cleanup leaves a directory-not-empty warning, inspect the
   remaining paths before retrying. Verify the exact reviewed head and a clean
   tracked tree. Remove only identified generated artifacts, never following
   symbolic links or Windows junctions into source or another dependency store.
   Let the guarded merge helper own branch and worktree removal.

   Preview the notification helper's exact structured payload before its
   one-time send. On Windows, set UTF-8 console and pipeline output encoding
   before generating that preview. Inspect readable fallback text and structured
   fields; question marks or replacement characters are not a verified preview.
   Distinguish output-encoding damage from actual payload corruption and correct
   the dry run before sending. Keep required field syntax, even when prose style
   rules prefer different punctuation. A proven local validation failure before
   any API call may be corrected; an indeterminate delivery must not be retried.
   Persist terminal provider refusals across the whole mission, including
   resumed sessions. A provider-level error such as `account_inactive` blocks
   later completion messages through the same unchanged account, even when
   their PR numbers differ. Record those messages as unsent without repeating
   the failed provider request. Resume sends only after explicit user direction
   or verified recovery of the account; a new merge alone is not recovery.
5. Revisit. After each full pass, return to every blocked item with fresh
   evidence. Apply the blockage ladder again. Repeat until stop condition 1 or
   2 holds.
6. Report. One table: issue or pull request, outcome, pull-request or merge
   link. Every hard-block gets its two attempted fixes plus the exact human
   ask. If any queued item is unresolved, write the incomplete-run report under
   "Learning from every run", then run the retrospective before ending.

## Blockage ladder

For every blocker, climb in order:

1. Fix the symptom now. Rebase over conflicts, repair the failing test or
   workflow, rerun a flaky check, switch the GitHub identity, reroute around a
   broken tool.
2. Root-cause it. When the same class of blocker appears twice, fix the cause
   in this pull request or a dedicated one. A recurring flaky test, a
   chronically red workflow, and a stale contributor doc are work items. Never
   mark the same symptom blocked twice without a root-cause attempt in
   between. A native crash inside a test binary (access violation, segfault)
   is a product or test bug, not tool flakiness, until the suspect test, run
   alone and single-threaded, passes repeatedly; find the last test started
   and bisect before calling it flaky. A test that passes alone but fails under the full parallel run usually
   waits a fixed budget (a settle loop, a fake-clock advance) for work done on real threads; make it wait, bounded,
   for the asserted effect itself instead of raising the budget (project-dashboard#18, #22). For recurring prerequisite gaps in composite commands, follow the
   called scripts and configs and validate the declared installation against its
   authoritative dependency declarations. Test a missing secondary tooling
   module. Adding the latest package name to a duplicated list is not a
   root-cause fix.
   Before reusing a build cache or moving validation into a source copy, preserve
   the effective working directory, discovered tool configuration, target,
   profile and compiler flags. A manifest path does not necessarily load the
   original working-directory configuration. When this mistake repeats, put
   those assertions in the validation runner. Stop an unintended rebuild,
   retain its actual incomplete result, and run the correctly configured command;
   do not call the interrupted invocation a test failure or a pass.
   Give each worktree of one repository its own build output directory (for
   example its own `CARGO_TARGET_DIR`). Cargo fingerprints workspace members by
   their workspace-relative path and source times, so sibling worktrees sharing
   one target can link another branch's newer crate and pass or fail on code the
   branch doesn't contain (codexbar#235/#236).
3. Bound the retries. Cap mechanical retries at three. Never request a review
   again for an unchanged head, except once for a failed review (above) or
   once for a hung one (the shared policy's "Hung reviews"). A Codex review
   still hung after that, or unavailable, goes to the shared policy's
   "Cross-model review fallback" without asking; a clean cross-model review of
   the current head counts as its review. Respect the shared policy's
   wait deadlines. Review rounds have no cap: keep fixing and requesting a
   review of each new head until the current head's review is clean, however
   many rounds it takes (Franz, 2026-10-21). Never merge without that clean
   review and never ask whether to stop after N rounds. Fix every valid
   finding; only an ultra-nitpick may be declined, with the reason in a reply on
   its thread. When reading
   review comments, fetch them all (`per_page=100` or `--paginate`); an
   unpaginated query can make a round look clean.
4. Hard-block, but only after the proof required by "Earning a hard-block"
   below. A block is a finding you must prove, not a feeling you may report.

## Decisions and ambiguity

When an issue is underspecified, pick the interpretation best supported by the
issue text, the codebase, and its history, then implement it and state the
interpretation in the pull-request body. The test is reversibility: code and
repository decisions belong to the agent; money, production data, and legal
exposure do not.

## Earning a hard-block

Most reported blocks are unworked problems. Clear all four of these before you
mark anything hard-blocked:

1. Name the exact missing thing. A credential, an access right, a decision
   with real-world irreversibility, or work owned outside the target
   repository. Vague blocks like "needs input" or "unclear requirements" do
   not qualify.
2. Attempt to self-serve it two different ways and log both attempts with
   commands and results in the state file. An alternative credential source,
   a different tool, a configuration default, a test double, an admin path.
   "I cannot obtain X" without two logged attempts is not a block.
3. Ask the ship-anyway question: if the answer arrived, what would I do, and
   is there a safe reversible default I can ship right now? If yes, ship it
   with the assumption documented. A block means no reversible default exists.
   For a missing third-party client registration or API grant, check first
   whether the provider's own official CLI or app can do the work for the
   product (sign-in, renewal, sign-out), each account in its own config folder.
   Delegating to it is a reversible default, not a block. For a missing
   production signing identity or distribution channel, a self-signed
   certificate and a local or file-share channel are the reversible default.
   Ship packaging, update and platform-integration work on them, and leave
   only the production choice open.
   Separate implementation from live qualification for every unfinished
   acceptance criterion. Missing credentials, App registration, account policy,
   activation authority or human measurements block the relevant live action,
   not reversible code, packaging or tests that can use fake providers, local
   transports and synthetic credentials. Before parking a whole issue, record
   its remaining source work separately from actual external observations and
   complete that source work. A partial library or test seam is not proof that
   all authorized implementation is exhausted. Revisit prerequisite assumptions
   when a later item can be implemented without exercising the blocked live
   dependency. Waiting for review also leaves the mission active.
4. Check the anti-list. Failing tests, flaky tests, merge conflicts, missing
   documentation, ambiguous acceptance criteria, and reviewer silence are
   work, not blocks.

Then, and only then: comment on the issue with the exact need and both
attempts, record it in the state file, and move to the next issue. A
hard-blocked item is parked, not abandoned; the revisit pass tries it again
with fresh evidence.

Ending the run with hard-blocked items requires one final pass over all of
them. If that pass moves any item, keep going.

## Waiting discipline

Under T3 Code, wait as the shared policy's "Waiting under T3 Code" section
says. For required checks, reviews and comments from other accounts, and
conflicts, call `watch_pull_request` and end the turn. That is a watch
checkpoint, not a stop; keep the mission goal active. Poll workflow runs that
aren't required checks in-turn up to the policy's cap, and handle a review
stuck on "Running" per its "Hung reviews" and "Cross-model review fallback"
sections. Don't start a timer,
background watcher or polling loop alongside a watch. Your own comments don't
wake it; the Chief's stall check wakes a stalled watch. On waking, re-read the
PR state, reviews and the runs you depend on before acting.

More generally, honor a native runtime's watch-and-yield contract instead of
the polling loop below, especially when the user limits CI checks. A persistent
goal can keep the provider run active while a watcher queues a completion turn
behind it. Read the owning thread's queued monitor message rather than
re-polling GitHub. Use the app's canonical thread identifier, not a goal or harness identifier, and prefer
supported read tools. If those tools omit queued text, a read-only lookup of the
exact message in that own thread's projection can recover the receipt; never
edit the queue or inspect unrelated threads. A queued run alone is not a pass:
require the completion message to name the unchanged head and successful checks.
Keep the mission goal active through this wait.

Waiting for CI is cheap; treat it as part of the work, never as a reason to
stop, rush, or skip. Outside T3, and under T3 for the waits a watch can't see,
never end a turn to wait. Either poll with bounded sleeps (`gh pr checks
--watch --fail-fast`, or 60 to 120 second sleeps up to the shared policy
deadline) or process another existing PR and come back.
Do not start an ordinary backlog issue just because an existing PR is waiting.
Once every existing PR is resolved or proven hard-blocked, bounded pipelining
of oldest-first backlog issues is allowed. A prerequisite repair needed to
finish an existing PR is part of that PR's work, not a backlog-order bypass.
Keep at most three queue items in flight, and never two branches that touch
the same files. A shared test file counts: branches that each append tests at
the same anchor conflict on every merge, so give each its own section anchor
or merge them serially. A waiting pull request is parked, not finished.
Outside T3, a watcher's done-condition must name the head: require the
reviewer's summary to report the current head completed and at least one check
in the rollup.
"Nothing pending and nothing running" is also true of an empty rollup right
after a push and of a review that failed, so it proves nothing by itself.

Never run a long-lived process, such as a dev server, test fixture, browser
session, or watcher, as a blocking foreground command. It never returns, so
the mission silently stalls. Start it detached or through the runtime's
background execution, confirm readiness with a bounded probe, record its PID in
the state file, and stop it when the evidence is captured.

During each CI-wait poll, refresh published review threads as well as checks,
even after the required reviewer has reported clean. Assess new passive
findings promptly. This does not authorize triggering or waiting for optional
review runs.

When results land, re-read the live situation and act the same turn, on your
own judgment:

- Green and mergeable means merge. Walk the guarded merge gate immediately.
  A green pull request that sits unmerged is an unfinished decision.
- Red means read the actual logs, not the check name. Apply the blockage
  ladder, fix, push, and wait again.
- A stale in-progress status is not proof of a hung producer. Compare step
  timestamps, completed-job logs and immutable uploaded artifacts before
  canceling or rerunning. Preserve those receipts while waiting for GitHub's
  terminal check state; producer evidence does not replace the merge gate.
- Flaky means one rerun, then root-cause per the ladder.
- Optional checks and optional reviewers never add a gate, per the shared
  policy. Weigh them with judgment instead of obeying them.
- Base or head moved means rebase and revalidate before any merge decision.

## State file

Keep durable state in `.git/merge-mission/STATE.md` inside the target
repository so git never tracks it. After every queue or item-state change,
record: the frozen queue in PR-first order, the active phase and documented
ordering exceptions, each issue or pull request's status
(QUEUED, IN-FLIGHT, WAITING, MERGED, CLOSED-EVIDENCE, HARD-BLOCKED with the
exact human ask), inherited replacements and generated follow-ups, in-flight
branch, worktree, head SHAs, and every decision made. A fresh invocation
resumes from this file instead of re-deriving state. When resuming a state file
written under an older ordering policy, preserve its frozen scope, evidence,
and reviewer requests, but apply PR-first selection before new backlog work.

Resolve the primary checkout's mission directory once. Use absolute paths for
its state, helper scripts, body files and logs whenever a command runs in a
worktree. A worktree's `.git` is a pointer file, not the primary `.git`
directory. Check each prerequisite command's exit before continuing to a
dependent PR write, review request or server launch; a failed path must not
silently skip evidence publication. Use a checked static, variable-bound GraphQL
template rather than constructing escaped braces in shell or interpolated strings.
Make dependent mutation chains fail fast. After a failed prerequisite, inspect live
state before any retry; reuse any request that was actually accepted despite the
failure instead of posting it again.

After pushing or retargeting a stacked PR, verify both its remote Git ref and
GitHub head/base metadata before publishing head-specific evidence or requesting
review. Git refs can update before PR metadata. A stale first read is pending
synchronization: reread within a bounded interval, without another push,
retarget, artificial commit or review trigger. If it stays stale, preserve the
accepted write receipt and exact expected heads; continue independent work.

Run `gh x status` to see the current state of the mission's progress. Use it
at run start, on resumed turns, and before any merge or block decision,
instead of re-deriving state from scratch. If the command is missing or
errors, fall back to direct `gh` queries and note that in the state file.

## Honesty gates

- Partial implementation PRs use plain related-issue references. Never negate a
  GitHub closing-keyword reference: GitHub can still interpret "does not close"
  followed by an issue number as an automatic closure. Commit messages count
  too: a squash merge carries `Closes #n` from any commit into the default
  branch, so decide closing versus partial before the first commit and reword
  commits when that decision changes. Inspect `closingIssuesReferences`
  immediately after creating the PR and again before merge, and remove
  unintended closing references. Recheck the issue state after merge; reopen an
  incomplete issue with an evidence comment if automatic closure was accidental.
- Merged means GitHub reports `MERGED`, checked with `gh pr view`, reached
  with every review thread resolved and no protection bypassed. Closed
  means `gh issue view` confirms it.
- Record exact SHAs, commands, and observed results. Never claim a check
  passed without reading its result. Read times, versions, and tool
  availability from the system (clock, log timestamps, `which`) before
  writing them into a PR, issue, or outward message; an omission reason like
  "no recorder installed" or a stated event time is a claim that needs the
  same receipt.
- Update state only after checking each claimed action's receipt and resulting
  data. Transport success, a later command's exit code, or an accepted request
  does not prove that an earlier mutation completed. Validate response errors,
  typed artifact IDs and per-item outcomes before recording completion.
- A newer qualification harness does not raise the shipped application's runtime
  floor. Compare documented support with actual exercised host versions. When
  behavior changed within a supported major version, qualify representative hosts
  on both sides of that boundary and any supported compatibility mode. Run real
  isolated hosts and assert their versions; changing a version variable cannot
  prove runtime behavior. Preserve separate harness and production prerequisites.
- Keep expected recurring subscription charges distinct from metered usage or
  overage. Preserve exact API totals and classify known subscription SKUs before
  raising missing-cap alerts. When a control is owner-confirmed but unavailable
  through the API, label explicit host configuration with its source; that
  configuration must not hide observed unexpected usage charges.
- Before deploying recurring API collectors, calculate aggregate work across all
  agents sharing the credential, using configured item counts, polling intervals,
  concurrency and requests per item. Use the user's active list, never every
  discovered checkout. Empty configuration must fail closed. Choose a conservative
  cadence, serialize or stagger calls, and avoid catch-up bursts after slow sweeps.
  Verify the installed arguments and endpoint counts. A service restart proving
  connectivity does not prove that its ongoing API cost is safe. On quota incidents,
  reduce deployed load first and use a separate available transport for repairs.
- For hub-and-agent features, delivery covers every in-scope online agent, its
  required producer version, and its configured input list. Inventory these
  before rollout; a deployed hub with unsupported agent endpoints is unfinished
  delivery. Respect remote UI exclusions while updating headless services, and
  compare every configured agent row with the hub.
- For upstream compatibility or presentation parity, verify a review's proposed
  behavior against the pinned upstream implementation and equivalent inputs
  before changing semantics. A generic recommendation that would break the
  stated parity contract is nonactionable when source and regression evidence
  prove the difference. Record that evidence and any documented local override;
  do not silently substitute the reviewer's preferred behavior for the spec.
- Reviewer workspace commits are not necessarily published history. Before
  acting on an attribution or history finding, verify the actual published PR
  head and the cited object's relationship to it with local Git and canonical
  Git Database metadata. Record the evidence. A reviewer-only copy does not
  justify rewriting repository history or changing legitimate attribution.
- Hash an immutable publication snapshot, not files still owned by background
  writers. Size and digest must describe the same bytes. Match the manifest to
  the uploader's exclusions, including hidden files. Verify downloaded bytes
  before calling the artifact complete; disclose missing or changed files.
- Complete source qualification and checklist updates before merging. Do not
  rewrite merged-PR bodies for routine delivery closeout: an edited event can
  rerun stale-head CI, which correctly rejects a closed PR and may compare an
  old changelog with a newer release. Put later delivery receipts in the state
  file or a completion comment instead. If this already happened, retain and
  diagnose the failed metadata runs separately from verified main/release
  delivery; do not weaken the open-PR guard or resend completion notifications.
- A matching destination does not prove configuration ownership. Before native
  commands replace a task, route or handler, compare the complete relevant
  settings against the intended setup. Preserve or refuse TLS modes, capability
  lists and unknown fields; never silently discard them. Inspect layered or
  foreground configuration that can override a successful background write.
  Maintain regressions for same-destination records with different settings.
- Validation claims require assertions that can detect the claimed failure.
  Comparing a wrapper with the helper it delegates to proves wiring, not the
  helper's output. An unchanged by-value input, an empty result collection with
  no providers, or a cached Load cannot prove instant preservation, absence of
  fetch calls, or disk integrity. Pin concrete output, record the actual receiver
  call, and read persisted bytes or a fresh instance as appropriate.
- Qualification must require a structurally valid policy document. Do not let
  JavaScript truthiness treat parsed JSON `null`, `false`, zero or empty text as
  an absent budget. Permit a missing budget only in an explicit baseline mode
  that cannot mark the candidate qualified. Test both malformed root values and
  valid JSON falsy values through policy assertions and the actual command path.
- Expected-failure fixtures must consume evidence from that invocation. Remove
  the exact prior report or bind a unique invocation identifier before starting
  the tool, then require fresh output. A nonzero startup exit plus a stale
  negative report is not a measured rejection. Prove that an actual tool startup
  failure cannot qualify against seeded prior evidence.
- Ancillary timing, diagnostic writes and cleanup must not replace an observed
  primary failure. Test real write or shutdown failure and assert the original
  exception identity, exact returned data, request count and no replay. Keep
  unavailable telemetry visible with a fixed non-sensitive notice. A successful
  exercise followed by failed required cleanup must still fail qualification.
- Semantic-tree presence and successful click metadata do not prove that a
  control was reachable or its action happened. Inspect rendered target geometry
  against headers, scroll boundaries and overlays, then assert the intended
  application state change. Do not replace that evidence with repeated taps.
- A short scroll correction can become a press. Start framing gestures on
  noninteractive content, account for observed touch slop, and keep the complete
  gesture inside the intended viewport. For display-only fixtures, inspect and
  retain the resulting saved bytes after both successful and failed navigation.
  Reject unintended mutation; never restore or replay the fixture to manufacture
  a pass. A failed navigation step does not excuse missing integrity evidence.
- When screenshots must have no alpha channel, inspect PNG color type and
  transparency chunks before publication. Opaque RGBA is not RGB; different
  capture tools can produce different formats within one evidence set. Preserve
  sources and disclose explicit RGB exports. Verify decoded samples, dimensions,
  metadata, size and hash. Never silently composite, crop, resize or normalize
  orientation. Check both published bytes and rendering after conversion.
- Attachment arguments must match the staged Markdown references. Inspect the
  published body for local references and appended duplicates. If upload succeeded
  but reference rewriting failed, repair with existing asset URLs rather than
  uploading the same images again.
- Never call a UI PR complete or merge-ready without screenshots from its
  current head visibly rendered in `## Validation`, unless the user explicitly
  prohibits further UI automation. In that case, state the published evidence's
  exact commit provenance and the current-head evidence limitation.
- A blocked report must include the two logged self-serve attempts and the
  exact human action. "Blocked" alone is not a report. A block without proof
  is an unfinished problem.

## Overrides while this mission runs

This skill composes the pipeline skills above and keeps their identity,
worktree, review, head-freshness, cleanup, and notification safeguards in
force. It overrides them in these ways only, for this run:

- The queue comes from all open issues and all open pull requests, not from an
  explicit selector. Issue-backed pull requests count once, not twice.
- The terminal state for each issue is a merged pull request, not an open one.
  A standalone pull request must merge or close with evidence.
- One blocked item parks and the queue continues, instead of blocking the
  batch.
- Bounded pipelining is allowed while a pull request waits on CI or review,
  instead of strict serial processing.

## Learning from every run

This skill improves itself by reading its own usage. The state file is the
primary evidence source, because a resumed run's conversation is gone; the
history files are the second source.

**Retrospective, every run.** Before ending, review the run's evidence and
answer four questions:

1. Which claimed hard-blocks did the user later overturn, and which blockers
   turned out to be ordinary work?
2. Which ladder rung actually moved things, and did any blocker need a rung
   the ladder lacks?
3. Where did the run improvise a rule this skill should have supplied?
4. Did the user correct anything mid-run? A correction outranks every other
   signal.

Write each finding as a `Lesson:` line in the day's history entry, with issue
or pull-request numbers as evidence. Write the four answers into the history
entry in the same step as the entry itself, before the final report, including
on a re-run that finds nothing new; an entry without them is incomplete.

**Incomplete runs.** A run that ends while any queued issue or pull request is
still unresolved owes the user a completion report, written so it can be
re-evaluated without replaying the session. Record it in the state file and summarize it in the
day's history entry:

1. The stop condition that fired, quoted from "The only ways to stop".
2. One line per incomplete issue: status, exact blocker, the logged attempts,
   the exact human ask, and a diagnosis of what would have let the run
   finish, stating whether that power is the agent's or the user's.
3. An honest classification: did the run end because a human is genuinely
   required, or because the agent ran out of ideas? Running out of ideas is
   a finding to log, not a human requirement.

When the user re-invokes after an incomplete run, read that report first,
state what changed since it was written, and never re-block the same way
without new evidence.

**Twice is a rule.** A one-off detail stays in History. A lesson that appears
twice, or any user correction, becomes an edit to this skill in the same
session: tighten a threshold, extend the anti-list, add a decision default,
or adjust an override. Bump the version in the frontmatter description and
name the lesson it encodes in the history entry. Keep repository-specific
trivia out of this skill; it holds rules that transfer across repositories.

## History

After using this skill, append `## HH:MM - {Action Taken}` plus a one-line
summary to `History/{YYYY-MM-DD}.md` in this skill folder. Include the
retrospective result and one `Lesson:` line per finding that qualifies under
"Learning from every run". Take the timestamp from the shell
(`Get-Date -Format "HH:mm"` on Windows, `date +%H:%M` elsewhere), never an
estimate.
