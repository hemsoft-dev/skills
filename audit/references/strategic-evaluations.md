# Architecture and tech-stack evaluations

After the tactical evidence pass, evaluate architecture and tech-stack suitability in every audit mode. These are evidence-backed judgments on a 1 to 10 scale, not deterministic quality-gate scores. Keep them separate from the 18-concern repository score and tool-native scores. Do not derive either rating by dividing a concern score by ten or average them into the repository score.

## Establish application context

1. Identify the application type, critical journeys, deployment model, supported clients, data sensitivity, availability needs, workload, and operating constraints from repository evidence.
2. Inventory implemented components, runtime and framework versions, databases, infrastructure, deployment services, and important dependencies. Distinguish shipped versions from declared ranges and proposed designs. Cite manifests, lockfiles, deployment configuration, and architecture decisions.
3. Record scale, performance budgets, team constraints, and roadmap needs only when supported. Label unknowns. Do not assume enterprise scale, a large team, or growth the repository has not established.
4. Trace representative critical flows through real code and deployment boundaries. Check documented architecture against the implementation.

## Architecture

Grade each criterion against the application's actual needs, with file, symbol, dependency, test, or deployment evidence.

| Criterion | Evaluate |
| --- | --- |
| Product and deployment fit | Whether the design supports the product, supported platforms, workload, and delivery constraints without unnecessary distributed components or complexity |
| Boundaries and dependency direction | Cohesion, ownership, coupling, cycles, public interfaces, hidden side effects, and isolation of external dependencies |
| State, data, and contracts | Data ownership, consistency, migrations, compatibility, API or IPC contracts, and explicit trust boundaries |
| Changeability and testability | Ability to change domain behavior, test components independently, replace dependencies, and enforce boundaries without duplicating rules |
| Resilience and operability | Failure isolation, timeouts, recovery, observability, deployment, rollback, and scaling design where the product needs them |

Explain the strongest design choices and the most important weaknesses. Recommend bounded changes to specific modules, interfaces, data ownership, or deployment boundaries. Prefer simplification when it resolves the problem. Do not recommend microservices, a rewrite, or a fashionable pattern without concrete benefit and migration cost.

## Tech stack and current web research

Fresh web search is required during each audit with an applicable application stack, including `score` mode. If no application stack applies, record `N/A` with repository evidence rather than researching an invented stack. Model memory, search snippets, and a prior audit's sources are not current research.

1. Use the available web-search skill or search API. Search for the detected application type and exact major versions of its principal runtimes, frameworks, database, and deployment platform. Do not send private code, internal URLs, secrets, or unnecessary proprietary context to a search service.
2. Open relevant sources and verify their contents. Prefer official support and end-of-life policies, security advisories, stable release notes, compatibility matrices, and security, performance, and production guidance. Use independent benchmarks only when their versions, workload, and methodology are comparable.
3. Check current stable and supported release lines, maintenance status, applicable security advisories and mitigations, interoperability, and recommended production configuration. Verify publication or update dates when available. Do not mistake a prerelease, old article, or newer major version for a required upgrade.
4. Compare the guidance with the installed versions, actual configuration, workload, and constraints. State which practices apply and why. Separate measured bottlenecks from untested performance hypotheses and vulnerable installed components from advisories that do not apply.
5. Record a source table with `Component and installed version`, `Source and direct URL`, `Published or updated date`, `Checked on`, `Current guidance`, and `Repository implication`. Use Eastern Time for the research timestamp. Say when the source has no date.
6. If current search or source verification is unavailable, report the exact blocker. Mark affected criteria and the overall tech-stack rating `Blocked`. Retain verified repository evidence and partial criterion ratings, but do not present a memory-based rating as current.

Grade these criteria using both repository evidence and the verified current sources:

| Criterion | Evaluate |
| --- | --- |
| Application and platform fit | Suitability for the UI, domain, workload, deployment environment, supported clients, and team constraints |
| Support and security | Supported release lines, maintenance health, applicable vulnerabilities, hardening, and a practical patch path |
| Performance and resource fit | Runtime, rendering, bundle, storage, query, concurrency, and resource characteristics for the measured workload and budgets |
| Stability and interoperability | Mature production behavior, component compatibility, reproducibility, upgrade hazards, and deployment or rollback support |
| Ecosystem and operating cost | Maintained libraries and tooling, debugging and observability, portability, dependency burden, and evidenced licensing or service constraints |

Assess major components as well as their combination. Do not reward novelty or penalize a stable supported stack merely for being older. A small dependency patch is not proof that the entire stack is unsuitable. Recommend staying with the stack when that is the best-supported choice.

## Rating method

Assign an integer from 1 to 10 to each applicable criterion. These anchors guide judgment; they do not claim measurement precision.

| Rating | Evidence anchor |
| --- | --- |
| 1 to 2 | Fundamental mismatch or severe supported risks that prevent dependable use for the stated purpose |
| 3 to 4 | Major weaknesses or unsupported choices; substantial changes are needed |
| 5 to 6 | Workable fit with material tradeoffs or improvement needs |
| 7 to 8 | Good fit with bounded weaknesses and practical improvement paths |
| 9 to 10 | Strong demonstrated fit; only minor improvements remain, with 10 requiring no material weakness in the evaluated scope |

For each evaluation:

1. Show each criterion's rating and a short evidence-backed rationale. Use `N/A` only with a specific applicability reason and `Blocked` for unavailable evidence. Do not convert either to zero.
2. Calculate the overall rating as the unweighted mean of applicable numeric criteria, rounded to one decimal with exact halves upward. Display it as `Architecture: x/10` or `Tech stack: x/10`.
3. If any applicable criterion is blocked, show the overall rating as `Blocked`, not a partial numeric average. If none apply, show `N/A` and explain why, such as a repository with no application. Do not invent an application or runtime stack.
4. State confidence as `High`, `Medium`, or `Low`, based on evidence breadth and freshness. Explain the main limitation. A numeric judgment with uncertain operating assumptions must disclose them.
5. Distinguish implementation problems from limitations inherent in the design or chosen technology. Link related tactical findings without double-counting them in the repository score.

## Recommendations and output

Include an architecture section and a tech-stack section after the tactical report in full mode. Include compact versions of both in score-only mode, with the ratings, criterion evidence, short recommendation notes, and research source table. This is the only recommendation content allowed in score-only mode.

For each evaluation, provide a short recommendation note. If no change is justified, state why retaining the current design or stack is preferable. When changes are justified, rank them and provide:

- the concrete change and affected component;
- supporting repository evidence and, for version-sensitive stack advice, a direct current source link;
- the expected benefit for maintainability, performance, security, or stability, without invented gains;
- urgency, migration effort, compatibility risks, and a validation or rollback plan;
- why a lower-cost configuration, patch, or incremental refactor is sufficient or insufficient before proposing replacement.

Separate immediate support or security work from incremental improvements and optional experiments. Advisory recommendations do not automatically become issues. Apply the existing reproduction, concrete-impact, bounded-outcome, and duplicate rules in [issue-publication.md](issue-publication.md) before publication. Scores alone never justify an issue. Do not implement recommendations during the audit.
