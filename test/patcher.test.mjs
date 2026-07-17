import assert from "node:assert/strict";
import { mkdtemp, mkdir, readFile, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";

import { patchSource } from "../src/patcher.mjs";

const catalog = {
  schemaVersion: 1,
  locale: "zh-CN",
  messages: [{ id: "sample", source: "hello", target: "你好" }],
};

async function fixture(version = "0.144.3", body = 'const TEXT: &str = "hello";\n') {
  const root = await mkdtemp(path.join(os.tmpdir(), "codex-cli-zh-test-"));
  await mkdir(path.join(root, "codex-rs"), { recursive: true });
  await writeFile(path.join(root, "codex-rs", "Cargo.toml"), `[workspace.package]\nversion = "${version}"\n`);
  await writeFile(path.join(root, "target.rs"), body);
  return root;
}

function adapter(overrides = {}) {
  return {
    schemaVersion: 1,
    id: "test-adapter",
    upstream: { version: "0.144.3" },
    operations: [
      {
        id: "sample",
        messageId: "sample",
        file: "target.rs",
        expectedMatches: 1,
        ...overrides,
      },
    ],
  };
}

test("check validates without changing source", async () => {
  const root = await fixture();
  const report = await patchSource({ sourceRoot: root, adapter: adapter(), catalog, write: false });
  assert.equal(report.operationCount, 1);
  assert.equal(await readFile(path.join(root, "target.rs"), "utf8"), 'const TEXT: &str = "hello";\n');
});

test("apply changes only the declared literal", async () => {
  const root = await fixture();
  await patchSource({ sourceRoot: root, adapter: adapter(), catalog, write: true });
  assert.equal(await readFile(path.join(root, "target.rs"), "utf8"), 'const TEXT: &str = "你好";\n');
});

test("already patched source is rejected", async () => {
  const root = await fixture();
  await patchSource({ sourceRoot: root, adapter: adapter(), catalog, write: true });
  await assert.rejects(
    patchSource({ sourceRoot: root, adapter: adapter(), catalog, write: true }),
    /expected 1 matches.*found 0/,
  );
});

test("unknown source version is rejected", async () => {
  const root = await fixture("0.145.0");
  await assert.rejects(
    patchSource({ sourceRoot: root, adapter: adapter(), catalog, write: false }),
    /Source version is not 0\.144\.3/,
  );
});

test("anchor count drift is rejected", async () => {
  const root = await fixture("0.144.3", 'const A: &str = "hello"; const B: &str = "hello";\n');
  await assert.rejects(
    patchSource({ sourceRoot: root, adapter: adapter(), catalog, write: false }),
    /expected 1 matches.*found 2/,
  );
});

test("path traversal is rejected", async () => {
  const root = await fixture();
  await assert.rejects(
    patchSource({
      sourceRoot: root,
      adapter: adapter({ file: "../outside.rs" }),
      catalog,
      write: false,
    }),
    /escapes the source tree/,
  );
});
