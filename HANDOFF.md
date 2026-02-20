# Deadwire Session Handoff

## What Was Done

### Session 1 (2026-02-20)

**Design review + project creation + research + implementation planning.**

1. Read the full Deadwire design document (~3000 words)
2. Created GitHub repo: https://github.com/rob-kingsbury/deadwire
3. Set up PZ mod directory structure with `mod.info` for B42
4. Wrote condensed design document (`docs/DESIGN.md`)
5. Ran 5 parallel Opus research agents investigating B42 modding:
   - Lua API (zombie manipulation, IsoObjects, tile detection, sound events)
   - Crafting system (craftRecipe format, items, loot tables, magazines)
   - Electrical system (generators, batteries, power grid)
   - Multiplayer architecture (client/server separation, sync, anti-cheat)
   - Existing mod patterns (Spear Traps, barbed wire, alarms, ModOptions)
6. Wrote comprehensive implementation plan (`docs/IMPLEMENTATION-PLAN.md`)
7. Researched camouflage system feasibility (1 additional research agent):
   - Confirmed `setAlphaAndTarget(float)` works per-client for MP visibility
   - Confirmed Foraging skill is the right detection gate
   - Designed scaling detection (not binary) with SandboxVars thresholds
8. Added camouflage system to Phase 1 MVP
9. Designed 73 SandboxVars across 9 settings pages for server customization
10. Updated all documentation and README

### Commits

- `fe094d7` - Initial project scaffolding and design document
- `53d15c2` - Add comprehensive implementation plan based on B42 API research
- `[pending]` - Add camouflage system, sandbox options, and handoff

## Key Technical Decisions

| Decision | Rationale |
|---|---|
| `OnZombieUpdate` + hash-table | Only proven pattern for tile detection. O(1) lookup. |
| `IsoThumpable` per-tile | Vanilla barbed wire uses this exact pattern. |
| `module Base` | Custom modules broken in B42 MP. |
| Legacy generator system | Component/wiring system not fully implemented in B42. |
| `setAlphaAndTarget()` for camo | Global alpha (no playerIndex) operates per-client in network MP. |
| SandboxVars over ModOptions | Gameplay values must be server-synced. ModOptions is client-only. |
| Camouflage in Phase 1 | Highest MP value feature, minimal additional code (~260 lines). |

## What's Next

### To start implementation, open a new session and say:

```
Continue working on Deadwire. Start Sprint 1: Foundation.
Read docs/IMPLEMENTATION-PLAN.md for the full plan.
```

### Sprint 1 tasks (Foundation):
1. Create the B42 mod folder structure under `Contents/mods/Deadwire/42/`
2. Write `Config.lua` (constants, wire type definitions)
3. Write `WireNetwork.lua` (hash-table tile index)
4. Write `Detection.lua` (OnZombieUpdate + OnPlayerUpdate detection)
5. Write `ServerCommands.lua` (OnClientCommand dispatcher)
6. Write `EventHandlers.lua` (OnServerCommand listener)
7. Test: hardcode a wire tile, walk zombie into it, verify detection fires

### Full sprint plan:
- Sprint 1: Foundation (detection + networking)
- Sprint 2: Placement system (ISBuildingObject + context menus)
- Sprint 3: Sound + trigger mechanics
- Sprint 4: Camouflage + SandboxVars + polish
- Ship Phase 1 MVP to Workshop
- Sprints 5-7: Phases 2-4

## Files In This Repo

| File | Purpose |
|---|---|
| `mod.info` | PZ mod metadata (B42+) |
| `README.md` | Project overview |
| `HANDOFF.md` | This file |
| `docs/DESIGN.md` | Condensed game design document |
| `docs/IMPLEMENTATION-PLAN.md` | Full technical plan with code examples, 73 SandboxVars, architecture |

## Research Artifacts

The research findings from 6 parallel agents are not saved as files but are fully incorporated into `IMPLEMENTATION-PLAN.md`. Key references:

- [Spear Traps source (GPL)](https://github.com/quarantin/zomboid-spear-traps) -- tile detection pattern
- [Vanilla ISBarbedWire.lua](https://github.com/Project-Zomboid-Community-Modding/ProjectZomboid-Vanilla-Lua) -- placement pattern
- [Konijima PZ-BaseMod](https://github.com/Konijima/PZ-BaseMod) -- MP command pattern
- [Immersive Solar Arrays](https://github.com/radx5Blue/ImmersiveSolarArrays) -- custom power system
- [PZEventDoc](https://github.com/demiurgeQuantified/PZEventDoc) -- B42 event list
- [B42 Mod Template](https://github.com/LabX1/ProjectZomboid-Build42-ModTemplate) -- folder structure
