# Translation Scope

## Translated

- User-visible slash command descriptions
- Approval titles and decision labels
- Stable request-user-input placeholders and confirmation labels
- Stable empty-state text in the slash command popup

## Preserved verbatim

- Slash command names and aliases
- Keyboard shortcuts and decision enums
- Configuration keys and file formats
- JSON, MCP, app-server, and rollout protocols
- Shell commands, paths, host names, and server names
- Model, tool, terminal, Git, and error output
- Authentication and account state
- Hidden debug-only descriptions

## Compatibility rule

Every replacement is tied to an exact upstream version, file, source literal,
and expected occurrence count. A missing or extra occurrence blocks the build.
New upstream versions require a new reviewed adapter.
