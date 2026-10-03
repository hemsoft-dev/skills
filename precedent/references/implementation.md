# Implementation and operation

## Install

Install the skill in `~/.agents/skills/precedent/`. The Python CLI needs only the
standard library, Python 3.10 or newer, and SQLite FTS5. In the examples below,
`{SKILL}` means that resolved absolute directory.

For Pi, add a small loader at `~/.pi/agent/extensions/precedent.ts`:

```typescript
export { default } from "../../../.agents/skills/precedent/scripts/pi-extension.ts";
```

Pi reload or a new session activates it. The package also declares this extension
in [its manifest](../package.json) for explicit local-package loading. The
[hash-verified installer](../scripts/install.py) installs code and that loader
from a distribution manifest. It refuses different active code, preserves
histories, and never copies private memory. Optional shared guidance is appended
without replacing machine-specific instructions. Previous instruction files
are hash-verified and backed up outside active skill paths. Use one
installation method, not both. Pi can report duplicate tool-name conflicts.

`/precedent status`, `/precedent off`, and `/precedent on` control the current
session. On always means shadow mode. `PRECEDENT_DISABLED=1` disables guidance
and recovery at startup. `PRECEDENT_PYTHON` selects an executable, not a shell
command. `PRECEDENT_STATE` overrides the private store directory.

## Private ledger

The index and reviewed ledger share a local SQLite database. Transcript import
creates candidate rows only. Automated proposal observations live in a separate
table and are never searched as human decisions.

To add reviewed decisions, inspect the original user message and its surrounding
context first. Prepare a private JSON array using these fields:

```json
[
  {
    "id": "synthetic-cleanup-preference",
    "source_id": "pi:exact-index-source-id",
    "source_sha256": "exact-normalized-message-digest",
    "topic": "cleanup_method",
    "decision": "Use the existing deterministic cleanup helper.",
    "scope": "Example/repo",
    "kind": "preference",
    "verification": "source-reviewed",
    "exclusions": ["No authority to discard active or uncertain work."],
    "supersedes": []
  }
]
```

The example is synthetic. It is not a real user decision or seed dataset.

```text
python {SKILL}/scripts/precedent.py curate --file {PRIVATE_REVIEWED_JSON}
```

Curation checks source role, exact digest, live source bytes, immutable decision
IDs, and later same-topic/same-scope supersession. It cannot determine whether
the message was pasted third-party text or whether your interpretation is right.
Source review must establish that. Candidate repository labels come from the
last two working-directory components, not verified historical Git remotes.
Different directory layouts or organization aliases can miss candidate matches.
Establish canonical scope explicitly during curation. The `decision`, `topic`, `scope`, and
`exclusions` fields are analyst-written interpretations; the source quote remains
the primary evidence. Do not invent a reason the user did not state.

Curation itself grants no action authority. A `task_approval` record cannot
support a shadow proposal. Retrieval chooses scoped records ahead of global
records for the same topic and flags contradictory unsuperseded records.

## Two-stage decision tool

The first call retrieves up to five reviewed records and five unverified
candidates. It does not choose an option. The calling agent compares the evidence
with the current situation, then optionally submits a typed proposal in a second
call. This uses the current agent's reasoning, not a separate uncalibrated model.

The second call checks that the chosen option exists and cites currently
retrievable reviewed records. It refuses proposals based only on candidates,
stale sources, task approvals, or unresolved same-topic conflicts. These checks
validate references, not semantic correctness. Shadow mode deliberately keeps
the recommendation advisory and preserves all existing execution gates.

No nested model call, paid review, remote index, vector service or Jev request is
made. Retrieved excerpts enter the current agent's context, which may already
use a remote model provider. The indexer itself has no network code.

## Pi recovery limits

Before a run starts, the extension adds brief consultation guidance. At final
settlement, a conservative prose detector can request one consultation when a
possible decision question ended the run without a consultation. It never
rewrites the question or inserts a fake human answer. Already-streamed text may
remain visible.

Recovery is capped at one continuation per user run. A successful or failed
consultation suppresses further recovery during that run. Abort/error outcomes,
disabled mode, and recognized sensitive approval or authentication questions do
not trigger it. The prose detector is a heuristic, not universal interception.

UI-prompt events record only that a wait occurred, without its title or answer.
Existing question tools and confirmation dialogs remain unchanged. A future
adapter should be integrated and tested with the specific question tool rather
than monkey-patching all UI methods.

## Privacy and storage

Keep `~/.agents/precedent/` outside repositories and skill distributions. Unix
state directories and database files are owner-only; Windows uses the profile's
inherited ACL. Review Windows ACLs if that profile is shared. Do not put this
store on a public share. Private source files and their excerpts are not included
in the package or fleet deployment.

The filter drops recognized token formats, credential assignment patterns,
private keys and JWTs. It is not comprehensive secret detection. Exclude any
sensitive transcript collection before indexing it if needed. The CLI accepts
`index --home {HOME}` and `--state {PRIVATE_DIRECTORY}` for an isolated subset.

Observation rows contain timestamps, request hashes, state, option IDs and
reviewed evidence IDs. Retention is capped at 2,000 rows. They omit question
text and source quotes. IDs can still
reveal context; the whole database remains private.

## Validation and rollout

Run the offline suites:

```text
python -m unittest discover -s {SKILL}/tests -v
node --test {SKILL}/tests/guard.test.mjs
```

The optional [Pi host smoke](../tests/pi-smoke.mjs) also verifies real extension
loading, tool execution, command toggling and boundary-handler contracts in an
isolated temporary store. Invoke it with `--sdk` pointing to the installed Pi
package's `dist/index.js`. It makes no provider request and reads no personal
history. This is not an end-to-end test of a live model deciding what to ask.

The tests use synthetic transcripts. They cover role and origin filtering,
partial files, idempotence, live source verification, scope, supersession,
conflicts, malformed input, permission abstention, bounded results, cancellation,
and one-continuation recovery. Exclusive `before` cutoffs hide the target answer
and later evidence during replay.

These are correctness tests, not measured agreement with Franz. Before any
promotion beyond shadow mode, build a representative historical question/answer
set, split by time and session lineage, prevent duplicated-fork leakage, and
compare ordinary agent decisions against evidence-backed proposals. Measure
incorrect choices, useful abstention, unnecessary questions, and unsafe scope
extension separately. V1 has no autonomous mode to enable.

The current source adapters cover Pi and Codex only. Other providers, automatic
reindexing, centralized fleet memory, question-tool adapters, and calibrated
autonomous decision categories are later work. Missing source history on a peer
means no vetted personal ledger there, not permission to synthesize one.

## Primary references

- [Pi extensions](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/extensions.md)
- [Pi session format](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/session-format.md)
- [Pi security](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/security.md)
- [Python SQLite](https://docs.python.org/3/library/sqlite3.html)
