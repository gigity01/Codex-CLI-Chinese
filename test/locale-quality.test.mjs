import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import path from "node:path";
import test from "node:test";

const root = path.resolve(import.meta.dirname, "..");
const catalog = JSON.parse(
  await readFile(path.join(root, "resources", "locales", "zh-CN.json"), "utf8"),
);

function protectedTokens(value) {
  return value.match(/\/[a-z][a-z0-9-]*(?:\s+verbose)?|<[^>]+>|\{[^}]+\}|`[^`]+`/g) ?? [];
}

test("Simplified Chinese catalog contains the complete slash-command set", () => {
  const slashMessages = catalog.messages.filter(({ id }) => id.startsWith("slash."));
  assert.equal(slashMessages.length, 50);
  assert.equal(new Set(slashMessages.map(({ id }) => id)).size, slashMessages.length);
});

test("localized messages preserve commands, arguments, and placeholders", () => {
  for (const message of catalog.messages) {
    for (const token of protectedTokens(message.source)) {
      assert.ok(message.target.includes(token), `${message.id} must preserve ${token}`);
    }
  }
});

test("slash descriptions avoid superseded literal translations", () => {
  const text = catalog.messages
    .filter(({ id }) => id.startsWith("slash."))
    .map(({ target }) => target)
    .join("\n");
  for (const phrase of ["选择模型和推理强度", "重新映射 TUI", "切换实验性功能", "批准一次最近"]) {
    assert.equal(text.includes(phrase), false, `superseded phrase remains: ${phrase}`);
  }
});
