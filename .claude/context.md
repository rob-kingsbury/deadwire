# Deadwire Context

```yaml
project: Deadwire
description: PZ mod — perimeter trip lines and electric livestock fencing for Project Zomboid (B42+)
last_session: 0
continue_with: "Phase 1 MVP — mod scaffolding and core systems (Sprint 1)"

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

## Architecture

Three-tier Lua design (same as gen-network):
- **Shared**: Core logic, config, wire network hash-table
- **Client**: UI, context menus, sound effects, placement
- **Server**: Authoritative state, validation, detection, commands

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

73 SandboxVars across 9 pages:
- General (master switches, tier toggles, wire limits)
- Sound (all radii independently tunable)
- Trip Lines (break chance, span, health, player damage)
- Tanglefoot (trip chance, size, prone duration)
- Pull-Alarm (max distance, wire cost)
- Electric Fencing (stagger, power drain, charger rarity)
- Advanced (kill chance, fire risk, barbed wire tangle)
- Camouflage (detection levels, ranges, degradation, faction visibility)
- Multiplayer (friendly fire, owner immunity, admin bypass, logging)
- Loot & Spawns (rarity for all new items)

## Phase Plan

| Phase | Content | Status |
|---|---|---|
| Phase 1 (MVP) | Tier 0 + Tier 1 + Camouflage + 73 SandboxVars | Not Started |
| Phase 2 (Pull-Alarms) | Tier 2: mechanical pull-cord alarm system | Not Started |
| Phase 3 (Electric) | Tier 3: electric livestock fencing + power | Not Started |
| Phase 4 (Advanced) | Tier 4: modified charger, detonation, electrified barbed | Not Started |

## Sprint Plan (Phase 1)

1. Foundation: WireNetwork hash-table, Detection, ServerCommands, EventHandlers
2. Placement: ISBuildingObject, context menus, timed actions
3. Sound + Trigger: handlers, loot distribution, item/recipe scripts
4. Camouflage + Config: CamoVisibility, CamoDegradation, all SandboxVars, ModOptions

## Recent Changes

### Session 1 (2026-02-20): Research + Planning
- Created repo, ran 6 parallel research agents on B42 modding APIs
- Wrote full implementation plan with code examples
- Designed camouflage system (per-client alpha via Foraging skill)
- Designed 73 SandboxVars for server customization
- Next: Sprint 1 (Foundation)
