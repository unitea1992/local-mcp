import assert from "node:assert/strict";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { Client } from "@modelcontextprotocol/client";
import { StdioClientTransport } from "@modelcontextprotocol/client/stdio";

test("stdioで起動し、想定したOrca toolsを公開する", async () => {
  const serverPath = fileURLToPath(new URL("./index.js", import.meta.url));
  const transport = new StdioClientTransport({
    command: process.execPath,
    args: [serverPath],
    stderr: "pipe",
    env: {
      ...process.env,
      ORCA_CLI_COMMAND: "/bin/echo",
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
      "orca_close_terminal",
      "orca_list_terminals",
      "orca_list_worktrees",
      "orca_read_terminal",
      "orca_send_terminal",
      "orca_show_terminal",
      "orca_start_agent",
      "orca_wait_terminal",
    ]);

    const sendTool = response.tools.find(
      (tool) => tool.name === "orca_send_terminal",
    );
    assert.equal(sendTool?.annotations?.readOnlyHint, false);
    assert.equal(sendTool?.annotations?.destructiveHint, true);

    const listTool = response.tools.find(
      (tool) => tool.name === "orca_list_worktrees",
    );
    assert.equal(listTool?.annotations?.readOnlyHint, true);
    assert.equal(listTool?.annotations?.destructiveHint, false);

    const blocked = await client.callTool({
      name: "orca_send_terminal",
      arguments: {
        terminal: "term_not_managed",
        text: "echo should-not-run",
      },
    });
    assert.equal(blocked.isError, true);

    const blockedRead = await client.callTool({
      name: "orca_read_terminal",
      arguments: {
        terminal: "term_not_managed",
      },
    });
    assert.equal(blockedRead.isError, true);

  } finally {
    await client.close();
  }
});

