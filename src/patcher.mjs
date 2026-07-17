import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";

export function sha256(value) {
  return createHash("sha256").update(value).digest("hex");
}

function assertPlainRelativePath(value) {
  if (typeof value !== "string" || value.length === 0 || path.isAbsolute(value)) {
    throw new Error(`Adapter path must be relative: ${String(value)}`);
  }
  const normalized = path.posix.normalize(value.replaceAll("\\", "/"));
  if (normalized === ".." || normalized.startsWith("../")) {
    throw new Error(`Adapter path escapes the source tree: ${value}`);
  }
  return normalized;
}

function countOccurrences(haystack, needle) {
  if (needle.length === 0) {
    throw new Error("Empty patch anchor is not allowed");
  }
  let count = 0;
  let offset = 0;
  while ((offset = haystack.indexOf(needle, offset)) !== -1) {
    count += 1;
    offset += needle.length;
  }
  return count;
}

function rustString(value) {
  return JSON.stringify(value);
}

export function validateCatalog(catalog) {
  if (catalog.schemaVersion !== 1 || catalog.locale !== "zh-CN") {
    throw new Error("Unsupported locale catalog schema");
  }
  const messages = new Map();
  for (const entry of catalog.messages ?? []) {
    if (!entry.id || messages.has(entry.id)) {
      throw new Error(`Duplicate or missing locale id: ${String(entry.id)}`);
    }
    if (typeof entry.source !== "string" || typeof entry.target !== "string") {
      throw new Error(`Invalid locale entry: ${entry.id}`);
    }
    messages.set(entry.id, entry);
  }
  return messages;
}

export async function verifySourceVersion(sourceRoot, adapter) {
  const cargoPath = path.join(sourceRoot, "codex-rs", "Cargo.toml");
  const cargo = await readFile(cargoPath, "utf8");
  const versionLine = `version = "${adapter.upstream.version}"`;
  if (!cargo.includes(versionLine)) {
    throw new Error(`Source version is not ${adapter.upstream.version}`);
  }
}

export async function patchSource({ sourceRoot, adapter, catalog, write = false }) {
  if (adapter.schemaVersion !== 1) {
    throw new Error("Unsupported adapter schema");
  }
  await verifySourceVersion(sourceRoot, adapter);
  const messages = validateCatalog(catalog);
  const files = new Map();
  const results = [];

  for (const operation of adapter.operations ?? []) {
    const relativePath = assertPlainRelativePath(operation.file);
    const message = messages.get(operation.messageId);
    if (!message) {
      throw new Error(`Missing locale message: ${operation.messageId}`);
    }
    const absolutePath = path.resolve(sourceRoot, relativePath);
    const rootWithSeparator = `${path.resolve(sourceRoot)}${path.sep}`;
    if (!absolutePath.startsWith(rootWithSeparator)) {
      throw new Error(`Resolved path escapes source tree: ${relativePath}`);
    }
    const original = files.has(absolutePath)
      ? files.get(absolutePath)
      : await readFile(absolutePath, "utf8");
    const anchor = rustString(message.source);
    const replacement = rustString(message.target);
    const matches = countOccurrences(original, anchor);
    if (matches !== operation.expectedMatches) {
      throw new Error(
        `${operation.id}: expected ${operation.expectedMatches} matches in ${relativePath}, found ${matches}`,
      );
    }
    if (original.includes(replacement)) {
      throw new Error(`${operation.id}: translated text already exists in ${relativePath}`);
    }
    files.set(absolutePath, original.replaceAll(anchor, replacement));
    results.push({
      id: operation.id,
      file: relativePath,
      matches,
      beforeSha256: sha256(original),
    });
  }

  for (const [absolutePath, content] of files) {
    if (write) {
      await writeFile(absolutePath, content, "utf8");
    }
  }

  return {
    adapterId: adapter.id,
    upstreamVersion: adapter.upstream.version,
    operationCount: results.length,
    changedFiles: [...files.keys()].map((file) => path.relative(sourceRoot, file).replaceAll("\\", "/")),
    operations: results,
  };
}
