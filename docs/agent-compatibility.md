# Agent compatibility is capability-driven

Local Dev Hub does not implement one adapter per coding agent. Codexify provides the local coding surface and Orca
owns agent launch, terminal placement, durable Task / Dispatch state, and supervised lifecycle where supported.

## Current matrix

The table records observed behavior, not a permanent vendor guarantee.

| Agent | Installed | Orca 1.4.212 native agent | Supervised acceptance | Recommended use |
| --- | --- | --- | --- | --- |
| Codex | Yes | Yes | Passed | Supervised worker / handoff |
| OMP | Yes | Yes | Passed | Supervised worker / handoff |
| OpenCode 2.0.18 | Yes | Yes | Incomplete lifecycle observation | Direct terminal / handoff |
| Claude Code | No | Yes | Not tested | Test after installation; expected first-class |
| Hermes Agent | No | Yes | Not tested | Test after installation; expected first-class |

OMP's initial worker-start receipt can report turn-start observation as unsupported. This does not by itself make
the worker unusable: in the 2026-09-27 acceptance test Orca subsequently exposed the OMP transcript and agent status,
received `worker_done`, and settled the Dispatch as succeeded/completed.

OpenCode behaved differently in the same environment: input was accepted, but the Dispatch stayed at
`input_accepted` with missing agent status until the test worker was explicitly stopped.

Orca upstream also has Hermes-specific startup, status-hook, session-history, skill mapping, and automation handling.
Treat Hermes as a native Orca integration rather than a generic custom terminal.

## Adding an agent later

Do not add a Local Dev Hub tool or MCP server solely for a new agent.

Prefer these integration tiers:

1. **Native supervised:** Orca accepts `worker-start --agent <id>` and the acceptance test settles.
2. **Existing-terminal supervised:** launch the agent with `terminal create --command ...`, then use
   `worker-start --terminal <handle>` if Orca recognizes it and can own the lifecycle.
3. **Unsupervised dispatch:** use Orca's low-level `dispatch --inject` only when Task/Dispatch messaging is useful
   but Orca cannot own the process.
4. **Direct terminal/handoff:** use the CLI agent normally without promising supervised completion.

This makes future agent support additive. Installing or removing Claude Code, Hermes Agent, or another terminal
agent does not require changing the ChatGPT Connector or Secure MCP Tunnel architecture.
