# Deadwire Context

```yaml
project: Deadwire
description: PZ mod — perimeter trip lines and electric fencing for Project Zomboid (B42+)
last_session: 7
continue_with: "Sprint 2: In-game test of placement system"

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
| Phase 1 (MVP) | Tier 0 + Tier 1 + Camouflage + SandboxVars | Sprint 1 PASSED, Sprint 2 next |
| Phase 2 (Pull-Alarms) | Tier 2: mechanical pull-cord alarm system | Not Started |
| Phase 3 (Electric) | Tier 3: electrified perimeter fencing + power | Not Started |
| Phase 4 (Advanced) | Tier 4: modified charger, detonation, electrified barbed | Not Started |

## Sprint Plan (Phase 1)

1. Foundation: WireNetwork hash-table, Detection, ServerCommands, EventHandlers — **DONE (tested in-game)**
2. Placement: ISBuildingObject, context menus, timed actions — **DONE (needs in-game test)**
3. Sound + Trigger: handlers, loot distribution, item/recipe scripts
4. Camouflage + Config: CamoVisibility, CamoDegradation, all SandboxVars, ModOptions

## Recent Changes

### Session 7 (2026-02-21): Sprint 2 Placement System implemented
- Created WireManager.lua: server-side wire lifecycle, IsoThumpable creation/destruction, GlobalModData persistence, save/load, chunk reconnect
- Created BuildActions.lua: ISBuildingObject derivative for wire placement (ISDeadwireTripLine)
- Created UI.lua: right-click context menu for placement (submenu with all tier 0/1 types) and removal (owner/admin)
- Created ClientCommands.lua: sendClientCommand wrappers
- Updated ServerCommands.lua: PlaceWire, RemoveWire, DebugPlaceWire all use WireManager (real IsoThumpable + persistence)
- Updated EventHandlers.lua: WirePlaced handler caches IsoObject ref for camo visibility
- Fixes #1 (WireNetwork persistence) and #4 (nextNetworkId persistence) via WireManager.loadAll
- Sprint 2 note: no material cost (free placement), vanilla barbed wire placeholder sprite

### Session 6 (2026-02-21): Fix mod structure, in-game test, Sprint 1 PASSED
- CRITICAL FIX: Mod was invisible in PZ mod list — missing `42/mod.info`
- Added `42/mod.info` (required duplicate of root mod.info)
- Added `common/` directory (standard B42 mod structure)
- Fixed `poster=poster.png` → `poster=42/poster.png` in root mod.info
- Documented B42 mod structure requirement in context.md
- Removed `--` comments from sandbox-options.txt (PZ parser may choke on them)
- Renamed `Sandbox_Deadwire_EN.txt` → `Sandbox_EN.txt` (PZ naming convention)
- **IN-GAME TEST PASSED**: All 5 Sprint 1 tests pass
  - Mod loads (3/3 init messages)
  - Debug wire registers at player tile
  - Zombie detection fires on wire tile
  - Player detection fires on wire tile
  - De-duplication prevents re-trigger on same entity
- Known minor: sandbox option labels show translation keys (fix confirmed, needs new save to verify)

### Session 5 (2026-02-20): Sprite Checklist + Handoff
- Created `docs/SPRITES.md`: comprehensive sprite checklist for all 4 phases (40 sprites total)
- Confirmed `Base.Bell` is vanilla — no custom bell item needed, Phase 1 needs zero new inventory items
- Note: Implementation plan recipes still reference `Base.Deadwire_Bell` — update to `Base.Bell` when writing Sprint 3

### Session 4 (2026-02-20): Audit + Fixes + Sandbox Options
- Full code audit: 3 critical, 4 moderate issues found and fixed
- CRITICAL FIX: Moved Detection.lua from server/ to client/ (OnZombieUpdate is client event)
- CRITICAL FIX: Made WireNetwork.registerTile idempotent (MP duplicate prevention)
- CRITICAL FIX: Fixed CamoEnabled → EnableCamouflage key mismatch in ServerCommands.lua
- DRY: Extracted `hasPosition()` helper in ServerCommands.lua and EventHandlers.lua
- DRY: Extracted `getSquareFromArgs()` helper in EventHandlers.lua
- DRY: Unified zombie/player detection into single `detectEntity()` function
- Created basic sandbox-options.txt (14 options, 1 page)
- Created advanced sandbox-options (60 options, 7 pages) in docs/
- Created translation file Sandbox_Deadwire_EN.txt with descriptive labels
- Rewrote README.md for Steam Workshop (plain English, no AI voice)
- Fixed doc counts, file structure refs, DESIGN.md Phase 1 description
- Consolidated mod.info files (root + Contents/)
- Created 5 GitHub Issues for deferred items (#1-#5)

### Session 3 (2026-02-20): Sprint 1 Foundation
- Created mod directory structure and `mod.info`
- Implemented `Config.lua`: wire types, tier defs, sandbox helpers, logging
- Implemented `WireNetwork.lua`: O(1) hash-table tile index, network tracking, camo state
- Implemented `Detection.lua`: OnZombieUpdate + OnPlayerUpdate with handler registry
- Implemented `ServerCommands.lua`: OnClientCommand dispatcher + debug commands
- Implemented `EventHandlers.lua`: OnServerCommand listener for sounds + cache updates

### Session 2 (2026-02-20): Session workflow infrastructure
- Created `.claude/` directory with context.md, settings.json, rules/
- Created session-start and handoff skills
- Created `CLAUDE.md`, `HANDOFF.md`, development-workflow.md

### Session 1 (2026-02-20): Research + Planning
- Created repo, ran 6 parallel research agents on B42 modding APIs
- Wrote full implementation plan with code examples
- Designed camouflage system and SandboxVars
