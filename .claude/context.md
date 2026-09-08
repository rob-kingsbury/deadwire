# Deadwire Context

```yaml
project: Deadwire
description: PZ mod — perimeter trip lines and electric fencing for Project Zomboid (B42+)
last_session: 24
last_updated: 2026-09-08
continue_with: "Push e436ee6, which closes #47. Then #50 (remnant item on single-use wire destroy), offline but blocked on one design decision from Rob. #49's audio fix needs Rob to relaunch and confirm before it can be called done."
blockers: "#50 #27 #45 #46 need a decision from Rob. #25 needs another game session for Parts C-G (D-G untouched, C mostly untouched). #51 needs the sprite/tiles pipeline touched, which is art work, not Lua. #48 is a real engine limitation (setOutlineHighlight on an irregular sprite), not a quick fix."
```

## To Resume

```
Deadwire v0.1.1, Session 25. Start from origin/main.

Session 24 closed #47. All fourteen mod .lua files now load in the suite,
run_tests.bat compiles all fourteen before running it, and 330 tests pass
(was 201). Commit e436ee6 is LOCAL AND UNPUSHED -- pushing it auto-closes #47.

NEXT, NO GAME NEEDED: #50. A destroyed single-use wire leaves nothing on the
tile, which Rob read as a bug rather than a mechanic. Blocked on one decision:
what item drops, scrap or the tin can minus its wire. Ask him, do not guess --
this is a design call, not an API lookup.

NEEDS ROB IN THE GAME: #49's audio fix is unverified. bell_ring.ogg and
wire_rattle.ogg were gain-boosted (+4dB, +10dB) after PZ had already loaded
them, so nothing has confirmed the new bytes were picked up; it needs a
relaunch and a walk over a wire. tin_can_rattle.ogg is UNCHANGED and already at
its 0dB ceiling -- getting it louder needs a mastering pass, not a gain knob,
so batch it with other art work. Parts C to G of docs/TEST-PLAN.md are unrun;
Session 23 ran A and B only, on purpose.

HARNESS (cd c:/xampp/htdocs/pz-test-pilot, then scripts/cmd.py get_status):
loadstring is off on this build so run_lua always throws -- use the registered
deadwire_smoke_a / deadwire_smoke_b instead. cmd.py cannot pass a real JSON
array through args=; call _ipc.send_command from a short Python script for a
list. teleport is broken (no setLx/setLy/setLz on IsoPlayer); walk the player.
Any NEW handler needs a full PZ relaunch, not a reloaded save. Session 23's two
smoke handlers live in pz-test-pilot and are still uncommitted there.
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

## What is actually verified in a running game

Session 18, in a real 42.20 game: harness IPC, item display names, all 4 kits
spawning, all 4 recipes registered and translated, item and crafting categories
resolving, `SandboxVars.Deadwire` via `getSandbox`, loot injection at **11/11
tables, chance 12**, and all 10 sprites as distinct 64x128 textures. Session 23
added Parts A and B of `docs/TEST-PLAN.md`, 24/24, including `createWire`'s real
path. Parts C to G are still unrun and are the list of what that leaves.

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
body parts, `Base.X` items, distributions, icon PNGs, sprite names, sandbox
options **in both directions**, translation filenames, category and page label
keys, the tiledef id range, event and sound names, the binary `.tiles` header,
and Java method existence and arity. `scripts/pzclass.py` is the `.class` reader
underneath and walks the superclass chain.

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

All local, no CI. `run_tests.bat` compiles **all 14** mod `.lua` files
(`tests/syntax_check.lua`) and stops there on failure, then runs the suite,
**330 pass**. PowerShell, not Git Bash -- `cmd //c` fails on the path, not the
tests. `python scripts/verify_names.py` **308 refs**. `python
tools/validate_pack.py` **130 checks**.

The syntax gate enumerates the tree rather than carrying a file list, and
finding zero files is a failure, not a pass. It compiles without executing, so
a file-scope call that throws at runtime gets past it; requiring all fourteen
in `tests/run.lua` is what catches that.

## Open Issues

Ten open. #47 closed in Session 24; all fourteen mod files now load and run in
the suite.

- **No game needed:** #50 destroyed single-use wires leave no remnant -- needs
  a decision on what item, not an API lookup.
- **With the game:** #25 smoke test (A and B done Session 23, C-G open). #12
  loot injection confirmed at 11/11 tables, needs one real container sighting.
  #49 the tin can trigger sound was too quiet; two of three assets gain-boosted,
  the boost itself unverified in a running game.
- **Needs a decision from Rob:** #27 Tier 1 balance (bell and reinforced are the
  same wire with a different noise). #45 wire damage, spans and tanglefoot wear.
  #46 camouflage materials, item names already verified. My recommendation is a
  comment on #27 and #45; #46 is written as Rob decided it.
- **Art/audio, not Lua:** #48 the outline box is sized to the object's engine
  bounds, not the sprite art, a real setOutlineHighlight limitation. #51 the
  wire sprite draws in front of the character, needs the tiles pipeline.
  tin_can_rattle.ogg needs a mastering pass, already at its gain ceiling.
- **Later phase:** #13 Tier 3. No adjacency graph yet; compute a circuit id per
  tile at place and remove time, never on the zombie tick.

## Recent sessions

### Session 23 (2026-09-08): watched it work, for the first time

Parts A and B of `docs/TEST-PLAN.md` run live against a real 42.20.4 game,
24/24 checks pass. `createWire`'s actual path watched for the first time --
Session 18 only ever placed raw `IsoObject`s standing in for it.

**The harness had no loadstring.** `run_lua` throws "loadstring unavailable"
on this build, contradicting pz-test-pilot's own CLAUDE.md, which claims it
works -- that repo's note is stale. Worked around it by adding two registered
command handlers (`deadwire_smoke_a`/`deadwire_smoke_b`) directly to the
harness mod rather than sending code over the wire, since `call_function`
cannot pass live objects (player, grid squares) across the JSON boundary
either. Cost one full relaunch to register -- Init.lua's requires run once at
process boot, a reloaded save does not re-run them.

**What that proved.** All 8 mod-load log lines, all 10 Deadwire globals, loot
still injected into `FarmerTools`/`MetalShopTools` after Session 22's changes,
`ISDeadwireTripLine:create` placing a real `IsoThumpable` with the right
sprite for all four wire types, exactly one kit consumed per placement, the
canPassThrough/blockAllTheSquare/isThumpable flags all correct, a door beside
a wire still opens (#8 holds), the context menu correctly gates on carried
kits, and the save/reload round trip (`loadAll` + `reconnectSquare`) rebuilding
all four wires with world objects relinked.

**What Rob found live that no script would have caught.** The owner-outline
box is sized to the object's engine bounds, not the sprite art (#48) --
visible only by looking at it. Tin can's single-use trigger fired correctly
when Rob walked over it by accident (confirming part of Part C nobody meant to
test yet), but the alert sound was so quiet it defeats the wire's entire
purpose (#49). Measured all three sound assets with ffmpeg: `bell_ring.ogg`
and `wire_rattle.ogg` had real unused headroom and got gain-boosted (+4dB,
+10dB, mono preserved, no clipping); `tin_can_rattle.ogg` was already at its
0dB ceiling, so it needs a mastering pass, not a gain knob. A destroyed
single-use wire leaves nothing behind, which reads as a bug rather than a
mechanic (#50). The wire sprite draws in front of the character model, a
tiles/sprite anchor problem with no Lua-side cause (#51).

**Four issues filed, one commented with full results (#25).** Ends with 11
open, tree clean except the two boosted `.ogg` files.

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
