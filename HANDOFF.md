# Deadwire - Handoff

## Current Priority

**Phase 1 MVP — Sprint 1: Foundation**

Project has design doc and implementation plan complete. No Lua code written yet. Next step is mod scaffolding and core systems.

---

## Status

| Area | Status | Notes |
|------|--------|-------|
| Design Document | Done | `docs/DESIGN.md` |
| Implementation Plan | Done | `docs/IMPLEMENTATION-PLAN.md` |
| Mod Scaffolding | Not Started | mod.info, directory structure, Config.lua |
| Sprint 1 (Foundation) | Not Started | WireNetwork, Detection, ServerCommands, EventHandlers |
| Sprint 2 (Placement) | Not Started | ISBuildingObject, context menus, timed actions |
| Sprint 3 (Sound+Trigger) | Not Started | Handlers, loot, items, recipes |
| Sprint 4 (Camo+Config) | Not Started | CamoVisibility, SandboxVars, ModOptions |
| Phase 2 (Pull-Alarms) | Not Started | Tier 2 |
| Phase 3 (Electric) | Not Started | Tier 3 |
| Phase 4 (Advanced) | Not Started | Tier 4 |

---

## Blockers

None currently.

---

## Key Technical Decisions

| Decision | Rationale | Date |
|----------|-----------|------|
| `OnZombieUpdate` + hash-table | Only proven pattern for tile detection. O(1) lookup. | 2026-02-20 |
| `IsoThumpable` per-tile | Vanilla barbed wire uses this exact pattern. | 2026-02-20 |
| `module Base` | Custom modules broken in B42 MP. | 2026-02-20 |
| Legacy generator system | Component/wiring system not fully implemented in B42. | 2026-02-20 |
| `setAlphaAndTarget()` for camo | Global alpha operates per-client in network MP. | 2026-02-20 |
| SandboxVars over ModOptions | Gameplay values must be server-synced. ModOptions is client-only. | 2026-02-20 |
| Camouflage in Phase 1 | Highest MP value feature, minimal additional code (~260 lines). | 2026-02-20 |
| `deadwire:tagname` namespace | Required since 42.13. | 2026-02-20 |

---

## Files Modified (Session 2)

| File | Changes |
|------|---------|
| `.claude/context.md` | Created: project state with YAML header |
| `.claude/settings.json` | Created: WebFetch permissions for PZ domains |
| `.claude/rules/development-workflow.md` | Created: PZ-specific workflow rules |
| `.claude/skills/session-start/SKILL.md` | Created: session initialization skill |
| `.claude/skills/handoff/SKILL.md` | Created: session handoff skill |
| `CLAUDE.md` | Created: project config with session start/end |
| `HANDOFF.md` | Restructured: added status table, blockers, decisions |

---

## Session History

### Session 2 (2026-02-20): Session workflow infrastructure

- Created session-start and handoff skills (adapted from AITA)
- Created CLAUDE.md, context.md, development-workflow.md
- Structured HANDOFF.md with status table (adapted from gen-network)
- Added mod sync rule for PZ testing

### Session 1 (2026-02-20): Research + Planning

- Created GitHub repo and project scaffolding
- Ran 6 parallel research agents on B42 modding APIs
- Wrote full implementation plan with code examples
- Designed camouflage system (per-client alpha via Foraging skill)
- Designed 73 SandboxVars across 9 settings pages
- Commits: `fe094d7`, `53d15c2`, `33a6744`

---

## Next Steps

1. Mod scaffolding: `mod.info`, directory structure under `Contents/mods/Deadwire/42/`
2. `Config.lua`: Constants, wire type definitions
3. `WireNetwork.lua`: Hash-table tile index (shared)
4. `Detection.lua`: `OnZombieUpdate` + `OnPlayerUpdate`
5. `ServerCommands.lua`: `OnClientCommand` dispatcher
6. `EventHandlers.lua`: `OnServerCommand` listener
7. Test: hardcode a wire tile, walk zombie into it, verify detection fires

---

## Research References

- [Spear Traps source](https://github.com/quarantin/zomboid-spear-traps) -- tile detection pattern
- [Vanilla ISBarbedWire.lua](https://github.com/Project-Zomboid-Community-Modding/ProjectZomboid-Vanilla-Lua) -- placement pattern
- [Konijima PZ-BaseMod](https://github.com/Konijima/PZ-BaseMod) -- MP command pattern
- [Immersive Solar Arrays](https://github.com/radx5Blue/ImmersiveSolarArrays) -- custom power system
- [PZEventDoc](https://github.com/demiurgeQuantified/PZEventDoc) -- B42 event list
- [B42 Mod Template](https://github.com/LabX1/ProjectZomboid-Build42-ModTemplate) -- folder structure

---

## To Resume

```
Deadwire — Start Phase 1 Sprint 1 (Foundation).
Design and implementation plan complete, no code written yet.
Read CLAUDE.md and .claude/context.md for full project context.
```
