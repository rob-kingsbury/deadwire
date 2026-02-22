# Deadwire

Perimeter trip lines and electric fencing for Project Zomboid (Build 42+).

## What it does

Adds perimeter alarm and defense systems using the junk and hardware already lying around 1993 rural Kentucky. Tin cans, fishing line, wire, bells, barbed wire, electric fence chargers from every farm supply store in the county. Vanilla PZ gives you none of this. Deadwire fills that gap.

You're not building turrets. You're stringing cans on fishing line between fence posts so you hear something coming before it's at your door. At the high end you're wiring up a fence charger from a barn to a car battery so the dead get a jolt when they push through. Nothing here makes you safe. You get information and time.

### Tiers

- **Tier 0** -- Tin cans on fishing line. No skills needed. Day one survival.
- **Tier 1** -- Wire trip lines with bells. Reusable, longer range, chainable along fences.
- **Tier 2** -- Mechanical pull-alarm. Trip wire at the perimeter, bell rings inside your base.
- **Tier 3** -- Electrified perimeter fencing. Staggers zombies on contact. Drains power. Dies when the battery does.
- **Tier 4** -- Modified chargers, trip-wire detonation, electrified barbed wire.

### Camouflage

Hide your trip wires with foraged twigs and branches. Other players need Foraging skill to spot them. Low Foraging sees nothing. High Foraging sees a faint shimmer, then a clear outline. Degrades in rain. Your faction always sees your own wires.

This is the PvP feature. Your perimeter alarm becomes a hidden intelligence network.

## Multiplayer

Built for MP from the start. Server-authoritative, no client-side cheating. Everything important is validated on the server before it happens.

- Per-player camouflage visibility based on individual Foraging skill
- Faction wire sharing
- Wire placement logging for admins investigating griefing
- Owner immunity and friendly fire toggles
- All gameplay values server-synced via SandboxVars

Works fine in singleplayer too.

## Installation

Subscribe on the Steam Workshop. Enable the mod in your mod list. That's it.

For manual install, drop the `Contents/mods/Deadwire` folder into your PZ mods directory.

## Server Configuration

### Basic settings

The mod ships with 14 server settings that cover what most admins actually want to change. You'll find them in the Deadwire page of your sandbox options.

| Setting | Default |
|---------|---------|
| Enable Deadwire mod | On |
| Allow players to camouflage wires | On |
| Max placed wires per player | 50 |
| Wires trigger on player contact | On |
| Global sound radius multiplier | 1.0x |
| Tin can trip lines are single-use | On |
| Tin can wire durability | 50 |
| Reinforced wire durability | 150 |
| Damage dealt to players who trip a wire | 5 |
| Players stumble when tripping a wire | On |
| Faction members trigger each other's wires | On |
| Wire placer is immune to their own wires | Off |
| How often bells appear in loot | Common |
| Log wire placements to server log | On |

These defaults are tuned for a standard PvP server. Most servers won't need to change anything.

### Advanced settings

If you want full control, there are 60 options available covering individual sound radii, break chances, cooldown timers, tanglefoot zone settings, camouflage detection thresholds and degradation rates, and more.

To enable the advanced settings:

1. Find `docs/sandbox-options-advanced.txt` in the mod folder
2. Copy it to `Contents/mods/Deadwire/42/media/sandbox-options.txt`, replacing the basic file
3. Restart the server or start a new game

The advanced options are spread across 7 settings pages: General, Sound, Trip Lines, Tanglefoot, Camouflage, Multiplayer, and Loot. Every gameplay-affecting value in the mod is tunable.

You can also edit sandbox vars directly in your server's save files if you know what you're doing.

## Requirements

- Project Zomboid Build 42+
- No other mod dependencies

## Current State

Phase 1 (Tier 0 + Tier 1) is in active development. What works right now:

- **Wire placement** -- Right-click ground with a kit in inventory to place trip lines. Four types: tin can, reinforced, bell, tanglefoot.
- **Detection** -- Zombies and players crossing a wire tile trigger the wire. Per-type behavior: noise alerts for alarm wires, knockdown for tanglefoot.
- **Sound effects** -- Tin can rattle, wire rattle, bell ring. Positional 3D audio attracts nearby zombies.
- **Crafting** -- Three kit recipes using vanilla materials (tin cans, fishing line, wire, nails, bells).
- **Removal** -- Right-click a placed wire to pick it up. Owner and admin only.
- **Multiplayer** -- Server-authoritative state, client commands validated before execution.
- **Sandbox options** -- 14 tunable settings (sound radius, durability, player damage, etc.)

Not yet implemented: camouflage system, custom world sprites (using vanilla placeholder), electric fencing (Phase 3), pull-alarms (Phase 2).

## Project Structure

```
Contents/mods/Deadwire/
  mod.info
  42/
    mod.info
    media/
      lua/
        shared/Deadwire/        -- Wire network, config
        shared/Translate/EN/    -- Translation files (sandbox, items, recipes)
        client/Deadwire/        -- Detection, trigger handlers, UI, client commands
        server/Deadwire/        -- Wire manager, build actions, server commands, loot
      scripts/                  -- Item, recipe, and sound definitions
      sound/                    -- OGG sound effects (mono, 3D positional)
      textures/                 -- Item icons (32x32 PNG)
      sandbox-options.txt       -- Server settings (basic, 14 options)
  common/                       -- Required empty dir (B42 structure)
docs/
  sandbox-options-advanced.txt  -- Full server settings (60 options)
  DESIGN.md                     -- Game design document
  IMPLEMENTATION-PLAN.md        -- Technical plan
  SPRITES.md                    -- Sprite checklist (all phases)
```

## License

TBD
