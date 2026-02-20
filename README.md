# Deadwire

Perimeter trip lines and electric livestock fencing for Project Zomboid (Build 42+).

## What Is This

A tiered base defense mod that adds what vanilla PZ is missing: perimeter alarm and deterrent systems built from the mundane materials already scattered across 1993 rural Kentucky.

**Tier 0** -- Tin cans on fishing line. No skills. Day one.
**Tier 1** -- Wire trip lines with bells. Reusable. Chainable.
**Tier 2** -- Mechanical pull-alarm system. Bell rings inside your base when the perimeter is breached.
**Tier 3** -- Electric livestock fencing. Staggers zombies, drains power, fails when the battery dies.
**Tier 4** -- Modified chargers, trip-wire detonation, electrified barbed wire.

**Camouflage system** -- Hide your trip wires with foraged materials. Opponents need Foraging skill to detect them. Degrades in rain.

Nothing is overpowered. You get information and time. What you do with it is up to you.

## Multiplayer First

Designed for MP/PvP from the ground up:
- Server-authoritative architecture (no client-side cheating)
- Camouflaged wires: per-player visibility based on Foraging skill
- Faction wire sharing and visibility options
- Wire placement logging for griefing investigation
- 73 SandboxVars across 9 settings pages for total server owner control

Works in singleplayer too. Same features, same progression.

## Status

**Pre-alpha.** Design document and implementation plan complete. Research phase done.

## Documentation

| Document | Contents |
|---|---|
| [docs/DESIGN.md](docs/DESIGN.md) | Full game design document (mechanics, balance, lore) |
| [docs/IMPLEMENTATION-PLAN.md](docs/IMPLEMENTATION-PLAN.md) | Technical implementation plan (B42 APIs, architecture, code examples) |

## Development Phases

| Phase | Content | Status |
|---|---|---|
| Phase 1 (MVP) | Tier 0 + Tier 1 + Camouflage + 73 SandboxVars | Not started |
| Phase 2 | Pull-alarm system (Tier 2) | Planned |
| Phase 3 | Electric livestock fencing (Tier 3) | Planned |
| Phase 4 | Advanced applications (Tier 4) | Planned |

Each phase is an independent Steam Workshop release.

## Technical Foundation

Built on confirmed-working B42 APIs:
- `OnZombieUpdate` + hash-table O(1) tile detection (Spear Traps pattern)
- `IsoThumpable` per-tile objects linked via ModData (vanilla barbed wire pattern)
- `setAlphaAndTarget()` for per-client camouflage visibility
- `WorldSoundManager.addSound()` for zombie-attracting sound events
- `sendClientCommand`/`sendServerCommand` for MP synchronization
- Legacy generator radius system for electric fence power
- `module Base` for MP compatibility (custom modules broken in B42)
- `SandboxVars` for server-synced configuration
- `PZAPI.ModOptions` for client preferences

## Requirements

- Project Zomboid Build 42+
- No other mod dependencies

## Project Structure

```
deadwire/
  Contents/mods/Deadwire/
    42/
      mod.info
      media/
        lua/
          shared/Deadwire/        # Constants, wire network, translations
          client/Deadwire/        # UI, placement, camouflage visibility
          server/Deadwire/        # Detection, wire management, power, degradation
        scripts/                  # Item + recipe definitions
        sandbox-options.txt       # 73 server-configurable options
        textures/Items/           # Item icons
        sound/                    # Sound effects
  docs/
    DESIGN.md                     # Game design document
    IMPLEMENTATION-PLAN.md        # Technical implementation plan
```

## License

TBD
