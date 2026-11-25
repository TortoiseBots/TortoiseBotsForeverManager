---
type: Playbook
title: Port Notes, Protocol, and Tests
description: Protocol reference, modern client port notes, Forever.lua bridge, and test suite.
tags: [developers, protocol, tests, port]
status: stable
generated: { by: "antigravity/gemini", at: "2026-11-25T14:55:00Z" }
sources:
  - id: protocol-md
    resource: https://github.com/TortoiseBots/TortoiseBotsForeverManager/blob/main/PROTOCOL.md
    title: Addon-server protocol specification
  - id: port-notes
    resource: https://github.com/TortoiseBots/TortoiseBotsForeverManager/blob/main/PORT-NOTES.md
    title: Modern client API port notes
---

# Key Developer Files

- `PROTOCOL.md` — Addon <-> server protocol matching TortoiseBotsManager 2.4.1.[^protocol-md]
- `PORT-NOTES.md` — Changes for the modern WoW Forever client API and remaining in-game checks.[^port-notes]
- `Forever.lua` — Transport and `.tb` GM command bridge while full native protocol verbs are being ported.

# Tests

```bash
lua5.1 tests/regression.lua .
lua5.1 tests/lint.lua .
sh tests/ui_smoke.sh .
```

Related: [Supported Tabs and Capabilities](../usage/capabilities.md), [Slash Commands](../usage/commands.md).

[^protocol-md]: Addon-server protocol specification
[^port-notes]: Modern client API port notes
