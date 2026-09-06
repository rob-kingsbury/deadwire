# Deadwire Context

```yaml
project: Deadwire
description: PZ mod — perimeter trip lines and electric fencing for Project Zomboid (B42+)
last_session: 20
last_updated: 2026-09-06
continue_with: "Execute the #30 review findings in the order set out in PLAN.md. Group 1 first: #31, #32, #33, #34. Those four are the ones that stop the mod working."
blockers: "None hard. #38 needs a decision from Rob, not code. Everything in #25 still needs someone willing to sit in-game."

tech:
  stack: pz-lua-mod
  tools: [Lua 5.1 (Kahlua2), Project Zomboid B42.20.4, Git, GitHub]

paths:
  mod_root: Contents/mods/Deadwire/42/
  shared: Contents/mods/Deadwire/42/media/lua/shared/Deadwire/
  client: Contents/mods/Deadwire/42/media/lua/client/Deadwire/
  server: Contents/mods/Deadwire/42/media/lua/server/Deadwire/
  scripts: Contents/mods/Deadwire/42/media/scripts/
  rules: .claude/rules/
  docs: docs/

workflow:
  tracking: GitHub Issues
  phases: 4 (MVP → Pull-Alarms → Electric Fencing → Advanced)
  current_phase: 1
```

## To Resume

```
Deadwire v0.1.1, Session 21. Start from origin/main (git pull).

The #30 code review is done and closed. Fourteen findings, eleven confirmed
against the installed 42.20.4 jar, filed as #31 to #43. The full report is
docs/REVIEW-30.md; the order to do them in is PLAN.md.

THIS WINDOW: execute Group 1 from PLAN.md — #31, #32, #33, #34. Those four
break the mod. Read the five run-mode facts in PLAN.md before touching any
file; three of the four findings only make sense with them.

Do NOT trust the four tests at tests/test_server_commands.lua:429-490. They
assert the #31 bug. Do NOT trust tests/stubs.lua on event names; it invents
any name asked for, which is how #33 passed 159 tests.

THEN: Group 2, then stop and show Rob before Group 3, which contains scope
calls (#36 deletes a handler, #38 is a decision not a patch).

Gates:  python scripts/verify_names.py  |  run_tests.bat (PowerShell, not Git
Bash)  |  python tools/validate_pack.py

Harness: cd c:/xampp/htdocs/pz-test-pilot, then scripts/cmd.py get_status or
run_lua 'code=<lua>'. cmd.py splits on the FIRST '=' only, so Lua full of '='
is safe. `harness_dead` almost always means PZ is PAUSED or ALT-TABBED, not
crashed; the poll loop stops when it loses focus, so wait and retry first.
```

## How PZ actually loads and routes mod Lua (Session 20, read from bytecode)

Nobody in this project had written these down. Half the Session 20 findings only
make sense with them, and every guard in this repo was written without them.

0. **In single player, `isServer()` and `isClient()` are BOTH false.**
   `isServer()` is true only on a dedicated server. The correct guard for "the
   authoritative side" is `if isClient() then return end`, which runs in single
   player and on the dedicated server. Getting this backwards in
   `LootDistribution.lua` meant no Deadwire loot ever spawned in any
   single-player game, for the entire life of the mod, silently (Session 18).
1. **A game client runs `shared/`, `client/` AND `server/` Lua.** `GameWindow`
   loads shared and client at boot; `GameLoadingState` loads `server` whenever a
   world loads, single player or multiplayer alike. So every `server/` file in
   this mod, including its event registrations, runs on multiplayer clients.
   `server/` does not mean "server only". It means "loaded last."
2. **A dedicated server runs `shared/` and `server/` only.** `GameServer` calls
   `LoadDirBase("client", true)`, and that boolean checksums the files without
   executing them. No `client/` code of ours can ever run there.
3. **`sendServerCommand` does nothing except on a real dedicated server.** Both
   Lua overloads are `if (GameServer.server) ...; return;`. In single player and
   on multiplayer clients it returns immediately. The single-player loopback is
   reachable only from `SGlobalObjectNetwork`. Everything in
   `client/EventHandlers.lua` is dead in single player; the mod works there only
   because both halves share one `tileIndex` in memory.
4. **`sendClientCommand` in single player is asynchronous.** It goes through
   `SinglePlayerClient` to a packet to `SinglePlayerServer.addIncoming` to
   `mainLoopDealWithNetData` to `OnClientCommand`, arriving on the next net pass,
   not the same frame. On a dedicated server it throws, which is unreachable for
   us because of fact 2.
5. **In multiplayer the server rebuilds the build object from scratch.**
   `ISBuildAction:perform` returns before `create()`; `zombie.core.BuildAction.parse`
   reads the class name from the metatable `Type` and calls `<Type>:new(...)` with
   values harvested **by parameter name** from the client instance's raw fields.
   Only String, Double, Boolean, table, InventoryItem, IsoDirections and
   IsoDeadBody survive. An IsoPlayer argument is silently dropped, which is #32.

Corollary worth stating on its own: **`server/` is the wrong place to put a
guard.** If a file must not run on a multiplayer client, it needs
`if isClient() then return end` inside it. The directory will not do it for you.

## What is actually verified in a running game (Session 18)

Confirmed in a real 42.20 game, not inferred: the harness IPC round-trip, item
display names, all 4 kits spawning, all 4 recipes registered and translated,
item and crafting categories both resolving, `SandboxVars.Deadwire` populated
and read through `getSandbox`, loot injection at **11/11 tables, chance 12**,
and all 10 sprites as real distinct 64x128 textures.

**Still unverified, the honest remainder of #25:** sounds, camo visibility, camo
rain degradation, and what happens when a zombie walks into a wire. Also the
whole `createWire` path, since Session 18 placed raw `IsoObject`s rather than
the mod's own `IsoThumpable`. MP cannot be tested in single player at all.

## Sprites

Art is finished. What remains here is only what breaks if you touch it.

**Index hazard:** `pz_tilesheet.py` globs `deadwire_*.png` alphabetically, and
`DeadwireConfig.Sprites` holds those indices by hand. A new sprite that sorts
earlier renumbers everything after it, silently. Adding `electric` in Session 18
moved reinforced/tanglefoot/tincan from 2,4,6 to 4,6,8.

```
0/1 bell      2/3 electric (banked for #13, absent from Sprites on purpose)
4/5 reinforced   6/7 tanglefoot   8/9 tincan
```

**Geometry:** in PZ's projection both facings are diagonal and mirrored about
the vertical axis. There is no flat-horizontal orientation. Verified against
vanilla `fencing_01`.

Stake heights: 18px above the ground line for tincan, bell, reinforced and
electric; 6px for tanglefoot.

`tools/process_sprite_render.py` is the whole pipeline and its docstring holds
the working prompts. The pipeline story, the abandoned ComfyUI experiment and
the Session 18 bug write-ups are in `.claude/archive/sessions.md`.

## Name verification: run the script, do not check by hand

```bash
python scripts/verify_names.py          # exit 0 = everything resolves
```

Resolves 109 references against the installed 42.20: perks, capabilities, body
parts, `Base.X` items, distribution names, icon PNGs, sprite names, sandbox
options, translation **filenames**, category and page label keys including the
prefixes themselves, and the `tiledef` id range. `scripts/pzclass.py` is the
Java `.class` reader underneath.

Read declared **fields and methods**, not the raw constant pool. A pool grep
matches any string anywhere in the class, so it passes `Perks.Foraging`.

The script proves what exists. What it cannot tell you is the traps, so those
live here. DOES NOT EXIST: `Perks.Foraging` (it is `PlantScavenging`),
`Perks.Carpentry` (`Woodwork`), `Capability.CanBuildAnywhere` (`UseBuildCheat`),
the `Climate` global (`getClimateManager()`), `getRainStrength`
(`getRainIntensity`), `Base.TreeBranch` (`TreeBranch2`), `Events.OnPlayerConnect`,
any church distribution at all, `sprite:getTextureCount()`, and `getTextOrNull`
for recipe display names, since recipes translate through the UI and a nil there
means nothing. There is **no electrocution system anywhere in the jar.**

**Internal name ≠ displayed name.** `Woodwork` displays as "Carpentry",
`PlantScavenging` as "Foraging".

## B42 Mod Structure (REQUIRED)

`mod.info` at root of the mod AND in `42/`, both must match. `common/` must
exist even if empty. `poster=42/poster.png`. `sandbox-options.txt` in
`42/media/`.

**Translations (42.15+) are JSON with NO `_EN` suffix** — the `EN/` directory
already says the language. `ItemName.json`, `Recipes.json`, `Sandbox.json`,
`IG_UI.json`. `zombie/core/Translator$1` holds a fixed hardcoded list of base
names; a file outside that list is never opened, with no error. Categories need
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
   features (Session 16).
8. **A missing name logs loudly.** LootDistribution warns rather than skipping
   in silence.
9. **A checker must derive, not remember.** Three checkers have now blessed bugs
   by agreeing with a hardcoded value nobody rechecked (Sessions 18 and 20).
   A checker that supplies whatever it is asked for cannot detect an absence:
   `tests/stubs.lua` invented `Events.OnPlayerConnect` for 159 passing tests.
10. **`server/` is a load-order directory, not a guard.** Files in it run on
    multiplayer clients too. If something must not run there, write
    `if isClient() then return end` inside it (Session 20).
11. **Validate the reported thing, not the reporter.** The trigger gate checked
    how far away the reporting player was, when the question was where the
    zombie is. Re-derive from world state server-side (Session 20, #31).

## Architecture

Shared (WireNetwork, Config) → Client (Detection, UI, TriggerHandlers,
CamoVisibility, EventHandlers) → Server (ServerCommands, WireManager,
BuildActions, LootDistribution, CamoDegradation). Client `sendClientCommand`,
server validates, `sendServerCommand` broadcasts. `ISBuildingObject:derive()`
files MUST live in `server/`, because load order is shared then client then
server. Cooldowns are **real seconds** (`os.time`), broadcast as a *duration*
because clocks are independently skewed.

## Gates

All local, no CI configured. `run_tests.bat` 159 pass, but **4 of them assert
bug #31**; run it from PowerShell, since `cmd //c` from Git Bash fails on the
path rather than on the tests. `python scripts/verify_names.py` 109 refs, all
resolve. `python tools/validate_pack.py` 130 checks. In-game via PZ Test Pilot
is partially run, see the section above.

## Open Issues

Titles come from `gh issue list` at session start. What that cannot tell you is
the order, so only the order lives here. Detail in PLAN.md, evidence in
`docs/REVIEW-30.md`.

- **Group 1, the mod does not work:** #31, #32, #33, #34.
- **Group 2, correctness:** #35, #37, #41, #39.
- **Group 3, needs Rob first:** #36 (deletes a handler), #38 (a decision, not a
  patch), #40, #42, #43.
Phase 1 (Tier 0 + Tier 1 + camo + sandbox) is where all current work is. Phase 2
pull-alarms and Phase 4 advanced are not started; Phase 3 electric is #13.

- **Older:** #29 mostly built inside CamoVisibility; #25 sounds/camo/rain/
  triggers; #27 Tier 1 balance, needs Rob; #13 Tier 3, and there is no adjacency
  graph yet, see the review comment on it; #12 loot injection confirmed 11/11
  and needs one real container sighting to close.

## Recent sessions

### Session 20 (2026-09-06): the review, and the mod's core feature does not work

A single Fable agent read all 2,136 lines against the installed 42.20.4 jar,
using `javap` on the bytecode rather than inference. Fourteen findings, eleven
confirmed, filed as #31 to #43. Report in `docs/REVIEW-30.md`.

**Trip lines only fire when a player is already within 3 tiles of the wire.**
`ServerCommands.lua:195` checks the distance of the player *reporting* the
trigger, but the reporter is whichever client saw the zombie, and the zombie can
be anywhere loaded. A wire tripped 10 tiles away rattles locally and is then
silently dropped: no break, no cooldown, no camo degrade, re-firing every
second. Broken since Session 17 while closing #15, and **four tests at
`tests/test_server_commands.lua:429-490` assert the broken behaviour.**

Three more that stop it working: placement fails entirely on a dedicated server
(#32), `Events.OnPlayerConnect` does not exist so it throws at load every
session and join-sync never fires (#33), and camouflage is never written to the
save (#34). Camouflage also turns out to have no player-facing entry point at
all (#42).

`tests/stubs.lua` invents any event name asked for, which is why 159 tests
passed over #33. Third blind checker after Session 18's two, so it is now a
rule: **a checker that supplies what it is asked for cannot detect an absence.**

Two of PLAN.md's own "expected behaviour" lines were fiction. `maxSpan` and
`proneDuration` are read by no code. I wrote that spec from Config fields
without checking they had readers, which is the same mistake as trusting a
checker.

Built `.claude/hooks/context-prune.cjs`, a Stop hook that counts this file
rather than asking whether it is too long, on the pattern of Sembr's
handoff-staleness blocker. Also cleaned the repo root and closed #26 and #28.

### Session 18 (2026-08-06): first in-game run, three bugs, two blind checkers

The mod ran in a real game for the first time. Item names, recipes, categories,
sandbox options, kit spawning and all 10 sprites confirmed working.

Fixed the `isServer()` guard that had disabled single-player loot forever,
`IGUI_CraftCategory_` to `IGUI_CraftingCategories_`, and fully opaque inventory
icons. Both checkers were found blessing hardcoded values and now derive them.
Full write-up in `.claude/archive/sessions.md`.

Ten inert test `IsoObject`s were left in a throwaway world at x=1914-1922,
y=14379/14381. Harmless unless that save is reused.

### Session 19 (2026-09-05/06): all art finished, sounds converted

Ten world sprites and five inventory icons replaced; stake heights normalised.

Rob's new bell and tin can takes arrived as Ogg **Opus stereo**, two silent
failures stacked: FMOD does not decode Opus in an .ogg container, and stereo
breaks 3D positional audio. Converted to Vorbis mono 44.1k. An electric zap is
banked for #13.

Confirmed the jar had moved to 42.20.4 three weeks after the name checker was
written, and all 109 references still resolve. Also dismissed a suspicion about
`distanceMin`: our sound scripts declare none, and neither does vanilla, in 0 of
the 69 files that use `distanceMax`.

