#!/usr/bin/env node
import { readFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";

import { patchSource } from "./patcher.mjs";

function parseArgs(argv) {
  const [command, ...rest] = argv;
  const options = {};
  for (let index = 0; index < rest.length; index += 2) {
    const key = rest[index];
    const value = rest[index + 1];
    if (!key?.startsWith("--") || value === undefined) {
      throw new Error(`Invalid argument near ${String(key)}`);
    }
    options[key.slice(2)] = value;
  }
  return { command, options };
}

const root = path.resolve(import.meta.dirname, "..");
const { command, options } = parseArgs(process.argv.slice(2));
if (!new Set(["check", "apply"]).has(command)) {
  throw new Error("Usage: node src/cli.mjs <check|apply> --source <path> [--adapter <path>] [--locale <path>]");
}
if (!options.source) {
  throw new Error("--source is required");
}

const adapterPath = path.resolve(options.adapter ?? path.join(root, "resources", "adapters", "codex-0.144.3.json"));
const localePath = path.resolve(options.locale ?? path.join(root, "resources", "locales", "zh-CN.json"));
const adapter = JSON.parse(await readFile(adapterPath, "utf8"));
const catalog = JSON.parse(await readFile(localePath, "utf8"));
const report = await patchSource({
  sourceRoot: path.resolve(options.source),
  adapter,
  catalog,
  write: command === "apply",
});
process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
