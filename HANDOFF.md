# Deadwire - Handoff

## Current Priority

**In-game test full chain (Sprints 3+4)**

All deferred code items now resolved. New save required for sandbox option changes. Four APIs still need in-game verification.

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

### Session 14 (2026-03-11): Deferred fixes — float safety, loot guard, north orientation

- tileKey/registerTile: `math.floor` on all coords — prevents float/int key mismatch
- LootDistribution: added `isServer()` guard for MP correctness
- Issue #12 code: `ReinforcedTripLineKit` added to `MetalFabrication`/`MetalFabricationStorage` dist tables (names need in-game verification)
- north orientation: `ClientCommands.placeWire` + `ServerCommands PlaceWire` handler now forward `args.north` to `createWire`
- 131/131 tests pass; synced to PZ mods folder

### Session 13 (2026-03-11): Fix #8, WireNetwork resync, CamoVisibility, CamoDegradation, SandboxVars

- Closed #8: removed RecalcAllWithNeighbours from createWire. Wires transparent to pathfinding.
- WireNetwork resync: OnPlayerConnect → broadcast WireNetworkSync to all clients (idempotent).
- CamoVisibility.lua (client): Foraging-scaled alpha, owner/admin bypass, orange outline at 7+.
- CamoDegradation.lua (server): rain-based camo degradation every 10 minutes, storm multiplier.
- EventHandlers: WireCamouflaged resets alpha to 1.0 + clears outline on uncamo.
- sandbox-options.txt: 14 missing options added.

### Session 12 (2026-03-11): Lua programmatic test harness

- Built full test harness: `tests/stubs.lua`, `tests/runner.lua`, `tests/run.lua`, `run_tests.bat`
- 131 tests across 4 files — Config (37), WireNetwork (45), Detection (15), ServerCommands (20)
- Confirmed 2 API usages: `os.time()` dedup, `getRole():hasCapability()` admin check

### Session 11 (2026-03-11): 42.15 compat + full audit + bug fixes

- Migrated all 3 translation files to JSON (42.15 breaking change)
- Created Issue #12 (metalfabrication loot)
- Fixed 8 bugs: admin check, kit loss, double sound, stagger API, dedup timestamp, 4 sandbox options, DEBUG flag, dead function

### Session 10 (2026-02-22): pz-tilesheet + sprites + bug fixes

- Built pz-tilesheet Python CLI (V2 .pack + tdef .tiles + .tiles.txt)
- Generated deadwire_01 tilesheet (8 sprites, 512x128, ID 200)
- Fixed #3: dedup flags timestamp-based; Fixed #10: TanglefootKit; Bumped to v0.1.1

### Sessions 1-9: See context.md

---

## To Resume

```
Deadwire v0.1.1 — all Phase 1 code complete (Session 14).
New save required for sandbox option changes.
Priority: in-game test full chain (Sprints 3+4).
  - Verify door bug fixed: place wire near door, confirm door opens normally
  - Verify WireNetworkSync works on reconnect (wire visible + removable after rejoin)
  - Verify camo alpha scaling by Foraging level
  - Verify rain degradation (Climate API — logs kits→N tables if metalfab dists found)
  - Verify Issue #12: check server log for "kits→N tables" — if 0, dist names need fixing
4 APIs still need in-game verification: sendServerCommand(player,...), Climate.GetInstance():getRainStrength(), Perks.Foraging, setOutlineHighlight.
After in-game test: ModOptions UI.
Run tests anytime: run_tests.bat
```
