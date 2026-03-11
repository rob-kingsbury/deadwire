# Deadwire - Handoff

## Current Priority

**In-game test full chain (Sprint 3+4), then ModOptions UI, Issue #12 metalfabrication loot**

Sprint 4 code is complete. **New save required** for sandbox option changes. Four APIs need in-game verification (see Deferred section).

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

---

## Open Issues

| # | Title | Labels | Status |
|---|-------|--------|--------|
| 12 | Add loot distribution for metalfabrication rooms (42.15) | enhancement, phase-1 | Open (Sprint 4) |

---

## Version

- **v0.1.1** — tagged, released on GitHub
- mod.info: `modversion=0.1.1`, `pack=deadwire_01`, `tiledef=deadwire_01 200`

---

## Key Technical Decisions

| Decision | Rationale | Date |
|----------|-----------|------|
| No RecalcAllWithNeighbours on wire place | Trip wires must be pathfinding-transparent. Recalc on place updated adjacent door tiles causing blocking. Recalc only on removal. Fixes #8. | 2026-03-11 |
| Targeted sendServerCommand(player, ...) for resync | Need to send wire list only to the connecting player, not broadcast. Verify API in-game. | 2026-03-11 |
| CamoVisibility on OnTick+throttle (not EveryOneMinute) | Visibility needs ~1s responsiveness when player moves or gains skill. OnTick with 60-tick counter. Visual-only, no game logic. | 2026-03-11 |
| CamoDegradation on EveryTenMinutes | Rain degrades slowly; 10-minute checks match the scale. No need for finer granularity. | 2026-03-11 |
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
| tileKey float safety | MODERATE | `math.floor` coords on input to prevent float/int key mismatch. |
| LootDistribution isServer() guard | MODERATE | Guard OnPreDistributionMerge with isServer() for MP correctness. |
| Issue #12: metalfabrication loot | Enhancement | Add ReinforcedTripLineKit to new 42.15 metalfabrication rooms. |
| ModOptions UI (PZAPI.ModOptions) | Enhancement | Client-side preferences. API not yet researched. Defer to next sprint. |

---

## Session History

### Session 13 (2026-03-11): Fix #8, WireNetwork resync, CamoVisibility, CamoDegradation, SandboxVars

- Closed #8: removed RecalcAllWithNeighbours from createWire. Wires transparent to pathfinding.
- WireNetwork resync: OnPlayerConnect → targeted WireNetworkSync to joining player. Fixes owner-can't-remove-after-rejoin.
- CamoVisibility.lua (client): Foraging-scaled alpha, owner/admin bypass, orange outline at 7+.
- CamoDegradation.lua (server): rain-based camo degradation every 10 minutes, storm multiplier.
- EventHandlers: WireCamouflaged resets alpha to 1.0 on uncamo.
- sandbox-options.txt: 14 missing options added.
- 4 APIs need in-game verification (see Deferred section).

### Session 12 (2026-03-11): Lua programmatic test harness

- Built full test harness: `tests/stubs.lua`, `tests/runner.lua`, `tests/run.lua`, `run_tests.bat`
- 131 tests across 4 files — Config (37), WireNetwork (45), Detection (15), ServerCommands (20)
- Discovered + confirmed 2 API usages during testing: `os.time()` dedup (not `getGameTime()`), `getRole():hasCapability()` in RemoveWire (not `isAccessLevel`)
- All Lua logic now testable without PZ — `run_tests.bat` from repo root

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
Deadwire v0.1.1 — Sprint 4 code complete (Session 13).
New save required for sandbox option changes.
Priority: in-game test full chain (Sprints 3+4).
  - Verify targeted WireNetworkSync works on reconnect
  - Verify camo alpha scaling by Foraging level
  - Verify rain degradation (Climate API)
  - Verify door bug fixed: place wire near door, confirm door opens normally
4 APIs need in-game verification: sendServerCommand(player,...), Climate.GetInstance():getRainStrength(), Perks.Foraging, setOutlineHighlight.
After in-game test: ModOptions UI, Issue #12 metalfabrication loot.
Run tests anytime: run_tests.bat
```
