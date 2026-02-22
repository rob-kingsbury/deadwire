# Deadwire - Handoff

## Current Priority

**Sprint 2: Placement System — CODE COMPLETE (needs in-game test)**

All 7 steps implemented. 4 new files + 3 updated files. Fixes #1 and #4 (persistence). Ready for in-game testing.

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
| Sprint 2 (Placement) | **Code Complete** | Needs in-game test |
| Sprint 3 (Sound+Trigger) | Not Started | Handlers, loot, items, recipes |
| Sprint 4 (Camo+Config) | Not Started | CamoVisibility, SandboxVars, ModOptions |

---

## Open Issues

| # | Title | Labels | Status |
|---|-------|--------|--------|
| 1 | WireNetwork state not persisted across save/load | bug, phase-1, sprint-2 | **Fixed** (WireManager.loadAll) |
| 2 | No sound feedback in singleplayer | bug, phase-1 | Open |
| 3 | Zombie/player modData de-dup flags never clear | design-review, phase-1 | Open |
| 4 | nextNetworkId not persisted across save/load | bug, sprint-2 | **Fixed** (WireManager.loadAll) |
| 5 | Test Sprint 1 foundation in-game | testing, phase-1 | **Closed** (passed) |
| 6 | Verify sandbox option labels display correctly | testing, phase-1 | Open |
| 7 | Sprint 2 pre-flight: verify PZ APIs before implementation | phase-1, sprint-2 | Superseded (implemented directly) |

---

## Sprint 2 Files

**New files:**
- `server/Deadwire/WireManager.lua` — wire lifecycle, IsoThumpable create/destroy, GlobalModData persistence, save/load on OnGameStart, chunk reconnect on LoadGridsquare
- `client/Deadwire/BuildActions.lua` — ISBuildingObject:derive("ISDeadwireTripLine"), create() calls WireManager on server
- `client/Deadwire/UI.lua` — right-click context menu: "Place Deadwire..." submenu (4 wire types) + "Remove Wire" (owner/admin)
- `client/Deadwire/ClientCommands.lua` — sendClientCommand wrappers

**Updated files:**
- `server/Deadwire/ServerCommands.lua` — PlaceWire/RemoveWire/DebugPlaceWire use WireManager
- `client/Deadwire/EventHandlers.lua` — WirePlaced caches IsoObject ref
- `shared/Deadwire/WireNetwork.lua` — setNextNetworkId() (step 1, previous session)

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

### Session 7 (2026-02-21): Sprint 2 Placement — code complete

- Created WireManager.lua, BuildActions.lua, UI.lua, ClientCommands.lua
- Updated ServerCommands.lua, EventHandlers.lua to use WireManager
- Fixes #1 and #4 (persistence bugs)
- Synced to PZ mods folder

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
Deadwire — Sprint 2 code complete, needs in-game test.
Read CLAUDE.md and .claude/context.md for full project context.
Next: Test placement in-game, then Sprint 3 (Sound + Trigger).
```
