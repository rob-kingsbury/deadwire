# Deadwire

Perimeter trip lines and electric livestock fencing for Project Zomboid (Build 42+).

## What Is This

A tiered base defense mod that adds what vanilla PZ is missing: perimeter alarm and deterrent systems built from the mundane materials already scattered across 1993 rural Kentucky.

**Tier 0** — Tin cans on fishing line. No skills. Day one.
**Tier 1** — Wire trip lines with bells. Reusable. Chainable.
**Tier 2** — Mechanical pull-alarm system. Bell rings inside your base when the perimeter is breached.
**Tier 3** — Electric livestock fencing. Staggers zombies, drains power, fails when the battery dies.
**Tier 4** — Modified chargers, trip-wire detonation, electrified barbed wire.

Nothing is overpowered. You get information and time. What you do with it is up to you.

## Status

**Pre-alpha.** Design document complete. Implementation in progress.

See [docs/DESIGN.md](docs/DESIGN.md) for the full design document.

## Requirements

- Project Zomboid Build 42+
- No other mod dependencies

## Installation

Not yet available. Will be published to the Steam Workshop when Phase 1 (MVP) is ready.

## Project Structure

```
deadwire/
  mod.info                  # PZ mod metadata
  media/
    lua/
      client/               # Client-side Lua (UI, rendering)
      server/               # Server-side Lua (authoritative logic)
      shared/               # Shared Lua (definitions, utilities)
    scripts/
      items/                # Item definitions
      recipes/              # Legacy recipe format
      craftRecipes/         # B42 craft recipe definitions
    textures/Items/         # Item icons
    sound/                  # Sound effects
  docs/
    DESIGN.md               # Condensed design document
```

## License

TBD
