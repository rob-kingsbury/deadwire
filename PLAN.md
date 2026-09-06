# Deadwire Plan

Living plan document. The pz-tilesheet build and the 0.1.0 to 0.1.1 version bump
that used to fill this file are both finished; the `.pack` and `.tiles.txt`
format specs that were written up here now live in `../pz-tilesheet/README.md`,
which is the tool's own repo and the right place for them.

---

## Session 20: full code review before Phase 2 (#30)

### What we are actually doing

Two passes over the same 2,136 lines of Lua. Fable hunts for bugs and writes the
fix plan. Opus executes it. Nothing new gets built until the existing code is
believed.

The reason this is worth a whole session: Session 16 found six silent failures,
Session 17 found eleven, Session 18 found three more. None of them threw an
error. Every one of them was a thing that looked correct, ran without complaint,
and did nothing. That rate has not yet flattened out, which is the only evidence
that matters for whether another pass will pay.

### The code under review

| File | Lines | Runs on |
|---|---|---|
| `server/ServerCommands.lua` | 366 | server |
| `shared/WireNetwork.lua` | 259 | both |
| `server/WireManager.lua` | 258 | server |
| `client/TriggerHandlers.lua` | 198 | client |
| `shared/Config.lua` | 196 | both |
| `client/EventHandlers.lua` | 174 | client |
| `client/Detection.lua` | 128 | client |
| `client/UI.lua` | 127 | client |
| `client/CamoVisibility.lua` | 111 | client |
| `server/CamoDegradation.lua` | 93 | server |
| `server/BuildActions.lua` | 89 | server |
| `server/LootDistribution.lua` | 81 | server |
| `client/ClientCommands.lua` | 56 | client |

Plus the data files that are just as capable of failing silently:
`deadwire_items.txt`, `deadwire_recipes.txt`, `deadwire_sounds.txt`,
`sandbox-options.txt`, and the four JSON files under `Translate/EN/`.

### Expected behaviour, so the review has something to check against

This is the spec. Where the code disagrees with this list, one of the two is
wrong and the review says which.

**Tin can trip line (tier 0).** Health 50, spans up to 4 tiles, breaks when
triggered. Makes a rattle audible to zombies within 25 tiles at volume 60. The
break-on-trigger behaviour is the one property a server owner can turn off
(`TinCanBreakOnTrigger`), and health is settable (`TripLineHealth`).

**Reinforced trip line (tier 1).** Health 150 (settable via
`ReinforcedHealth`), spans up to 8, survives being triggered, 36 real seconds of
cooldown before it can fire again, sound radius 40 at volume 80.

**Bell trip line (tier 1).** Same as reinforced except sound radius 60 and a
different clip. No health sandbox option on purpose. Right now it is otherwise
stat-identical to reinforced, which is #27 and is a balance decision Rob owes us,
not a bug.

**Tanglefoot (tier 1).** Health 100, occupies one tile, 40 percent chance to trip
whatever walks in, 3 seconds prone. No sound.

**Cooldowns are real seconds** measured with `os.time`, and they broadcast as a
duration rather than an absolute time, because two machines' clocks do not agree.

**Camouflage** hides a wire from anyone who is not its owner or in the owner's
group, degrades in rain, and its visibility check keys off the Foraging perk
(`Perks.PlantScavenging` internally).

**Everything authoritative happens server-side.** Client detects and asks, server
validates and decides, server broadcasts, clients play the sound. A client that
lies gets refused.

### What the hunt is looking for, in priority order

1. **Guards that are never true, or always true.** The `isServer()` bug is the
   template: a single-player game has `isServer()` and `isClient()` both false, so
   `if not isServer() then return end` disabled loot for the life of the mod
   without one line of log output. Every early-return in the codebase gets asked
   the same question: under which of the three run modes (single player, hosted
   client, dedicated server) is this branch taken?
2. **Names that do not resolve.** `python scripts/verify_names.py` covers 109 of
   them and is the only checker in this repo that has ever caught anything. The
   hunt's job is to find the references it does not cover yet, and to widen it.
3. **Settings that nothing reads.** Four sandbox options were found in Session 17
   being offered to server owners while no code looked at them. Every option in
   `sandbox-options.txt` needs a reader.
4. **Two things that agree with each other and nothing else.** The crafting
   category prefix was wrong in exactly two places, and those two places were the
   mod and the checker written to verify the mod. Any value that appears twice
   and is verified nowhere is the same shape.
5. **Client authority leaks.** Two multiplayer exploits were fixed in Session 17.
   Assume there are more; check every `OnClientCommand` argument for whether the
   server re-derives it or trusts it.
6. **The `WireNetwork` graph walk at perimeter scale.** It is the foundation for
   the fence electrification idea, and nobody has looked at what it costs on a
   long run of wire.

### Two loose ends the survey turned up

- `media/` ships both `deadwire_01.tiles` (120 bytes) and
  `deadwire_01.tiles.txt` (981 bytes), and they are not the same file. `mod.info`
  says `tiledef=deadwire_01 200`. Only one of these can be the one PZ reads.
  Find out which, delete the other.
- `DeadwireConfig.FALLBACK_SPRITE = "construction_01_24"` is a metal wall frame
  standing in for a missing sprite. All ten real sprites now exist and are
  verified in-game, so this may be a guard with nothing left to guard.

### The oracles

Use the sibling projects, not general Lua advice.

- `../unbreaker` and `../pz-head-for-the-hills` are our own shipped B42 mods.
- `../pz-test-pilot` is the live harness, for anything that needs a running game.
- `../pz-tilesheet` for sprite and tiledef questions.
- **Do not trust `../pz-mod-checker`.** It reported this repo clean before and
  after the Session 16 audit and caught none of the six failures found that day,
  nor the eleven from Session 17. A clean result from it is not evidence.

### Done means

- Every finding is either fixed, or filed as an issue with the evidence in it.
- `run_tests.bat` still passes (159 at the start of the session).
- `python scripts/verify_names.py` still exits 0, and covers more than 109
  references than it did at the start if the hunt found a gap.
- `python tools/validate_pack.py` still passes its 130 checks.
- The mod is synced to `C:/Users/roban/Zomboid/mods/Deadwire/`.

### What this session cannot settle

Sounds actually being audible, camouflage actually being invisible, rain actually
degrading it, and a zombie actually walking into a wire. Those are the remainder
of #25 and they need someone sitting in a running game. Multiplayer cooldowns
cannot be tested in single player at all. The review can prove the code is
*capable* of being right; only the harness proves it *is*.
