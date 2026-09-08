# Archived session write-ups

Moved out of `.claude/context.md` by `.claude/hooks/context-prune.cjs`, which keeps
the newest three in the live file. Nothing loads this file; it is here because why
a thing was done a certain way is worth keeping and is worth nothing on every turn.

Read it when a decision looks arbitrary and you want to know what it cost.

---

## Art and sprite pipeline (sessions 15, 18, 19)


`tools/process_sprite_render.py` is the whole pipeline: hue-key the magenta,
erode the blend ring, area-average down to 64 wide, anchor to the tile's ground
edge, mirror east into north. Its docstring holds the working Gemini prompts.

**The geometry rule that matters:** in PZ's projection both facings are
diagonal and mirrored about the vertical axis. There is no flat-horizontal
orientation. The Session 10 placeholders drew north flat, which is why they
looked wrong rather than merely crude. Verified against vanilla `fencing_01`
sprites extracted with `pz_unpack.py`.

**Index hazard:** `pz_tilesheet.py` globs `deadwire_*.png` alphabetically.
A new sprite that sorts earlier renumbers everything after it, and
`DeadwireConfig.Sprites` holds those indices by hand. Adding `electric` in
Session 18 moved reinforced/tanglefoot/tincan from 2,4,6 to 4,6,8.

```
0/1 bell      2/3 electric (banked for #13, absent from Sprites on purpose)
4/5 reinforced   6/7 tanglefoot   8/9 tincan
```

Stake height above the ground line, after the Session 19 replacement:

| sprite | above ground |
|---|---|
| tincan, bell, reinforced, electric | 18px |
| tanglefoot | 6px |

Previously these ranged 22 to 32 and the tall ones read as fences rather than
trip lines.

**At 32px, silhouette contrast beats object identity.** An icon pass that shrank
the pale wire coil to enlarge the cans produced a brown blob on a dark
inventory panel. The coil is not filler, it is the high-contrast shape that
makes the item findable in a list. Tanglefoot is the clearest case the other
way: it reads instantly at 1x purely because the whole coil is rust-coloured.

**A local ComfyUI pipeline was built and abandoned.** SDXL with a pixel-art
LoRA holds composition once the hanging objects are drawn into the ControlNet
skeleton, but it renders thin and washed out at this scale and lost every
comparison against the existing art. The models are installed at C:/ai/ComfyUI
if anyone wants them; the generation half is not worth rebuilding.


---

## Session 18 bugs, in full


### `isServer()` is FALSE in single-player

`LootDistribution.lua` opened with `if not isServer() then return end`, so the
merge returned immediately and **no Deadwire loot has ever spawned in any
single-player game**. Not bells, not kits, not once.

In PZ single-player, `isServer()` and `isClient()` are **both false**.
`isServer()` is true only on a dedicated server. The correct guard for "the
authoritative side" is:

```lua
if isClient() then return end   -- runs in SP and on the dedicated server
```

`TriggerHandlers.lua` already used `if not isClient()` correctly, with a comment
explaining it. The knowledge was in the repo; the loot file just never got it.

### The crafting category key was wrong, and the checker agreed with it

The mod shipped `IGUI_CraftCategory_Deadwire`. B42 uses
**`IGUI_CraftingCategories_Deadwire`**. The sidebar rendered the raw key.

`verify_names.py` had the wrong prefix hardcoded and had been reporting it
green. A checker that encodes a remembered fact rather than a checked
relationship is worse than no checker: it converts an unverified belief into a
green tick. It now derives both category prefixes from the game's own
`IG_UI.json` and fails loudly if neither is found. Same fix applied to
`validate_pack.py`, which hardcoded "8 sprites" and failed the moment a
legitimate 9th and 10th were added.

The wrong prefix lived in exactly two places, the mod's `IG_UI.json` and
`verify_names.py`, and they agreed with each other. Nothing else in the repo or
in auto-memory recorded it, so there was no third source to catch the
disagreement. That is the shape to watch for: a checker and its subject sharing
one unverified assumption looks identical to a passing test.

### Inventory icons had opaque backgrounds

All four were 100% opaque, alpha 255 on every pixel, sitting on grey boxes in
the inventory. Rebuilt from the 1024x1024 originals with an edge flood-fill and
a premultiplied downscale. A plain white colour-key would have punched holes
through the tin cans, which is why the fill runs inward from the border.


---

### Session 17 (2026-08-05/06): eleven silent failures, six PRs

Built `scripts/verify_names.py` + `pzclass.py` **before** fixing anything.
Closed #14–#18 and found six more bugs on no issue at all. PRs #19–#24.

`Perks.Foraging` nil so camo was invisible forever (#17); the entire Climate
call was fiction so camo never degraded (#18); `Capability.CanBuildAnywhere` in
three places (#14); two MP exploits (#15); cooldowns in game time and checked on
the wrong side (#16). Found by the verifier: `ChurchStorageMisc` does not exist;
both Tier 1 recipes required the nonexistent perk `Carpentry`; **all three
translation files were named `*_EN.json` and were never loaded**; no
`IG_UI.json` existed; four sandbox options were read by no code.

### Session 16 (2026-08-05): B42.20.2 audit — six silent failures, three fixed

Audited against an installed 42.20 rather than docs. Fixed four bad loot table
names, a kit item id typo, and `Base.TreeBranch`. Filed #14–#18.
`pz-mod-checker scan` reported clean before and after and caught none of it.

### Session 15 (2026-04-14): Gemini inventory icons + pz_unpack.py

Built `pz_unpack.py` at `c:/xampp/htdocs/pz-tilesheet/`. Generated all 4
inventory icons — on opaque white backgrounds, which Session 18 had to fix.

---

### Session 20 (2026-09-06): the review

A Fable agent read all 2,136 lines against the installed jar with `javap`, not
inference. Fourteen findings, eleven confirmed, filed as #31 to #43. Report in
`docs/REVIEW-30.md`. Established the five run-mode facts above, and found two of
PLAN.md's own "expected behaviour" lines were fiction.
