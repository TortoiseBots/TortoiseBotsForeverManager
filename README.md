<p align="center"><img src="docs/banner.jpg" alt="TortoiseBots Forever Manager"></p>

# TortoiseBotsForeverManager

The in-game control panel (`/tbfm`) for [TortoiseBotsForever](https://github.com/TortoiseBots/TortoiseBotsForever) on
**WoW Forever** (**ForeverCore**). It ports [TortoiseBotsManager](https://github.com/TortoiseBots/TortoiseBotsManager)
to the WoW Forever client, driving supported panels natively over the `TBM` addon channel (`TBM:VERBS` / `TBM:CAPS`)
with `.tb` bridge fallbacks for GM accounts.

> [!WARNING]
> **Work in progress.** Many features are still being ported on the server side; unsupported buttons stay greyed out
> with a **Not currently available** tooltip and unlock automatically as the server advertises each capability.

## Install

1. Download the repository ZIP (**Code → Download ZIP**) or clone it.
2. Extract into `World of Warcraft/_forever_/Interface/AddOns/TortoiseBotsForeverManager` so
   `TortoiseBotsForeverManager.toc` sits at the folder root.
3. Restart the game client fully (not `/reload`) and run `/tbfm`.

## Screenshots

| Fight | Camp |
| :---: | :---: |
| <img src="docs/screenshots/fight.png" width="400" alt="Fight tab"> | <img src="docs/screenshots/camp.png" width="400" alt="Camp tab"> |
| **Party** | **Guild (WIP)** |
| <img src="docs/screenshots/party.png" width="400" alt="Party tab"> | <img src="docs/screenshots/guild.png" width="400" alt="Guild tab"> |

<sub>Rendered offline via `tools/preview` (grey = not available yet).</sub>

## Documentation

| Area | Topics |
|---|---|
| [Usage](knowledge/usage/index.md) | [Supported Tabs & Capabilities](knowledge/usage/capabilities.md), [Slash Commands (`/tbfm`)](knowledge/usage/commands.md) |
| [Developers](knowledge/developers/index.md) | [Port Notes, Protocol & Tests](knowledge/developers/port-and-tests.md) |

Additional references: [`PROTOCOL.md`](PROTOCOL.md), [`PORT-NOTES.md`](PORT-NOTES.md). Bug reports and feature requests
go to [TortoiseBotsForever](https://github.com/TortoiseBots/TortoiseBotsForever).

## Credits & Licence

- TortoiseBotsManager by **Sagiroth** ([`TortoiseBots/TortoiseBotsManager`](https://github.com/TortoiseBots/TortoiseBotsManager)).
- Port to the WoW Forever client by [waterys419](https://github.com/waterys419).

Licensed under the **MIT License** ([`LICENSE`](LICENSE), [`NOTICE`](NOTICE)). Unofficial community project made for
educational purposes; not affiliated with Blizzard Entertainment or the WoW Forever project.
