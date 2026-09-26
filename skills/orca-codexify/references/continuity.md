# Checkpoints and continuity

Keep ordinary multi-step work in Codexify when Orca's durable worker lifecycle is not needed. For long commands,
use Codexify's yielding `exec_command` session and continue the same returned handle with `write_stdin`; do not
start the same command again after a timeout.

At a meaningful phase boundary, update the plan and save only context that would be costly to rediscover. If a
substantial phase remains, report progress and continue in a later turn instead of holding an otherwise idle turn
open.

When a task needs durable supervision, remember the live Orca Run, Task, Dispatch IDs and exact worktree path only
while they are needed. Saved IDs are a checkpoint, not live state: query Orca before acting on them. For a new
ChatGPT conversation, resume the exact Codexify `resumePath` first and then call `recall` to restore task context.
The current Orca CLI remains the source of truth for worker state.
