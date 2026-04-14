# Deadwire - Handoff

## Current Priority

**Complete world sprites, then in-game test full chain (Sprints 3+4)**

All 4 inventory icons replaced with Gemini-generated art (Session 15). World sprites in progress — full-size source PNGs saved at repo root, need manual crop/resize then tilesheet rebuild before in-game test.

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
| Custom world sprites | **In progress** | Placeholders replaced with Gemini art in progress. Source PNGs at repo root pending resize + tilesheet rebuild. |
| pz-tilesheet tool | **Done** | `tools/pz-tilesheet/`, also published standalone |
| Test harness | **Done** | 131 tests, 0 failures — `run_tests.bat` (Session 12) |
| Sprint 4 (Camo+Config) | **Code complete** | CamoVisibility, CamoDegradation, SandboxVars done. ModOptions deferred. |
| Session 14 deferred fixes | **Done** | tileKey float safety, isServer guard, Issue #12 code, north orientation |

---

## Open Issues

| # | Title | Labels | Status |
|---|-------|--------|--------|
| 12 | Add loot distribution for metalfabrication rooms (42.15) | enhancement, phase-1 | Code done — dist names need in-game verification |

---

## Version

- **v0.1.1** — tagged, released on GitHub
- mod.info: `modversion=0.1.1`, `pack=deadwire_01`, `tiledef=deadwire_01 200`

---

## Key Technical Decisions

| Decision | Rationale | Date |
|----------|-----------|------|
| No RecalcAllWithNeighbours on wire place | Trip wires must be pathfinding-transparent. Recalc on place updated adjacent door tiles causing blocking. Recalc only on removal. Fixes #8. | 2026-03-11 |
| WireNetworkSync broadcast (not targeted) | registerTile is idempotent; broadcast avoids unverified 4-arg sendServerCommand overload. | 2026-03-11 |
| CamoVisibility on OnTick+throttle (not EveryOneMinute) | Visibility needs ~1s responsiveness when player moves or gains skill. OnTick with 60-tick counter. Visual-only, no game logic. | 2026-03-11 |
| CamoDegradation on EveryTenMinutes | Rain degrades slowly; 10-minute checks match the scale. No need for finer granularity. | 2026-03-11 |
| tileKey floors coords | Float/int key mismatch possible if coords arrive as 10.0 vs 10. math.floor in tileKey + registerTile. | 2026-03-11 |
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

## Deferred / Needs In-Game Verification

| Item | Severity | Notes |
|------|----------|-------|
| `sendServerCommand(player, module, cmd, args)` targeted send | CRITICAL | Used in WireNetworkSync. If API signature is wrong, sync won't work. Verify in-game by reconnecting and checking wire network. |
| `Climate.GetInstance():getRainStrength()` | MODERATE | Used in CamoDegradation. If API unavailable, rain degradation silently no-ops (safe failure). |
| `Perks.Foraging` enum name | MODERATE | Used in CamoVisibility. If wrong name, getPerkLevel returns nil/0 → all wires appear invisible. |
| `setOutlineHighlight` / `setOutlineHighlightCol` | MINOR | Used in CamoVisibility for 7+ outline. If unavailable, outline is skipped (safe failure). |
| BodyPartType.Foot_L enum name | MINOR | Used in TriggerHandlers tanglefootPlayerHandler. If wrong, foot damage silently no-ops. |
| Issue #12 dist names | MODERATE | `MetalFabrication`/`MetalFabricationStorage` — safe no-op if wrong; logs `kits→0 tables` as signal. |
| ModOptions UI (PZAPI.ModOptions) | Enhancement | Client-side preferences. API not yet researched. Defer to next sprint. |

---

## Session History

### Session 15 (2026-04-14): Gemini art — inventory icons + world sprite pipeline

- Built `pz_unpack.py` at `c:/xampp/htdocs/pz-tilesheet/` — extracts sprites from .pack files.
- Unpacked Tiles2x.pack, identified `fencing_damaged_01_1/4.png` as world sprite references.
- Generated + saved all 4 inventory icons (32x32) via Gemini. Replaced placeholders in mod textures.
- World sprites in progress. Full-size source PNGs at repo root pending manual crop/resize + tilesheet rebuild.

### Session 14 (2026-03-11): Deferred fixes — float safety, loot guard, north orientation

- tileKey/registerTile: `math.floor` on all coords. LootDistribution: `isServer()` guard + Issue #12 code.
- ClientCommands/ServerCommands: `north` param forwarded. 131/131 tests pass.

---

## To Resume

```
Deadwire v0.1.1 — all Phase 1 code complete. World sprites being replaced with Gemini art.
Step 1: Finish world sprites.
  - Full-size source PNGs sitting at repo root (4 wire types x 2 orientations = 8 files)
  - Crop/resize each to 64x128px with wire sitting near bottom of canvas
  - Rebuild tilesheet: python pz_tilesheet.py (in tools/pz-tilesheet/)
  - Reference images for Gemini prompting: fencing_damaged_01_1.png (east), fencing_damaged_01_4.png (north)
    at C:\Users\roban\tmp-pz-tiles\ (extracted from Tiles2x.pack via pz_unpack.py)
Step 2: New save required for sandbox option changes, then in-game test full chain (Sprints 3+4).
  - Verify door bug fixed, WireNetworkSync on reconnect, camo alpha, rain degradation, Issue #12 dist names
4 APIs still need in-game verification: sendServerCommand(player,...), Climate.GetInstance():getRainStrength(), Perks.Foraging, setOutlineHighlight.
After in-game test: ModOptions UI.
Run tests anytime: run_tests.bat
```
