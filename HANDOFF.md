# Deadwire - Handoff

## Current Priority

**Build Python .pack/.tiles packer tool (Issue #11)**

Sprint 3 code is complete but blocked on custom world sprites. Individual PNGs don't work for IsoThumpable — PZ requires `.pack` + `.tiles` tilesheet files. Building a Python CLI tool to generate these from PNGs.

After packer tool: generate Deadwire tilesheet, update Config.lua sprite mapping, test Sprint 3 end-to-end.

---

## Status

| Area | Status | Notes |
|------|--------|-------|
| Design Document | Done | `docs/DESIGN.md` |
| Implementation Plan | Done | `docs/IMPLEMENTATION-PLAN.md` |
| Mod Scaffolding | Done | mod.info (root + 42/), common/, correct structure |
| Sprint 1 (Foundation) | **PASSED** | All 5 in-game tests pass (Session 6) |
| Sprint 2 (Placement) | **PASSED** | All 6 tests pass (Session 8) |
| Sprint 3 (Sound+Trigger) | **Code Complete** | Blocked on custom sprites (Issue #11) |
| Sprint 3 — Trigger handlers | Done | TriggerHandlers.lua: all 4 wire types |
| Sprint 3 — Sound scripts | Done | 3 GameSound defs, mono OGGs deployed |
| Sprint 3 — Item scripts | Done | 3 kit items with DisplayCategory |
| Sprint 3 — Recipe scripts | Done | 3 craft recipes |
| Sprint 3 — Translation files | Done | ItemName_EN.txt, Recipes_EN.txt, Sandbox_EN.txt |
| Sprint 3 — Loot distribution | Done | LootDistribution.lua (bells) |
| Sprint 3 — Server WireTriggered | Done | Break/cooldown/degrade/log |
| Sprint 3 — Client commands | Done | wireTriggered wrapper |
| Sprint 3 — UI improvements | Done | Kit-gated menu, friendly labels |
| Custom world sprites | **Blocked** | Need .pack/.tiles tool (Issue #11) |
| Packer tool | Not Started | Python CLI, Issue #11 |
| Sprint 4 (Camo+Config) | Not Started | CamoVisibility, SandboxVars, ModOptions |

---

## Open Issues

| # | Title | Labels | Status |
|---|-------|--------|--------|
| 2 | No sound feedback in singleplayer | bug, phase-1 | Likely fixed (mono OGGs + is3D), needs test |
| 3 | Zombie/player modData de-dup flags never clear | design-review, phase-1 | Open |
| 7 | Sprint 2 pre-flight: verify PZ APIs | phase-1, sprint-2 | Superseded |
| 8 | Wire placed near door blocks passage | bug, phase-1 | Open |
| 9 | Create TileZed tilesheet pack | enhancement, phase-1 | Superseded by #11 |
| 10 | Add tanglefoot kit item | enhancement, phase-1 | Open |
| 11 | Build Python .pack/.tiles packer tool | enhancement, phase-1 | **Next priority** |

---

## Sprint 3 Files (Session 9)

**New files:**
- `client/Deadwire/TriggerHandlers.lua` — 4 wire type handlers (tin can, reinforced, bell, tanglefoot)
- `server/Deadwire/LootDistribution.lua` — Bell loot spawns via OnPreDistributionMerge
- `42/media/scripts/deadwire_items.txt` — 3 kit item definitions
- `42/media/scripts/deadwire_recipes.txt` — 3 craft recipes
- `42/media/scripts/deadwire_sounds.txt` — 3 GameSound definitions (is3D=true)
- `42/media/sound/tin_can_rattle.ogg` — Mono, 24kHz
- `42/media/sound/wire_rattle.ogg` — Mono, 44.1kHz
- `42/media/sound/bell_ring.ogg` — Mono, 24kHz
- `42/media/textures/Item_Deadwire_TinCanTripLineKit.png` — 32x32 icon
- `42/media/textures/Item_Deadwire_ReinforcedTripLineKit.png` — 32x32 icon
- `42/media/textures/Item_Deadwire_BellTripLineKit.png` — 32x32 icon
- `shared/Translate/EN/ItemName_EN.txt` — Kit item display names
- `shared/Translate/EN/Recipes_EN.txt` — Recipe display names

**Updated files:**
- `shared/Deadwire/Config.lua` — Added Sprites table (empty), FALLBACK_SPRITE, KitItems, Sounds
- `server/Deadwire/WireManager.lua` — Per-type sprites, setIsThumpable(false), setBlockAllTheSquare(false)
- `server/Deadwire/BuildActions.lua` — Per-type sprites, consume kit item
- `server/Deadwire/ServerCommands.lua` — WireTriggered handler
- `client/Deadwire/ClientCommands.lua` — wireTriggered wrapper
- `client/Deadwire/UI.lua` — Kit-gated placement menu, friendly remove labels
- `README.md` — Updated current state and project structure

---

## Key Discoveries (Session 9)

| Finding | Detail |
|---------|--------|
| OGG must be mono | Stereo files fail silently with `is3D = true`. No error logged. |
| Item icons path | `media/textures/Item_Name.png` — no subdirectory, `Item_` prefix |
| Translation format | `ItemName_EN.txt`, table `ItemName_EN`, keys `ItemName_Base.ItemName` |
| World sprites need tilesheet | Individual PNGs don't work for IsoThumpable. Must be `.pack` + `.tiles` |
| `/additem` broken in B42 console | Evaluates as Lua, `Base` is null. Use item spawner UI instead. |
| `setIsThumpable(true)` | Makes zombies target wire for destruction. Must be false for trip wires. |

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

---

## Session History

### Session 9 (2026-02-22): Sprint 3 code complete + fixes

- Implemented all Sprint 3 code: handlers, sounds, items, recipes, loot, translations
- Two rounds of in-game testing, diagnosed and fixed 6 bugs
- Root cause analysis: stereo OGGs, wrong icon paths, wrong translation format, passability flags
- Converted OGGs to mono, fixed all code issues
- Discovered individual PNGs don't work for world sprites — need .pack/.tiles
- Decided to build Python packer tool (Issue #11) instead of TileZed or pz-pack
- Installed Rust (no MSVC linker available), confirmed Python 3.11 as tool stack
- Created Issues #9, #10, #11

### Session 8 (2026-02-21): Sprint 2 PASSED

- CRITICAL FIX: Moved BuildActions.lua from client/ to server/
- Sprint 2 in-game test PASSED (all 6 tests)

### Sessions 1-7: See context.md

---

## To Resume

```
Deadwire — Sprint 3 code complete, blocked on custom sprites.
Next: Build Python .pack/.tiles packer tool (Issue #11).
Reference: pz-pack Rust source at /tmp/pz-pack, vanilla .tiles in PZ install dir.
After tool: generate tilesheet, update Config.lua, test Sprint 3 end-to-end.
```
