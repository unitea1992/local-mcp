---
name: orca-codexify
description: Use when delegating or supervising long-running, parallel, or isolated coding work from Local Dev Hub to Orca.
---

# Orca from Local Dev Hub

Use Local Dev Hub native tools for inspection, tests, machine configuration, and final integration. Route retained
Git-repository changes, parallel agents, and durable supervised work to an Orca-managed worktree. Codexify
worktrees are disabled; Orca owns worktree and orchestration state.

## Before Orca operations

Orca's installed CLI and bundled skills define the current execution contract. Read the relevant current skill and
command `--help` before a non-trivial operation; this guide and its references are workflow guidance, not a CLI
specification:

~~~bash
orca-ide skills get orca-cli
orca-ide skills get orchestration
~~~

Load only the workflow reference needed for the task:

- Agent selection, compatibility, or acceptance: [references/agents.md](references/agents.md)
- Worktree, Run, Task, Dispatch, worker lifecycle, or retries: [references/orchestration.md](references/orchestration.md)
- Checkpoints, long commands, or cross-chat resume: [references/continuity.md](references/continuity.md)

Keep Orca idempotency and lifecycle decisions in Orca. After an ambiguous mutation, inspect state before retrying;
reuse a returned request ID only with the installed CLI's documented retry flow. Do not create a duplicate operation
because a response was lost.
