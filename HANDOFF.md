# Deadwire - Handoff

## Current Priority

**In-game test Sprint 3 end-to-end, then begin Sprint 4 (Camo + Config)**

Sprint 3 is code complete with custom sprites generated. All blocking issues resolved. Needs a new save to test the full wire lifecycle: craft kit → place wire → zombie/player triggers → sound + effects → removal.

---

## Status

| Area | Status | Notes |
|------|--------|-------|
| Design Document | Done | `docs/DESIGN.md` |
| Implementation Plan | Done | `docs/IMPLEMENTATION-PLAN.md` |
| Mod Scaffolding | Done | mod.info (root + 42/), common/, correct structure |
| Sprint 1 (Foundation) | **PASSED** | All 5 in-game tests pass (Session 6) |
| Sprint 2 (Placement) | **PASSED** | All 6 tests pass (Session 8) |
| Sprint 3 (Sound+Trigger) | **Ready to test** | Code complete + custom sprites + all kits |
| Custom world sprites | **Done** | deadwire_01.pack + .tiles (8 sprites, tileset ID 200) |
| pz-tilesheet tool | **Done** | `tools/pz-tilesheet/`, also published standalone |
| Tanglefoot kit | **Done** | Item, recipe, icon, translations (Session 10) |
| Dedup bug fix | **Done** | Timestamp-based 1s expiry (was permanent flag) |
| Sprint 4 (Camo+Config) | Not Started | CamoVisibility, SandboxVars, ModOptions |

---

## Open Issues

| # | Title | Labels | Status |
|---|-------|--------|--------|
| 3 | Zombie/player modData de-dup flags never clear | design-review, phase-1 | **Fixed** (close after test) |
| 8 | Wire placed near door blocks passage | bug, phase-1 | Open (needs in-game investigation) |

Closed this session: #7 (superseded), #9 (superseded), #11 (completed)

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
| Timestamp dedup (1s window) | Permanent modData flag broke reusable wires. Short expiry handles MP latency. | 2026-02-22 |

---

## Session History

### Session 10 (2026-02-22): pz-tilesheet + sprites + bug fixes

- Built pz-tilesheet Python CLI (V2 .pack + tdef .tiles + .tiles.txt)
- Published standalone: github.com/rob-kingsbury/pz-tilesheet
- Generated deadwire_01 tilesheet (8 sprites, 512x128, ID 200)
- Validated .pack binary (108/108 checks pass) and .tiles binary against vanilla
- Fixed #3: dedup flags now timestamp-based with 1s expiry
- Fixed #10: TanglefootKit item + recipe + icon + translations
- Bumped to v0.1.1, tagged, released on GitHub
- Closed #7, #9, #11

### Session 9 (2026-02-22): Sprint 3 code complete + fixes

- All Sprint 3 code: handlers, sounds, items, recipes, loot, translations
- Two in-game test rounds, fixed 6 bugs
- Root cause: stereo OGGs, icon paths, translation format, passability
- Discovered world sprites need tilesheet → created Issue #11

### Sessions 1-8: See context.md

---

## To Resume

```
Deadwire v0.1.1 — Sprint 3 code complete with custom sprites.
Next: In-game test (new save required). Test all 4 wire types: craft, place, trigger, sound, remove.
After test: Sprint 4 — CamoVisibility, CamoDegradation, SandboxVars, ModOptions.
Only open bug: #8 (wire near door blocks passage — investigate in-game).
```
