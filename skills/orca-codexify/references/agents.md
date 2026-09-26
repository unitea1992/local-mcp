# Agent selection and compatibility

Read the installed Orca agent catalog and current `worker-start --help` before selecting an agent. The matrix below
records observed behavior only; installed support and lifecycle behavior can change.

| Agent | Observed support | Recommended route |
| --- | --- | --- |
| Codex | Direct supervised start accepted; `worker_done` settled successfully | Supervised worker |
| OMP | Direct supervised start accepted; `worker_done` settled successfully | Supervised worker |
| OpenCode 2.0.18 | Direct `worker-start --agent opencode` can remain at `input_accepted`; prewarmed terminal flow settled successfully | Create terminal with `--command opencode`, wait for `tui-idle`, then supervise that handle with `worker-start --terminal <handle>` |
| Claude Code | Native Orca support; not installed or acceptance-tested | Test after installation |
| Hermes Agent | Native Orca support; not installed or acceptance-tested | Test after installation |

For OpenCode's successful route, require an accepted `worker_done` with succeeded outcome as completion evidence.
Status liveness can report `missing_status`; that alone neither proves completion nor failure. Do not resend a prompt
just because `input_accepted` is the latest receipt.

Hermes is an Orca-native integration, including agent catalog and TUI selection, startup, hooks, session history,
skill mapping, and automation handling. Do not treat it as a generic custom terminal.

## Accepting another agent

1. Confirm the executable is installed and inspect the current Orca agent catalog and help.
2. If Orca advertises a native agent ID, run one read-only supervised acceptance task with `worker-start --agent <id>`.
3. Require evidence the task ran and an accepted `worker_done` that settles the Dispatch; verify useful output can be
   read and release/cleanup behaves correctly.
4. If no native agent is advertised, start its terminal and wait for TUI readiness. Use
   `worker-start --terminal <handle>` only if Orca recognizes the existing terminal and can own its lifecycle.
5. Use low-level `dispatch --inject` only for an expressiveness gap; it is unsupervised and Orca does not own or
   stop that process. Otherwise use direct terminal/handoff without claiming durable completion tracking.

Do not add agent-specific adapters to Local Dev Hub just to support another CLI agent.
