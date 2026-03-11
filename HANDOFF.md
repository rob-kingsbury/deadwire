# Deadwire - Handoff

## Current Priority

**In-game test Sprint 3 end-to-end (new save required), then Sprint 4 (Camo + Config)**

Sprint 3 is code complete with custom sprites and a full audit pass. **Requires a new save** to pick up the updated sandbox options and translation files. Test all 4 wire types: craft kit → place wire → zombie/player triggers → sound + effects → removal.

---

## Status

| Area | Status | Notes |
|------|--------|-------|
| Design Document | Done | `docs/DESIGN.md` |
| Implementation Plan | Done | `docs/IMPLEMENTATION-PLAN.md` |
| Mod Scaffolding | Done | mod.info (root + 42/), common/, correct structure |
| Sprint 1 (Foundation) | **PASSED** | All 5 in-game tests pass (Session 6) |
| Sprint 2 (Placement) | **PASSED** | All 6 tests pass (Session 8) |
| Sprint 3 (Sound+Trigger) | **Ready to test** | Code complete + audited + custom sprites + all kits |
| 42.15 compat | **Done** | Translation files migrated to JSON (Session 11) |
| Audit (Sprints 2+3) | **Done** | 8 bugs fixed (Session 11) |
| Custom world sprites | **Done** | deadwire_01.pack + .tiles (8 sprites, tileset ID 200) |
| pz-tilesheet tool | **Done** | `tools/pz-tilesheet/`, also published standalone |
| Sprint 4 (Camo+Config) | Not Started | CamoVisibility, SandboxVars, ModOptions |

---

## Open Issues

| # | Title | Labels | Status |
|---|-------|--------|--------|
| 8 | Wire placed near door blocks passage | bug, phase-1 | Open (needs in-game investigation) |
| 12 | Add loot distribution for metalfabrication rooms (42.15) | enhancement, phase-1 | Open (Sprint 4) |

---

## Version

- **v0.1.1** — tagged, released on GitHub
- mod.info: `modversion=0.1.1`, `pack=deadwire_01`, `tiledef=deadwire_01 200`

---

## Key Technical Decisions

| Decision | Rationale | Date |
|----------|-----------|------|
| `OnZombieUpdate` + hash-table | Only proven pattern for tile detection. O(1) lookup. | 2026-02-20 |
| Detection.lua in **client/** | OnZombieUpdate/OnPlayerUpdate are client-only events. | 2026-02-20 |
| `IsoThumpable` per-tile | Vanilla barbed wire uses this exact pattern. | 2026-02-20 |
| `module Base` | Custom modules broken in B42 MP. | 2026-02-20 |
| BuildActions.lua in **server/** | ISBuildingObject is in server/. derive() at file-load time requires server/. | 2026-02-21 |
| GlobalModData for persistence | `ModData.getOrCreate()` persists in save file. | 2026-02-21 |
| Python packer over pz-pack | No MSVC build tools. Python 3.11 available. More maintainable. | 2026-02-22 |
| Mono OGG requirement | PZ is3D audio silently fails on stereo. All sound files must be mono. | 2026-02-22 |
| Binary .tiles required | PZ needs compiled tdef binary, not just .tiles.txt. Verified via workshop mods. | 2026-02-22 |
| Dedup via os.time() | Real-time seconds (1s window). Game-hours at 60x = ~1 frame window (was broken). | 2026-03-11 |
| Admin check: isAdmin() / getRole() | Client: `isAdmin()` global. Server: `player:getRole():hasCapability(Capability.CanBuildAnywhere)`. `isAccessLevel` does not exist. | 2026-03-11 |
| Sound: SP local, MP broadcast | TriggerHandlers plays locally only in SP (`not isClient()`). MP uses server broadcast via EventHandlers. Prevents double-play. | 2026-03-11 |
| Player stagger: setBumpType | `setSlowFactor`/`setSlowTimer` don't exist in B42. Stagger via `setBumpType("stagger")` + `setVariable`. | 2026-03-11 |
| Translation files now JSON | PZ 42.15 requires `.json` files. Keys: ItemName drops `ItemName_` prefix; Recipes drops `Recipe_` prefix; Sandbox keeps `Sandbox_` prefix. | 2026-03-11 |
| transmitRemoveItemFromSquare valid server-side | Confirmed in ISBuildingObject.lua — not a client-only API. | 2026-03-11 |

---

## Deferred (Sprint 4 or later)

| Item | Severity | Notes |
|------|----------|-------|
| WireNetwork resync on client rejoin | CRITICAL | Owner can't remove own wire after reconnect. Needs server-side broadcast of all active wires on player join. Design work required. |
| BodyPartType.Foot_L enum name | MINOR | Unverified against B42. If wrong, tanglefoot damage silently no-ops. Verify in-game. |
| tileKey float safety | MODERATE | `math.floor` coords on input to prevent float/int key mismatch. |
| LootDistribution isServer() guard | MODERATE | Guard OnPreDistributionMerge with isServer() for MP correctness. |
| Issue #12: metalfabrication loot | Enhancement | Add ReinforcedTripLineKit to new 42.15 metalfabrication rooms. |

---

## Session History

### Session 11 (2026-03-11): 42.15 compat + full audit + bug fixes

- Researched PZ 42.15 changes; key finding: translation files now JSON
- Migrated all 3 translation files to JSON format (breaking change in 42.15)
- Added validate_pack.py to version control; removed local skill stubs
- Created Issue #12 (metalfabrication loot for 42.15 new rooms)
- Ran 3 parallel audit agents across 6 unaudited files; found 9 criticals, 6 moderates, 5 minors
- Verified confirmed vs false-positive findings against actual PZ game files
- Fixed 8 bugs: admin check API, kit loss on placement failure, double sound MP,
  non-existent slow APIs, dedup timestamp, 4 missing sandbox options, DEBUG flag, dead function

### Session 10 (2026-02-22): pz-tilesheet + sprites + bug fixes

- Built pz-tilesheet Python CLI (V2 .pack + tdef .tiles + .tiles.txt)
- Generated deadwire_01 tilesheet (8 sprites, 512x128, ID 200)
- Fixed #3: dedup flags timestamp-based; Fixed #10: TanglefootKit
- Bumped to v0.1.1, tagged, released on GitHub

### Sessions 1-9: See context.md

---

## To Resume

```
Deadwire v0.1.1 — Sprint 3 audited and ready to test.
Start a NEW save (sandbox options + translation changes need fresh save).
Test: craft kit → place wire → zombie triggers → player triggers → sound → remove.
Check all 4 types. Investigate #8 (door blocking) in-game.
After test passes: Sprint 4 — CamoVisibility, CamoDegradation, SandboxVars, ModOptions.
First Sprint 4 task: WireNetwork resync on rejoin (deferred critical from Session 11 audit).
```
