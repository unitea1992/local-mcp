import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);
type OrcaConcurrencyGroup = "default" | "wait";

const concurrency = {
  default: {
    limit: 4,
    active: 0,
    waiters: [] as Array<() => void>,
  },
  wait: {
    limit: 16,
    active: 0,
    waiters: [] as Array<() => void>,
  },
} satisfies Record<
  OrcaConcurrencyGroup,
  { limit: number; active: number; waiters: Array<() => void> }
>;
const SAFE_ENV_NAMES = new Set([
  "HOME",
  "PATH",
  "LANG",
  "LC_ALL",
  "LC_CTYPE",
  "USER",
  "LOGNAME",
  "SHELL",
  "TERM",
  "TZ",
  "XDG_CONFIG_HOME",
  "XDG_DATA_HOME",
  "XDG_STATE_HOME",
  "XDG_CACHE_HOME",
  "XDG_RUNTIME_DIR",
  "DBUS_SESSION_BUS_ADDRESS",
  "DISPLAY",
  "WAYLAND_DISPLAY",
]);

export type OrcaResult = unknown;

export function orcaExecutable(): string {
  return process.env.ORCA_CLI_COMMAND?.trim() || "orca-ide";
}

export function orcaEnvironment(
  env: NodeJS.ProcessEnv = process.env,
): NodeJS.ProcessEnv {
  return Object.fromEntries(
    Object.entries(env).filter(([name]) => SAFE_ENV_NAMES.has(name)),
  );
}

export async function runOrca(
  args: string[],
  timeoutMs = 30_000,
  concurrencyGroup: OrcaConcurrencyGroup = "default",
): Promise<OrcaResult> {
  const state = concurrency[concurrencyGroup];
  if (state.active >= state.limit) {
    await new Promise<void>((resolve) => state.waiters.push(resolve));
  }
  state.active += 1;

  try {
    const { stdout, stderr } = await execFileAsync(orcaExecutable(), args, {
      timeout: timeoutMs,
      killSignal: "SIGTERM",
      maxBuffer: 4 * 1024 * 1024,
      env: orcaEnvironment(),
    });

    if (stderr.trim()) {
      process.stderr.write(stderr);
    }

    const output = stdout.trim();
    if (!output) {
      return { ok: true };
    }

    try {
      return JSON.parse(output) as unknown;
    } catch {
      return { ok: true, output };
    }
  } finally {
    state.active -= 1;
    state.waiters.shift()?.();
  }
}

