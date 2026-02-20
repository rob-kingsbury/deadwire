# Deadwire - Handoff

## Current Priority

**Test Sprint 1 in-game (Issue #5), then start Sprint 2: Placement System**

Sprint 1 Foundation complete and audited. All critical code bugs fixed. 5 GitHub Issues track remaining work. Next step is in-game testing to verify detection fires, then begin ISBuildingObject placement system.

---

## Status

| Area | Status | Notes |
|------|--------|-------|
| Design Document | Done | `docs/DESIGN.md` |
| Implementation Plan | Done | `docs/IMPLEMENTATION-PLAN.md` (updated: Detection in client/) |
| Mod Scaffolding | Done | mod.info, directory structure |
| Sprint 1 (Foundation) | Done + Audited | Config, WireNetwork, Detection (client), ServerCommands, EventHandlers |
| Sandbox Options (Basic) | Done | 14 options, 1 page |
| Sandbox Options (Advanced) | Done | 60 options, 7 pages, in docs/ |
| Translation File | Done | Sandbox_Deadwire_EN.txt with descriptive labels |
| README (Workshop) | Done | Plain English, basic+advanced settings documented |
| Sprite Checklist | Done | `docs/SPRITES.md` — 40 sprites across all phases |
| Sprint 2 (Placement) | Not Started | ISBuildingObject, context menus, timed actions, IsoThumpable |
| Sprint 3 (Sound+Trigger) | Not Started | Handlers, loot, items, recipes |
| Sprint 4 (Camo+Config) | Not Started | CamoVisibility, SandboxVars, ModOptions |

---

## Open Issues

| # | Title | Labels | Priority |
|---|-------|--------|----------|
| 1 | WireNetwork state not persisted across save/load | bug, phase-1, sprint-2 | High (Sprint 2) |
| 2 | No sound feedback in singleplayer | bug, phase-1 | Moderate |
| 3 | Zombie/player modData de-dup flags never clear | design-review, phase-1 | Low |
| 4 | nextNetworkId not persisted across save/load | bug, sprint-2 | Low (Sprint 2) |
| 5 | Test Sprint 1 foundation in-game | testing, phase-1 | **Next** |

---

## Blockers

- **In-game test needed (Issue #5)**: Sprint 1 code compiles but needs PZ testing. Use `DebugPlaceWire` command to hardcode a wire, walk zombie into it, verify detection fires and sound broadcasts.

---

## Key Technical Decisions

| Decision | Rationale | Date |
|----------|-----------|------|
| `OnZombieUpdate` + hash-table | Only proven pattern for tile detection. O(1) lookup. | 2026-02-20 |
| Detection.lua in **client/** | OnZombieUpdate/OnPlayerUpdate are client-only events. | 2026-02-20 |
| `IsoThumpable` per-tile | Vanilla barbed wire uses this exact pattern. | 2026-02-20 |
| `module Base` | Custom modules broken in B42 MP. | 2026-02-20 |
| Legacy generator system | Component/wiring system not fully implemented in B42. | 2026-02-20 |
| `setAlphaAndTarget()` for camo | Global alpha operates per-client in network MP. | 2026-02-20 |
| SandboxVars over ModOptions | Gameplay values must be server-synced. ModOptions is client-only. | 2026-02-20 |
| Basic/Advanced sandbox split | 14 essential options ship by default; 60 full options as swap-in file. | 2026-02-20 |
| Camouflage in Phase 1 | Highest MP value feature, minimal additional code (~260 lines). | 2026-02-20 |
| `deadwire:tagname` namespace | Required since 42.13. | 2026-02-20 |
| Handler registry pattern | Detection dispatches to registered handlers per wire type. | 2026-02-20 |
| Idempotent registerTile | MP host receives its own broadcast — prevents duplicate entries. | 2026-02-20 |

---

## Files Modified (Session 4)

| File | Changes |
|------|---------|
| `client/Deadwire/Detection.lua` | MOVED from server/. DRY: single `detectEntity()` for zombies + players |
| `shared/Deadwire/WireNetwork.lua` | Made `registerTile` idempotent (check-before-insert) |
| `server/Deadwire/ServerCommands.lua` | Fixed CamoEnabled → EnableCamouflage. DRY: `hasPosition()` helper |
| `client/Deadwire/EventHandlers.lua` | DRY: `hasPosition()` + `getSquareFromArgs()` helpers |
| `42/media/sandbox-options.txt` | Created: basic options (14 options, 1 page) |
| `docs/sandbox-options-advanced.txt` | Created: advanced options (60 options, 7 pages) |
| `shared/Translate/EN/Sandbox_Deadwire_EN.txt` | Created: all 60 option translations with descriptive labels |
| `README.md` | Rewritten for Steam Workshop |
| `mod.info` (both) | Consolidated root + Contents versions |
| `docs/DESIGN.md` | Fixed Phase 1: added Camouflage, SandboxVars (not ModOptions) |
| `docs/IMPLEMENTATION-PLAN.md` | Fixed Detection.lua location (server → client), CamoEnabled → EnableCamouflage |
| `.claude/context.md` | Updated: session 4, fixed counts, added architecture notes |

---

## Session History

### Session 5 (2026-02-20): Sprite Checklist + Handoff

- Created `docs/SPRITES.md` with all custom sprites needed across 4 phases
- Confirmed `Base.Bell` is vanilla — Phase 1 needs zero new inventory items
- Noted: update `Base.Deadwire_Bell` → `Base.Bell` in implementation plan recipes (Sprint 3)

### Session 4 (2026-02-20): Audit + Fixes + Sandbox Options

- Full 3-agent parallel audit of all code, config, and docs
- Fixed 3 critical bugs: Detection.lua location, idempotent registration, CamoEnabled key
- DRY refactored all validation patterns across ServerCommands + EventHandlers
- Created basic (14) and advanced (60) sandbox options split
- Created translation file with self-descriptive labels
- Rewrote README for Steam Workshop (plain English)
- Fixed all doc inconsistencies (counts, file paths, stale refs)
- Consolidated mod.info files
- Created 5 GitHub Issues (#1-#5) for deferred items

### Session 3 (2026-02-20): Sprint 1 Foundation

- Created mod directory structure and mod.info
- Implemented Config.lua, WireNetwork.lua, Detection.lua, ServerCommands.lua, EventHandlers.lua

### Session 2 (2026-02-20): Session workflow infrastructure

- Created session-start and handoff skills, CLAUDE.md, context.md, development-workflow.md

### Session 1 (2026-02-20): Research + Planning

- Created GitHub repo, ran research agents, wrote implementation plan and design doc

---

## Next Steps

1. **Test Sprint 1 in-game (Issue #5)**: Enable mod, use `DebugPlaceWire`, verify detection + sound
2. Sprint 2: `BuildActions.lua` — ISBuildingObject derivative for wire placement
3. Sprint 2: `UI.lua` — Right-click context menu
4. Sprint 2: `TimedActions.lua` — Placement timed action
5. Sprint 2: `WireManager.lua` — Server-side IsoThumpable creation/destruction
6. Sprint 2: Fix save/load persistence (Issue #1) and nextNetworkId (Issue #4)

---

## To Resume

```
Deadwire — Sprint 1 Foundation complete and audited. 5 open issues.
Test Sprint 1 in-game first (Issue #5), then start Sprint 2.
Read CLAUDE.md and .claude/context.md for full project context.
```
