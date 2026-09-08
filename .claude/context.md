# Deadwire Context

```yaml
project: Deadwire
description: PZ mod — perimeter trip lines and electric fencing for Project Zomboid (B42+)
last_session: 22
last_updated: 2026-09-08
continue_with: "Rob is launching PZ and leaving it on a loaded save. Drive docs/TEST-PLAN.md through the PZ Test Pilot harness yourself. Do not ask him to perform the steps."
blockers: "Nothing is blocked on code. #25 and #12 need the running game Rob is providing; #27 #45 #46 need a decision from him; #13 is a later phase."
```

## To Resume

```
Deadwire v0.1.1, Session 23. Start from origin/main (git pull).

Tree clean, 7 issues open, nothing in flight. Last code change is 062101e.

ROB IS RUNNING THE GAME FOR YOU. He agreed at the end of Session 22 to launch
PZ and leave it sitting on a loaded save so you can drive the test plan through
the harness instead of asking him to perform steps. Do not hand him a checklist.
Ask only for things a person has to do: launch it, enable the mod, alt-tab away,
listen for a sound.

  1. scripts/cmd.py get_status FIRST. `harness_dead` almost always means PZ is
     PAUSED or ALT-TABBED, not crashed -- the poll loop stops when it loses
     focus. Wait and retry before telling him anything is wrong.
  2. Work docs/TEST-PLAN.md in order. Part A is the log check and costs almost
     nothing; Part B is the createWire path, which has never once been watched.
     Stop after B and report before going further.
  3. Read results with `grep '\[Deadwire\]'`, never by reading console.txt.
     Measured: 29 Deadwire lines, 3.5KB, in a real session. The whole file is
     724KB of which none of it is ours.
  4. Sounds and visuals are the two things the harness cannot see. Those are the
     only checks worth asking Rob to eyeball.

IF THE HARNESS WILL NOT COOPERATE, fall back to #47: eight of the mod's
fourteen Lua files execute in no test at all, six of them written in Session 22,
including the whole owner outline. That is the highest-value offline work left
and it needs no game.

Gates:  python scripts/verify_names.py  |  run_tests.bat (PowerShell, not Git
Bash)  |  python tools/validate_pack.py
Plus, unscripted: every mod .lua through `lua -e loadfile`. Part of #47.

Harness: cd c:/xampp/htdocs/pz-test-pilot, then scripts/cmd.py get_status or
run_lua 'code=<lua>'. cmd.py splits on the FIRST '=' only, so Lua full of '='
is safe.
```

## How PZ actually loads and routes mod Lua

Read from bytecode in Session 20. Half of Sessions 20 and 21 only make sense
with these, and every guard written before them was written blind.

0. **In single player, `isServer()` and `isClient()` are BOTH false.**
   `isServer()` is true only on a dedicated server. The guard for "the
   authoritative side" is `if isClient() then return end`, which runs in single
   player and on the dedicated server. Getting this backwards meant no Deadwire
   loot ever spawned in any single-player game, silently, for the mod's whole
   life (Session 18).
1. **A game client runs `shared/`, `client/` AND `server/` Lua.** `GameWindow`
   loads shared and client at boot; `GameLoadingState` loads `server` whenever a
   world loads. `server/` does not mean "server only". It means "loaded last".
2. **A dedicated server runs `shared/` and `server/` only.** `GameServer` calls
   `LoadDirBase("client", true)`, which checksums without executing. No
   `client/` code of ours can ever run there.
3. **`sendServerCommand` does nothing except on a real dedicated server.** Both
   overloads are `if (GameServer.server) ...; return;`. Everything in
   `client/EventHandlers.lua` is dead in single player; the mod works there only
   because both halves share one `tileIndex` in memory.
4. **`sendClientCommand` in single player is asynchronous**, arriving on the
   next net pass, not the same frame.
5. **In multiplayer the server rebuilds the build object from scratch.**
   `BuildAction.parse` reads the class name from the metatable and calls
   `<Type>:new(...)` with values harvested **by parameter name**. Only String,
   Double, Boolean, table, InventoryItem, IsoDirections and IsoDeadBody survive.
   An IsoPlayer argument is silently dropped, which was #32.

Corollary: **`server/` is the wrong place to put a guard.** If a file must not
run on a multiplayer client, write `if isClient() then return end` inside it.

## What is actually verified in a running game (Session 18)

Confirmed in a real 42.20 game: harness IPC, item display names, all 4 kits
spawning, all 4 recipes registered and translated, item and crafting categories
resolving, `SandboxVars.Deadwire` read through `getSandbox`, loot injection at
**11/11 tables, chance 12**, and all 10 sprites as distinct 64x128 textures.

**Everything else is unverified**, including the whole `createWire` path —
Session 18 placed raw `IsoObject`s, never the mod's own `IsoThumpable`.
`docs/TEST-PLAN.md` is the full list of what that leaves and how to check it.

## Sprites

Art is finished. What remains here is only what breaks if you touch it.

**Index hazard:** `pz_tilesheet.py` globs `deadwire_*.png` alphabetically, and
`DeadwireConfig.Sprites` holds those indices by hand. A new sprite that sorts
earlier renumbers everything after it, silently.

```
0/1 bell      2/3 electric (banked for #13, absent from Sprites on purpose)
4/5 reinforced   6/7 tanglefoot   8/9 tincan
```

**Geometry:** both facings are diagonal and mirrored about the vertical axis;
there is no flat-horizontal one. Stakes 18px above the ground line, tanglefoot
6px. `tools/process_sprite_render.py` is the pipeline; its docstring has the
working prompts.

**The `.tiles` file:** `42/media/deadwire_01.tiles` is what the game loads.
There is no `.tiles.txt` any more — the game never opened it, and checking it
proved nothing about the binary beside it. The fifth per-tileset field is the
**tileset number**, bounded 1..512 by `LoadTileDefinitions`; it is NOT the
mod.info tiledef id, whose range is 100..8190. `tools/pz-tilesheet` used to
write the tiledef id there, so a future id above 512 would have made the game
refuse the file and every world sprite vanish with no error. Fixed to write 1.
Our shipped file still says 200, which is legal and loads.

## Name verification: run the script, do not check by hand

```bash
python scripts/verify_names.py          # exit 0 = everything resolves
```

Resolves **308** references against the installed 42.20.4: perks, capabilities,
body parts, `Base.X` items, distribution names, icon PNGs, sprite names, sandbox
options **in both directions**, translation filenames, category and page label
keys, the tiledef id range, event names, sound names, the binary `.tiles`
header, and Java method existence and arity. `scripts/pzclass.py` is the Java
`.class` reader underneath and walks the superclass chain.

`--update-events` regenerates `tests/pz_events.lua`, the allow-list
`tests/stubs.lua` uses to refuse an event name the game does not have. The gate
fails if that committed copy drifts from the jar.

The script proves what exists. The traps live here. DOES NOT EXIST:
`Perks.Foraging` (it is `PlantScavenging`), `Perks.Carpentry` (`Woodwork`),
`Capability.CanBuildAnywhere` (`UseBuildCheat`), the `Climate` global
(`getClimateManager()`), `getRainStrength` (`getRainIntensity`),
`Base.TreeBranch` (`TreeBranch2`), `Events.OnPlayerConnect`, any church
distribution, `sprite:getTextureCount()`, and `getTextOrNull` for recipe display
names. There is **no electrocution system anywhere in the jar.**

**Internal name ≠ displayed name.** `Woodwork` displays as "Carpentry",
`PlantScavenging` as "Foraging".

## B42 Mod Structure (REQUIRED)

`mod.info` at root of the mod AND in `42/`, both must match. `common/` must
exist even if empty. `poster=42/poster.png`. `sandbox-options.txt` in
`42/media/`.

**Translations (42.15+) are JSON with NO `_EN` suffix** — the `EN/` directory
already says the language. `zombie/core/Translator$1` holds a fixed list of base
names; a file outside it is never opened, with no error. verify_names now reads
that list from the jar rather than remembering it. Categories need
`IGUI_ItemCat_X` and `IGUI_CraftingCategories_X` in `IG_UI.json`; the sandbox
page label needs `Sandbox_<page>` in `Sandbox.json`.

## Key Rules

1. **Privacy First**: no PII or credentials in commits
2. **GitHub Issues**: all tasks tracked in Issues
3. **Multiplayer First**: server-authoritative
4. **Test In-Game**: provide clear test steps
5. **Module Base** for all items; namespace tags `deadwire:tagname`
6. **Detection is CLIENT-side**: OnZombieUpdate/OnPlayerUpdate are client events
7. **No guards around unverified API names.** A guard around a typo is
   indistinguishable from a guard around a real fallback. Cost three dead
   features (Session 16) and one invisible fallback sprite (#39).
8. **A missing name logs loudly.** Never substitute a default for it.
9. **A checker must derive, not remember.** Four checkers have now blessed bugs
   by agreeing with a hardcoded value nobody rechecked. A checker that supplies
   whatever it is asked for cannot detect an absence.
10. **`server/` is a load-order directory, not a guard** (see run modes above).
11. **Validate the reported thing, not the reporter.** The trigger gate checked
    how far away the reporting player was, when the question was where the
    zombie is. Re-derive from world state server-side (#31).
12. **Green tests are not evidence.** Put the bug back and confirm they fail.
    Every fix in Sessions 21 and 22 was checked that way, and two of the checks
    that looked fine did not bite until the mutation was made faithful.
13. **Dead code is still somewhere things live.** "Nothing calls it" is a
    complete answer to the wrong question. Deleting the uncalled `PlaceWire`
    handler also deleted the only reader of `WireMaxPerPlayer` and
    `LogWirePlacements`. Before deleting a path, ask what it is the only place
    for. verify_names caught this one; it will not always be there.

## Architecture

Shared (WireNetwork, Config) → Client (Detection, UI, WireActions,
TriggerHandlers, CamoVisibility, EventHandlers) → Server (ServerCommands,
WireManager, BuildActions, LootDistribution, CamoDegradation). Client
`sendClientCommand`, server validates, `sendServerCommand` broadcasts.
`ISBuildingObject:derive()` files MUST live in `server/`. Cooldowns are **real
seconds** (`os.time`), broadcast as a *duration* because clocks are
independently skewed, and declared per wire type with no fallback.

Placement is `ISDeadwireTripLine` only; there is no PlaceWire command. Acting on
a placed wire goes through `luautils.walkAdj` plus `ISDeadwireWireAction`, so
the player is standing next to it when the server's four-tile bound is checked.

## Gates

All local, no CI. `run_tests.bat` **201 pass** (PowerShell, not Git Bash --
`cmd //c` fails on the path, not the tests). `python scripts/verify_names.py`
**308 refs**. `python tools/validate_pack.py` **130 checks**.

A fourth gate is worth running and is not scripted yet: every mod `.lua`
through `lua -e "loadfile"`. Six of the fourteen files are loaded by no test,
so a syntax error in them is invisible until the game refuses the file.

## Open Issues

Seven open. Only #47 can be worked without either the game or a decision.

- **Next session, with the game Rob is providing:** #25 the smoke test, scripted
  in `docs/TEST-PLAN.md`. #12 loot injection is confirmed at 11/11 tables and
  needs one real container sighting to close.
- **Buildable now, no game needed:** #47 eight of fourteen Lua files execute in
  no test. Six were written in Session 22, including the whole owner outline.
  The fallback if the harness will not run.
- **Needs Rob:** #27 Tier 1 balance (bell and reinforced are the same wire with
  a different noise). #45 wire damage, spans and tanglefoot wear. #46 camouflage
  materials, one grass or hay plus one twigs, item names already verified. My
  recommendation is a comment on #27 and #45; #46 is written as Rob decided it.
- **Later phase:** #13 Tier 3. No adjacency graph yet; compute a circuit id per
  tile at place and remove time, never on the zombie tick.

Phase 1 is code-complete. Nothing in it has been watched working.

## Recent sessions

### Session 22 (2026-09-08): the paper work finished, and a test plan

Five issues closed in three commits, and the mod stopped being a thing with
known holes in it. It is now a thing nobody has watched.

**Authority and the way in (de322da).** `PlaceWire` is gone: a server command
that trusted whatever coordinates it was handed, with no proximity check, that
nothing ever called. Deleting it took the per-player wire cap and the placement
log with it, which `verify_names` caught on its own -- two options came back as
declared-but-unread within a minute (now Key Rule 13). Both moved to
`ISDeadwireTripLine:create`, the path the engine actually uses. `CamouflageWire`
gained the owner check it never had, `RemoveWire` gained a distance bound, and
camouflage gained a context menu, which it had never had at all. Both menu
options walk the player to the wire and run a timed action, because a context
menu opens on any tile on screen and the new bound would have refused most
clicks -- which would have been #31 all over again.

**Text and outline (4e84ef2, 062101e).** `maxSpan` and `proneDuration` deleted:
declared per type, read by nothing, and promising spans and prone timers in the
tooltips. 76 orphan label lines gone from `Sandbox.json`, and `verify_names` now
refuses a label with no option as well as an option with no label. The rain
tooltip said "per hour" and the code runs every ten in-game minutes, found while
writing the test plan -- which is worth noting as a method, since prose a person
will act on has to bottom out in the code. `PLAN.md` carries a banner naming
every place it disagrees with the mod. Owner outline (#29) walks every wire now,
coloured per type.

**The tests grew where the risk was.** 187 to 201. `ISDeadwireTripLine` had no
tests at all before this, which is exactly why the moved gates could have gone
missing quietly. Six mutations, all six bit.

### Session 21 (2026-09-06): the review executed, and the checkers made honest

Ten issues closed across three commits. The mod's core feature works again.

**The four that broke it (df281ce).** Trip lines only fired when a player was
already within 3 tiles, because the server checked the *reporter's* distance
rather than where the zombie was; it now re-derives from `getMovingObjects()` on
a 3x3 around the wire. Wire placement failed entirely on a dedicated server
because `new(character, wireType)` put a non-serializable IsoPlayer first.
`Events.OnPlayerConnect` does not exist, so the join sync never ran once —
replaced with a client `OnGameStart` request and a targeted reply. Camouflage
was never written to the save.

**Correctness (0295d6b).** `CamoDegradation` and the wire load were running on
multiplayer clients; the uncamouflage alpha reset moved into
`WireNetwork.setCamouflaged` so it runs in single player at all; tanglefoot
stopped inheriting the 36-second Tier 1 cooldown; Detection stopped leaking one
modData key per tile crossed; `FALLBACK_SPRITE` deleted.

**The checkers (ee2393b).** `verify_names.py` went from 109 references to 271:
event names, sound names, the binary `.tiles`, and Java method existence and
arity. `tests/stubs.lua` no longer invents event names — the allow-list is
generated from the jar. Deleted `deadwire_01.tiles.txt`, which the game never
read and which this checker had been verifying instead of the real file. Fixed
`tools/pz-tilesheet` writing the tiledef id into the tileset-number field.

### Session 20 (2026-09-06): the review

A Fable agent read all 2,136 lines against the installed jar with `javap`, not
inference. Fourteen findings, eleven confirmed, filed as #31 to #43. Report in
`docs/REVIEW-30.md`. Established the five run-mode facts above, and found two of
PLAN.md's own "expected behaviour" lines were fiction.
