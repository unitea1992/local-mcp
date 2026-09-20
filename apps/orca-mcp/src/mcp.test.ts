import assert from "node:assert/strict";
import { chmod, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { Client } from "@modelcontextprotocol/client";
import { StdioClientTransport } from "@modelcontextprotocol/client/stdio";

async function createFakeOrca(): Promise<{
  directory: string;
  executable: string;
}> {
  const directory = await mkdtemp(join(tmpdir(), "local-mcp-orca-"));
  const executable = join(directory, "orca-fake");
  const recoveryMarker = join(directory, "recover-created");
  const parallelMarker = join(directory, "parallel-created");
  const source = [
    "#!/usr/bin/env node",
    "const fs = require('node:fs');",
    "const args = process.argv.slice(2);",
    "const key = args.slice(0, 2).join(' ');",
    `const recoveryMarker = ${JSON.stringify(recoveryMarker)};`,
    `const parallelMarker = ${JSON.stringify(parallelMarker)};`,
    "let payload;",
    "if (key === 'repo show') {",
    "  payload = { ok: true, result: { repo: { id: 'repo', path: '/tmp/project', displayName: 'project' } } };",
    "} else if (key === 'terminal show') {",
    "  const index = args.indexOf('--terminal');",
    "  const terminal = index >= 0 ? args[index + 1] : '';",
    "  if (terminal === 'term_existing_agent' || terminal === 'term_recovered') {",
    "    const handle = terminal;",
    "    payload = { ok: true, result: { terminal: { handle: 'term_existing_agent', worktreeId: 'repo::/tmp/project', worktreePath: '/tmp/project', branch: 'refs/heads/main', title: 'OpenCode', connected: true, writable: true, lastOutputAt: 1789910066129, agentIdentity: 'opencode' } } };",
    "    payload.result.terminal.handle = handle;",
    "  } else {",
    "    payload = { ok: true, result: { terminal: { handle: 'term_shell', worktreeId: 'repo::/tmp/project', worktreePath: '/tmp/project', branch: 'refs/heads/main', title: 'shell', connected: true, writable: true } } };",
    "  }",
    "} else if (key === 'worktree list') {",
    "  const worktrees = [];",
    "  if (fs.existsSync(recoveryMarker)) worktrees.push({ id: 'repo::/tmp/recover-task', repoId: 'repo', path: '/tmp/recover-task', branch: 'refs/heads/recover-task', displayName: 'recover-task', workspaceStatus: 'in-progress', parentWorktreeId: null });",
    "  if (fs.existsSync(parallelMarker)) worktrees.push({ id: 'repo::/tmp/parallel-task', repoId: 'repo', path: '/tmp/parallel-task', branch: 'refs/heads/parallel-task', displayName: 'parallel-task', workspaceStatus: 'in-progress', parentWorktreeId: null });",
    "  payload = { ok: true, result: { worktrees } };",
    "} else if (key === 'terminal list') {",
    "  payload = { ok: true, result: { terminals: [{ handle: 'term_recovered', worktreeId: 'repo::/tmp/recover-task', worktreePath: '/tmp/recover-task', branch: 'refs/heads/recover-task', title: 'OpenCode', connected: true, writable: true, lastOutputAt: 1789910066129, agentIdentity: 'opencode' }] } };",
    "} else if (key === 'terminal read') {",
    "  const index = args.indexOf('--terminal');",
    "  const handle = index >= 0 ? args[index + 1] : 'term_unknown';",
    "  payload = { ok: true, result: { terminal: { handle, status: 'running', source: 'stream', tail: ['output'], nextCursor: '1', oldestCursor: '0', latestCursor: '1', truncated: false, limited: false, returnedLineCount: 1, internal: 'must-not-leak' } } };",
    "} else if (key === 'terminal send') {",
    "  const index = args.indexOf('--terminal');",
    "  const handle = index >= 0 ? args[index + 1] : 'term_unknown';",
    "  payload = { ok: true, result: { send: { handle, accepted: true, bytesWritten: 8, prompt: { requestId: 'req-1', stages: ['input_accepted', 'turn_started'], provider: 'opencode', observation: 'turn_started', processIncarnation: 'proc-1', generation: 1, baselineWorkingSequence: 0 }, internal: 'must-not-leak' } } };",
    "} else if (key === 'terminal wait') {",
    "  const index = args.indexOf('--terminal');",
    "  const handle = index >= 0 ? args[index + 1] : 'term_unknown';",
    "  const conditionIndex = args.indexOf('--for');",
    "  const condition = conditionIndex >= 0 ? args[conditionIndex + 1] : 'tui-idle';",
    "  payload = { ok: true, result: { wait: { handle, condition, satisfied: true, status: 'running', exitCode: null, internal: 'must-not-leak' } } };",
    "} else if (key === 'terminal close') {",
    "  const index = args.indexOf('--terminal');",
    "  const handle = index >= 0 ? args[index + 1] : 'term_unknown';",
    "  payload = { ok: true, result: { close: { handle, closeMode: 'terminal', ptyKilled: true, internal: 'must-not-leak' } } };",
    "} else if (key === 'worktree create') {",
    "  const nameIndex = args.indexOf('--name');",
    "  const name = nameIndex >= 0 ? args[nameIndex + 1] : '';",
    "  if (name === 'recover-task') {",
    "    fs.writeFileSync(recoveryMarker, '1');",
    "    process.stdout.write('not-json\\n');",
    "    process.exit(0);",
    "  }",
    "  if (name === 'parallel-task') {",
    "    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 150);",
    "    fs.writeFileSync(parallelMarker, '1');",
    "    payload = { ok: true, result: { worktree: { id: 'repo::/tmp/parallel-task', repoId: 'repo', path: '/tmp/parallel-task', branch: 'refs/heads/parallel-task', displayName: 'parallel-task', workspaceStatus: 'in-progress', parentWorktreeId: null }, startupTerminal: { handle: 'term_parallel' }, agentTerminalHandle: 'term_parallel' } };",
    "  } else {",
    "  payload = { ok: true, result: { worktree: { id: 'repo::/tmp/new-task', repoId: 'repo', path: '/tmp/new-task', branch: 'refs/heads/new-task', displayName: 'new-task', workspaceStatus: 'in-progress', parentWorktreeId: null }, startupTerminal: { handle: 'term_spawned' }, agentTerminalHandle: 'term_spawned' } };",
    "  }",
    "} else {",
    "  payload = { ok: true, result: {} };",
    "}",
    "process.stdout.write(JSON.stringify(payload) + '\\n');",
    "",
  ].join("\n");
  await writeFile(
    executable,
    source,
    "utf8",
  );
  await chmod(executable, 0o755);
  return { directory, executable };
}

test("stdioで起動し、既存agentの引き継ぎと新規agent起動を扱える", async () => {
  const serverPath = fileURLToPath(new URL("./index.js", import.meta.url));
  const fake = await createFakeOrca();
  const transport = new StdioClientTransport({
    command: process.execPath,
    args: [serverPath],
    stderr: "pipe",
    env: {
      ...process.env,
      ORCA_CLI_COMMAND: fake.executable,
    },
  });
  const client = new Client({
    name: "orca-mcp-test",
    version: "0.1.0",
  });

  try {
    await client.connect(transport);
    const response = await client.listTools();
    const names = response.tools.map((tool) => tool.name).sort();

    assert.deepEqual(names, [
      "orca_attach_terminal",
      "orca_close_terminal",
      "orca_create_agent_worktree",
      "orca_detach_terminal",
      "orca_list_terminals",
      "orca_list_worktrees",
      "orca_read_terminal",
      "orca_send_terminal",
      "orca_show_terminal",
      "orca_wait_terminal",
    ]);

    const sendTool = response.tools.find(
      (tool) => tool.name === "orca_send_terminal",
    );
    assert.equal(sendTool?.annotations?.readOnlyHint, false);
    assert.equal(sendTool?.annotations?.destructiveHint, true);

    assert.equal(response.tools.length, 10);
    const expectedAnnotations = {
      orca_attach_terminal: {
        readOnlyHint: false,
        destructiveHint: false,
        openWorldHint: false,
        idempotentHint: true,
      },
      orca_close_terminal: {
        readOnlyHint: false,
        destructiveHint: true,
        openWorldHint: false,
        idempotentHint: false,
      },
      orca_create_agent_worktree: {
        readOnlyHint: false,
        destructiveHint: false,
        openWorldHint: false,
        idempotentHint: false,
      },
      orca_detach_terminal: {
        readOnlyHint: false,
        destructiveHint: false,
        openWorldHint: false,
        idempotentHint: true,
      },
      orca_list_terminals: {
        readOnlyHint: true,
        destructiveHint: false,
        openWorldHint: false,
        idempotentHint: true,
      },
      orca_list_worktrees: {
        readOnlyHint: true,
        destructiveHint: false,
        openWorldHint: false,
        idempotentHint: true,
      },
      orca_read_terminal: {
        readOnlyHint: true,
        destructiveHint: false,
        openWorldHint: false,
        idempotentHint: true,
      },
      orca_send_terminal: {
        readOnlyHint: false,
        destructiveHint: true,
        openWorldHint: false,
        idempotentHint: false,
      },
      orca_show_terminal: {
        readOnlyHint: true,
        destructiveHint: false,
        openWorldHint: false,
        idempotentHint: true,
      },
      orca_wait_terminal: {
        readOnlyHint: true,
        destructiveHint: false,
        openWorldHint: false,
        idempotentHint: true,
      },
    } as const;
    for (const tool of response.tools) {
      assert.ok(tool.title);
      assert.ok(tool.outputSchema);
      assert.equal(
        (tool.outputSchema as { type?: string }).type,
        "object",
      );
      assert.equal(tool.annotations?.openWorldHint, false);
      assert.deepEqual(
        tool.annotations,
        expectedAnnotations[tool.name as keyof typeof expectedAnnotations],
      );
    }

    const listTool = response.tools.find(
      (tool) => tool.name === "orca_list_worktrees",
    );
    assert.equal(listTool?.annotations?.readOnlyHint, true);
    assert.equal(listTool?.annotations?.destructiveHint, false);

    const listed = await client.callTool({
      name: "orca_list_worktrees",
      arguments: {},
    });
    assert.notEqual(listed.isError, true);
    assert.deepEqual(listed.structuredContent, {
      ok: true,
      result: { worktrees: [] },
    });
    assert.deepEqual(JSON.parse((listed.content?.[0] as { text: string }).text), listed.structuredContent);

    const shown = await client.callTool({
      name: "orca_show_terminal",
      arguments: {
        terminal: "term_existing_agent",
      },
    });
    assert.notEqual(shown.isError, true);
    assert.deepEqual(shown.structuredContent, {
      ok: true,
      result: {
        terminal: {
          handle: "term_existing_agent",
          worktreeId: "repo::/tmp/project",
          worktreePath: "/tmp/project",
          branch: "refs/heads/main",
          title: "OpenCode",
          connected: true,
          writable: true,
          lastOutputAt: 1789910066129,
          agentIdentity: "opencode",
        },
      },
    });

    const blocked = await client.callTool({
      name: "orca_send_terminal",
      arguments: {
        terminal: "term_not_managed",
        text: "echo should-not-run",
      },
    });
    assert.equal(blocked.isError, true);

    const readable = await client.callTool({
      name: "orca_read_terminal",
      arguments: {
        terminal: "term_not_managed",
      },
    });
    assert.notEqual(readable.isError, true);
    assert.deepEqual(readable.structuredContent, {
      ok: true,
      result: {
        terminal: {
          handle: "term_not_managed",
          status: "running",
          source: "stream",
          tail: ["output"],
          nextCursor: "1",
          oldestCursor: "0",
          latestCursor: "1",
          truncated: false,
          limited: false,
          returnedLineCount: 1,
        },
      },
    });
    assert.deepEqual(JSON.parse((readable.content?.[0] as { text: string }).text), readable.structuredContent);
    assert.equal(
      JSON.stringify(readable.structuredContent).includes("must-not-leak"),
      false,
    );

    const waited = await client.callTool({
      name: "orca_wait_terminal",
      arguments: {
        terminal: "term_not_managed",
        state: "tui-idle",
        timeoutMs: 1_000,
      },
    });
    assert.notEqual(waited.isError, true);
    assert.deepEqual(waited.structuredContent, {
      ok: true,
      result: {
        wait: {
          handle: "term_not_managed",
          condition: "tui-idle",
          satisfied: true,
          status: "running",
          exitCode: null,
        },
      },
    });
    assert.deepEqual(JSON.parse((waited.content?.[0] as { text: string }).text), waited.structuredContent);

    const shellAttach = await client.callTool({
      name: "orca_attach_terminal",
      arguments: {
        terminal: "term_shell",
      },
    });
    assert.equal(shellAttach.isError, true);

    const attached = await client.callTool({
      name: "orca_attach_terminal",
      arguments: {
        terminal: "term_existing_agent",
      },
    });
    assert.notEqual(attached.isError, true);

    const sendAfterAttach = await client.callTool({
      name: "orca_send_terminal",
      arguments: {
        terminal: "term_existing_agent",
        text: "continue",
      },
    });
    assert.notEqual(sendAfterAttach.isError, true);
    assert.deepEqual(sendAfterAttach.structuredContent, {
      ok: true,
      result: {
        send: {
          handle: "term_existing_agent",
          accepted: true,
          bytesWritten: 8,
          prompt: {
            requestId: "req-1",
            stages: ["input_accepted", "turn_started"],
            provider: "opencode",
            observation: "turn_started",
            processIncarnation: "proc-1",
            generation: 1,
            baselineWorkingSequence: 0,
          },
        },
      },
    });
    assert.deepEqual(JSON.parse((sendAfterAttach.content?.[0] as { text: string }).text), sendAfterAttach.structuredContent);

    const detached = await client.callTool({
      name: "orca_detach_terminal",
      arguments: {
        terminal: "term_existing_agent",
      },
    });
    assert.notEqual(detached.isError, true);
    assert.deepEqual(detached.structuredContent, {
      terminal: "term_existing_agent",
      writable: false,
    });

    const blockedAfterDetach = await client.callTool({
      name: "orca_send_terminal",
      arguments: {
        terminal: "term_existing_agent",
        text: "continue",
      },
    });
    assert.equal(blockedAfterDetach.isError, true);

    const created = await client.callTool({
      name: "orca_create_agent_worktree",
      arguments: {
        repo: "id:repo",
        name: "new-task",
        agent: "opencode",
        setup: "skip",
      },
    });
    assert.notEqual(created.isError, true);

    const closeSpawned = await client.callTool({
      name: "orca_close_terminal",
      arguments: {
        terminal: "term_spawned",
      },
    });
    assert.notEqual(closeSpawned.isError, true);
    assert.deepEqual(closeSpawned.structuredContent, {
      ok: true,
      result: {
        close: {
          handle: "term_spawned",
          closeMode: "terminal",
          ptyKilled: true,
        },
      },
    });

    const recovered = await client.callTool({
      name: "orca_create_agent_worktree",
      arguments: {
        repo: "id:repo",
        name: "recover-task",
        agent: "opencode",
        setup: "skip",
      },
    });
    assert.notEqual(recovered.isError, true);
    assert.deepEqual(recovered.structuredContent, {
      ok: true,
      result: {
        worktree: {
          id: "repo::/tmp/recover-task",
          repoId: "repo",
          path: "/tmp/recover-task",
          branch: "refs/heads/recover-task",
          displayName: "recover-task",
          workspaceStatus: "in-progress",
          parentWorktreeId: null,
        },
        agent: { identity: "opencode", terminal: "term_recovered" },
        recovered: true,
      },
    });

    const closeRecovered = await client.callTool({
      name: "orca_close_terminal",
      arguments: {
        terminal: "term_recovered",
      },
    });
    assert.notEqual(closeRecovered.isError, true);

    const duplicateRecovered = await client.callTool({
      name: "orca_create_agent_worktree",
      arguments: {
        repo: "id:repo",
        name: "recover-task",
        agent: "opencode",
        setup: "skip",
      },
    });
    assert.equal(duplicateRecovered.isError, true);

    const parallelResults = await Promise.all([
      client.callTool({
        name: "orca_create_agent_worktree",
        arguments: {
          repo: "path:/tmp/project",
          name: "parallel-task",
          agent: "opencode",
          setup: "skip",
        },
      }),
      client.callTool({
        name: "orca_create_agent_worktree",
        arguments: {
          repo: "id:repo",
          name: "parallel-task",
          agent: "opencode",
          setup: "skip",
        },
      }),
    ]);
    assert.equal(
      parallelResults.filter((response) => response.isError === true).length,
      1,
    );
    assert.equal(
      parallelResults.filter((response) => response.isError !== true).length,
      1,
    );

    const blockedClose = await client.callTool({
      name: "orca_close_terminal",
      arguments: {
        terminal: "term_existing_agent",
      },
    });
    assert.equal(blockedClose.isError, true);
  } finally {
    await client.close();
    await rm(fake.directory, { recursive: true, force: true });
  }
});
