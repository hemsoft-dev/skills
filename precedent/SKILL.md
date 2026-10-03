---
name: precedent
description: "V1.0 - Commands: Consult, Index, Status. Consult Franz's source-linked past choices before asking him a decision question, clarifying a preference, choosing a design or scope interpretation, or disposing of retained work. Separate facts and authority from preferences."
disable-model-invocation: false
compatibility: Requires Python 3.10+ with SQLite FTS5. Optional Pi integration requires Pi extension APIs and Node.js 22.19+. No extra Python packages or external model service.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If precedent files were read or changed, verify a truthful History
            entry. Obtain the timestamp from the shell. Keep private questions,
            quotes and source paths out of published skill history.
  Stop:
    - matcher: "*"
      hooks:
        - type: prompt
          prompt: |
            If precedent was used, verify a truthful History entry and retrospective.
            Get the timestamp from the shell. Never log private questions or quotes
            in the published skill history, and never treat an automated proposal
            as a human decision.
---

# Precedent

Before asking Franz to make a decision, consult his past choices. Do this within
current instructions and the task's existing authority. Honor an explicitly
disabled advisor. Do not invoke a broader
workflow just because its permissions would make a proposed action easier.

## Consult

1. Classify the missing item as a fact, preference, design, scope, authority,
   or human-only action. Investigate factual gaps through files and APIs first.
2. In Pi, call `resolve_decision` without a proposal. Supply a bounded question,
   two to eight explicit options, the kind, and the verified canonical
   `OWNER/REPO`. Use an empty repository only for genuinely global choices.
3. Read the quoted sources, scope, exclusions, later corrections and conflicts.
   A candidate is a search lead, not an established human preference. Inspect
   its original transcript and context before relying on it.
4. Compare the relevant evidence with current instructions. Current explicit
   instructions win. Narrow repository decisions do not become global defaults.
   A task approval does not become permission for another task.
5. If reviewed evidence supports a choice, call `resolve_decision` again with
   a proposal containing the option ID, reviewed decision IDs, rationale,
   differences from precedent, and conditions that would invalidate it.
6. V1 runs in shadow mode. Record the proposal but retain the normal decision
   process. Do not change existing execution or approval gates based on the
   proposal. Continue independent authorized work instead of stopping all work.

A missing match does not prove a human is required. Existing instructions can
already supply a reversible default. Genuine new authority, secrets, MFA,
CAPTCHAs, hardware touches, legal commitments and production-data changes remain
outside this advisor. Never guess a secret or approve a confirmation dialog.

For non-Pi clients, use the same procedure through the local CLI. Send JSON on
stdin, not a shell-quoted command line. Resolve the script against this skill's
absolute directory, then run:

```text
python scripts/precedent.py resolve
```

Use `python3` on macOS/Linux if that is the available executable. The CLI outputs
quoted evidence and either `investigate`, `needs_authority`, `needs_human`, or a
`shadow` proposal. It always returns `execute: false` and
`authority: not_granted_by_precedent`. Those fields are not runtime enforcement
for other tools, which retain their own authority requirements.

## Index and status

```text
python scripts/precedent.py index
python scripts/precedent.py status
```

The index covers top-level Pi and Codex transcripts, including archived Codex.
It excludes recognized child/fork origins, expanded skill bodies, known generated
briefs, assistant thinking, tool results and detected secrets. Heuristics cannot
prove human authorship or detect every secret. Keep the store private.

Files unchanged in size and modification time are skipped. Changed files are
replaced transactionally. A moving file is deferred rather than indexed from a
mixed snapshot. Every returned source is re-read and checked against its digest.
Missing sources remain unusable. Use `index --rebuild` after parser or filter
updates. It retains the reviewed ledger and re-reads the source collection.

Private state defaults to `~/.agents/precedent/`. It is outside this skill and
must never be committed, fleet-synced, exported or sent to Jev. See
[the implementation notes](references/implementation.md) for source review,
installation, privacy, shadow evaluation and limits.

## End-to-end work

Use precedent inside an already-authorized issue/review/merge/cleanup workflow.
It does not invoke one or expand its scope. Keep issue, PR, review, merge,
cleanup and deployment receipts in that workflow's durable state. A merge is
not completion when its expected release or deployment remains unfinished.
Verify the actual delivery target, source revision and health check under the
repository's established deployment contract.

## History

Append `## HH:MM - {Action Taken}` and a truthful one-line summary to this
skill's `History/{YYYY-MM-DD}.md`. Obtain the time from the shell. Record the
retrospective and any reusable improvement. Never publish private questions,
source quotes, personal decisions, or transcript paths in that history.
