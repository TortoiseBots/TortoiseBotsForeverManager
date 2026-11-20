# Port notes: TortoiseBotsManager 2.4.1 → TortoiseBotsForeverManager

Target client: **WoW Forever 1.60.1** (`## Interface: 16001`, modern Classic API).
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
| Interface | `11200` | `16001` |
| Window title | TortoiseBots Manager | TortoiseBots Forever Manager |
| Version | `2.4.1` | `2.4.1-forever.1` (`TB.C.VERSION` stays `2.4.1` for the update check) |
| SavedVariables | `TortoiseBotsDB` | unchanged (each client has its own WTF folder, so no clash) |
| Slash commands | `/tbm` | `/tbm`, plus `/tbmf` for trace and the offline demo |

## Bridge mode (`Forever.lua`)

While the server has not sent `TBM:CAPS`:

| Addon button | Sent to the server |
|---|---|
| Attack, Pull | `.tb order <scope> attack my` / `pull my` (the pull timer is dropped) |
| End pull, Follow, Stay, Come, Free, Release | `.tb order <scope> endpull` / `follow` / `stay` / `come` / `free` / `release` |
| Bot role tank / healer / DPS | `.tb role <bot> tank` / `healer` / `dps` |
| Log out, Kick, Summon | `.tb logout <bot>`, `.tb ungroup <bot>`, `.tb tele <bot> to <you>` |

- `<scope>` is the targeted party bot, else `party <you>`.
- The line goes as a **whisper to yourself**: client 70707 blocks addons from sending to `/say`, and the server runs
  a dot command from any chat line before it is delivered. It is sent straight from the click.
- `.tb` commands need a **GM account**. Without one the server refuses and the status line says so.
- Replies (`TortoiseBots: ...`, `order-begin` … `order-end`, `error ...`) are shown in the status line and the Log
  tab; the raw lines and the outgoing whisper are hidden from chat, errors stay visible.
- Every other command is not sent (only a silent addon message to the group, so a server that learns the protocol
  can answer it). Its control is grey with the tooltip; whole tabs without any working command (Roster list,
  Guild, Loot, Dungeon, Raid) show a WIP banner.

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

- `/tbmf on` / `off`: every message sent (`>`) and received (`<`) is printed in chat.
- `/tbmf fake`: a fake server answers locally through the real parsers; nothing leaves the client. The party tab
  stays empty offline because the group comes from the client.
- `/tbmf status`: trace, demo and transport state.

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
