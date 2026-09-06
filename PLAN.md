# Deadwire Plan

Living plan document. The pz-tilesheet build and the 0.1.0 to 0.1.1 version bump
that used to fill this file are both finished; the `.pack` and `.tiles.txt`
format specs it carried now live in `../pz-tilesheet/README.md`.

---

## Session 21: execute the #30 review findings

The review is done and closed. Fourteen findings, eleven confirmed against the
42.20.4 jar, filed as #31 to #43. The whole report is `docs/REVIEW-30.md` and is
the source of truth for detail; this file is the order to do them in.

### Run-mode facts. Read these before touching any file.

Established during the review by reading bytecode. Several findings only make
sense with them, and none of them were written down anywhere before.

1. **A game client runs `shared/`, `client/` AND `server/` Lua.** `GameWindow`
   loads shared and client at boot; `GameLoadingState` loads `server` whenever a
   world loads, single player or multiplayer. Every `server/` file in this mod,
   including its event registrations, runs on multiplayer clients.
2. **A dedicated server runs `shared/` and `server/` only.** It checksums
   `client/` without executing it. No `client/` code of ours can ever run there.
3. **`sendServerCommand` does nothing except on a real dedicated server.** In
   single player and on multiplayer clients it returns immediately. Everything in
   `client/EventHandlers.lua` is dead in single player; the mod works there only
   because both halves share one `tileIndex` in memory.
4. **`sendClientCommand` in single player is asynchronous**, arriving on the next
   net pass, not the same frame.
5. **In multiplayer the server rebuilds the build object from scratch**, calling
   `<Type>:new(...)` with fields harvested by parameter name. Only String,
   Double, Boolean, table, InventoryItem, IsoDirections and IsoDeadBody survive
   the trip. An IsoPlayer argument is silently dropped.

### Order of work

Fix the four that break the mod first, run the gates, then stop and show Rob
before the scope calls.

**Group 1, the mod does not work.**

1. **#31** `server/ServerCommands.lua` — replace the reporter-distance gate with
   an entity-on-or-beside-the-tile check (3x3, `getMovingObjects`), keep a
   100-tile sanity bound on the reporter. Rewrite the four tests at
   `tests/test_server_commands.lua:429-490` that currently assert the bug.
2. **#32** `server/BuildActions.lua`, `client/UI.lua:35` —
   `new(wireType, character)` with character last and optional.
3. **#33** `server/WireManager.lua`, `server/ServerCommands.lua`,
   `client/EventHandlers.lua` — drop `OnPlayerConnect`; client-only `OnGameStart`
   sends `RequestWireSync`; server replies with the targeted `sendServerCommand`
   overload; the sync handler does the per-wire object lookup.
4. **#34** `server/WireManager.lua`, `shared/WireNetwork.lua` — persist and sync
   `camouflaged` and `camoDurability`; update all three flag-flip sites.

Run `run_tests.bat` (from PowerShell, not Git Bash), `verify_names.py` and
`validate_pack.py`, sync to the mods folder, commit, and report before Group 2.

**Group 2, correctness that does not stop the mod running.**

5. **#35** run-mode guards — `isClient()` early return in `CamoDegradation`,
   guard `WireManager.onInitGlobalModData`, move the alpha and outline reset into
   `WireNetwork.setCamouflaged`, fix the two wrong single-player comments.
6. **#37** explicit `cooldownSeconds` per wire type, drop the `or 36`.
7. **#41** two-key dedup in `Detection`; self-heal object lookup in
   `CamoVisibility`.
8. **#39** delete `FALLBACK_SPRITE`, make `getSprite` log and return nil.

**Group 3, scope calls. Show Rob before doing these.**

9. **#36** deletes the `PlaceWire` handler and its wrapper outright, and adds
   owner and proximity gates to `CamouflageWire` and `RemoveWire`.
10. **#38** is a decision, not a patch: wire health, `maxSpan` and
    `proneDuration` are declared and read by nothing. Either the text comes down
    to what ships, or the behaviour gets built.
11. **#40** and **#43** widen `verify_names.py` and make `tests/stubs.lua` stop
    inventing event names, then delete the dead `.tiles.txt`.
12. **#39**'s orphan sandbox labels and **#42**'s missing camouflage UI.

Finish by writing the five run-mode facts into `.claude/context.md` so the next
session does not re-derive them.

### What actually ships today, corrected

The version of this list in the previous draft of PLAN.md was wrong in two
places, and the review caught it. `maxSpan` and `proneDuration` are read by no
code at all.

**Tin can trip line (tier 0).** Health 50 (`TripLineHealth`), breaks when
triggered (`TinCanBreakOnTrigger`), rattle audible to zombies within 25 tiles at
volume 60. Span is not enforced.

**Reinforced trip line (tier 1).** Health 150 (`ReinforcedHealth`), survives
triggering, 36 real seconds of cooldown, sound radius 40 at volume 80. Span is
not enforced.

**Bell trip line (tier 1).** Same as reinforced but sound radius 60 and a
different clip. No health sandbox option on purpose. Otherwise stat-identical to
reinforced, which is #27, a balance decision Rob owes us and not a bug.

**Tanglefoot (tier 1).** One tile, 40 percent chance to trip, `knockDown(false)`
with vanilla get-up timing. No sound. Health 100 is declared and never reduced.
Currently inherits a 36-second cooldown it should not have (#37).

**Wire health is inert.** `setIsThumpable(false)` removes the zombie-thump path
and nothing else reduces health, so no wire can be destroyed by a zombie despite
the sandbox tooltip saying otherwise (#38).

**Camouflage is unreachable.** No UI calls it (#42).

**Cooldowns are real seconds** via `os.time`, broadcast as a duration rather than
an absolute time because two machines' clocks do not agree.

**Everything authoritative happens server-side.** Client detects and asks, server
validates, server broadcasts, clients play the sound. Three handlers currently
trust the client more than they should (#36).

### What no amount of reading will settle

Sounds being audible and attenuating, camouflage actually hiding a wire, rain
degrading it, and what happens when a zombie walks into a wire. That is the
remainder of #25 and needs someone in a running game with PZ Test Pilot.

Also newly on that list: the whole `createWire` path has never been walked
through, because Session 18 placed raw `IsoObject`s rather than the mod's
`IsoThumpable`. And a wire beside a door may still reproduce #8, because
`ISBuildAction:perform` calls `RecalcAllWithNeighbours(true)` right after
`create()`, which makes the premise of the comment at `WireManager.lua:68-73`
false in single player.

Multiplayer cannot be tested in single player at all: #32's rebuild, #33's join
sync, #34's camo after restart, and whether a client-side `addSound` attracts
server-simulated zombies in B42 MP. If it does not, the server should call
`addSound` itself when it accepts a trigger.
