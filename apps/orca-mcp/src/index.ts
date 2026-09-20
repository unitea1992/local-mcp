#!/usr/bin/env node

import { McpServer } from "@modelcontextprotocol/server";
import { serveStdio } from "@modelcontextprotocol/server/stdio";
import * as z from "zod/v4";
import { runOrca } from "./orca.js";

function result(value: unknown) {
  return {
    content: [
      {
        type: "text" as const,
        text: JSON.stringify(value, null, 2),
      },
    ],
  };
}

function terminalHandle(value: unknown): string | undefined {
  if (!value || typeof value !== "object") {
    return undefined;
  }
  const resultValue = (value as { result?: unknown }).result;
  if (!resultValue || typeof resultValue !== "object") {
    return undefined;
  }
  const terminal = (resultValue as { terminal?: unknown }).terminal;
  if (!terminal || typeof terminal !== "object") {
    return undefined;
  }
  const handle = (terminal as { handle?: unknown }).handle;
  return typeof handle === "string" ? handle : undefined;
}

function safeTerminal(
  terminal: Record<string, unknown>,
): Record<string, unknown> {
  return {
    handle: terminal.handle,
    worktreeId: terminal.worktreeId,
    worktreePath: terminal.worktreePath,
    branch: terminal.branch,
    title: terminal.title,
    connected: terminal.connected,
    writable: terminal.writable,
    orphaned: terminal.orphaned,
    lastOutputAt: terminal.lastOutputAt,
    executionHostId: terminal.executionHostId,
  };
}

function sanitizeTerminalResponse(value: unknown): unknown {
  if (!value || typeof value !== "object") {
    return value;
  }

  const source = value as {
    ok?: unknown;
    result?: {
      terminal?: Record<string, unknown>;
      terminals?: Array<Record<string, unknown>>;
    };
  };

  if (source.result?.terminal) {
    return {
      ok: source.ok,
      result: {
        terminal: safeTerminal(source.result.terminal),
      },
    };
  }
  if (Array.isArray(source.result?.terminals)) {
    return {
      ok: source.ok,
      result: {
        terminals: source.result.terminals.map(safeTerminal),
      },
    };
  }
  return { ok: source.ok, result: {} };
}

function sanitizeWorktreeResponse(value: unknown): unknown {
  if (!value || typeof value !== "object") {
    return value;
  }

  const source = value as {
    ok?: unknown;
    result?: {
      worktrees?: Array<Record<string, unknown>>;
    };
  };
  const worktrees = source.result?.worktrees;
  if (!Array.isArray(worktrees)) {
    return value;
  }

  return {
    ok: source.ok,
    result: {
      worktrees: worktrees.map((worktree) => ({
        id: worktree.id,
        repoId: worktree.repoId,
        path: worktree.path,
        branch: worktree.branch,
        displayName: worktree.displayName,
        isMainWorktree: worktree.isMainWorktree,
        workspaceStatus: worktree.workspaceStatus,
        isArchived: worktree.isArchived,
      })),
    },
  };
}

function createServer(): McpServer {
  const server = new McpServer({
    name: "orca-mcp",
    version: "0.1.0",
  });
  const managedAgentTerminals = new Set<string>();
  const terminalQueues = new Map<string, Promise<unknown>>();

  function assertManagedTerminal(terminal: string): void {
    if (!managedAgentTerminals.has(terminal)) {
      throw new Error(
        "このterminalはorca-mcpが起動したOMP/OpenCodeではないため、書き込み操作を拒否しました。",
      );
    }
  }

  async function withTerminalWriteLock<T>(
    terminal: string,
    action: () => Promise<T>,
  ): Promise<T> {
    const previous = terminalQueues.get(terminal) ?? Promise.resolve();
    const current = previous.catch(() => undefined).then(action);
    terminalQueues.set(terminal, current);
    try {
      return await current;
    } finally {
      if (terminalQueues.get(terminal) === current) {
        terminalQueues.delete(terminal);
      }
    }
  }

  server.registerTool(
    "orca_list_worktrees",
    {
      description: "Orcaが管理しているworktree一覧を取得します。",
      annotations: {
        readOnlyHint: true,
        destructiveHint: false,
        idempotentHint: true,
      },
    },
    async () =>
      result(
        sanitizeWorktreeResponse(
          await runOrca(["worktree", "list", "--json"]),
        ),
      ),
  );

  server.registerTool(
  "orca_list_terminals",
  {
    description: "指定したOrca worktreeのterminal一覧を取得します。",
    inputSchema: z.object({
      worktree: z.string().min(1).describe("Orca worktree selector"),
    }),
    annotations: {
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
    },
  },
  async ({ worktree }) =>
    result(
      sanitizeTerminalResponse(
        await runOrca([
          "terminal",
          "list",
          "--worktree",
          worktree,
          "--json",
        ]),
      ),
    ),
  );

  server.registerTool(
  "orca_show_terminal",
  {
    description: "Orca terminalの現在状態を取得します。",
    inputSchema: z.object({
      terminal: z.string().min(1).describe("Orca terminal handle"),
    }),
    annotations: {
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
    },
  },
  async ({ terminal }) =>
    result(
      sanitizeTerminalResponse(
        await runOrca(["terminal", "show", "--terminal", terminal, "--json"]),
      ),
    ),
  );

  server.registerTool(
  "orca_read_terminal",
  {
    description: "Orca terminalの出力を読み取ります。",
    inputSchema: z.object({
      terminal: z.string().min(1).describe("Orca terminal handle"),
      cursor: z.string().min(1).optional(),
      limit: z.number().int().min(1).max(5000).optional(),
    }),
    annotations: {
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
    },
  },
  async ({ terminal, cursor, limit }) => {
    assertManagedTerminal(terminal);
    const args = ["terminal", "read", "--terminal", terminal];
    if (cursor) {
      args.push("--cursor", cursor);
    }
    if (limit !== undefined) {
      args.push("--limit", String(limit));
    }
    args.push("--json");
    return result(await runOrca(args));
  },
  );

  server.registerTool(
  "orca_send_terminal",
  {
    description:
      "orca-mcpが起動したOMP/OpenCodeへ追加指示を送ります。通常のshellや既存terminalには送信しません。",
    inputSchema: z.object({
      terminal: z.string().min(1).describe("Orca terminal handle"),
      text: z.string().min(1).max(20_000),
      enter: z.boolean().default(true),
      waitSubmitSeconds: z.number().int().min(1).max(60).optional(),
    }),
    annotations: {
      readOnlyHint: false,
      destructiveHint: true,
      idempotentHint: false,
    },
  },
  async ({ terminal, text, enter, waitSubmitSeconds }) => {
    assertManagedTerminal(terminal);
    return withTerminalWriteLock(terminal, async () => {
      assertManagedTerminal(terminal);
      const args = [
        "terminal",
        "send",
        "--terminal",
        terminal,
        "--text",
        text,
      ];
      if (enter) {
        args.push("--enter");
      }
      if (waitSubmitSeconds !== undefined) {
        args.push("--wait-submit", String(waitSubmitSeconds));
      }
      args.push("--json");
      return result(await runOrca(args, 90_000));
    });
  },
  );

  server.registerTool(
  "orca_wait_terminal",
  {
    description:
      "Orca terminalが終了するか、TUIエージェントが入力待ちになるまで待機します。",
    inputSchema: z.object({
      terminal: z.string().min(1).describe("Orca terminal handle"),
      state: z.enum(["exit", "tui-idle"]),
      timeoutMs: z.number().int().min(1_000).max(300_000).default(60_000),
    }),
    annotations: {
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
    },
  },
  async ({ terminal, state, timeoutMs }) => {
    assertManagedTerminal(terminal);
    return result(
      await runOrca(
        [
          "terminal",
          "wait",
          "--terminal",
          terminal,
          "--for",
          state,
          "--timeout-ms",
          String(timeoutMs),
          "--json",
        ],
        timeoutMs + 5_000,
      ),
    );
  },
  );

  server.registerTool(
  "orca_start_agent",
  {
    description:
      "指定したOrca worktreeでOMPまたはOpenCodeを新しいterminalとして起動します。",
    inputSchema: z.object({
      worktree: z.string().min(1).describe("Orca worktree selector"),
      agent: z.enum(["omp", "opencode"]),
      title: z.string().min(1).max(80).optional(),
      focus: z.boolean().default(false),
    }),
    annotations: {
      readOnlyHint: false,
      destructiveHint: false,
      idempotentHint: false,
    },
  },
  async ({ worktree, agent, title, focus }) => {
    const args = [
      "terminal",
      "create",
      "--worktree",
      worktree,
      "--command",
      agent,
    ];
    if (title) {
      args.push("--title", title);
    }
    if (focus) {
      args.push("--focus");
    }
    args.push("--json");
    const response = await runOrca(args);
    const handle = terminalHandle(response);
    if (!handle) {
      throw new Error("Orcaが作成したterminal handleを取得できませんでした。");
    }
    managedAgentTerminals.add(handle);
    return result(sanitizeTerminalResponse(response));
  },
  );

  server.registerTool(
  "orca_close_terminal",
  {
    description: "orca-mcpが起動したOMP/OpenCodeのterminalだけを終了して閉じます。",
    inputSchema: z.object({
      terminal: z.string().min(1).describe("Orca terminal handle"),
    }),
    annotations: {
      readOnlyHint: false,
      destructiveHint: true,
      idempotentHint: false,
    },
  },
  async ({ terminal }) => {
    assertManagedTerminal(terminal);
    return withTerminalWriteLock(terminal, async () => {
      assertManagedTerminal(terminal);
      const response = await runOrca([
        "terminal",
        "close",
        "--terminal",
        terminal,
        "--json",
      ]);
      managedAgentTerminals.delete(terminal);
      return result(response);
    });
  },
  );

  return server;
}

const handle = serveStdio(createServer);
process.on("SIGINT", () => {
  void handle.close();
});
console.error("orca-mcp is listening on stdio");

