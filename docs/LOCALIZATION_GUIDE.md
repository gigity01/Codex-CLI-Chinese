# Localization Guide

## Scope

Each release localizes one reviewed language catalog against one exact upstream Codex CLI adapter.
The patcher changes display strings only and refuses unknown versions, missing anchors, duplicate anchors,
and source-tree escapes.

## Writing Rules

- Keep slash command names, command-line flags, placeholders, file names, product names, and protocol names unchanged.
- Translate meaning, not English word order. Prefer short action-first descriptions that fit a terminal menu.
- Use one consistent glossary per language. Do not mix translated and untranslated variants of the same UI term.
- Keep dynamic model messages, server responses, tool output, errors, authentication data, and configuration data out of catalogs.
- Review every catalog in the real TUI before release. Machine translation alone is not release-ready.

## Language Sequence

1. Stabilize and review `zh-CN`.
2. Add `ja-JP` as a separate catalog and artifact after native-language review.
3. Add `ko-KR` as a separate catalog and artifact after native-language review.

Do not combine partially reviewed languages into one binary. The adapter may be shared when all source anchors are
identical, but each language must have its own catalog, package name, install manifest, checksum, provenance, and
release validation.
