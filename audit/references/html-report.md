# HTML audit report

Every audit, including `score` mode and a partially blocked audit, writes one self-contained HTML report.

## Fixed destination

Resolve the path from the audited repository root:

```text
<repository-root>/audit/audit-score.html
```

Create the `audit` directory when it does not exist. Do not choose another directory or filename. Replace an older report only after the new report is complete. Write a temporary file beside the destination, validate it, then rename it over `audit-score.html`. Remove the known temporary file after a failed write.

The report is the sole permitted file mutation in the audited repository. Do not stage or commit it unless the user separately requests that action. Exclude the report and its temporary file from source inventory, quality findings, worktree cleanliness judgments, and score calculations. Record whether the report path was already tracked or ignored.

If the destination cannot be written, do not fall back to Markdown, another directory, or chat-only output. Mark report generation blocked and state the exact filesystem or permission error.

## Document requirements

Generate valid HTML5 with:

- `<!doctype html>`, `<html lang="en">`, UTF-8 metadata, and a viewport declaration;
- a descriptive `<title>` containing the repository name and audited revision;
- one `<h1>`, followed by semantic `<main>`, `<section>`, heading, table, caption, list, and link elements;
- all styling inline in one `<style>` block, with no scripts, remote fonts, images, stylesheets, or runtime dependencies;
- a restrained light and dark color scheme using CSS custom properties and `prefers-color-scheme`;
- visible keyboard focus, underlined links, text labels for every status, and color used only as a secondary cue;
- responsive table wrappers with horizontal overflow instead of clipped columns;
- print styles that remove decoration, preserve URLs where practical, and avoid splitting table rows;
- escaped repository data, commands, evidence, issue titles, and error text before insertion into HTML.

Use a readable system-font stack. Keep the score and evidence easy to scan. Do not add animation, decorative charts, letter grades, maturity labels, or client-side sorting.

## Required report structure

The document header must show:

- repository identity;
- full audited commit;
- generation time in Eastern Time with `EDT` or `EST`;
- audit mode, either `full` or `score`;
- repository score, evidence coverage, and provisional state.

Both modes must include the complete ranked score table from `scoring.md`, with all 18 concern IDs. Preserve the fixed ranking order and display `Blocked` and `N/A` as text.

A full audit report must then include, in this order:

1. declared quality gates;
2. completed audit matrix;
3. created issues and existing issue coverage;
4. evidence that did not justify an issue;
5. blocked commands and unavailable environments;
6. report provenance, including the audit revision and report path.

A score-only report stops after short blocker and applicability notes. It must not include issue drafts, publication details, recommendations, or the full narrative audit.

Use stable section IDs and a short contents list for a full report. Evidence links must point to the exact URL or repository-relative file and line when available. Do not embed credentials, tokens, raw secrets, private file contents, or unredacted scanner output.

## Validation

Before replacing the prior report, verify:

1. the temporary file is non-empty and decodes as UTF-8;
2. it contains one doctype, one opening and closing `html`, `head`, and `body` element;
3. the repository identity and full audited commit appear in text;
4. each fixed concern ID appears exactly once in the score table body;
5. the score, evidence coverage, mode, and generated time are present;
6. full mode contains every required section, while score mode contains none of the excluded sections;
7. no `script`, remote stylesheet, remote font, or remote image dependency is present.

After the atomic replacement, verify that `audit/audit-score.html` exists and report its absolute path. The audit is incomplete until this verification succeeds.
