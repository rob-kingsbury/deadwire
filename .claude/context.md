# Deadwire Context

```yaml
project: Deadwire
description: PZ mod — perimeter trip lines and electric fencing for Project Zomboid (B42+)
last_session: 25
last_updated: 2026-09-08
continue_with: "Next in-game session: the tin can audio check (#49 -- ask him plainly whether he HEARS it) and Parts C-G of docs/TEST-PLAN.md (#25). #13 and #52 are unblocked now (see below) but are design/build work, not probes -- no game needed to start on them."
blockers: "#27 and #45 need a decision from Rob. #48 and #51 are art, batch them. tin_can_rattle.ogg needs a mastering pass, not another gain boost."
```

## To Resume

```
Deadwire v0.1.1, Session 26. Start from origin/main. Tree clean, 11 issues open.

Session 25 answered all four Tier 3 unknowns (#54, closed) -- results on #54,
#13, #52. #13 and #52 are unblocked and can start any time, no game needed.

NEXT IN-GAME SESSION (not urgent): tin can audio check (#49 -- ask Rob plainly
whether he HEARS it) and Parts C-G of docs/TEST-PLAN.md (#25).

TALK TO ROB IN PLAIN WORDS, no issue numbers, no labels only we understand.

HARNESS: cd c:/xampp/htdocs/pz-test-pilot, scripts/cmd.py get_status.
loadstring is off so run_lua always throws. cmd.py can't pass a real JSON
array through args=; call _ipc.send_command from a short Python script for a
list. teleportTo(x,y,z) is a real, verified IsoGameCharacter method -- the old
"teleport is broken" note was about a different, nonexistent one.

`deadwire_probe_setup` (pz-test-pilot) teleports to a fixed outdoor site
(8504,9414,0) and builds a real activated generator + StickFence in two steps
(step=teleport, step=build) -- reuse it rather than hand-building a base. A
generator left running for days burns its tank dry; remove_object + rebuild
before trusting a power reading, and advance_time past ElecShutModifier
BEFORE building, not after.
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
6px. `tools/process_sprite_render.py` is the pipeline, prompts in its docstring.

**The `.tiles` file:** `42/media/deadwire_01.tiles` is what the game loads;
there is no `.tiles.txt` any more, the game never opened it. The fifth
per-tileset field is the **tileset number**, bounded 1..512 by
`LoadTileDefinitions`, NOT the mod.info tiledef id whose range is 100..8190.
`tools/pz-tilesheet` used to write the tiledef id there, so a future id above
512 would have made the game refuse the file and every world sprite vanish with
no error. Fixed to write 1; our shipped file says 200, legal and loads.

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

Eleven open. #54 closed in Session 25 -- its results live as comments on #54,
#13 and #52 rather than repeated here.

- **Next, in game:** #49 the tin can audio check, #25 Parts C-G of the test
  plan, #12 one real container sighting.
- **Ready to build, no game needed to start:** #13 electrified deadwire and
  #52 electrified fence -- both were blocked on Tier 3 probes, both answered.
  #53 circuit adjacency, the one genuinely new piece of code Tier 3 needs.
  #46 camouflage materials, already decided as Rob wanted it, just needs
  building.
- **Needs a decision from Rob:** #27 bell and reinforced are the same wire with
  a different noise. #45 wire damage, spans, tanglefoot wear.
- **Art, batch them:** #48 outline box sized to engine bounds not sprite art,
  #51 wire draws in front of the character, tin_can_rattle.ogg needs mastering.

## Recent sessions

### Session 25 (2026-09-08): four unknowns answered, and two false readings caught before they shipped

All four Tier 3 probes from #54 run live -- full results on #54, #13, #52.

**`deadwire_probe_setup` builds a real generator and real fence from Lua**,
no hand-built base needed: the generator via vanilla's own
`MOGenerator.lua` construction path, the fence via `ISBuildIsoEntity` with
build cheat flipped on, the same path the F2 debug entity panel uses. Two
bugs before it worked, both needing a relaunch to catch since the fix lives
in code loaded at process boot: `setInfo()` reads `self.player`, unset
outside the normal drag-to-place flow, threw deep in perk-level lookup; and
the fence's `nSprite=1` (west layout) disagreed with a hardcoded `north=true`
passed to `create()`, which would have built the fence with its collision on
the wrong edge -- exactly what the vault probe measures.

**Two false power-radius readings before the real one.** Day 1's city grid
was still live, so `haveElectricity()` read true everywhere regardless of the
generator -- looked like a huge radius, meant nothing. Jumped the clock past
`ElecShutModifier` (instant, no real-time cost) to kill grid power, which
surfaced a second false reading: the generator, "on" for the whole jump, had
burned its tank dry and read unpowered everywhere including its own square.
Neither was a probe bug, both were artifacts of skipping simulated time
instead of living through it. Rebuilt the generator fresh post-jump; real
reading was 40 tiles, not the Generator Range mod's hardcoded 20. Repeated on
a second save after Rob's first corrupted -- same trap, same fix, so it's the
process, not the save.

**No registered handler could spawn a zombie**, and `SendCommandToServer`
routed through `call_function` ran with no error and no effect either --
fire-and-forget gives no way to tell permissions gate from silent parse
failure. What worked: right-click ground with `-debug` running gives a real
Debug > Add Zombie option, a real player action instead of a scripted one.

**One cosmetic casualty left alone:** right-clicking the directly-built
generator throws a stack error, some field a normal placement wires up that
`IsoGenerator.new` alone doesn't. Throwaway test code, not the mod.

### Session 24 (2026-09-08): eight dark files lit, and Tier 3 designed

Three commits here plus one in pz-test-pilot, and the mod stopped carrying code
nobody had ever executed.

**All fourteen files now load in the suite (e436ee6, #47).** Eight ran in no
test at all. `run_tests.bat` compiles every mod `.lua` first, then runs the
suite; 201 tests became 330 across seven new files. Twenty mutations, all
caught. The real find was in the suite itself: `test_detection.lua` nils handler
entries per test and never restored them, so once TriggerHandlers loaded, every
file after it silently ran against zero registered handlers.

**A destroyed wire leaves its parts (1fb8faf, #50).** One roll per wire over its
durable parts; a wire taken up by hand returns the whole kit with no roll. Cord
is never salvaged, which dissolved the design knot -- the recipes accept any of
three cords, the kit records none, and the cord is what snapped. 330 to 346.
Mutation testing caught two stubs that had blessed real bugs: `ZombRand`
answered the same number forever, hiding one-roll-per-part, and accepted a
bound below 1, hiding a range computed backwards.

**Tier 3 designed and split (#13, #52, #53, #54).** Rob's framing: a farmer and
a survivalist are different people. A pasture fence is meant to be seen, since
visibility is the deterrent; an electrified deadwire is meant not to be. Two
API claims in the old #13 body were wrong and would each have cost a session --
`isGeneratorPoweringSquare()` is on `IsoChunk`, not `IsoGridSquare`, and
`setGeneratorRange` takes zero arguments. The power model is one
`square:haveElectricity()` call on the energiser's square, which is
radius-agnostic and so satisfied by any power mod energising a square the
vanilla way. `GeneratorNetwork_42` in Rob's own mods folder does exactly that,
so the compatibility claim has a working example rather than a hope.

**pz-test-pilot pushed (cb03c49).** Session 23's smoke handlers had sat
uncommitted for a session. Four `deadwire_probe_*` handlers added for #54.
Corrected that repo's CLAUDE.md, which claimed `loadstring()` works; it does
not, and that sentence sent Session 23 down a blind alley.

Session 23's write-up (watched `createWire` run live for the first time,
filed #48-#51) is in `.claude/archive/sessions.md`.
