# .NET AI Community Standup - Using the GitHub Copilot CLI and SDK for .NET dev

## Executive Summary

In this .NET AI Community Standup, guest host John Galloway joins Steve Sanderson to explore the rapidly evolving landscape of AI-powered development tools. The session focuses heavily on the **GitHub Copilot CLI** and the new **Copilot SDK**, demonstrating how these tools are shifting the software engineering paradigm from manual coding to "agentic" workflows. Sanderson showcases several cutting-edge features including **Plan Mode**, **Multi-Agent Reviews**, and **Custom Skills**, arguing that these advancements allow developers to move faster, prototype more aggressively, and tackle complex tasks in languages they may not even speak fluently.

## Key Takeaways

* **The "Agentic" Shift:** Software development is moving from simple AI autocomplete to multi-step agents that can plan, implement, test, and iterate autonomously.
* **Immediacy of CLIs:** Tools like the Copilot CLI are gaining popularity because they offer immediate productivity without being tethered to a specific IDE or source control system.
* **Radical Productivity:** Sanderson reports that his small team (7–10 people) shipped over 200 items in a single week by leveraging these agentic tools.
* **Fail Fast, Prototype Faster:** AI agents reduce the cost of prototyping from days to minutes, allowing teams to "learn by doing" rather than spending weeks in design meetings.
* **The Copilot SDK:** Developers can now integrate the "smarts" of the GitHub Copilot agent—including its optimized prompts and tool-using capabilities—directly into their own .NET applications.

## Detailed Notes

### The Evolution of Coding Agents

Steve Sanderson outlines two major waves of AI tools:

1. **IDE-Based Agents:** Started with tools like Cursor and evolved into VS Code's "Agent Mode," moving beyond simple autocomplete to multi-step problem solving.
2. **CLI-Based Agents:** The arrival of Claude Code, Gemini CLI, and GitHub Copilot CLI. These are praised for their "dopamine machine" effect—providing progress on a problem within seconds of a prompt.

### Feature Deep Dive

* **Multi-Agent Reviews:** Sanderson demonstrates running a PR review using **Claude Opus, Haiku, and Gemini** in parallel. This "council of AIs" helps mitigate hallucinations. Each model has a personality: Gemini is often more critical/fussy, Haiku is lenient, and Opus is rigorous and focused on real issues.
* **Plan Mode:** A recently shipped feature that forces the agent to write an interactive Markdown plan before writing any code. Developers can review, edit, and iterate on this plan, ensuring consensus before implementation begins.
* **Custom Skills:** Skills are reusable sets of context (Markdown instructions and helper scripts). They allow the agent to discover how to perform specific tasks (like interacting with Slack or checking a build status) without blowing up the context window.
* **Large Output Handling:** The tools now intelligently save large data blocks (like 96KB diffs) to disk and read them in chunks to avoid overwhelming the model's context window.

### The Copilot SDK for .NET

The new SDK allows .NET developers to instantiate a `CopilotClient` and create sessions that utilize the same optimized agent loop used in the CLI.

* **Function Calling:** You can easily wrap standard C# methods into AI functions that the agent can invoke.
* **Custom Workflows:** Sanderson demonstrates a tool that fetches a GitHub issue via URL and uses the agent's reasoning to provide an accurate implementation estimate (sizing).

### Changing the Developer Mindset

Sanderson encourages developers to stop being "precious" about their code. Because the cost of production has dropped so significantly, it is now viable to implement a feature multiple times in different ways just to see which fits the system best. He also highlights the "liberation" of no longer needing to manually handle Git branching, merging, or writing PR descriptions—tasks the agents now handle fluently.

## Conclusion

The session concludes with a strong call to action: **Give these tools a try on a task you wouldn't normally do.** Whether it's porting code to a language you don't know or prototyping a "crazy" feature you've been putting off, the current generation of coding agents provides an empowering moment for developers. While the landscape is changing fast—with many features shown being only weeks or days old—the shift toward high-level, agentic interaction with AI is clearly the future of the industry.
