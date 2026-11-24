# Changelog

All notable changes to TortoiseBotsForeverManager are documented here.

## v3.0.0 (2026-11-24)

### Client Compatibility & Stability
- The window and minimap button now actually appear on the WoW Forever client: stale 1.12 group events no longer explode mid-startup and template buttons no longer error out on backdrop styling. [#6](https://github.com/TortoiseBots/TortoiseBotsForeverManager/pull/6)
- Combat no longer trips `ADDON_ACTION_BLOCKED ... UNKNOWN()` on 1.60.1 — queued `.bot` chat lines and the native `.tb` bridge now wait for combat to drop instead of firing into a blocked client. [#9](https://github.com/TortoiseBots/TortoiseBotsForeverManager/pull/9)

### Tactical & Actions
- Auto-gear / Equip upgrades switched on from the bot panel and bags: the bot equips every better item and tells you how many, or that it's already up to date. [#4](https://github.com/TortoiseBots/TortoiseBotsForeverManager/pull/4)
- Rest, Use, Attack, Pull, Pull back and Focus now act on your clicked target — the addon converts the target id into the form the server expects, and Attack/Pull still work targetless as before. [#4](https://github.com/TortoiseBots/TortoiseBotsForeverManager/pull/4)
- Town errands (repair and friends) are live, and role buttons now also work on your own character. [#4](https://github.com/TortoiseBots/TortoiseBotsForeverManager/pull/4)
- Craft orders are no longer greyed out in bridge mode: create from the order window or Professions view and the bot mails you the finished items. [#5](https://github.com/TortoiseBots/TortoiseBotsForeverManager/pull/5)
- Guild orders wired up for craft, farm and buy, plus cancel, status and list — all sent as the matching `.tb guildorder` command. [#5](https://github.com/TortoiseBots/TortoiseBotsForeverManager/pull/5)

### UI & Controls
- One slash command for everything: `/tbfm` opens the panel, with `/tbfm trace`, `/tbfm fake` and `/tbfm status` replacing the old `/tbmf` forms. `/tbm` and `/tbmf` are gone; `/tb`, `/tbot` and `/tortoise` still work. [#1](https://github.com/TortoiseBots/TortoiseBotsForeverManager/pull/1)
- Help text, tooltips and README command tables all show the new command, so you can stop guessing which prefix does what. [#1](https://github.com/TortoiseBots/TortoiseBotsForeverManager/pull/1)
- Header tidied up and button colours fixed — no more default red faces on template buttons. [#6](https://github.com/TortoiseBots/TortoiseBotsForeverManager/pull/6)

### Forever Bridge & Protocol
- The addon now speaks the real native TBM channel, so normal players — not just GMs — get working buttons when the server offers the command. [#8](https://github.com/TortoiseBots/TortoiseBotsForeverManager/pull/8)
- Per-button routing picks the path automatically: native message if the server knows the command, old GM bridge if you're a GM and it doesn't, otherwise a greyed button with a "not available yet" tooltip. Old servers without the command list behave exactly as before. [#8](https://github.com/TortoiseBots/TortoiseBotsForeverManager/pull/8)
- The server now reports your GM status to the addon, and every server command added since batch 10 is caught up. [#8](https://github.com/TortoiseBots/TortoiseBotsForeverManager/pull/8)

### Release Tooling & Automation
- New manual **Release** action in the Actions tab: runs tests, raises the version, tags, packs a ready-to-install zip and publishes the GitHub release. [#10](https://github.com/TortoiseBots/TortoiseBotsForeverManager/pull/10)
- Releases now ask for patch, minor, major or a custom number, and the addon keeps its own `X.Y.Z` version — the `-forever.N` suffix is retired (2.4.1-forever.3 → 2.4.2). The `.toc` and the in-game version stamp stay in sync. [#13](https://github.com/TortoiseBots/TortoiseBotsForeverManager/pull/13)
- Release notes and `CHANGELOG.md` are written by AI from the merged PRs since the last release, and used as the release text. [#11](https://github.com/TortoiseBots/TortoiseBotsForeverManager/pull/11)
- AI changelog endpoint and model now come from repo variables (`OPENCODE_ENDPOINT`, `OPENCODE_MODEL`) with secrets as fallback; `OPENCODE_API_KEY` stays secret and `OPENCODE_REASONING_EFFORT` optionally dials how hard the model thinks. Without a key, releases still ship with GitHub's plain PR list. [#12](https://github.com/TortoiseBots/TortoiseBotsForeverManager/pull/12)
- The AI step gets five minutes instead of sixty seconds, so a high-reasoning model can't stall the release before the version commit and tag. [#14](https://github.com/TortoiseBots/TortoiseBotsForeverManager/pull/14)

### Docs
- README and docs now say the addon targets WoW Forever on ForeverCore, with client version and build numbers dropped so the docs stop going stale. [#3](https://github.com/TortoiseBots/TortoiseBotsForeverManager/pull/3)
- README states the project is an unofficial community project made for educational purposes, alongside the existing non-affiliation note. [#2](https://github.com/TortoiseBots/TortoiseBotsForeverManager/pull/2)
