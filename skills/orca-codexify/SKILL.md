---
name: orca-codexify
description: Use Codexify reliably for multi-step local development, checkpoint long work, and route long-running, parallel, or isolated coding work to Orca CLI and durable Orchestration.
---

# Orca through Codexify

Use Codexify native tools for ordinary repository work. Use Orca only when the task benefits from a separate
worktree, a long-running agent, parallel execution, or durable supervised worker state.

## Make ordinary Codexify work resumable too

For multi-step work, keep `update_plan` current and save only information that would be expensive to rediscover.
Prefer short MCP calls. If a local command cannot finish promptly, yield it to a Codexify session and poll the
returned handle instead of holding one MCP call open.

At a natural phase boundary, assess the remaining work. Continue in the same turn when the remainder is short.
When another substantial phase remains, save the checkpoint and give the user a concise progress report before
starting that phase. The next turn should be able to continue from the saved plan without repeating completed work.
Do not keep an otherwise idle turn alive merely to wait for background work.

## Always load the installed Orca contract first

Orca changes quickly. Before a non-trivial Orca operation, read the bundled guide from the installed version.

~~~bash
orca-ide skills get orca-cli
orca-ide skills get orchestration
~~~

Treat those guides and current `--help` output as authoritative over copied examples in this skill.

## Prefer short MCP calls

Run Orca commands through Codexify `exec_command` with JSON output. Let Codexify yield quickly and return a
session handle when the CLI call takes longer. Continue the same command with `write_stdin`; do not start it again.

For an unknown mutation result, inspect Orca state before retrying. Reuse Orca's returned mutation/request ID with
the documented `--retry-request` flow only when it is the exact same operation.

## Supervised worker flow

Prefer Codex for supervised workers that require reliable lifecycle settlement. With Orca 1.4.212 and
OpenCode 2.0.18, prompt input can be accepted while turn-start and agent-status observation remain unsupported,
leaving the Dispatch at `input_accepted`. Use OpenCode for direct terminal work or handoff when appropriate, but
do not depend on it for supervised completion until the installed Orca/OpenCode contract proves status support.

For an existing workspace:

1. Resolve the exact Orca worktree with `orca-ide worktree list --json`.
2. Create a dedicated coordinator terminal on the exact `path:` selector.
3. Create an Orchestration Run with `run-create --from <coordinator>`.
4. Start a worker with the exact worktree, Run ID, and coordinator handle.
5. Inspect it with `worker-show` and `worker-read`.
6. After it settles, call `worker-release`.
7. Close the dedicated coordinator terminal.

For an isolated task, first create the worktree explicitly with `orca-ide worktree create --json`, then follow the
same flow using the returned exact path. Do not depend on pseudo-selectors such as `new-top-level` when an explicit
create followed by an exact selector is available.

Remove a temporary worktree only after confirming the task is settled and no wanted changes remain.

## Cross-chat continuity

Store expensive-to-rediscover state in Codexify:

- keep the current multi-step work in `update_plan`;
- remember Orca Run / Task / Dispatch IDs and the exact worktree path when they are still needed;
- in a new ChatGPT conversation, resume the exact Codexify workspace first, then call `recall`;
- query Orca for live state instead of assuming the saved note is current.

## Turn boundaries

The MCP server cannot guarantee that ChatGPT keeps one turn alive indefinitely. At a meaningful phase boundary,
save the plan and durable IDs. If substantial work remains, report current progress to the user and continue in the
next turn rather than keeping an otherwise idle turn open.
