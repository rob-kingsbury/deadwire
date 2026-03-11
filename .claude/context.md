# Deadwire Context

```yaml
project: Deadwire
description: PZ mod — perimeter trip lines and electric fencing for Project Zomboid (B42+)
last_session: 14
continue_with: "In-game test full chain (Sprints 3+4), then ModOptions UI"

tech:
  stack: pz-lua-mod
  tools: [Lua 5.1 (Kahlua2), Project Zomboid B42.12+, Git, GitHub]

paths:
  mod_root: Contents/mods/Deadwire/42/
  src: Contents/mods/Deadwire/42/media/lua/
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

## B42 Mod Structure (REQUIRED)

PZ B42 requires this exact folder layout for mods to appear in-game:

```
Contents/mods/Deadwire/
  mod.info              ← root mod.info (poster=42/poster.png)
  42/
    mod.info            ← REQUIRED duplicate (PZ won't detect mod without this)
    poster.png
    media/
      sandbox-options.txt
      lua/
        client/
        server/
        shared/
          Translate/EN/
  common/               ← REQUIRED empty dir (standard B42 structure)
```

Both `mod.info` files must exist. The `common/` directory must exist even if empty.

## Key Rules

1. **Privacy First**: No PII or credentials in commits
2. **GitHub Issues**: All tasks, bugs, and features tracked in Issues
3. **Multiplayer First**: Everything server-authoritative
4. **Test In-Game**: Lua mods require in-game testing — provide clear test steps
5. **Module Base**: Use `module Base` for all items (custom modules broken in MP)
6. **Namespace Tags**: Use `deadwire:tagname` format (required since 42.13)
7. **Detection is CLIENT-side**: OnZombieUpdate/OnPlayerUpdate are client events, not server

## Architecture

Three-tier Lua design:
- **Shared**: Core logic, config, wire network hash-table
- **Client**: Detection (OnZombieUpdate), UI, context menus, sound effects, placement
- **Server**: Authoritative state, validation, commands

Communication: Client `sendClientCommand` → Server validates + executes → `sendServerCommand` broadcasts

## Confirmed B42 APIs

| Capability | API |
|---|---|
| Zombie stagger | `zombie:setStaggerBack(true)` |
| Zombie knockdown | `zombie:knockDown(false)` |
| Zombie kill | `zombie:Kill(nil)` |
| Tile entity detection | `OnZombieUpdate` + hash-table lookup |
| Placed objects | `IsoThumpable.new()` |
| Custom buildables | `ISBuildingObject:derive()` |
| World sounds | `getWorldSoundManager():addSound()` |
| Audible sounds | `getSoundManager():PlayWorldSound()` |
| Persistent data | `obj:getModData()` |
| MP commands | `sendClientCommand` / `sendServerCommand` |
| Config | `SandboxVars.Deadwire.*` |
| Loot | `ProceduralDistributions` + `OnPreDistributionMerge` |
| B42 crafting | `craftRecipe` blocks |

## What to AVOID

| System | Problem | Alternative |
|---|---|---|
| Component/wiring system | Not implemented | Legacy generator radius |
| Custom modules | Broken in MP | `module Base` |
| `OnTick` for game logic | 60x/sec perf death | `EveryOneMinute` / `EveryTenMinutes` |
| IsoZombie ref storage | Object pooling recycles | Fresh references per tick |
| `DisplayName` in scripts | Removed in 42.13 | Translation files only |
| Bare tag names | 42.13 requires namespaces | `deadwire:tagname` |
| Missing `42/mod.info` | Mod won't appear in PZ mod list | Duplicate mod.info in both root and `42/` |
| Missing `common/` dir | Non-standard, may break detection | Always include `common/` even if empty |
| `--` comments in sandbox-options.txt | PZ parser may fail silently | No comments in sandbox-options.txt |
| Translation file not named `Sandbox_EN.txt` | Labels show raw keys | Must be exactly `Sandbox_EN.txt` |

## Camouflage System (Ships Phase 1)

- Players camouflage wires with foraged twigs/branches
- Per-client visibility via `setAlphaAndTarget(float)` based on Foraging level
- Scaling detection: Foraging 0-2 invisible, 3-4 faint, 5-6 semi-visible, 7+ clear + outline
- Rain degrades camouflage durability, zombie triggers degrade too
- Step Over / Disarm actions for players who can detect wires
- Owner/faction always see their own wires (configurable)

## Server Customization

Basic: 14 options on 1 page (ships by default)
Advanced: 60 options across 7 pages (swap-in from docs/)

Pages: General, Sound, Trip Lines, Tanglefoot, Camouflage, Multiplayer, Loot

## Phase Plan

| Phase | Content | Status |
|---|---|---|
| Phase 1 (MVP) | Tier 0 + Tier 1 + Camouflage + SandboxVars | Sprint 1-2 PASSED, Sprint 3 code complete + sprites |
| Phase 2 (Pull-Alarms) | Tier 2: mechanical pull-cord alarm system | Not Started |
| Phase 3 (Electric) | Tier 3: electrified perimeter fencing + power | Not Started |
| Phase 4 (Advanced) | Tier 4: modified charger, detonation, electrified barbed | Not Started |

## Sprint Plan (Phase 1)

1. Foundation: WireNetwork hash-table, Detection, ServerCommands, EventHandlers — **DONE (tested in-game)**
2. Placement: ISBuildingObject, context menus, timed actions — **PASSED (tested in-game)**
3. Sound + Trigger: handlers, loot distribution, item/recipe scripts — **CODE COMPLETE + sprites generated, needs in-game test**
4. Camouflage + Config: CamoVisibility, CamoDegradation, all SandboxVars, ModOptions — **CODE COMPLETE (Session 13)**

## Recent Changes

### Session 14 (2026-03-11): Deferred fixes — float safety, loot guard, north orientation
- **WireNetwork.lua**: `tileKey` now floors all 3 coords; `registerTile` floors before storing in entry. Prevents float/int key mismatch if coords arrive as 10.0 vs 10.
- **LootDistribution.lua**: Added `isServer()` guard (MP correctness). Added `ReinforcedTripLineKit` to `MetalFabrication`/`MetalFabricationStorage` distributions (Issue #12 code done; dist names need in-game verification).
- **ClientCommands.lua**: `placeWire` now accepts and forwards `north` param.
- **ServerCommands.lua**: PlaceWire handler passes `args.north` to `createWire`.
- 131/131 tests pass

### Session 13 (2026-03-11): Fix #8, WireNetwork resync, CamoVisibility, CamoDegradation, SandboxVars
- **Fixed #8** (door blocking): removed `RecalcAllWithNeighbours` from `createWire`. Wires pathfinding-transparent.
- **WireNetwork resync**: `OnPlayerConnect` broadcasts `WireNetworkSync` to all clients (idempotent registerTile).
- **CamoVisibility.lua** (new, client/): Foraging-scaled alpha, owner/admin bypass, orange outline at 7+.
- **CamoDegradation.lua** (new, server/): EveryTenMinutes rain-based degradation, storm multiplier.
- **sandbox-options.txt**: added 14 missing options — EnableTier0/1, all Camo* options.

### Session 12 (2026-03-11): Lua programmatic test harness
- Built `tests/` harness: stubs.lua (PZ API mocks), runner.lua, run.lua, run_tests.bat
- 131 tests across Config (37), WireNetwork (45), Detection (15), ServerCommands (20) — all pass
- Confirmed 2 API usages: `os.time()` dedup, `getRole():hasCapability()` admin check

### Session 11 (2026-03-11): 42.15 compat + full audit + bug fixes
- Migrated all 3 translation files to JSON (42.15 breaking change)
- Created Issue #12 (metalfabrication loot)
- Fixed 8 bugs: admin check, kit loss, double sound, stagger API, dedup timestamp, 4 sandbox options, DEBUG flag, dead function

### Session 10 (2026-02-22): pz-tilesheet + sprites + bug fixes
- Built pz-tilesheet Python CLI (V2 .pack + tdef .tiles + .tiles.txt)
- Generated deadwire_01 tilesheet (8 sprites, 512x128, ID 200)
- Fixed #3: dedup flags timestamp-based; Fixed #10: TanglefootKit; Bumped to v0.1.1

### Sessions 1-9: See git log

### Session 8 (2026-02-21): Fix BuildActions load order + audit
- CRITICAL FIX: Moved BuildActions.lua from client/ to server/ (ISBuildingObject is in server/, loads after client/)
- Simplified create() — removed fragile DeadwireWireManager branch, now always calls WireManager directly (file is in server/)
- Fixed UI.lua: removed require for BuildActions (ISDeadwireTripLine is a global available at callback time)
- Fixed UI.lua: changed `context:getNew(context)` to `ISContextMenu:getNew(context)` (vanilla pattern)
- Added `require "Deadwire/WireManager"` to BuildActions.lua (server-side dependency)
- Key learning: PZ load order is shared → client → server. ISBuildingObject:derive() files MUST be in server/

### Session 7 (2026-02-21): Sprint 2 Placement System implemented
- Created WireManager.lua, BuildActions.lua, UI.lua, ClientCommands.lua
- Sprint 2 PASSED; GlobalModData persistence, IsoThumpable placement, right-click menus
