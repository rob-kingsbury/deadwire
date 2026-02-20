# Deadwire — Sprite Checklist

All custom sprites needed across all four phases. Vanilla items (tin cans, fishing line, twine, wire, nails, hammer, bell, barbed wire, etc.) already have sprites and are not listed here.

---

## Inventory Icons (Item Sprites)

### Phase 1

- [ ] `Deadwire_TinCanTripLineKit` — Bundle of cans threaded on fishing line, ready to place
- [ ] `Deadwire_ReinforcedTripLineKit` — Coiled wire with tin cans/noisemakers attached
- [ ] `Deadwire_BellTripLineKit` — Coiled wire with bell attached

### Phase 2

- [ ] `Deadwire_PullAlarmTrigger` — Small mechanical spring-loaded pull trigger
- [ ] `Deadwire_AlarmBellMount` — Bell bolted to a plank bracket
- [ ] `Deadwire_AlarmHornMount` — Car horn wired to a plank bracket
- [ ] `Deadwire_CarHorn` — Car horn ripped out of a vehicle
- [ ] `Deadwire_Spring` — Coil spring (from mattresses, appliances)
- [ ] `Deadwire_SecurityHandbook` — "Farm & Ranch Security Handbook" book/pamphlet

### Phase 3

- [ ] `Deadwire_FenceCharger` — Boxy electric fence energizer unit
- [ ] `Deadwire_Insulator` — Ceramic knob insulator
- [ ] `Deadwire_GroundRod` — Metal rod with wire wrapped at top
- [ ] `Deadwire_FarmManual` — "Kentucky Farm & Ranch Manual" book

### Phase 4

No new inventory items. Modified charger is a right-click action on the existing FenceCharger.

**Total: 13 inventory icons**

---

## World Sprites (Placed Objects)

Each needs two orientations: north/south (`_n`) and east/west (`_e`).

### Phase 1

- [ ] `deadwire_tincan_n` / `deadwire_tincan_e` — Low fishing line/twine between two points, 2-3 cans dangling
- [ ] `deadwire_reinforced_n` / `deadwire_reinforced_e` — Taut wire at ankle height, slightly thicker than tin can
- [ ] `deadwire_bell_n` / `deadwire_bell_e` — Same as reinforced with a small bell hanging from center
- [ ] `deadwire_tanglefoot_n` / `deadwire_tanglefoot_e` — Criss-cross fishing line on short wooden stakes, ground-level

### Phase 2

- [ ] `deadwire_alarm_trigger_n` / `deadwire_alarm_trigger_e` — Small mechanical device at ground level near a post
- [ ] `deadwire_alarm_bell_n` / `deadwire_alarm_bell_e` — Bell mounted on wall or post with pull wire
- [ ] `deadwire_alarm_horn_n` / `deadwire_alarm_horn_e` — Car horn bolted to wall or post

No sprite for the wire between trigger and bell — it's a logical link, not rendered.

### Phase 3

- [ ] `deadwire_charger_n` / `deadwire_charger_e` — Box unit on ground or mounted to wall
- [ ] `deadwire_insulated_post_n` / `deadwire_insulated_post_e` — Wooden post with ceramic insulator on top
- [ ] `deadwire_elec_wire_n` / `deadwire_elec_wire_e` — Wire between insulated posts, faint glow or spark
- [ ] `deadwire_ground_rod_n` / `deadwire_ground_rod_e` — Metal rod sticking out of ground with wire

### Phase 4

- [ ] `deadwire_charger_modified_n` / `deadwire_charger_modified_e` — Charger with visible jury-rigging (exposed wires, removed panel)
- [ ] `deadwire_elec_barbed_n` / `deadwire_elec_barbed_e` — Barbed wire with spark indicators

**Total: 13 bases x 2 orientations = 26 world sprite files**

---

## Other

- [ ] `poster.png` — Steam Workshop thumbnail (referenced in mod.info)

---

## Summary

| Category | Phase 1 | Phase 2 | Phase 3 | Phase 4 | Total |
|----------|---------|---------|---------|---------|-------|
| Inventory icons | 3 | 6 | 4 | 0 | **13** |
| World sprites (x2) | 4 (8) | 3 (6) | 4 (8) | 2 (4) | **13 (26)** |
| Other | 1 | 0 | 0 | 0 | **1** |
| **Phase total** | **12** | **12** | **12** | **4** | **40** |

## Notes

- Bell (`Base.Bell`) is vanilla — no custom sprite needed
- Camouflage is handled in code via `setAlphaAndTarget()`, not separate sprites
- World sprites go in `Contents/mods/Deadwire/42/media/textures/` as `.png` files
- Inventory icons go in `Contents/mods/Deadwire/42/media/textures/Items/` as `.png` files
- PZ isometric tiles are typically 128x256 or 64x128 depending on object size
- Inventory icons are typically 32x32
