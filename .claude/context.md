# Deadwire Context

```yaml
project: Deadwire
description: PZ mod — perimeter trip lines and electric fencing for Project Zomboid (B42+)
last_session: 5
continue_with: "Test Sprint 1 in-game (Issue #5), then Sprint 2: Placement"

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
| Phase 1 (MVP) | Tier 0 + Tier 1 + Camouflage + SandboxVars | Sprint 1 Done, needs in-game test |
| Phase 2 (Pull-Alarms) | Tier 2: mechanical pull-cord alarm system | Not Started |
| Phase 3 (Electric) | Tier 3: electrified perimeter fencing + power | Not Started |
| Phase 4 (Advanced) | Tier 4: modified charger, detonation, electrified barbed | Not Started |

## Sprint Plan (Phase 1)

1. Foundation: WireNetwork hash-table, Detection, ServerCommands, EventHandlers — **DONE**
2. Placement: ISBuildingObject, context menus, timed actions
3. Sound + Trigger: handlers, loot distribution, item/recipe scripts
4. Camouflage + Config: CamoVisibility, CamoDegradation, all SandboxVars, ModOptions

## Recent Changes

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
