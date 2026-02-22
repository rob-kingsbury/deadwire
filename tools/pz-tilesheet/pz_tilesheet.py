#!/usr/bin/env python3
"""pz-tilesheet: Generate Project Zomboid .pack and .tiles.txt files from PNGs.

Usage:
    python pz_tilesheet.py --name NAME --id ID --sprites *.png --out ./output/

Creates:
    output/texturepacks/NAME.pack   (V2 binary atlas)
    output/NAME.tiles.txt           (tile definitions)
"""

import argparse
import glob
import io
import json
import os
import struct
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("Error: Pillow is required. Install with: pip install Pillow", file=sys.stderr)
    sys.exit(1)

# .pack V2 format constants
PACK_MAGIC = b"PZPK"
PACK_MASK = 1


def write_u32(f, value):
    f.write(struct.pack("<I", value))


def write_i32(f, value):
    f.write(struct.pack("<i", value))


def write_string(f, s):
    encoded = s.encode("utf-8")
    write_u32(f, len(encoded))
    f.write(encoded)


def load_sprites(paths):
    """Load PNG files and validate uniform dimensions."""
    sprites = []
    for path in sorted(paths):
        img = Image.open(path).convert("RGBA")
        sprites.append({"path": path, "name": Path(path).stem, "image": img})

    if not sprites:
        print("Error: No sprites found.", file=sys.stderr)
        sys.exit(1)

    w, h = sprites[0]["image"].size
    for s in sprites[1:]:
        sw, sh = s["image"].size
        if (sw, sh) != (w, h):
            print(
                f"Error: {s['name']} is {sw}x{sh}, expected {w}x{h} "
                f"(matching {sprites[0]['name']}).",
                file=sys.stderr,
            )
            sys.exit(1)

    return sprites, w, h


def build_atlas(sprites, sprite_w, sprite_h, cols):
    """Combine sprites into a single atlas image."""
    count = len(sprites)
    rows = (count + cols - 1) // cols
    atlas_w = cols * sprite_w
    atlas_h = rows * sprite_h

    if atlas_w > 2048 or atlas_h > 2048:
        print(
            f"Warning: Atlas is {atlas_w}x{atlas_h}, exceeds 2048x2048. "
            f"PZ may not load it.",
            file=sys.stderr,
        )

    atlas = Image.new("RGBA", (atlas_w, atlas_h), (0, 0, 0, 0))
    entries = []

    for i, sprite in enumerate(sprites):
        col = i % cols
        row = i // cols
        x = col * sprite_w
        y = row * sprite_h
        atlas.paste(sprite["image"], (x, y))
        entries.append(
            {
                "index": i,
                "col": col,
                "row": row,
                "x": x,
                "y": y,
                "w": sprite_w,
                "h": sprite_h,
                "source": sprite["name"],
            }
        )

    return atlas, entries, rows


def write_pack(out_dir, name, atlas, entries, sprite_w, sprite_h):
    """Write a V2 .pack file."""
    pack_dir = os.path.join(out_dir, "texturepacks")
    os.makedirs(pack_dir, exist_ok=True)
    pack_path = os.path.join(pack_dir, f"{name}.pack")

    # Encode atlas as PNG bytes
    png_buf = io.BytesIO()
    atlas.save(png_buf, format="PNG")
    png_bytes = png_buf.getvalue()

    with open(pack_path, "wb") as f:
        # File header
        f.write(PACK_MAGIC)
        write_i32(f, PACK_MASK)
        write_u32(f, 1)  # one page

        # Page header
        page_name = name + "0"
        write_string(f, page_name)
        write_u32(f, len(entries))
        write_i32(f, PACK_MASK)

        # Entries
        for entry in entries:
            entry_name = f"{name}_{entry['index']}"
            write_string(f, entry_name)
            write_u32(f, entry["x"])
            write_u32(f, entry["y"])
            write_u32(f, entry["w"])
            write_u32(f, entry["h"])
            write_u32(f, 0)  # x_offset
            write_u32(f, 0)  # y_offset
            write_u32(f, sprite_w)  # total_width
            write_u32(f, sprite_h)  # total_height

        # Image data
        write_u32(f, len(png_bytes))
        f.write(png_bytes)

    return pack_path


def write_tiles(out_dir, name, tileset_id, entries, cols, rows, tile_props=None):
    """Write a .tiles.txt file."""
    tiles_path = os.path.join(out_dir, f"{name}.tiles.txt")

    lines = [f"version = 1", "", "tileset", "{"]
    lines.append(f"    file = {name}")
    lines.append(f"    size = {cols},{rows}")
    lines.append(f"    id = {tileset_id}")

    for entry in entries:
        sprite_name = f"{name}_{entry['index']}"
        lines.append("")
        lines.append(f"    // {sprite_name} (from {entry['source']}.png)")
        lines.append("    tile")
        lines.append("    {")
        lines.append(f"        xy = {entry['col']},{entry['row']}")

        # Add custom properties if provided
        if tile_props and sprite_name in tile_props:
            for key, value in tile_props[sprite_name].items():
                if isinstance(value, bool) and value:
                    lines.append(f"        {key} =")
                elif not isinstance(value, bool):
                    lines.append(f"        {key} = {value}")

        lines.append("    }")

    lines.append("}")
    lines.append("")

    with open(tiles_path, "w", newline="\n") as f:
        f.write("\n".join(lines))

    return tiles_path


def validate_args(args):
    if not args.name.replace("_", "").isalnum():
        print("Error: --name must be alphanumeric (underscores allowed).", file=sys.stderr)
        sys.exit(1)
    if args.id < 100 or args.id > 8190:
        print("Error: --id must be 100-8190.", file=sys.stderr)
        sys.exit(1)
    if args.cols < 1:
        print("Error: --cols must be >= 1.", file=sys.stderr)
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(
        description="Generate PZ .pack and .tiles.txt from PNG sprites."
    )
    parser.add_argument("--name", required=True, help="Tilesheet name (e.g. deadwire_01)")
    parser.add_argument("--id", required=True, type=int, help="Tile definition ID (100-8190)")
    parser.add_argument("--sprites", required=True, nargs="+", help="PNG files (globs supported)")
    parser.add_argument("--cols", type=int, default=8, help="Atlas columns (default: 8)")
    parser.add_argument("--out", required=True, help="Output directory")
    parser.add_argument("--tile-props", help="JSON file with per-sprite tile properties")
    parser.add_argument("-v", "--verbose", action="store_true", help="Print details")
    args = parser.parse_args()

    validate_args(args)

    # Expand globs (Windows doesn't expand them automatically)
    sprite_paths = []
    for pattern in args.sprites:
        expanded = glob.glob(pattern)
        if expanded:
            sprite_paths.extend(expanded)
        elif os.path.isfile(pattern):
            sprite_paths.append(pattern)
        else:
            print(f"Warning: No files match '{pattern}'", file=sys.stderr)
    sprite_paths = sorted(set(sprite_paths))

    if not sprite_paths:
        print("Error: No sprite files found.", file=sys.stderr)
        sys.exit(1)

    # Load tile properties if provided
    tile_props = None
    if args.tile_props:
        with open(args.tile_props) as f:
            tile_props = json.load(f)

    # Load and validate
    sprites, sprite_w, sprite_h = load_sprites(sprite_paths)
    if args.verbose:
        print(f"Loaded {len(sprites)} sprites ({sprite_w}x{sprite_h} each)")

    # Build atlas
    atlas, entries, rows = build_atlas(sprites, sprite_w, sprite_h, args.cols)
    if args.verbose:
        print(f"Atlas: {atlas.size[0]}x{atlas.size[1]} ({args.cols} cols x {rows} rows)")

    # Write outputs
    os.makedirs(args.out, exist_ok=True)
    pack_path = write_pack(args.out, args.name, atlas, entries, sprite_w, sprite_h)
    tiles_path = write_tiles(args.out, args.name, args.id, entries, args.cols, rows, tile_props)

    # Summary
    print(f"Pack:  {pack_path}")
    print(f"Tiles: {tiles_path}")
    print(f"Sprites: {len(entries)}")
    print()
    print("Sprite mapping:")
    for entry in entries:
        print(f"  {args.name}_{entry['index']} <- {entry['source']}.png")
    print()
    print("Add to mod.info:")
    print(f"  pack={args.name}")
    print(f"  tiledef={args.name} {args.id}")


if __name__ == "__main__":
    main()
