# Miasma TODO

## Active Run

- [x] Capture end time when the current run finishes or fails.
- [x] Record final summary from the resume run `miasma-remote-scan.json`.
- [ ] Open/review the generated HTML report before sharing conclusions.

Current run:

```text
Owner: relias-engineering
Mode: BranchTip
Implementation: GraphQL path-existence scan
Started: 2026-06-08T22:41:12.0427380-04:00
Ended: 2026-06-08T23:32:22.1294680-04:00
ProcessId: 88744
OutputDirectory: C:\Users\User\.agents\skills\miasma\output\remote\relias-engineering\20260608-224111-graphql-branchtip
ScanTextPath: C:\Users\User\.agents\skills\miasma\output\remote\relias-engineering\20260608-224111-graphql-branchtip\miasma-remote-scan.txt
JsonPath: C:\Users\User\.agents\skills\miasma\output\remote\relias-engineering\20260608-224111-graphql-branchtip\miasma-remote-scan.json
HtmlPath: C:\Users\User\.agents\skills\miasma\output\remote\relias-engineering\20260608-224111-graphql-branchtip\miasma-remote-audit.html
Failure: empty branch list bound as null to `Add-GraphqlBranchTipFinding -Branches`
CompletedBeforeFailure: 195 repos
FailedAtRepository: 196/287 `relias-credentials`
ResumeRepositoryPath: C:\Users\User\.agents\skills\miasma\output\remote\relias-engineering\20260608-224111-graphql-branchtip\resume-from-196-repositories.txt
ResumeRunOutputDirectory: C:\Users\User\.agents\skills\miasma\output\remote\relias-engineering\20260608-234844-graphql-branchtip
ResumeStarted: 2026-06-08T23:48:45.5089088-04:00
ResumeEnded: 2026-06-08T23:56:34.0964994-04:00
ResumeRepositoriesScanned: 92
ResumeRepositoriesWithAnyIndicator: 2
ResumeRepositoriesWithSetupJs: 0
ResumeFindingBearingCommitTrees: 3
ResumeErrors: 0
CombinedBranchTipCoverage: 287 repos
CombinedRepositoriesWithAnyIndicator: crowdin-test-app, Integrations-Contract-Reviewer, ixr-HealthSimVR-Legacy, pdf-conversion-test-app, VR-Simulations
CombinedRepositoriesWithSetupJs: ixr-HealthSimVR-Legacy, VR-Simulations
CombinedFindingBearingCommitTrees: 22
```

## When The Run Finishes

- [x] Verify the process exited; result was failed, not clean.
- [x] Check `run-stderr.txt` for non-empty content.
- [x] Check JSON `Errors` count; resume run had 0 errors.
- [ ] Record:
  - repositories scanned
  - repositories with any indicator
  - repositories with `.github/setup.js`
  - total findings
  - total errors
  - top affected repositories
- [ ] Triage all findings before calling them malicious.
- [ ] Separate high-confidence Miasma indicators from low-signal inherited files.

## Scanner Fixes After This Run

- [x] Allow GraphQL BranchTip scans to handle zero-branch repositories without aborting.
- [ ] Rename GraphQL BranchTip output from `commits` to `matchedTipCommits`.
- [ ] Stop flagging `.vscode/tasks.json` by path alone.
- [ ] Only flag `.vscode/tasks.json` when content contains suspicious auto-run or payload execution patterns, such as:
  - `runOn: folderOpen`
  - `.github/setup.js`
  - `node .github/setup.js`
  - shell/curl/wget download-exec patterns
  - agent/editor hook persistence
- [ ] Add finding classification fields:
  - `critical`
  - `high`
  - `low-signal`
  - `needs-content-review`
- [ ] Add run metadata to JSON and HTML:
  - scanner implementation
  - start time
  - end time
  - duration
  - throttle delay

## Known Follow-Up

- [ ] Reclassify `crowdin-test-app` findings as likely low-signal unless content review finds dangerous task behavior.
- [ ] Preserve `crowdin-test-app` evidence:
  - `.vscode/tasks.json` blob `a298b5bd8796ac377fe9ed64caa249e24c7ec3b6`
  - inherited from initial commit `ae5a98f11439`
  - Snyk branches did not modify `.vscode/tasks.json`
- [x] Triage `pdf-conversion-test-app` `.vscode/tasks.json` as low-signal:
  - both `main` and `feature/various-enhancements` use blob `4dfb6cade7bc96a70fdc4ab98f471260a63c0395`
  - content is a manual VS Code shell task for `dotnet run`
  - no `runOn: folderOpen`, `.github/setup.js`, download-exec, or agent hook pattern
- [ ] Keep avoiding GitHub API side traffic while the long scan is running.
