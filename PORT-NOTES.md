# Port notes: TortoiseBotsManager 2.4.1 → TortoiseBotsForeverManager

Target: the WoW Forever client (modern Classic API) on a **ForeverCore** server; the interface number is in the `.toc`.
Base: **TortoiseBotsManager v2.4.1** (Sagiroth, MIT), ported to the modern client by waterys419.
Server: **TortoiseBotsForever**, which is still being ported.

## Status in one minute

- The addon loads on the modern client and draws every window.
- The TortoiseBotsForever server does **not** have the addon protocol (`.bot` and the `TBM:` lines) yet.
  It has GM test commands, `.tb <sub>`.
- So the addon runs in **bridge mode**: a few buttons are sent as `.tb` commands, everything else is grey with a
  **Not currently available** tooltip. See "Bridge mode" below.
- When the server starts answering with `TBM:CAPS`, bridge mode switches off by itself and the addon works as it
  does on TortoiseBots.
- Nothing has been tested in the real game client yet; all checks are offline (see "Verified").

## Identity

| Item | 1.12 addon | This port |
|---|---|---|
| Folder / `.toc` | `TortoiseBotsManager` | `TortoiseBotsForeverManager` |
| Interface | `11200` | the WoW Forever client's (see the `.toc`) |
| Window title | TortoiseBots Manager | TortoiseBots Forever Manager |
| Version | `2.4.1` | `2.4.1-forever.2` (`TB.C.VERSION` stays `2.4.1` for the update check) |
| SavedVariables | `TortoiseBotsDB` | unchanged (each client has its own WTF folder, so no clash) |
| Slash commands | `/tbm` | `/tbfm` (with `/tbfm trace`, `/tbfm fake` and `/tbfm status` for the trace and the offline demo) |

## Bridge mode (`Forever.lua`)

While the server has not sent `TBM:CAPS`:

| Addon button | Sent to the server |
|---|---|
| Attack, Pull | `.tb cmd attack <guid>` / `pull <guid>` (your target; `.tb order` without one) |
| Pullback, Focus | `.tb cmd pullback <guid>` / `focus <guid>` (your target) |
| End pull, Follow, Stay, Come, Free, Release | `.tb order <scope> endpull` / `follow` / `stay` / `come` / `free` / `release` |
| Rest | `.tb cmd rest` (needs the party bound to you) |
| Use | `.tb cmd use my` (uses your target; needs the party bound to you) |
| Repair, Sell, Train | `.tb order <scope> repair` / `sell` / `train` (the bot must stand near the right NPC) |
| Accept quests (camp tab) | `.tb quest <bot> accept *` (the offered quest on that bot) |
| Bot role tank / healer / DPS (a bot, or yourself) | `.tb role <bot> tank` / `healer` / `dps`, `.tb role <word>` for yourself |
| Auto-gear (bot panel) | `.bot autogear <bot> [quality\|ilvl]` (typed `.bot` chat, no GM needed) |
| Equip upgrades (bot panel bags) | `.tb gear <bot> upgrade` |
| Maintenance / Upkeep (bot panel) | `.bot maintenance <bot>` (typed `.bot` chat, no GM needed) |
| Tactical orders (Stop, Flee, Guard, Stance, Engage, Rebuff, Interrupt) | `.tb order <scope> stop\|flee\|guard\|stance <word>\|engage [0-60]\|rebuff\|interrupt my` (or `.tb cmd interrupt <guid>`) |
| Party switches (AoE, Auto CC, Sap, Loot) & Corpse run | `.tb cmd aoe\|autocc\|sap\|loot [on\|off\|status]` / `.tb cmd corpserun` (needs TBF PR #205) |
| CC mark pick / clear & Ignore target | `.tb cmd cc <mark> <guid> [<bot>] [family]` / `.tb cmd cc clear [<bot>]` (needs TBF PR #208); `.tb ignore <scope> add\|remove <guid>` |
| Bot stats / Who / Spec / Talents | `.bot stats <bot>` (needs TBF PR #203), `.bot who [all]`, `.tb spec <bot\|party> <tab\|name\|none>`, `.tb talents <bot>` |
| Log out, Kick, Summon | `.tb logout <bot>`, `.tb ungroup <bot>`, `.tb tele <bot> to <you>` |
| Personal craft order (Professions view) | `.tb craftorder create <bot> <item> <amount>` / `cancel <bot>` / `status <bot>` |
| Guild order (Farm, Buy, Craft, Cancel, List) | `.tb guildorder create <bot> <item> <amount> <farm\|buy\|craft>` / `cancel <bot>` / `list` (hours, keep, gold, bring dropped) |

- `<scope>` is the targeted party bot, else `party <you>`.
- The line goes as a **whisper to yourself**: the client blocks addons from sending to `/say`, and the server runs
  a dot command from any chat line before it is delivered. It is sent straight from the click.
- `.tb` commands need a **GM account**. Without one the server refuses and the status line says so.
- Replies (`TortoiseBots: ...`, `order-begin` … `order-end`, `error ...`) are shown in the status line and the Log
  tab; the raw lines and the outgoing whisper are hidden from chat, errors stay visible.
- Every other command is not sent (only a silent addon message to the group, so a server that learns the protocol
  can answer it). Its control is grey with the tooltip; whole tabs without any working command (Roster list,
  Guild, Loot, Dungeon, Raid) show a WIP banner.

### Command catch-up decision table (TBFM #7)

| Server command / feature | Server status | Decision | Panel / Surface | Notes |
|---|---|---|---|---|
| `.tb order`/`.tb cmd` `stop`, `flee`, `guard`, `stance`, `engage`, `rebuff`, `interrupt` (M1/M2) | Merged (`main`) | Button + bridge line (`BridgeTactical.lua`) | Actions Fight cards | `stop`/`guard`/`rebuff`/`interrupt` un-greyed via existing gating; `flee`/`engage`/`stance` bridged |
| `.tb cmd` `aoe`, `autocc`, `sap`, `loot` toggles (M3) | Open PR #205 | Bridge line + state parser (`BridgeToggles.lua`) | BotPanel toggles / Switches card | Needs PR #205 merged; `cmd` / `order status=read` replies update toggle state |
| `.tb cmd corpserun` (M3) | Open PR #205 | Bridge line (`BridgeToggles.lua`) | Actions Death button (`corpse run`) | Needs PR #205 merged |
| `.tb cmd cc <mark> <guid>` / `cc clear` (M4) | Open PR #208 | Bridge line (`BridgeCC.lua`) | Actions CC-mark menu | Needs PR #208 merged; `.tb cc` (allow/deny) Future row stays OFF |
| `.bot who [all]` (R1) | Merged (`main`) | Bridge line + reply parser (`BridgeInfo.lua`) | Roster / Log | Sent as typed `.bot` chat; `roster` auto-poll stays `nil` in bridge mode |
| `.bot add`, `.bot logout` (R2) | Merged (`main`) | Keep `.tb login`/`logout` in bridge; native `.bot` after #130 | Roster lifecycle bar | GM `.tb` path works today; non-GM `.bot` path waits for #130 |
| `.bot follow/stay/attack/flee` (R2) | Merged (`main`) | Nothing new | — | Already covered by `.tb order` equivalents |
| `.bot summon` (R3) | Open PR #203 | Keep `.tb tele` in bridge; native `.bot summon` after #130 | Roster summon | Cooldown-aware reply arrives with #130 |
| `.bot stats <bot>` (R3) | Open PR #203 | Bridge line + reply parser (`BridgeUpkeep.lua`) | BotOverview / Status | Needs PR #203 merged; sent as typed `.bot` chat (no GM needed) |
| `.bot maintenance <bot>` (#213) | Merged (`main`) | Bridge line + reply parser (`BridgeUpkeep.lua`) | BotPanel Upkeep button | Sent as typed `.bot` chat (no GM needed) |
| `.bot autogear <bot> [cap]` (#213) | Merged (`main`) | Bridge line fixed (`Forever.lua` + `BridgeUpkeep.lua`) | BotPanel AutoGear button | Fixed from `.tb gear upgrade` to `.bot autogear`; `d equip upgrades` keeps `.tb gear upgrade` |
| `.autogear [player] <spec> [ilvl]` (#213) | Merged (`main`) | Nothing in bridge (low priority) | — | Real-player self-gear command; typed chat |
| `.tb spec` / `.tb talents` | Merged (`main`) | Bridge line + reply parser (`BridgeInfo.lua`) | BotChoice / Status & Log | `.tb spec <bot\|party> <tab\|name\|none>`, `.tb talents <bot>` |
| `.tb bg status` / `events` (BG1) | Merged (`main`) | Nothing in bridge; BG card post-#130 | — | Behind `TortoiseBots.Bg.Enable=0`; skipped per #7 |
| `.tb ignore add/remove` | Merged (`main`) | Bridge line (`BridgeCC.lua`) | Actions CC menu (future) | Helper + `ignore add/remove` translation ready |
| R4/R5 whisper words (29 + 10) | Merged / PR #211 | Nothing | — | Typed chat by design |
| Auto rolls / pool seed / class kits / demon pick | Merged (`main`) | Nothing | — | Server-only behavior |

## Client API changes

1. **Handlers.** `this`, `event`, `arg1…` are gone: every `SetScript` handler takes `(self, ...)`.
2. **Backdrops.** Frames that use `SetBackdrop` are created with `BackdropTemplate`.
3. **Lua 5.1.** `table.getn` → `#`, `string.gfind` → `string.gmatch`, `math.mod` → `math.fmod`,
   `getglobal` → `_G`.
4. **Addon messages.** `C_ChatInfo` prefix registration and send (`Compat.lua`), retry on throttle;
   `CHAT_MSG_ADDON` read with the modern argument order.
5. **Group size.** `GetNumSubgroupMembers`, `IsInRaid`, `GetNumGroupMembers`.
6. **Bags.** `C_Container` first (`TB.Bag*` in `Compat.lua`).
7. **Power, auras, sound.** `UnitPower`, `C_UnitAuras`, `SOUNDKIT`.
8. **Mail.** `GetSendMailItem(slot)` with the modern return order.
9. **Chat.** The old `ChatFrame_OnEvent` hook became `ChatFrame_AddMessageEventFilter`; chat commands go as a
   whisper to yourself, never `/say`; item links go in with `ChatEdit_InsertLink`.
10. **Lists.** `FauxScrollFrame_OnVerticalScroll(self, offset, rowHeight, update)` (modern 4-argument form).
11. **Items.** `GetItemInfo` read with the modern positions (type 6th, equip slot 9th, texture 10th).
12. **Targeting.** Clicking a party row targets the bot out of combat only (targeting from addon code is protected
    in combat on this client).
13. **Bindings.** `Bindings.xml` entries carry `category="ADDONS"`.

## Offline testing

- `/tbfm trace`: every message sent (`>`) and received (`<`) is printed in chat.
- `/tbfm fake`: a fake server answers locally through the real parsers; nothing leaves the client. The party tab
  stays empty offline because the group comes from the client.
- `/tbfm status`: trace, demo and transport state.

## Verified

All offline, no game client:

| Check | Command |
|---|---|
| Regression suites (upstream suites, bridge, WIP greying, fake server) | `lua5.1 tests/regression.lua .` |
| Every window and tab built, every event handler ran | `sh tests/ui_smoke.sh .` |
| Every `.toc` file compiles in Lua 5.1, no 1.12 API left | `lua5.1 tests/lint.lua .` |
| Screenshots of the bridge-mode look | `TB_FOREVER_PREVIEW=1 sh tools/preview/run.sh <out> <assets>` |

The API choices were checked against addons that already run on this client.

## Still to check in the real client

- That the `.tb` whisper is not blocked and the server runs it (needs a GM account).
- Dropdown menus (`UIDropDownMenu_*`): present on this client, but our menus were never opened in game.
- Mail attach (`ClickSendMailItemButton`, `MailFrameTab_OnClick`, the send-mail edit boxes): not seen in any
  installed addon; the feature refuses and names the missing API if they are gone. Grey in bridge mode anyway.
- Key bindings.

## When the server gets the addon protocol

- The server sends `TBM:TRANSPORT|party` and `TBM:CAPS|...` on `roster`: bridge mode switches off, the normal
  capability gating takes over.
- Then update the README section "What works today" and retest every tab in game.

## Hybrid transport (`ForeverHybrid.lua`, `TBM:VERBS_*`)

- Servers migrating to the native protocol incrementally advertise the exact verbs they answer natively, right
  before `TBM:CAPS|...`: `TBM:VERBS_BEGIN|<n>` (total token count), then `TBM:VERBS|<tok>,<tok>,...` lines, then
  `TBM:VERBS_END`. Each chunk line fits one 255-byte addon message and never splits a token mid-message (the old
  single `TBM:VERBS|...` line was cut mid-token at 255 bytes, hiding half the verbs from routing).
  Tokens are top verbs like `roster`, `add`, `maintenance` or `action:<intent>` like `action:follow`.
- The addon accumulates chunks and commits the set only on `TBM:VERBS_END` when the received count matches the
  `BEGIN` total; a mismatch keeps the previous set. A bare `TBM:VERBS|...` line with no open `BEGIN` still commits
  immediately (old servers).
- Each command routes independently:
  1. **Native** (`.bot` / `TBM` addon channel) when its token is in `VERBS`, or when `TBM:CAPS` arrived without `TBM:VERBS` (old-server fallback).
  2. **Bridge** (`.tb` self-whisper, GM-only) when `Forever.Translate` has a twin and either the handshake has not arrived yet or `TBM:CAPS` includes `tb-gm`.
  3. **Grey** (`Not currently available` tooltip) otherwise.
- Non-GM players: once `TBM:CAPS` arrives without `tb-gm`, bridge-only controls grey out while native controls stay lit.
- Bootstrapping: before `VERBS` arrives, `"roster"` still sends as a silent `PARTY` addon probe so the server can answer with the handshake.
