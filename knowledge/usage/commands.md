---
type: Reference
title: Slash Commands
description: Complete /tbfm command reference including trace and offline fake-server demo mode.
tags: [commands, slash, debug, demo]
status: stable
generated: { by: "antigravity/gemini", at: "2026-11-25T14:55:00Z" }
sources:
  - id: forever-lua
    resource: https://github.com/TortoiseBots/TortoiseBotsForeverManager/blob/main/Forever.lua
    title: ForeverCore transport and slash command handler
---

# `/tbfm` Commands

| Command | Behavior |
|---|---|
| `/tbfm` | Open or close the panel. |
| `/tbfm mini` / `full` | Toggle between the compact fight bar and the full window. |
| `/tbfm settings` | Open window options. |
| `/tbfm resetpos` | Recentre the window. |
| `/tbfm trace` | Toggle chat tracing of every sent/received addon message. |
| `/tbfm fake` | Offline demo mode: a fake server responds locally without network traffic.[^forever-lua] |
| `/tbfm status` | Print trace, demo, and transport state. |
| `/tbfm help` | List all slash commands. |

Related: [Supported Tabs and Capabilities](capabilities.md).

[^forever-lua]: ForeverCore transport and slash command handler
