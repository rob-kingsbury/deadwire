# Deadwire Context

```yaml
project: Deadwire
description: PZ mod — perimeter trip lines and electric fencing for Project Zomboid (B42+)
last_session: 21
last_updated: 2026-09-06
continue_with: "Loop until the whole mod is believed-correct on paper, then hand Rob a test plan. Two decisions block the last of it: #36 and #38. Everything else is #42, #44, #29."
blockers: "#36 and #38 need Rob, not code. #25 needs someone sitting in a running game; nothing in this mod has ever been watched working."
```

## To Resume

```
Deadwire v0.1.1, Session 22. Start from origin/main (git pull).

Last code change is ee2393b; the handoff commit sits on top of it.
Tree clean, 9 issues open, nothing in flight.

Session 21 executed the whole #30 review except the two decisions. Ten issues
closed: #31 #32 #33 #34 (the mod did not work), #35 #37 #39 #41 (correctness),
#40 #43 (the checkers were lying).

THIS WINDOW, per Rob: keep going until the mod is theoretically correct, then
stop and produce a test plan he can run in-game. Order:

  1. Ask Rob the two decisions FIRST, because they change what gets built:
     - #36 deletes the PlaceWire server handler and its client wrapper. Nothing
       calls them; the real path is the build action, which the engine already
       validates server-side. It also adds owner and distance gates to
       CamouflageWire and RemoveWire.
     - #38 is not a patch. Wire health, maxSpan and proneDuration are declared
       and read by no code, so the sandbox tooltips promise behaviour that does
       not exist. Either the text comes down to what ships, or the behaviour
       gets built.
  2. #42 camouflage has no player-facing entry point at all. Twelve sandbox
     options, CamoVisibility, CamoDegradation, and no way for a player to
     apply it. Needs a context-menu option, and #36 decides its gating.
  3. #44 orphan sandbox labels and uncalled functions. Read the labels before
     deleting; they map what got cut.
  4. #29 owner outline.
  5. THEN write the test plan and stop. #25 is the remainder: sounds, camo
     visibility, camo rain decay, and what happens when a zombie hits a wire.

Do NOT trust a green test suite on its own. Every fix this session was checked
by putting the bug back and confirming the tests failed. Do that.

Gates:  python scripts/verify_names.py  |  run_tests.bat (PowerShell, not Git
Bash)  |  python tools/validate_pack.py

Harness: cd c:/xampp/htdocs/pz-test-pilot, then scripts/cmd.py get_status or
run_lua 'code=<lua>'. cmd.py splits on the FIRST '=' only, so Lua full of '='
is safe. `harness_dead` almost always means PZ is PAUSED or ALT-TABBED, not
crashed; the poll loop stops when it loses focus, so wait and retry first.
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

**Everything else is unverified.** Sounds, camo visibility, camo rain decay,
what happens when a zombie walks into a wire, and the whole `createWire` path —
Session 18 placed raw `IsoObject`s, never the mod's own `IsoThumpable`. MP
cannot be tested in single player at all, which leaves #32's rebuild, #33's join
sync and #34's camo-after-restart untested by anything but reasoning.

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

Resolves **271** references against the installed 42.20.4: perks, capabilities,
body parts, `Base.X` items, distribution names, icon PNGs, sprite names, sandbox
options, translation filenames, category and page label keys, the tiledef id
range, **event names, sound names, the binary `.tiles` header, and Java method
existence and arity**. `scripts/pzclass.py` is the Java `.class` reader
underneath and now walks the superclass chain.

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
    Every fix in Session 21 was checked that way, and two of the checks that
    looked fine did not bite until the mutation was made faithful.

## Architecture

Shared (WireNetwork, Config) → Client (Detection, UI, TriggerHandlers,
CamoVisibility, EventHandlers) → Server (ServerCommands, WireManager,
BuildActions, LootDistribution, CamoDegradation). Client `sendClientCommand`,
server validates, `sendServerCommand` broadcasts. `ISBuildingObject:derive()`
files MUST live in `server/`. Cooldowns are **real seconds** (`os.time`),
broadcast as a *duration* because clocks are independently skewed, and declared
per wire type with no fallback.

## Gates

All local, no CI. `run_tests.bat` **187 pass** (PowerShell, not Git Bash —
`cmd //c` fails on the path, not the tests). `python scripts/verify_names.py`
**271 refs**. `python tools/validate_pack.py` **130 checks**. In-game via PZ
Test Pilot is partially run; see "What is actually verified" above.

## Open Issues

Nine open. Titles come from `gh issue list`; only the order lives here.

- **Needs Rob first:** #36 (deletes a handler), #38 (a decision, not a patch).
- **Then:** #42 camouflage has no player-facing entry point, #44 orphan sandbox
  labels and uncalled functions, #29 owner outline.
- **Needs a running game:** #25 sounds, camo, rain, triggers. #12 loot injection
  confirmed 11/11 and needs one real container sighting to close.
- **Later phases:** #27 Tier 1 balance needs Rob; #13 Tier 3, and there is no
  adjacency graph yet — compute a circuit id per tile at place and remove time,
  never on the zombie tick.

Phase 1 (Tier 0 + Tier 1 + camo + sandbox) is where all current work is.

## Recent sessions

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

Every fix was mutation-checked: the bug put back, the tests confirmed failing.
That caught two tests that looked like they covered a fix and did not. On its
first run the new Java check flagged the checker's own wrong class path for
`Role`, which is the behaviour it exists for.

### Session 20 (2026-09-06): the review

A Fable agent read all 2,136 lines against the installed jar with `javap`, not
inference. Fourteen findings, eleven confirmed, filed as #31 to #43. Report in
`docs/REVIEW-30.md`. Established the five run-mode facts above, and found two of
PLAN.md's own "expected behaviour" lines were fiction.

### Session 19 (2026-09-05/06): all art finished, sounds converted

Ten world sprites and five inventory icons replaced. Rob's bell and tin can
takes arrived as Ogg **Opus stereo**, two silent failures stacked: FMOD does not
decode Opus in an .ogg container, and stereo breaks 3D audio. Now Vorbis mono.
