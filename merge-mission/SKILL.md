---
name: merge-mission
description: V1.40 - Resolve every open issue and pull request in a repository, processing existing PRs first and then oldest-first issues. Runs as a persistent goal with current-head review, validation, guarded merges, delivery verification, cleanup, and one-time notifications. Repairs CI and delivery failures, preserves evidence and recovery state, proves remaining hard blocks, and records retrospective lessons. Manual invocation only.
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
- Merge through the guarded gate, including the `--admin` fallback when branch
  protection is the only refusal.
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

An explicit user restriction against browser, UI, or desktop automation
overrides the mission's normal current-head UI evidence requirement. Stop all
such automation immediately. Preserve already-published evidence, label its
exact commit provenance, disclose the current-head evidence gap, and use only
allowed non-UI validation. Do not treat the missing rerun as a hard block and do
not violate the restriction to satisfy a generic evidence rule.

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
   do not add a wait gate. Diagnose failing CI from its logs and fix the cause
   rather than handing back a red or waiting PR. Then use the guarded merge gate,
   `mergepr`, cleanup, and notification from `issue-to-pr-merge` phases 3 and
   4. Read `../process-pr/references/pr-reviewer-policy.md` before reviewer
   work. For a generated dependency update, update its authoritative source or
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
   Review requests must branch on the refreshed evidence. Do not append an
   unconditional trigger to a command that only prints comments or reactions.
   If an automatic review is running or complete for the current head, reuse it
   and record its receipt. Persist the head-specific request decision before any
   later polling loop can issue another trigger.
   Before merging release-bearing work, compare its `Unreleased` notes
   with the automatic release/changelog path, including issue-to-PR links whose
   numbers differ. Reconcile notes that would repeat the generated release
   entry on the source branch, then repeat current-head review and checks. If
   the duplicate is discovered only in a generated PR, correct it before
   merging; do not bypass its guarded gate. For UI work, require current-head
   screenshots visibly rendered in the PR's `## Validation` section and a
   recording when practical or a concrete reason for omission.
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
   between. For recurring prerequisite gaps in composite commands, follow the
   called scripts and configs and validate the declared installation against its
   authoritative dependency declarations. Test a missing secondary tooling
   module. Adding the latest package name to a duplicated list is not a
   root-cause fix.
3. Bound the retries. Cap mechanical retries at three. Never request a review
   again for an unchanged head. Respect the shared policy's wait deadlines.
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
   Delegating to it is a reversible default, not a block.
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

Waiting for CI is cheap; treat it as part of the work, never as a reason to
stop, rush, or skip. Never end a turn to wait. Either poll with bounded
sleeps (`gh pr checks --watch --fail-fast`, or 60 to 120 second sleeps up to
the shared policy deadline) or process another existing PR and come back.
Do not start an ordinary backlog issue just because an existing PR is waiting.
Once every existing PR is resolved or proven hard-blocked, bounded pipelining
of oldest-first backlog issues is allowed. A prerequisite repair needed to
finish an existing PR is part of that PR's work, not a backlog-order bypass.
Keep at most three queue items in flight, and never two branches that touch
the same files. A waiting pull request is parked, not finished.

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
silently skip evidence publication.

Run `gh x status` to see the current state of the mission's progress. Use it
at run start, on resumed turns, and before any merge or block decision,
instead of re-deriving state from scratch. If the command is missing or
errors, fall back to direct `gh` queries and note that in the state file.

## Honesty gates

- Merged means GitHub reports `MERGED`, checked with `gh pr view`. Closed
  means `gh issue view` confirms it.
- Record exact SHAs, commands, and observed results. Never claim a check
  passed without reading its result.
- A newer qualification harness does not raise the shipped application's runtime
  floor. Compare documented support with actual exercised host versions. When
  behavior changed within a supported major version, qualify representative hosts
  on both sides of that boundary and any supported compatibility mode. Run real
  isolated hosts and assert their versions; changing a version variable cannot
  prove runtime behavior. Preserve separate harness and production prerequisites.
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
