# Premonition development

This is a UE4SS Lua mod using Dawnwalker Mod Menu. Keep runtime code in Scripts,
tests in tests, tooling in tools and public documentation in docs. Keep personal
config.ini, builds, archives, logs, dumps and internal reports out of Git.
Use explicit package manifests and preserve existing user settings on installation.
The runtime owns a bottom-center directional attack cue, its native hooks, and its
UMG widgets. Do not claim live gameplay acceptance from offline tests or install state.

Use event-driven settings Apply; no gameplay polling or unnecessary module
dependencies. Read docs/INTEGRATION.md and docs/REPOSITORY-STANDARDS.md. Run the
Lua settings regressions and Python package/guard tests for relevant changes.
Ask before computer control. Coordinate cross-module contracts or deployment
conflicts with COORDINATOR; routine user requests do not need to be relayed.

## Shared release safeguards

Keep diagnostic tooling, collected evidence and log fixtures outside public source
and history. Preserve ordinary regression tests and production runtime code.
Before installation, verify package hashes against source and installed files, close
the game before replacement, and preserve personal settings and enablement. Keep
installation backups outside public source and payload directories. Installed files
are not proof of loaded state; offline tests do not establish native acceptance.
Run staged-file and introduced-history hygiene checks before committing or
publishing. Never bypass a failed guard. Use explicit release manifests and publish
tested packages and checksums as release assets only when requested.
