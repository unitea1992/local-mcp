import assert from "node:assert/strict";
import test from "node:test";
import { orcaEnvironment, orcaExecutable } from "./orca.js";

test("ORCA_CLI_COMMANDがなければorca-ideを使う", () => {
  const original = process.env.ORCA_CLI_COMMAND;
  delete process.env.ORCA_CLI_COMMAND;

  try {
    assert.equal(orcaExecutable(), "orca-ide");
  } finally {
    if (original === undefined) {
      delete process.env.ORCA_CLI_COMMAND;
    } else {
      process.env.ORCA_CLI_COMMAND = original;
    }
  }
});

test("ORCA_CLI_COMMANDを指定できる", () => {
  const original = process.env.ORCA_CLI_COMMAND;
  process.env.ORCA_CLI_COMMAND = "/custom/orca";

  try {
    assert.equal(orcaExecutable(), "/custom/orca");
  } finally {
    if (original === undefined) {
      delete process.env.ORCA_CLI_COMMAND;
    } else {
      process.env.ORCA_CLI_COMMAND = original;
    }
  }
});

test("Secure MCP Tunnelの秘密値をOrcaへ渡さない", () => {
  const env = orcaEnvironment({
    PATH: "/usr/bin",
    HOME: "/home/test",
    CONTROL_PLANE_API_KEY: "secret",
    OPENAI_ADMIN_KEY: "admin-secret",
    OPENAI_API_KEY: "openai-secret",
    GITHUB_TOKEN: "github-secret",
    EXAMPLE_PASSWORD: "password",
    SAFE_VALUE: "ok",
  });

  assert.equal(env.PATH, "/usr/bin");
  assert.equal(env.HOME, "/home/test");
  assert.equal(env.SAFE_VALUE, undefined);
  assert.equal(env.CONTROL_PLANE_API_KEY, undefined);
  assert.equal(env.OPENAI_ADMIN_KEY, undefined);
  assert.equal(env.OPENAI_API_KEY, undefined);
  assert.equal(env.GITHUB_TOKEN, undefined);
  assert.equal(env.EXAMPLE_PASSWORD, undefined);
});

