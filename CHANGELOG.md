# Changelog

All notable changes to TortoiseBotsForeverManager are documented here.

## v1.0.0 (2026-11-24)

### Release & Changelog Automation
- Manual Release action runs tests, bumps the `.toc` version, tags, packs an installable zip, and publishes a GitHub release with merged PR notes. [#10](https://github.com/TortoiseBots/TortoiseBotsForeverManager/pull/10)
- Releases now support patch, minor, major, and custom version bumps; TBFM keeps its own `X.Y.Z` version and drops the old `-forever.N` numbering. [#13](https://github.com/TortoiseBots/TortoiseBotsForeverManager/pull/13)
- Release notes and `CHANGELOG.md` can be AI-generated from merged PRs, with a plain GitHub PR-list fallback when no API key is configured. [#11](https://github.com/TortoiseBots/TortoiseBotsForeverManager/pull/11)
- AI changelog endpoint and model are configurable via repo variables with secret fallback; optional reasoning effort controls model depth. [#12](https://github.com/TortoiseBots/TortoiseBotsForeverManager/pull/12)
- AI changelog wait now extends to five minutes, preventing high-reasoning releases from timing out before commit and tag. [#14](https://github.com/TortoiseBots/TortoiseBotsForeverManager/pull/14)

### Client Compatibility & Stability
- Fixed WoW Forever startup and styling issues from legacy group events, missing backdrops, default button colors, secret health, and header layout so the window and minimap button appear correctly. [#6](https://github.com/TortoiseBots/TortoiseBotsForeverManager/pull/6)
- Queued chat sends now respect combat lockdown, avoiding `ADDON_ACTION_BLOCKED ... UNKNOWN()` from chat fallback and Forever bridge paths during combat. [#9](https://github.com/TortoiseBots/TortoiseBotsForeverManager/pull/9)

### Forever Bridge & Protocol
- Native TBM channel routing sends each command the way the server supports it: native messages for known commands, GM bridge fallback when needed, and greyed “not available yet” buttons otherwise. [#8](https://github.com/TortoiseBots/TortoiseBotsForeverManager/pull/8)

### Orders & Bot Actions
- Equip upgrades, play-as-role, target-aware Rest/Use/Attack/Pull/Pull back/Focus, town errands, and quest accept are wired to newer `.tb` commands. [#4](https://github.com/TortoiseBots/TortoiseBotsForeverManager/pull/4)
- Bridge-mode craft and guild orders now send craft/farm/buy plus cancel/status/list commands, so the order window is no longer greyed out. [#5](https://github.com/TortoiseBots/TortoiseBotsForeverManager/pull/5)

### Commands & Documentation
- Consolidated commands under `/tbfm` for panel, trace, fake, and status; removed `/tbm` and `/tbmf` while keeping `/tb`, `/tbot`, and `/tortoise` aliases. [#1](https://github.com/TortoiseBots/TortoiseBotsForeverManager/pull/1)
- README and docs now target WoW Forever on ForeverCore and drop stale client version/build numbers. [#3](https://github.com/TortoiseBots/TortoiseBotsForeverManager/pull/3)
- README now states the project is an unofficial community project made for educational purposes. [#2](https://github.com/TortoiseBots/TortoiseBotsForeverManager/pull/2)
