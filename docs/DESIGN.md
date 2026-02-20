# Deadwire — Perimeter Trip Lines & Electric Fencing for Project Zomboid

## Mod Design Document v1.0

---

## Executive Summary

Deadwire fills a glaring hole in Project Zomboid: **players have no way to build perimeter alarm or defense systems using the mundane materials that surround them.** The game is set in 1993 rural Kentucky — a landscape full of fishing line, wire, empty cans, barbed wire, and electric fence chargers from every farm supply store in the county. Yet vanilla PZ offers zero way to string a trip wire between two fence posts or electrify a perimeter fence.

This mod adds a tiered progression of perimeter security systems, starting with zero-skill junk solutions (tin cans on fishing line) and scaling up through electrical skill to powered electric livestock fencing. Every component is period-accurate, uses existing vanilla items wherever possible, and is grounded in what a real person would actually build in this situation. Nothing breaks roleplay immersion. Nothing is overpowered. You're buying time and information, not invincibility.

---

## Design Philosophy

### The Realism Test

Every feature in this mod must pass one question: **"Would a person in 1993 rural Kentucky know how to build this with the materials available?"**

- A teenager who went camping knows how to tie cans to fishing line.
- A farmer knows how to wire an electric fence charger to a car battery.
- An electrician knows how to run a pull-wire alarm bell circuit.
- A military veteran or engineer knows about tanglefoot and trip-wire detonation.

If a feature requires knowledge or technology that wouldn't exist in this setting, it doesn't belong in the mod.

### The Balance Test

Nothing in Deadwire should make the player safe. Everything is a trade-off:

- **Tin can lines** alert you but break on first trigger.
- **Wire alarms** work at range but require materials and time to set up.
- **Electric fences** stall zombies but drain power resources constantly.
- **A big enough horde overwhelms everything.**

The mod gives you *information* (something is coming) and *time* (a few seconds of delay). What you do with that information and time is still up to you.

### The Vanilla Integration Test

Deadwire should feel like it belongs in the base game. It uses vanilla items (twine, wire, fishing line, barbed wire, tin cans, nails, car batteries, generators). It respects existing skill trees (Electrical, Carpentry, Trapping). It introduces the minimum number of new items necessary (fence chargers, insulators, bells). New recipe magazines follow vanilla naming conventions and spawn in logical locations.

---

## Tier Overview

### Tier 0: Junk Perimeter Alarms
- No skills required. Day-one crafting.
- Tin cans on fishing line/twine. Single-use. Small sound radius (25 tiles).
- Variants: fishing line (invisible, fragile), twine (visible, slightly durable), glass shard scatter (area, rain-degradable).

### Tier 1: Reinforced Trip Lines
- Carpentry 2 + Trapping 2. No magazine.
- Wire-based, reusable. Longer span (8 tiles). Louder (40-50 tiles).
- Bell option (60 tile radius). Chainable along fence runs.
- Tanglefoot variant (Trapping 3): area denial, trips zombies prone.

### Tier 2: Wired Pull-Alarm System
- Electrical 3 + Carpentry 3. Requires "Farm & Ranch Security Handbook" magazine.
- Mechanical (not electronic) pull-cord system. Bell/horn mounted at base, trip wire at perimeter.
- 100+ tile range. Directional info via separate lines to separate bells.
- Car horn variant (Mechanics 2 salvage): louder but attracts zombies to base.

### Tier 3: Electric Livestock Fencing
- Electrical 5. Requires "Kentucky Farm & Ranch Manual" magazine. Requires power source.
- Fence chargers (scavenge-only), insulators (scavenge or Pottery 2 craft), ground rods.
- Stagger on contact (1-2s), audible zap, power drain per hit.
- Cascade failure: no power = no defense.
- Fire risk (optional, configurable).

### Tier 4: Advanced Applications
- Engineer occupation OR Electrical 7+.
- Modified Fence Charger: higher output, can kill, burns out fast.
- Trip Line Detonation: wire to noise makers or pipe bombs.
- Electrified barbed wire: scratch damage + tangle chance.

---

## New Items

### Scavengeable Only
| Item | Found In | Rarity |
|------|----------|--------|
| Fence Charger | Barns, farm supply, hardware stores, sheds | Moderate |
| Bell | Churches, schools, reception desks, farms | Common (location-specific) |
| Kentucky Farm & Ranch Manual | Farm supply, barns, libraries | Moderate |
| Farm & Ranch Security Handbook | Same + police stations | Moderate |

### Craftable
| Item | Key Ingredients |
|------|----------------|
| Tin Can Trip Line | 3x Empty Tin Can + Fishing Line/Twine + 2x Nails |
| Reinforced Trip Line | Wire + 3x Tin Can/Bell + 2x Nails + Hammer |
| Tanglefoot Zone | 5x Fishing Line + 4x Wooden Stakes + Hammer |
| Pull-Alarm Trigger | Wire + Spring + 2x Nails + Screwdriver |
| Ceramic Insulator | Clay (pottery workbench, Pottery 2) |
| Ground Rod | Iron Pipe/Metal Rod + Hammer + Wire |

---

## Phasing

### Phase 1 — MVP
Tier 0 + Tier 1 + sound events + new items + ModOptions

### Phase 2 — Pull-Alarms
Tier 2 + magazine + car horn salvage

### Phase 3 — Electric Fencing
Tier 3 + chargers + insulators + power system + pottery integration

### Phase 4 — Advanced
Tier 4 + modified charger + detonation + electrified barbed wire + fire risk

---

See full design document for detailed mechanics, multiplayer considerations, B43 NPC readiness, ModOptions configuration, and technical implementation notes.
