# Security Policy

## Build boundary

The localization process must not read, package, or upload `CODEX_HOME`, user
profiles, authentication files, chat history, cookies, tokens, or payment data.

## Supported versions

Only versions with an exact adapter in `resources/adapters/` are supported.
Unknown versions and changed source anchors must fail closed.

## Reporting

Report a suspected unsafe patch, installer issue, or supply-chain problem by
opening a GitHub security advisory. Do not include credentials or private CLI
state in reports.
