import assert from "node:assert/strict";
import { cp, mkdir, mkdtemp, readFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";

import { patchSource } from "../src/patcher.mjs";

const projectRoot = path.resolve(import.meta.dirname, "..");
const sourceRoot = process.env.CODEX_UPSTREAM_SOURCE;

test("0.144.3 adapter changes display text without changing slash command behavior", { skip: !sourceRoot }, async () => {
  const adapter = JSON.parse(await readFile(path.join(projectRoot, "resources", "adapters", "codex-0.144.3.json"), "utf8"));
  const catalog = JSON.parse(await readFile(path.join(projectRoot, "resources", "locales", "zh-CN.json"), "utf8"));
  const tempRoot = await mkdtemp(path.join(os.tmpdir(), "codex-cli-zh-upstream-"));
  await mkdir(path.join(tempRoot, "codex-rs"), { recursive: true });
  await cp(path.join(sourceRoot, "codex-rs", "Cargo.toml"), path.join(tempRoot, "codex-rs", "Cargo.toml"));
  for (const relative of [...new Set(adapter.operations.map((item) => item.file))]) {
    await mkdir(path.dirname(path.join(tempRoot, relative)), { recursive: true });
    await cp(path.join(sourceRoot, relative), path.join(tempRoot, relative));
  }

  const slashPath = path.join(tempRoot, "codex-rs", "tui", "src", "slash_command.rs");
  const before = await readFile(slashPath, "utf8");
  const report = await patchSource({ sourceRoot: tempRoot, adapter, catalog, write: true });
  const after = await readFile(slashPath, "utf8");

  assert.deepEqual(report.changedFiles.sort(), [
    "codex-rs/tui/src/bottom_pane/approval_overlay.rs",
    "codex-rs/tui/src/bottom_pane/command_popup.rs",
    "codex-rs/tui/src/bottom_pane/request_user_input/mod.rs",
    "codex-rs/tui/src/slash_command.rs",
  ].sort());
  const behaviorMarker = "    /// Command string without the leading '/'.";
  assert.equal(after.slice(after.indexOf(behaviorMarker)), before.slice(before.indexOf(behaviorMarker)));
  assert.equal(after.slice(0, after.indexOf("impl SlashCommand")), before.slice(0, before.indexOf("impl SlashCommand")));
  assert.match(after, /SlashCommand::Feedback => "向维护者发送日志"/);
  assert.match(after, /SlashCommand::Permissions => "选择允许 Codex 执行的操作"/);
});
