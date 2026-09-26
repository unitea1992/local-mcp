# Worktree and supervised orchestration

Use Orca for long-running, parallel, or isolated work. Codexify's `worktrees.mode=never`; create and manage task
worktrees through Orca. The standard location is `<projects-root>/.worktrees/<repo>/<worktree>`.

## Exact workspace and ownership

For an existing workspace, resolve the exact worktree with `worktree list --json`, create a coordinator terminal
on its exact `path:` selector, create a Run from that handle, and start the worker with the exact worktree, Run ID,
and coordinator handle. For isolated work, explicitly create the worktree first and use the returned exact path.
Do not rely on pseudo-selectors such as `new-top-level` when an explicit create and exact selector are available.

The installed orchestration skill defines the current lifecycle commands. The common flow is:

1. Create/reuse the correct worktree and a dedicated coordinator terminal.
2. Create or bind the Run and start the Task's Dispatch with `worker-start`.
3. Inspect active work through Orca's worker commands and process coordinator messages.
4. Treat an accepted `worker_done` as settlement evidence; then decide whether to reuse, retain, or release the
   worker. Close the coordinator terminal after the work is settled.
5. Remove a temporary worktree only after confirming the task settled and no wanted changes remain.

## Safety and idempotency

- A Run is a durable namespace, a Task is the requested work, and a Dispatch is one authoritative attempt. Lifecycle
  authority comes from the active Dispatch, not a terminal label or transcript alone.
- A successful message send proves enqueue only. A heartbeat proves liveness, not completion.
- Absence, timeout, `missing_status`, or connection loss is not proof that a worker exited. Do not stop, abandon,
  retry, release, or launch a duplicate from absence alone. Consult current Orca liveness and recovery guidance.
- After an ambiguous mutation, inspect Orca state before retrying. Use a request ID only with the exact same
  operation and the installed CLI's documented `--retry-request` flow.
- Prefer `worker-start` for supervised lifecycle. `dispatch --inject` leaves a process unsupervised.
- `worker_done` settles its Task and Dispatch; do not issue a second Task completion mutation.
- Release is post-settlement cleanup, not cancellation. Do not replace uncertain release with terminal close.

For a new agent or a changed lifecycle, read [agents.md](agents.md). Before operations, read the installed
`orca-cli` and `orchestration` skills; their instructions and current `--help` are authoritative.
