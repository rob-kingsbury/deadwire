# Deadwire - Handoff

## Current Priority

**Sprint 2: Placement System — IN PROGRESS (Step 1 of 7 done)**

Plan approved and written to `.claude/plans/refactored-pondering-starfish.md`. Implementation started: `WireNetwork.setNextNetworkId()` added. Remaining: WireManager.lua, BuildActions.lua, UI.lua, ClientCommands.lua, ServerCommands update, EventHandlers update.

---

## Status

| Area | Status | Notes |
|------|--------|-------|
| Design Document | Done | `docs/DESIGN.md` |
| Implementation Plan | Done | `docs/IMPLEMENTATION-PLAN.md` |
| Mod Scaffolding | Done | mod.info (root + 42/), common/, correct structure |
| Sprint 1 (Foundation) | **PASSED** | All 5 in-game tests pass (Session 6) |
| Sandbox Options (Basic) | Done | 14 options, 1 page, no comments |
| Translation File | Done | `Sandbox_EN.txt` (renamed from Sandbox_Deadwire_EN.txt) |
| README (Workshop) | Done | Plain English |
| Sprite Checklist | Done | `docs/SPRITES.md` — 40 sprites across all phases |
| Sprint 2 (Placement) | **In Progress** | Step 1/7: WireNetwork updated. Plan at `.claude/plans/` |
| Sprint 3 (Sound+Trigger) | Not Started | Handlers, loot, items, recipes |
| Sprint 4 (Camo+Config) | Not Started | CamoVisibility, SandboxVars, ModOptions |

---

## Open Issues

| # | Title | Labels | Status |
|---|-------|--------|--------|
| 1 | WireNetwork state not persisted across save/load | bug, phase-1, sprint-2 | Sprint 2 fixes this |
| 2 | No sound feedback in singleplayer | bug, phase-1 | Open |
| 3 | Zombie/player modData de-dup flags never clear | design-review, phase-1 | Open |
| 4 | nextNetworkId not persisted across save/load | bug, sprint-2 | Sprint 2 fixes this |
| 5 | Test Sprint 1 foundation in-game | testing, phase-1 | **Closed** (passed) |
| 6 | Verify sandbox option labels display correctly | testing, phase-1 | Open |
| 7 | Sprint 2 pre-flight: verify PZ APIs before implementation | phase-1, sprint-2 | Open |

---

## Sprint 2 Plan Summary

4 new files + 3 file updates. No custom sprites (vanilla placeholder). No item scripts (free placement for testing). Key architecture: `ISBuildingObject:derive()` → `create()` runs server-side via PZ's `createBuildAction` in MP → creates IsoThumpable directly → `sendServerCommand("WirePlaced")` syncs clients. Save/load via `ModData.getOrCreate("DeadwireWires")`.

**Implementation order:**
1. ~~WireNetwork.lua — add `setNextNetworkId()`~~ **DONE**
2. WireManager.lua — server-side wire lifecycle + GlobalModData persistence
3. BuildActions.lua — ISBuildingObject derivative
4. UI.lua — context menu for placement + removal
5. ClientCommands.lua — sendClientCommand wrappers
6. ServerCommands.lua — wire RemoveWire to use WireManager
7. EventHandlers.lua — cache IsoObject in WirePlaced handler

Full plan: `.claude/plans/refactored-pondering-starfish.md`

---

## Key Technical Decisions

| Decision | Rationale | Date |
|----------|-----------|------|
| `OnZombieUpdate` + hash-table | Only proven pattern for tile detection. O(1) lookup. | 2026-02-20 |
| Detection.lua in **client/** | OnZombieUpdate/OnPlayerUpdate are client-only events. | 2026-02-20 |
| `IsoThumpable` per-tile | Vanilla barbed wire uses this exact pattern. | 2026-02-20 |
| `module Base` | Custom modules broken in B42 MP. | 2026-02-20 |
| `setAlphaAndTarget()` for camo | Global alpha operates per-client in network MP. | 2026-02-20 |
| Idempotent registerTile | MP host receives its own broadcast — prevents duplicate entries. | 2026-02-20 |
| `create()` runs server-side | PZ's `createBuildAction` sends build action to server in MP. No need for sendClientCommand from create(). | 2026-02-21 |
| GlobalModData for persistence | `ModData.getOrCreate()` persists in save file. Rebuild WireNetwork on game load. | 2026-02-21 |
| Vanilla placeholder sprite | No custom sprites yet. Use barbed wire sprite until art is done. | 2026-02-21 |
| Skip material checks Sprint 2 | No item scripts exist. Free placement for testing mechanics. | 2026-02-21 |

---

## Session History

### Session 6 (2026-02-21): Sprint 1 PASSED + Sprint 2 started

- Fixed mod structure: added `42/mod.info`, `common/`, fixed poster path
- Removed `--` comments from sandbox-options.txt
- Renamed `Sandbox_Deadwire_EN.txt` → `Sandbox_EN.txt`
- **Sprint 1 in-game test PASSED** (all 5 tests: load, register, zombie detect, player detect, de-dup)
- Closed Issue #5, created Issues #6 (labels) and #7 (API pre-flight)
- Planned Sprint 2, approved, started implementation (step 1/7 done)

### Session 5 (2026-02-20): Sprite Checklist + Handoff

- Created `docs/SPRITES.md`, confirmed `Base.Bell` is vanilla

### Session 4 (2026-02-20): Audit + Fixes + Sandbox Options

- 3 critical fixes, DRY refactors, sandbox options, translation file, README

### Session 3 (2026-02-20): Sprint 1 Foundation

- Config.lua, WireNetwork.lua, Detection.lua, ServerCommands.lua, EventHandlers.lua

### Session 2 (2026-02-20): Workflow infrastructure

### Session 1 (2026-02-20): Research + Planning

---

## To Resume

```
Deadwire — Sprint 2 Placement in progress (step 1/7 done).
Read plan at .claude/plans/refactored-pondering-starfish.md
Read CLAUDE.md and .claude/context.md for full project context.
Continue with step 2: Create WireManager.lua
```
