# Implementation Plan: pz-tilesheet + Version Bump

## Part A: Version Bump & GitHub Setup

### A1. Bump mod version 0.1.0 → 0.1.1
- Edit `Contents/mods/Deadwire/mod.info` — change `modversion=0.1.1`
- Edit `Contents/mods/Deadwire/42/mod.info` — same change

### A2. Create git tag + GitHub release
- `git tag v0.1.1` after commit
- `gh release create v0.1.1 --title "v0.1.1 — Sprint 3 code complete" --notes "..."`

---

## Part B: Python CLI Tool — `pz-tilesheet`

General-purpose tool. Lives at `tools/pz-tilesheet/` in the repo.

### Confirmed Format Specs

**.pack V2 binary format** (verified from pz-pack Rust source + hex dumps):
```
Header:
  "PZPK"           (4 bytes, magic)
  mask              (i32 LE, always 1)
  pages_count       (u32 LE)

Per Page:
  page_name_len     (u32 LE)
  page_name         (UTF-8 bytes)
  entries_count     (u32 LE)
  page_mask         (i32 LE, always 1)

  Per Entry × entries_count:
    entry_name_len  (u32 LE)
    entry_name      (UTF-8 bytes, e.g. "deadwire_01_0")
    x_pos           (u32 LE, pixel X in atlas)
    y_pos           (u32 LE, pixel Y in atlas)
    width           (u32 LE, sprite width)
    height          (u32 LE, sprite height)
    x_offset        (u32 LE, 0 for full-cell sprites)
    y_offset        (u32 LE, 0 for full-cell sprites)
    total_width     (u32 LE, cell width = sprite width)
    total_height    (u32 LE, cell height = sprite height)

  image_data_len    (u32 LE)
  image_data        (raw PNG bytes)
```

**.tiles.txt text format** (verified from vanilla + workshop mods):
```
version = 1

tileset
{
    file = deadwire_01
    size = 8,1
    id = 200

    // deadwire_01_0
    tile
    {
        xy = 0,0
    }
}
```

Key relationships:
- `file = X` in .tiles.txt matches the page_name in .pack
- Entry names = `pagename_index` where index = row * cols + col
- mod.info: `pack=NAME` → `media/texturepacks/NAME.pack`
- mod.info: `tiledef=NAME ID` → `media/NAME.tiles.txt`

### B1. File structure

```
tools/pz-tilesheet/
  pz_tilesheet.py       # Single-file CLI tool (~300 lines)
  README.md             # Usage docs
```

Single file. No package structure. Dependencies: Pillow only (stdlib + Pillow).

### B2. CLI interface

```bash
python pz_tilesheet.py \
  --name deadwire_01 \
  --id 200 \
  --sprites sprites/*.png \
  --cols 8 \
  --out ./output/
```

Arguments:
- `--name` (required): Tilesheet name. Becomes page name in .pack, `file` in .tiles.txt
- `--id` (required): Tile definition ID (100-8190, must be unique across mods)
- `--sprites` (required): Glob or list of PNG files. Sorted alphabetically for deterministic ordering.
- `--cols` (optional, default=8): Columns in the atlas grid. Rows computed automatically.
- `--out` (required): Output directory. Creates `texturepacks/NAME.pack` and `NAME.tiles.txt` inside it.
- `--tile-props` (optional): JSON file mapping sprite names to tile properties (for non-default props)
- `--verbose` / `-v`: Print atlas layout and entry details

### B3. Core logic

1. **Load PNGs**: Read all input files with Pillow. Validate same dimensions. Sort alphabetically.
2. **Build atlas**: Create grid image (cols × rows). Paste sprites left-to-right, top-to-bottom.
3. **Write .pack**: V2 format — PZPK header, one page, N entries, atlas PNG bytes.
4. **Write .tiles.txt**: Text format — version, one tileset block, N tile blocks.
5. **Print summary**: Sprite name → index mapping for integration.

### B4. Tile properties support

Default: tiles with no properties (empty `tile { xy = X,Y }` blocks).

Optional `--tile-props` JSON for custom properties per sprite:
```json
{
  "deadwire_01_0": { "solid": true },
  "deadwire_01_2": { "MaterialType": "Metal_Small" }
}
```

Boolean properties emit `PropertyName =` (flag). String/int properties emit `PropertyName = value`.

### B5. Validation

- All input PNGs must have identical dimensions
- ID must be 100-8190
- Name must be valid (alphanumeric + underscores)
- At least 1 sprite required
- Warn if atlas exceeds 2048×2048 (PZ texture limit)

---

## Part C: Generate Deadwire Tilesheet

### C1. Run the tool

```bash
python tools/pz-tilesheet/pz_tilesheet.py \
  --name deadwire_01 \
  --id 200 \
  --sprites Contents/mods/Deadwire/42/media/textures/deadwire_*.png \
  --cols 8 \
  --out Contents/mods/Deadwire/42/media/
```

Output:
- `Contents/mods/Deadwire/42/media/texturepacks/deadwire_01.pack`
- `Contents/mods/Deadwire/42/media/deadwire_01.tiles.txt`

### C2. Update mod.info (both files)

Add these lines:
```ini
pack=deadwire_01
tiledef=deadwire_01 200
```

### C3. Update Config.lua sprite mapping

Replace the empty `Sprites` table with actual sprite names:
```lua
DeadwireConfig.Sprites = {
    tin_can_tripline =    { north = "deadwire_01_X", east = "deadwire_01_Y" },
    reinforced_tripline = { north = "deadwire_01_X", east = "deadwire_01_Y" },
    bell_tripline =       { north = "deadwire_01_X", east = "deadwire_01_Y" },
    tanglefoot =          { north = "deadwire_01_X", east = "deadwire_01_Y" },
}
```

Exact indices depend on alphabetical sort order of the 8 PNGs.

### C4. Sync to PZ mods folder and provide test steps

---

## Execution Order

1. Build the Python tool (B1-B5)
2. Generate Deadwire tilesheet (C1)
3. Update mod files (C2-C3)
4. Sync + test instructions (C4)
5. Version bump + commit + tag + release (A1-A2)
