---
type: Reference
title: Supported Tabs and Capabilities
description: Working tabs, capability-driven gating, and targeting rules.
tags: [usage, capabilities, tabs, tbm-protocol]
status: stable
generated: { by: "antigravity/gemini", at: "2026-11-25T14:55:00Z" }
sources:
  - id: forever-lua
    resource: https://github.com/TortoiseBots/TortoiseBotsForeverManager/blob/main/Forever.lua
    title: ForeverCore transport and .tb bridge
  - id: protocol-md
    resource: https://github.com/TortoiseBots/TortoiseBotsForeverManager/blob/main/PROTOCOL.md
    title: TBM 2.4.1 addon protocol
---

# Transport and Capability Gating

Once the server advertises native verbs (`TBM:VERBS`) and capabilities (`TBM:CAPS`), **non-GM players** drive supported panels natively over the `TBM` addon channel, while GM accounts retain `.tb` bridge fallbacks when `tb-gm` is advertised.[^forever-lua][^protocol-md]

| Tab / Panel | Supported Today |
|---|---|
| **Fight** | Attack, Pull, Pullback, Focus (target), End pull, Follow, Stay, Come, Free, Use (target), Spread / party switches (when `behavior` is advertised). |
| **Party** | Bot roles (tank, healer, DPS), Summon, Kick, Log out, Blessings board & per-player exceptions (`blessing`, `blessing-player`). |
| **Bot panel** | Gear & Bags (`inv`, `item equip`/`unequip`/`give`/`trade`), gear readiness dots, the Missing line and the Stats/Model sheet (`armory`), Behaviour toggles (`behavior`), Shaman totems (`totem`), Class choices (`choice`), Mage/Warlock services & portals (`service`), Professions & recipes (`professions`), Auto-gear, Upkeep, Craft orders. |
| **Armory** | Readiness list for the bots you may order (only while the server advertises `armory`): spec and role, hit against the +3 goal, tank defense against the crit cover, role tiles and problem chips, search / This raid / Problems only filters, and a 17-slot equipped strip with quality borders and red dots on gaps. |
| **Loot** | Loot & roll history (`lootlog` / `loot-log`). |
| **Guild & Orders** | Guild orders (Farm, Buy, Craft, Cancel, Active orders; search/enchants/meet/rank remain greyed out). |
| **Camp** | Rest, Repair, Sell, Train, Release, Accept quests, Drop totems (`totem`). |

# Targeting and Unported Controls

- Orders target your selected bot, or the whole party when no party bot is targeted. Attack, Pull, Pullback, Focus, Rest, and Use require a bound party (without a target, Attack and Pull fall back to party orders).
- Unadvertised features (guild roster sync, order search/enchants/meet/rank, dungeon runs, raid tab, formations, tactics, server info) stay greyed out with **Not currently available** and unlock automatically as the server adds them.

Related: [Slash Commands](commands.md), [Port Notes, Protocol, and Tests](../developers/port-and-tests.md).

[^forever-lua]: ForeverCore transport and .tb bridge
[^protocol-md]: TBM 2.4.1 addon protocol
