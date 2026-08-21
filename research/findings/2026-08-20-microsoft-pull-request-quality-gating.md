# Pull request quality and gating at Microsoft and GitHub

Research date: 2026-08-20

## Executive answer

Microsoft's current model is layered. Pull requests and policies control entry to the main branch. Fast automated checks catch repeatable failures. A separate person reviews and approves the change. Longer tests can run after merge. AI review is an additional early review, not a replacement for those controls.

Native GitHub Copilot code review cannot serve as a required approval or block a merge. GitHub states that Copilot always submits a `Comment` review, never `Approve` or `Request changes`. Automatic Copilot review can be enabled through a ruleset, including drafts and new pushes, but this only guarantees review coverage. It does not turn Copilot's opinion into a branch gate.

A custom AI gate is technically possible. A workflow or GitHub App can publish a check run or commit status, and a ruleset can require that check from a named source. This is a custom control, not a supported native Copilot Code Review gate. GitHub also says Copilot can miss problems and produce false positives, and explicitly recommends careful human review. For that reason, an AI verdict should not be the sole approval gate.

## What Microsoft currently describes

Microsoft's [Security Development Lifecycle implementation](https://learn.microsoft.com/en-us/compliance/assurance/assurance-security-development-and-operation) requires manual review by someone other than the author before code reaches a release branch. The reviewer checks design and SDL requirements, functional and security tests, reliability, documentation, configuration, and dependencies. Microsoft also builds automated security tooling into commit and build pipelines. Findings must be fixed before the build can pass security review.

Microsoft's description of its [internal DevOps release flow](https://learn.microsoft.com/en-us/devops/develop/how-microsoft-develops-devops) follows the same split:

1. A pull request runs a quick build and test pass.
2. Other engineers review and approve it, with human review focused on architectural and code-quality issues that tests do not cover.
3. The change merges only after build policies and reviewers are satisfied.
4. Broader acceptance tests run after merge.

The page gives one useful design target: Microsoft's fast PR suites run about 60,000 tests in under five minutes. The number is product-specific, but the principle is not. Keep the blocking PR path fast and reliable, then run slower, broader validation later.

The open [Microsoft Engineering Fundamentals Playbook pull request guidance](https://microsoft.github.io/code-with-engineering-playbook/code-reviews/pull-requests/) says main-branch changes should use pull requests and that PR requirements should be enforced by policy. Before opening a PR, code should meet conventions, build without errors or warnings, pass new and existing tests, and include matching documentation. PRs should be small, focused on one goal, and include related tests.

Its [code review process guidance](https://microsoft.github.io/code-with-engineering-playbook/code-reviews/process-guidance/) recommends a review service-level agreement, tracking time to merge, keeping PRs compact, and automating linting and analysis so people can focus on design and functionality.

These playbook pages were last updated in 2024. They remain useful process guidance, but current GitHub and Microsoft Learn documentation should control product configuration and preview-status decisions.

## Recommended hard gates

GitHub rulesets are the cleaner organization-scale control because several rulesets can apply together, organization rules can target multiple repositories, and auditors with read access can inspect active rules. The most restrictive overlapping rules win. See [About rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets).

| Control | Recommended merge behavior | Reason |
| --- | --- | --- |
| Pull request required | Block direct changes to protected branches | Creates a review and audit point |
| Human approval | Require at least one person other than the author | Matches Microsoft SDL separation of duties |
| Code owner or path-based team review | Require for security, infrastructure, shared APIs, data, and other high-risk paths | Routes risky changes to accountable specialists |
| Latest-change protection | Dismiss stale approvals or require approval of the latest reviewable push | Prevents approved PRs from gaining unreviewed code |
| Conversation resolution | Require all review threads to be resolved | Forces explicit handling of findings |
| Fast CI | Require build, lint, type checks, unit tests, and focused integration or contract tests | These are repeatable and objective |
| Security and dependency checks | Require CodeQL or equivalent thresholds and dependency review | Stops known code and supply-chain risks |
| Secret push protection | Block secrets before they enter repository history | Prevention is cheaper than PR-time cleanup |
| Merge queue | Require on busy branches | Rechecks the combined merge group against current main |
| Bypass control | Keep the bypass list small and audited | Avoids turning policy into an optional suggestion |

GitHub's [ruleset rule reference](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets) supports required reviews, code owners, latest-push approval, conversation resolution, required status checks, deployments, code scanning results, code-quality results, and coverage thresholds. The coverage-threshold rule remains in public preview as of this research date.

GitHub can [block merges based on code scanning](https://docs.github.com/en/code-security/how-tos/find-and-fix-code-vulnerabilities/manage-your-configuration/set-merge-protection), with configurable error and security-severity thresholds. Its [dependency review action](https://docs.github.com/en/code-security/concepts/supply-chain-security/dependency-review) fails by default when a PR introduces vulnerable packages and can be required across an organization. [Secret push protection](https://docs.github.com/en/code-security/concepts/secret-security/push-protection) stops supported credentials before they reach the repository.

For repositories with a high merge rate, a [merge queue](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue) tests the proposed change against the latest base branch and changes ahead of it. GitHub Actions workflows must listen for both `pull_request` and `merge_group` events or required checks will never report for queued changes.

## Current Copilot code review status

The "new" agentic Copilot reviewer is no longer beta on GitHub. GitHub made the agentic tool-calling architecture [generally available on 2026-03-05](https://github.blog/changelog/2026-03-05-copilot-code-review-now-runs-on-an-agentic-architecture/). It gathers broader repository context and runs its agentic work through GitHub Actions.

Recent changes include:

- Automatic review at PR open, while draft, and on each new push through repository or organization [rulesets](https://docs.github.com/en/copilot/how-tos/copilot-on-github/set-up-copilot/configure-automatic-review).
- Lite and Balanced review effort. Balanced examines complex logic, security-sensitive code, and cross-service changes more deeply, at higher AI-credit and Actions-minute use.
- Repository-wide `.github/copilot-instructions.md`, root `AGENTS.md`, and path-specific `.github/instructions/**/*.instructions.md` guidance. Copilot reads these from the PR head branch.
- Agent skills and read-only MCP context became [generally available on 2026-07-29](https://github.blog/changelog/2026-07-29-copilot-code-review-agent-skills-and-mcp-now-generally-available/).
- Custom setup through `.github/workflows/copilot-code-review.yml`, separate runner controls, and a default firewall were announced in the [2026-07-17 customization update](https://github.blog/changelog/2026-07-17-copilot-code-review-customization-and-configurability-improvements/).
- Severity labels and grouped comments are available in the new pull request experience, according to the [2026-05-12 comment update](https://github.blog/changelog/2026-05-12-copilot-code-review-comment-experience-improvements/).

The important limit did not change. GitHub's [Copilot code review instructions](https://docs.github.com/en/copilot/how-tos/copilot-on-github/use-copilot-agents/copilot-code-review) say the review is always a comment, does not count toward required approvals, and does not block merging. GitHub's [Copilot code review overview](https://docs.github.com/en/copilot/concepts/agents/code-review) says Copilot may miss problems or make mistakes and should be supplemented with human review.

For Azure Repos, Copilot code review is a separate [limited public preview](https://learn.microsoft.com/en-us/azure/devops/repos/git/copilot-code-reviews?view=azure-devops). It is currently on-demand, has preview limits and no SLA, and likewise never approves, requests changes, satisfies required-reviewer policy, or blocks merging. Microsoft's July 2026 roadmap lists automatic Azure Repos reviews, instructions, skills, cancellation, and Managed DevOps Pools as preview improvements.

## Can AI be made into a gate?

There are three different meanings of "AI gate":

| Design | Possible? | Recommendation |
| --- | --- | --- |
| Require a native Copilot approval | No | Copilot does not submit approval or change-request reviews |
| Automatically run Copilot on every PR | Yes | Recommended as advisory coverage, especially on drafts |
| Convert a custom AI verdict into a required status check | Yes | Pilot carefully; do not use as the only approval |

GitHub rulesets can require a status check and can pin the expected source to a specific GitHub App. A custom reviewer can therefore analyze a fixed commit, publish a success or failure check, and have that check required. That conclusion is an inference from GitHub's status-check API and ruleset behavior, not a GitHub recommendation for Copilot Code Review.

The current `relias-engineering/set-it-free-loop` workflow is a concrete example of this custom pattern. Its `SFL Review Evidence` check is tied to the expected base SHA, head SHA, PR number, and workflow run. It succeeds only when the reviewer approves and both new and unresolved finding counts are zero. The check fails if the PR head changes or the evidence does not match. A repository can then require that check in its ruleset. This is stronger than parsing a Copilot comment, but it still inherits model errors, runtime availability, cost, and configuration risks.

## Recommended path for the meeting

Adopt a two-lane policy.

First, make objective controls mandatory now. Require a PR, one independent human approval, latest-push protection, resolved conversations, fast CI, code scanning, dependency review, and tightly controlled bypass. Add a merge queue where main sees frequent concurrent merges.

Second, enable automatic Copilot review as an advisory pre-review. Run it on drafts so authors can clear obvious issues before asking for human time. Use Balanced effort for security-sensitive or high-risk repositories and Lite for lower-risk repositories. Add concise repository and path-specific instructions. Request a fresh review after material changes rather than assuming the first review still applies.

Run the AI reviewer in shadow mode for four to six weeks before considering a custom blocking check. Measure:

- Percentage of comments accepted as actionable.
- False-positive rate and repeated-comment rate.
- High-severity defects found by AI, humans, CI, and after merge.
- PR lead time and reviewer wait time.
- Review completion reliability, Actions use, and AI-credit cost.
- Differences by language, repository, PR size, and risk class.

Only consider a blocking AI status after the team has an explicit quality threshold, current-head binding, fail-safe behavior for outages, a documented human override, and evidence that the gate catches enough real defects to justify its cycle-time and false-positive cost. Keep the separate human approval.

## Meeting statement

> Microsoft's published practice is policy-enforced pull requests, fast automated checks, and approval by a separate human. GitHub Copilot can now review every PR with broader repository context, but GitHub deliberately makes its native review advisory. We should use it early and automatically, keep deterministic CI and security checks as hard gates, and retain human approval. If we later want an AI verdict to block merge, that requires a custom status-check workflow and should earn that authority through a measured pilot.
