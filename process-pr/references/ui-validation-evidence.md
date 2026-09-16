# UI validation evidence

Apply this policy when an issue or pull request changes visible or interactive
UI in a web, native desktop, mobile, or game application.

## Issue contract

Every UI issue must have a `## Validation` section. Its checklist must require
the resulting pull request to embed screenshots from the implemented head. Name
the states, viewport sizes, themes, input modes, or platforms needed to prove
the acceptance criteria. Require a short interaction recording when motion,
input, navigation, timing, responsive behavior, or a multi-step flow matters.

When the reported UI already exists and can be run safely, also embed one or
more current-state screenshots in the issue. A net-new UI issue may instead
identify the screen or flow where final evidence must be captured. Do not
present a mockup as proof that implementation is complete. If the UI cannot be
run safely or no authorized attachment route is available, record the exact
blocker. Do not start a browser login or account-switch flow only to attach
issue evidence.

## Pull-request contract

Every UI pull request must have a `## Validation` section that contains all of
the following for its current head:

- the exact command or repeatable manual steps used to run and exercise the
  affected UI;
- one or more screenshots of the implemented result, covering every changed
  state needed to prove the acceptance criteria;
- concise captions that identify the tested state, viewport or platform, and
  observed result; and
- an inline-playable screen recording when practical. A recording is strongly
  preferred for interaction, animation, navigation, responsive transitions,
  timing, or multi-step behavior. If it is omitted, state the concrete reason
  in the section. A recording supplements screenshots and never replaces them.

Capture evidence from the pull request's current head after exercising the
actual affected path. Recapture any image or recording made stale by a later
code change.

## Accessibility validation

Use keyboard navigation, automated accessibility checks, semantic markup, and
browser accessibility-tree inspection when they apply to the changed UI. Do
not require a manual screen-reader pass unless the user or repository explicitly
requests one. Do not infer a manual screen-reader requirement from a general
accessibility acceptance criterion.

## Attachment and rendering rules

Upload screenshots and recordings as GitHub attachments. Put the generated
attachment URL directly in the issue or pull-request body so GitHub renders the
image or playable recording there. Use descriptive image alt text. Do not use
local paths, repository-relative paths, committed evidence files, CI artifact
links, or prose that tells reviewers to find a file elsewhere.

Use GitHub CLI 2.99.0 or newer as the default upload path. Its repeatable
`--attach` flag supports images and videos on `gh issue create`, `gh issue
edit`, `gh issue comment`, `gh pr create`, `gh pr edit`, and `gh pr comment`.
The requesting identity needs push access to the repository. Follow GitHub's
[CLI attachment documentation](https://docs.github.com/en/github-cli/github-cli/attaching-files-with-github-cli)
for supported media, size limits, and body-reference rewriting.

Put local image and video references in the body file, then pass each file with
`--attach`. GitHub CLI replaces matching local references with GitHub attachment
URLs. Keep a video reference alone in its paragraph so GitHub renders an inline
player. Add image alt text in Markdown or after `#` in the attachment argument.
For example:

```powershell
gh pr edit 123 --repo OWNER/REPO `
  --body-file pr-body.md `
  --attach 'desktop.png#Desktop validation state' `
  --attach 'mobile.png#Mobile validation state' `
  --attach interaction.webm
```

After the command, fetch the issue or pull-request body and verify that GitHub
CLI replaced every local reference with a GitHub attachment URL. For standard
image and media attachments, the successful upload plus the rewritten URL in
the fetched body is sufficient rendering evidence. Use browser inspection only
when the rendered Markdown presentation itself is under test, the CLI cannot
verify the rewrite, or the attachment does not render as expected.

If `--attach` is unavailable, upgrade GitHub CLI through the approved package
manager before considering browser automation. Browser upload is a last resort
for a GitHub host or environment that cannot use the supported CLI attachment
flow. Never open a login form, switch browser accounts, or invoke password
manager autofill solely to upload validation evidence. If the attached browser
identity lacks repository access, stop and record that blocker.

Use test data and redact tokens, personal information, customer data, internal
URLs, and unrelated desktop content before upload.

## Gate

A UI pull request without at least one current-head screenshot embedded through
a verified GitHub attachment URL in its `## Validation` section is blocked. Do
not call it human-ready or merge it. When a UI issue requires current-state
screenshots under the issue contract, do not call the issue implementation-ready
until the attachment rewrite is verified or an exact access or safety blocker
is recorded.
