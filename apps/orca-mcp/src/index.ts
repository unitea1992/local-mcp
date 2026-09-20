#!/usr/bin/env node

import { McpServer } from "@modelcontextprotocol/server";
import { serveStdio } from "@modelcontextprotocol/server/stdio";
import * as z from "zod/v4";
import { runOrca } from "./orca.js";

const ATTACHABLE_AGENT_IDENTITIES = new Set([
  "omp",
  "opencode",
  "codex",
]);

const nullableString = z.string().nullable().optional();
const nullableTimestamp = z
  .union([z.string(), z.number().int().nonnegative()])
  .nullable()
  .optional();

const worktreeSchema = z.object({
  id: z.string().optional(),
  repoId: z.string().optional(),
  path: z.string().optional(),
  branch: nullableString,
  displayName: z.string().optional(),
  isMainWorktree: z.boolean().optional(),
  workspaceStatus: z.string().optional(),
  isArchived: z.boolean().optional(),
  parentWorktreeId: nullableString,
});

const terminalSchema = z.object({
  handle: z.string().optional(),
  worktreeId: z.string().optional(),
  worktreePath: z.string().optional(),
  branch: nullableString,
  title: nullableString,
  connected: z.boolean().optional(),
  writable: z.boolean().optional(),
  orphaned: z.boolean().optional(),
  lastOutputAt: nullableTimestamp,
  executionHostId: nullableString,
  agentIdentity: nullableString,
});

const worktreeListOutputSchema = z.object({
  ok: z.boolean().optional(),
  result: z.object({
    worktrees: z.array(worktreeSchema),
  }),
});

const terminalListOutputSchema = z.object({
  ok: z.boolean().optional(),
  result: z.object({
    terminals: z.array(terminalSchema),
  }),
});

const terminalOutputSchema = z.object({
  ok: z.boolean().optional(),
  result: z.object({
    terminal: terminalSchema,
  }),
});

const terminalReadOutputSchema = z.object({
  ok: z.boolean().optional(),
  result: z.object({
    terminal: z.object({
      handle: z.string(),
      status: z.string(),
      source: z
        .enum(["stream", "screen", "screen-unavailable"])
        .optional(),
      draft: z.string().optional(),
      tail: z.array(z.string()),
      nextCursor: z.string().nullable(),
      oldestCursor: z.string().optional(),
      latestCursor: z.string().optional(),
      truncated: z.boolean().optional(),
      limited: z.boolean().optional(),
      returnedLineCount: z.number().int().nonnegative().optional(),
    }),
  }),
});

const promptReceiptSchema = z.object({
  requestId: z.string(),
  stages: z.array(z.string()),
  provider: z.string(),
  observation: z.string(),
  processIncarnation: z.string().optional(),
  generation: z.number().int().optional(),
  baselineWorkingSequence: z.number().int().optional(),
});

const terminalSendOutputSchema = z.object({
  ok: z.boolean().optional(),
  result: z.object({
    send: z.object({
      handle: z.string(),
      accepted: z.boolean(),
      bytesWritten: z.number().int().nonnegative().optional(),
      refusedReason: z.string().optional(),
      prompt: promptReceiptSchema.optional(),
    }),
    warnings: z.array(z.string()).optional(),
  }),
});

const terminalWaitOutputSchema = z.object({
  ok: z.boolean().optional(),
  result: z.object({
    wait: z.object({
      handle: z.string(),
      condition: z.string(),
      satisfied: z.boolean(),
      status: z.string(),
      exitCode: z.number().int().nullable().optional(),
      blockedReason: z.string().optional(),
    }),
  }),
});

const createdWorktreeOutputSchema = z.object({
  ok: z.boolean().optional(),
  result: z.object({
    worktree: worktreeSchema,
    agent: z.object({
      identity: z.enum(["omp", "opencode", "codex"]),
      terminal: z.string(),
    }),
    recovered: z.boolean(),
  }),
});

const terminalCloseOutputSchema = z.object({
  ok: z.boolean().optional(),
  result: z.object({
    close: z.object({
      handle: z.string(),
      closeMode: z.string().optional(),
      tabId: z.string().optional(),
      ptyKilled: z.boolean().optional(),
      ptyStopVerdict: z.string().optional(),
      ptyStopReason: z.string().optional(),
    }),
  }),
});

const detachOutputSchema = z.object({
  terminal: z.string(),
  writable: z.boolean(),
});

function result(value: unknown) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("MCP tool result must be a JSON object.");
  }
  const structuredContent = value as Record<string, unknown>;
  return {
    structuredContent,
    content: [
      {
        type: "text" as const,
        text: JSON.stringify(structuredContent, null, 2),
      },
    ],
  };
}

function terminalAgentIdentity(value: unknown): string | undefined {
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
  const identity = (terminal as { agentIdentity?: unknown }).agentIdentity;
  return typeof identity === "string" ? identity : undefined;
}

function createdAgentTerminalHandle(value: unknown): string | undefined {
  if (!value || typeof value !== "object") {
    return undefined;
  }
  const resultValue = (value as { result?: unknown }).result;
  if (!resultValue || typeof resultValue !== "object") {
    return undefined;
  }
  const resultObject = resultValue as {
    agentTerminalHandle?: unknown;
    startupTerminal?: { handle?: unknown };
  };
  if (typeof resultObject.agentTerminalHandle === "string") {
    return resultObject.agentTerminalHandle;
  }
  return typeof resultObject.startupTerminal?.handle === "string"
    ? resultObject.startupTerminal.handle
    : undefined;
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
    agentIdentity: terminal.agentIdentity,
  };
}

function safeWorktree(
  worktree: Record<string, unknown>,
): Record<string, unknown> {
  return {
    id: worktree.id,
    repoId: worktree.repoId,
    path: worktree.path,
    branch: worktree.branch,
    displayName: worktree.displayName,
    isMainWorktree: worktree.isMainWorktree,
    workspaceStatus: worktree.workspaceStatus,
    isArchived: worktree.isArchived,
    parentWorktreeId: worktree.parentWorktreeId,
  };
}

function worktreesFromResponse(
  value: unknown,
): Array<Record<string, unknown>> {
  if (!value || typeof value !== "object") {
    return [];
  }
  const resultValue = (value as { result?: unknown }).result;
  if (!resultValue || typeof resultValue !== "object") {
    return [];
  }
  const worktrees = (resultValue as { worktrees?: unknown }).worktrees;
  return Array.isArray(worktrees)
    ? worktrees.filter(
        (worktree): worktree is Record<string, unknown> =>
          Boolean(worktree) && typeof worktree === "object",
      )
    : [];
}

function terminalsFromResponse(
  value: unknown,
): Array<Record<string, unknown>> {
  if (!value || typeof value !== "object") {
    return [];
  }
  const resultValue = (value as { result?: unknown }).result;
  if (!resultValue || typeof resultValue !== "object") {
    return [];
  }
  const terminals = (resultValue as { terminals?: unknown }).terminals;
  return Array.isArray(terminals)
    ? terminals.filter(
        (terminal): terminal is Record<string, unknown> =>
          Boolean(terminal) && typeof terminal === "object",
      )
    : [];
}

function repoIdFromResponse(value: unknown): string | undefined {
  if (!value || typeof value !== "object") {
    return undefined;
  }
  const resultValue = (value as { result?: unknown }).result;
  if (!resultValue || typeof resultValue !== "object") {
    return undefined;
  }
  const repo = (resultValue as { repo?: unknown }).repo;
  if (!repo || typeof repo !== "object") {
    return undefined;
  }
  const id = (repo as { id?: unknown }).id;
  return typeof id === "string" ? id : undefined;
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
      worktrees: worktrees.map(safeWorktree),
    },
  };
}

function sanitizeCreatedWorktreeResponse(
  value: unknown,
  agent: string,
): unknown {
  if (!value || typeof value !== "object") {
    return value;
  }
  const source = value as {
    ok?: unknown;
    result?: {
      worktree?: Record<string, unknown>;
      agentTerminalHandle?: unknown;
      startupTerminal?: { handle?: unknown };
      recovered?: unknown;
    };
  };
  const worktree = source.result?.worktree;
  const handle = createdAgentTerminalHandle(value);
  if (!worktree || !handle) {
    return { ok: source.ok, result: {} };
  }

  return {
    ok: source.ok,
    result: {
      worktree: safeWorktree(worktree),
      agent: {
        identity: agent,
        terminal: handle,
      },
      recovered: source.result?.recovered === true,
    },
  };
}

function sanitizeTerminalReadResponse(value: unknown): unknown {
  if (!value || typeof value !== "object") {
    throw new Error("Orca terminal read response is not an object.");
  }
  const source = value as {
    ok?: unknown;
    result?: {
      terminal?: Record<string, unknown>;
    };
  };
  const terminal = source.result?.terminal;
  if (!terminal || typeof terminal !== "object") {
    throw new Error("Orca terminal read response is missing terminal data.");
  }
  return {
    ok: source.ok,
    result: {
      terminal: {
        handle: terminal.handle,
        status: terminal.status,
        source: terminal.source,
        draft: terminal.draft,
        tail: terminal.tail,
        nextCursor: terminal.nextCursor,
        oldestCursor: terminal.oldestCursor,
        latestCursor: terminal.latestCursor,
        truncated: terminal.truncated,
        limited: terminal.limited,
        returnedLineCount: terminal.returnedLineCount,
      },
    },
  };
}

function sanitizeTerminalSendResponse(value: unknown): unknown {
  if (!value || typeof value !== "object") {
    throw new Error("Orca terminal send response is not an object.");
  }
  const source = value as {
    ok?: unknown;
    result?: {
      send?: Record<string, unknown>;
      warnings?: unknown;
    };
  };
  const send = source.result?.send;
  if (!send || typeof send !== "object") {
    throw new Error("Orca terminal send response is missing send data.");
  }
  const prompt =
    send.prompt && typeof send.prompt === "object"
      ? (send.prompt as Record<string, unknown>)
      : undefined;
  return {
    ok: source.ok,
    result: {
      send: {
        handle: send.handle,
        accepted: send.accepted,
        bytesWritten: send.bytesWritten,
        refusedReason: send.refusedReason,
        prompt: prompt
          ? {
              requestId: prompt.requestId,
              stages: prompt.stages,
              provider: prompt.provider,
              observation: prompt.observation,
              processIncarnation: prompt.processIncarnation,
              generation: prompt.generation,
              baselineWorkingSequence: prompt.baselineWorkingSequence,
            }
          : undefined,
      },
      warnings: Array.isArray(source.result?.warnings)
        ? source.result.warnings.filter(
            (warning): warning is string => typeof warning === "string",
          )
        : undefined,
    },
  };
}

function sanitizeTerminalWaitResponse(value: unknown): unknown {
  if (!value || typeof value !== "object") {
    throw new Error("Orca terminal wait response is not an object.");
  }
  const source = value as {
    ok?: unknown;
    result?: {
      wait?: Record<string, unknown>;
    };
  };
  const wait = source.result?.wait;
  if (!wait || typeof wait !== "object") {
    throw new Error("Orca terminal wait response is missing wait data.");
  }
  return {
    ok: source.ok,
    result: {
      wait: {
        handle: wait.handle,
        condition: wait.condition,
        satisfied: wait.satisfied,
        status: wait.status,
        exitCode: wait.exitCode,
        blockedReason: wait.blockedReason,
      },
    },
  };
}

function sanitizeTerminalCloseResponse(value: unknown): unknown {
  if (!value || typeof value !== "object") {
    throw new Error("Orca terminal close response is not an object.");
  }
  const source = value as {
    ok?: unknown;
    result?: {
      close?: Record<string, unknown>;
    };
  };
  const close = source.result?.close;
  if (!close || typeof close !== "object") {
    throw new Error("Orca terminal close response is missing close data.");
  }
  return {
    ok: source.ok,
    result: {
      close: {
        handle: close.handle,
        closeMode: close.closeMode,
        tabId: close.tabId,
        ptyKilled: close.ptyKilled,
        ptyStopVerdict: close.ptyStopVerdict,
        ptyStopReason: close.ptyStopReason,
      },
    },
  };
}

function createServer(): McpServer {
  const server = new McpServer({
    name: "orca-mcp",
    version: "0.1.0",
  });
  const spawnedAgentTerminals = new Set<string>();
  const writableAgentTerminals = new Set<string>();
  const terminalQueues = new Map<string, Promise<unknown>>();
  const createQueues = new Map<string, Promise<unknown>>();

  function assertWritableTerminal(terminal: string): void {
    if (!writableAgentTerminals.has(terminal)) {
      throw new Error(
        "このterminalは書き込み対象としてattachされていません。先にorca_attach_terminalで引き継いでください。",
      );
    }
  }

  function assertSpawnedTerminal(terminal: string): void {
    if (!spawnedAgentTerminals.has(terminal)) {
      throw new Error(
        "このterminalはorca-mcpが起動したものではないため、終了操作を拒否しました。",
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

  async function withCreateLock<T>(
    repo: string,
    name: string,
    action: () => Promise<T>,
  ): Promise<T> {
    const key = `${repo}\u0000${name}`;
    const previous = createQueues.get(key) ?? Promise.resolve();
    const current = previous.catch(() => undefined).then(action);
    createQueues.set(key, current);
    try {
      return await current;
    } finally {
      if (createQueues.get(key) === current) {
        createQueues.delete(key);
      }
    }
  }

  async function findWorktreeByName(
    repo: string,
    name: string,
  ): Promise<Record<string, unknown> | undefined> {
    const response = await runOrca([
      "worktree",
      "list",
      "--repo",
      repo,
      "--json",
    ]);
    const matches = worktreesFromResponse(response).filter(
      (worktree) =>
        worktree.displayName === name ||
        worktree.branch === `refs/heads/${name}`,
    );
    return matches.length === 1 ? matches[0] : undefined;
  }

  async function canonicalRepoSelector(repo: string): Promise<{
    id: string;
    selector: string;
  }> {
    const response = await runOrca([
      "repo",
      "show",
      "--repo",
      repo,
      "--json",
    ]);
    const id = repoIdFromResponse(response);
    if (!id) {
      throw new Error("Orca repo selectorを正規IDへ解決できませんでした。");
    }
    return {
      id,
      selector: `id:${id}`,
    };
  }

  async function recoverCreatedAgent(
    repo: string,
    name: string,
    agent: string,
  ): Promise<unknown | undefined> {
    for (let attempt = 0; attempt < 5; attempt += 1) {
      try {
        const worktree = await findWorktreeByName(repo, name);
        const worktreeId = worktree?.id;
        if (typeof worktreeId === "string") {
          const terminalsResponse = await runOrca([
            "terminal",
            "list",
            "--worktree",
            `id:${worktreeId}`,
            "--json",
          ]);
          const terminals = terminalsFromResponse(terminalsResponse);

          for (const terminal of terminals) {
            const handle = terminal.handle;
            if (typeof handle !== "string") {
              continue;
            }
            if (terminal.agentIdentity === agent) {
              return {
                ok: true,
                result: {
                  worktree,
                  agentTerminalHandle: handle,
                  recovered: true,
                },
              };
            }

            const shown = await runOrca([
              "terminal",
              "show",
              "--terminal",
              handle,
              "--json",
            ]);
            if (terminalAgentIdentity(shown) === agent) {
              return {
                ok: true,
                result: {
                  worktree,
                  agentTerminalHandle: handle,
                  recovered: true,
                },
              };
            }
          }
        }
      } catch {
        // Recovery is best-effort. Retry briefly because Orca may still be
        // finishing work after the client-side create response was lost.
      }
      if (attempt < 4) {
        await new Promise((resolve) => setTimeout(resolve, 1_000));
      }
    }
    return undefined;
  }

  server.registerTool(
    "orca_list_worktrees",
    {
      title: "Orca worktree一覧",
      description: "Orcaが管理しているworktree一覧を取得します。",
      outputSchema: worktreeListOutputSchema,
      annotations: {
        readOnlyHint: true,
        destructiveHint: false,
        openWorldHint: false,
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
    title: "Orca terminal一覧",
    description: "指定したOrca worktreeのterminal一覧を取得します。",
    inputSchema: z.object({
      worktree: z.string().min(1).describe("Orca worktree selector"),
    }),
    outputSchema: terminalListOutputSchema,
    annotations: {
      readOnlyHint: true,
      destructiveHint: false,
      openWorldHint: false,
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
    title: "Orca terminal状態",
    description: "Orca terminalの現在状態を取得します。",
    inputSchema: z.object({
      terminal: z.string().min(1).describe("Orca terminal handle"),
    }),
    outputSchema: terminalOutputSchema,
    annotations: {
      readOnlyHint: true,
      destructiveHint: false,
      openWorldHint: false,
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
    title: "Orca terminal出力を読む",
    description:
      "Orca terminalの出力を読み取ります。既存のOMP/OpenCodeやshellもレビュー対象として読めます。",
    inputSchema: z.object({
      terminal: z.string().min(1).describe("Orca terminal handle"),
      cursor: z.string().min(1).optional(),
      limit: z.number().int().min(1).max(5000).optional(),
    }),
    outputSchema: terminalReadOutputSchema,
    annotations: {
      readOnlyHint: true,
      destructiveHint: false,
      openWorldHint: false,
      idempotentHint: true,
    },
  },
  async ({ terminal, cursor, limit }) => {
    const args = ["terminal", "read", "--terminal", terminal];
    if (cursor) {
      args.push("--cursor", cursor);
    }
    if (limit !== undefined) {
      args.push("--limit", String(limit));
    }
    args.push("--json");
    return result(sanitizeTerminalReadResponse(await runOrca(args)));
  },
  );

  server.registerTool(
  "orca_attach_terminal",
  {
    title: "Orca agent terminalを引き継ぐ",
    description:
      "OrcaがOMP/OpenCode/Codexと認識している既存terminalを引き継ぎ、ChatGPTから追加指示を送れるようにします。送信前にorca_read_terminalで内容を確認してください。",
    inputSchema: z.object({
      terminal: z.string().min(1).describe("Orca terminal handle"),
    }),
    outputSchema: terminalOutputSchema,
    annotations: {
      readOnlyHint: false,
      destructiveHint: false,
      openWorldHint: false,
      idempotentHint: true,
    },
  },
  async ({ terminal }) => {
    const response = await runOrca([
      "terminal",
      "show",
      "--terminal",
      terminal,
      "--json",
    ]);
    const identity = terminalAgentIdentity(response);
    if (!identity || !ATTACHABLE_AGENT_IDENTITIES.has(identity)) {
      throw new Error(
        "このterminalはOMP/OpenCode/Codexとして認識されていないためattachできません。",
      );
    }
    writableAgentTerminals.add(terminal);
    return result(sanitizeTerminalResponse(response));
  },
  );

  server.registerTool(
  "orca_detach_terminal",
  {
    title: "Orca agent terminalの引き継ぎを解除",
    description:
      "既存terminalの引き継ぎを解除します。terminal自体は終了せず、以後の入力だけを拒否します。",
    inputSchema: z.object({
      terminal: z.string().min(1).describe("Orca terminal handle"),
    }),
    outputSchema: detachOutputSchema,
    annotations: {
      readOnlyHint: false,
      destructiveHint: false,
      openWorldHint: false,
      idempotentHint: true,
    },
  },
  async ({ terminal }) => {
    if (!spawnedAgentTerminals.has(terminal)) {
      writableAgentTerminals.delete(terminal);
    }
    return result({
      terminal,
      writable: writableAgentTerminals.has(terminal),
    });
  },
  );

  server.registerTool(
  "orca_send_terminal",
  {
    title: "Orca agent terminalへ指示を送る",
    description:
      "orca-mcpが起動したterminal、またはorca_attach_terminalで引き継いだ既存terminalへ追加指示を送ります。",
    inputSchema: z.object({
      terminal: z.string().min(1).describe("Orca terminal handle"),
      text: z.string().min(1).max(20_000),
      enter: z.boolean().default(true),
      waitSubmitSeconds: z.number().int().min(1).max(60).optional(),
    }),
    outputSchema: terminalSendOutputSchema,
    annotations: {
      readOnlyHint: false,
      destructiveHint: true,
      openWorldHint: false,
      idempotentHint: false,
    },
  },
  async ({ terminal, text, enter, waitSubmitSeconds }) => {
    assertWritableTerminal(terminal);
    return withTerminalWriteLock(terminal, async () => {
      assertWritableTerminal(terminal);
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
      return result(
        sanitizeTerminalSendResponse(await runOrca(args, 90_000)),
      );
    });
  },
  );

  server.registerTool(
  "orca_wait_terminal",
  {
    title: "Orca terminalを待機",
    description:
      "Orca terminalが終了するか、TUIエージェントが入力待ちになるまで待機します。",
    inputSchema: z.object({
      terminal: z.string().min(1).describe("Orca terminal handle"),
      state: z.enum(["exit", "tui-idle"]),
      timeoutMs: z.number().int().min(1_000).max(300_000).default(60_000),
    }),
    outputSchema: terminalWaitOutputSchema,
    annotations: {
      readOnlyHint: true,
      destructiveHint: false,
      openWorldHint: false,
      idempotentHint: true,
    },
  },
  async ({ terminal, state, timeoutMs }) => {
    return result(
      sanitizeTerminalWaitResponse(
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
          "wait",
        ),
      ),
    );
  },
  );

  server.registerTool(
  "orca_create_agent_worktree",
  {
    title: "Orca agent worktreeを作成",
    description:
      "Orcaのagent-aware launcherを使い、新しいworktreeとOMP/OpenCode/Codexをまとめて起動します。",
    inputSchema: z.object({
      repo: z.string().min(1).describe("Orca repo selector"),
      name: z.string().min(1).max(80).describe("新しいworktree名"),
      agent: z.enum(["omp", "opencode", "codex"]),
      prompt: z.string().min(1).max(20_000).optional(),
      setup: z.enum(["inherit", "run", "skip"]).default("inherit"),
      parentWorktree: z
        .string()
        .min(1)
        .describe("stacked workにする場合の親worktree selector")
        .optional(),
      baseBranch: z
        .string()
        .min(1)
        .describe("明示的にGit baseを変える場合だけ指定")
        .optional(),
    }),
    outputSchema: createdWorktreeOutputSchema,
    annotations: {
      readOnlyHint: false,
      destructiveHint: false,
      openWorldHint: false,
      idempotentHint: false,
    },
  },
  async ({
    repo,
    name,
    agent,
    prompt,
    setup,
    parentWorktree,
    baseBranch,
  }) => {
    const canonicalRepo = await canonicalRepoSelector(repo);
    return withCreateLock(canonicalRepo.id, name, async () => {
      if (await findWorktreeByName(canonicalRepo.selector, name)) {
        throw new Error(
          "同名のOrca worktreeが既に存在します。別のnameを指定してください。",
        );
      }

      const args = [
        "worktree",
        "create",
        "--repo",
        canonicalRepo.selector,
        "--name",
        name,
        "--agent",
        agent,
        "--setup",
        setup,
      ];
      if (parentWorktree) {
        args.push("--parent-worktree", parentWorktree);
      } else {
        args.push("--no-parent");
      }
      if (baseBranch) {
        args.push("--base-branch", baseBranch);
      }
      if (prompt) {
        args.push("--prompt", prompt);
      }
      args.push("--json");

      let response: unknown;
      try {
        response = await runOrca(args, 180_000);
      } catch (error) {
        const recovered = await recoverCreatedAgent(
          canonicalRepo.selector,
          name,
          agent,
        );
        if (!recovered) {
          throw error;
        }
        response = recovered;
      }

      let handle = createdAgentTerminalHandle(response);
      if (!handle) {
        const recovered = await recoverCreatedAgent(
          canonicalRepo.selector,
          name,
          agent,
        );
        if (recovered) {
          response = recovered;
          handle = createdAgentTerminalHandle(recovered);
        }
      }
      if (!handle) {
        throw new Error(
          "Orcaが作成したagent terminal handleを取得できず、再発見にも失敗しました。",
        );
      }
      spawnedAgentTerminals.add(handle);
      writableAgentTerminals.add(handle);
      return result(sanitizeCreatedWorktreeResponse(response, agent));
    });
  },
  );

  server.registerTool(
  "orca_close_terminal",
  {
    title: "Orca MCP作成terminalを閉じる",
    description: "orca-mcpが起動したOMP/OpenCode/Codexのterminalだけを終了して閉じます。",
    inputSchema: z.object({
      terminal: z.string().min(1).describe("Orca terminal handle"),
    }),
    outputSchema: terminalCloseOutputSchema,
    annotations: {
      readOnlyHint: false,
      destructiveHint: true,
      openWorldHint: false,
      idempotentHint: false,
    },
  },
  async ({ terminal }) => {
    assertSpawnedTerminal(terminal);
    return withTerminalWriteLock(terminal, async () => {
      assertSpawnedTerminal(terminal);
      const response = sanitizeTerminalCloseResponse(
        await runOrca([
          "terminal",
          "close",
          "--terminal",
          terminal,
          "--json",
        ]),
      );
      spawnedAgentTerminals.delete(terminal);
      writableAgentTerminals.delete(terminal);
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
