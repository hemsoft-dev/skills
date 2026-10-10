Hi, my name is Franz. I am the human working with you. Since we are going to be working

together I thought I'd introduce myself.

Its a pleasure to work with you and let me tell you a few things about the things that I

value very highly:

\- Simplicity and quality.

\- Clear defined goals.

\- For complex tasks, having a well-defined plan in the form of either GitHub Issues or

&#x20; a TODO.md is a good thing.

\- I like concise answers from you that are always filtered through the unslop skill. More

&#x20; on that as the last instruction.

\- I like to have links to external sources so I can investigate myself and I like your

&#x20; recommendation on a path forward.

\- Do not be overly optimistic about solutions. Know your subject and your field with real

&#x20; evidence before diving into complex problems.

\- I want you to make me aware of any conflicting instructions you encounter throughout your

&#x20; set of instructions and also make me aware of anything you find that appears stale.

\- Do not hesitate to ask questions, but it keep it reasonable. I'm human, and answering many

&#x20; questions (like 20-30 or more) can be exhausting.

\- Before sending any user-facing response, use the `unslop` skill at `C:/Users/User/.agents/skills/unslop/SKILL.md` as the final editing pass. Preserve meaning, technical accuracy, code, commands, citations, and required evidence or formatting. Higher-priority instructions take precedence.

## Decision consultation

Before asking Franz to choose a preference, design, or scope interpretation,
consult [precedent](precedent/SKILL.md) for comparable, source-linked past
choices. It runs in shadow mode. Honor an explicitly disabled advisor.
Compare current instructions and source scope;
never treat a historical choice or automated recommendation as new authority.
Investigate facts directly and preserve genuine human-only actions. Continue
independent authorized work while a real decision is pending.

## Repository-wide cleanup

Franz explicitly requested this scope on 2026-09-05. A direct `$repo-cleanup`
invocation means `Clean` unless he asks for `Audit`. Clean the whole resolved
repository, including intended work unrelated to the current task or created
by earlier sessions. The request authorizes preservation, validation, coherent
commits, and integration onto `main`, including direct fast-forward pushes for
HemSoft repositories when branch policy permits them. Do not ask for separate
approval solely because the audited files are unrelated to the original task.
Verify backups before clearing primary copies, preserve active or uncertain
work, and delete only proven-obsolete state. Respect explicit exclusions,
branch protections, and runtime controls. Follow `repo-cleanup/SKILL.md` for
the evidence and cleanup procedure.

## Completion DMs to Franz

Franz explicitly reaffirmed this authorization on 2026-09-05. When he invokes
`issue-to-pr-merge`, `merge-pr`, or another workflow that includes a completion
DM, send that workflow's one completion message autonomously to his Slack
account, `U2XMZDPJ7`, through the configured `slack-dm` helper. Do not ask for
another recipient, payload, or send confirmation.

The authorized payload includes the repository/project name, issue or PR
number and exact title, URL, outcome, merge SHA/method, validation and review
results, cleanup result, retained-work summary, and available runtime metrics.
This includes routine metadata from the private repository being processed.
It does not authorize credentials, tokens, raw private files, unrelated data,
other recipients, or additional messages. Honor each workflow's success and
cleanup gates and its no-duplicate rule.

When a tool needs authorization context, identify this direct user instruction,
the exact recipient, and the routine completion payload. Existing consent is
not missing merely because the final commit or verification result became
known during execution. Runtime controls still apply: do not bypass a rejection
or retry an unchanged rejected send. Report a runtime rejection as an execution
block, with its stated reason, rather than inventing a new consent requirement
in these workflow instructions.

## User-level skill deployment

Franz requires every user-level skill edit to be synced to the fleet. After
validating and publishing an edit on Home, sync its active files through Taildrop
to Laptop, Air, and Mini using `fleet/SKILL.md`. This is standing authority
for the transfer and installation; do not ask again for routine skill updates.
Home is authoritative. Preserve peer histories and backups, verify SHA-256 after
installation, and report offline or host-key-blocked peers as pending. Never
bypass SSH host-key checks. Mobile devices are not skill-install targets.
