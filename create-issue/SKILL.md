---
name: create-issue
description: V1.2 - Creates one evidence-backed GitHub issue with concise required sections, measurable acceptance criteria, reproducible validation, CLI-uploaded UI evidence when applicable, and repository-appropriate labels.
disable-model-invocation: true
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the create-issue directory (path contains 'create-issue'), verify that history logging occurred.

            Check if History/{YYYY-MM-DD}.md exists and contains an entry for this interaction with:
            - Format: "## HH:MM - {Action Taken}"
            - One-line summary
            - Accurate timestamp (obtained via `Get-Date -Format "HH:mm"` command, never guessed)

            If history entry is missing or incomplete, provide specific feedback on what needs to be added.
            If history entry exists and is properly formatted, acknowledge completion.
  Stop:
    - matcher: "*"
      hooks:
        - type: prompt
          prompt: |
            Before stopping, if create-issue was used, verify that the interaction was logged:

            1. Check if History/{YYYY-MM-DD}.md exists in the create-issue directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"`
            3. Ensure the entry includes a one-line summary of what was done
            4. Verify a retrospective check was performed

            If history is missing, return a blocking decision that names the required entry.
            If history exists, approve stopping.
---

# Create issue

Create one GitHub issue that is ready for implementation. Read
`../process-pr/references/ui-validation-evidence.md` before drafting any issue
that changes visible or interactive UI.

## Workflow

1. Resolve the exact `OWNER/REPO` and authenticate as the account authorized for that repository.
2. Read the repository instructions and inspect the relevant code, tests, documentation, automation, and live repository settings. Correct unverified or overstated premises before drafting.
3. Search open and closed issues for the same outcome. Do not create a duplicate. Report the existing issue unless the user explicitly asks for another.
4. Inspect the repository's existing labels. Apply at least one accurate type label and any useful area or priority label already supported by its taxonomy. Prefer conventional labels such as `bug`, `enhancement`, `documentation`, `dependencies`, and `github_actions`. Create the smallest missing conventional label set only when labels are required and repository policy allows it. Never attach a label merely to fill a category.
5. Write a short imperative title that names the outcome. Keep the body concise, specific, and free of sales language or filler. For UI work, make `## Validation` require screenshots rendered in the resulting PR and a recording when practical. If the current UI can be run safely, capture and embed current-state screenshots in the issue as required by the shared UI evidence policy.
6. Create the issue noninteractively with `gh issue create --repo {OWNER/REPO} --title {TITLE} --body-file {FILE} --label {LABEL}`. Do not add an assignee, milestone, project, or relationship unless requested. For UI evidence, put local media references in the body file and add one `--attach` flag per image or video. Require GitHub CLI 2.99.0 or newer and upgrade it through the approved package manager when needed. Use browser upload only when the target GitHub host or environment cannot use the supported CLI attachment flow. Never open a browser login or account-switch flow solely for evidence upload.
7. Fetch the created issue and verify its title, body sections, labels, state, author, URL, and every attachment rewrite before reporting success. For each UI attachment, confirm the fetched body contains a GitHub attachment URL instead of the local path. Use browser inspection only when the rendered presentation itself is under test or the CLI rewrite cannot be verified.

## Required body

Use these headings in this order:

```markdown
## Description

State the verified current behavior or gap and the bounded task.

## Why

Name the concrete user, maintenance, reliability, security, or delivery impact.

## Goal

Describe the desired end state without prescribing incidental implementation details.

## Acceptance Criteria

- [ ] List observable outcomes with clear pass or fail conditions.

## Definition of Done

- [ ] Cover implementation, tests, documentation or automation changes, review, and repository quality gates that apply.

## Validation

- [ ] Give exact commands or repeatable manual steps and the expected result.
- [ ] For UI work, require the resulting PR to embed current-head screenshots
      that prove the changed states and add an inline recording when practical.
```

Keep the sections distinct. Acceptance Criteria describe product or system behavior. Definition of Done describes the evidence required to close the work. Validation tells another person how to reproduce and inspect that evidence.

For UI work, follow `../process-pr/references/ui-validation-evidence.md`. Name
the states and viewports the screenshots must prove. Require one or more
current-head screenshots uploaded as GitHub attachments and visibly rendered in
the PR's `## Validation` section. Local paths, repository file references, and
CI artifact links do not count. Require an inline-playable recording when
practical for interaction or multi-step behavior; if omitted, the PR must state
the concrete reason. When current-state screenshots belong in the issue, upload
them as GitHub attachments and verify them in the rendered issue.

## Quality rules

- Cite concrete files, commands, settings, or observed behavior when they support the task.
- Preserve the user's priority or severity only when evidence or repository policy supports it.
- Avoid solution lock-in unless the repository already dictates the mechanism.
- Use checkboxes only for work that can be verified independently.
- Do not promise scope beyond the issue's stated goal.
- Apply the `unslop` skill to the title and body before creation.
- Do not call a UI issue implementation-ready when its required validation
  contract omits rendered PR screenshots.
- Do not add a manual screen-reader acceptance criterion or validation step
  unless the user or repository explicitly requires one. Use keyboard,
  automated accessibility, semantic markup, and accessibility-tree evidence by
  default.

## History

After using this skill, append `## HH:MM - {Action Taken}` plus a one-line summary
to `History/{YYYY-MM-DD}.md`. State whether the retrospective found a reusable
improvement. Take the timestamp from the shell, never an estimate.
