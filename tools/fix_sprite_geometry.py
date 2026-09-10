#!/usr/bin/env python3
"""Re-anchor the Deadwire world sprites onto the tile's real ground diamond.

Why this exists
---------------
Every sprite shipped through Session 25 was drawn to the target written in
process_sprite_render.py: "content spans the full 64px width and its bottom
sits at y=96, which is the low end of the tile's 2:1 ground edge running
(0,64) -> (63,96)". No such edge exists on a Project Zomboid tile, and that
target was taken "from the sprites already in the mod", so the art was measured
against itself and agreed.

The real geometry, derived from the game's own files rather than remembered:
every floor tile in media/texturepacks/Tiles1x.floor.pack is a 63x32 image
pasted at offset (0,96) inside a 64x128 cell. So the ground diamond is

    N(32,96)   E(64,112)   S(32,128)   W(0,112)

An edge object occupies ONE edge of that diamond, which is 32px wide, not 64.
Vanilla agrees: fencing_01_5 (north) sits at x 30..62, y 59..110, and
fencing_01_4 (west) at x 1..33, y 59..110.

Ours spanned x 0..64 and bottomed out at y=96, so every wire was drawn at
double length and floating entirely above the square it belonged to. That is
#51: the wire covering a character on the neighbouring square.

What this does
--------------
Halves each sprite (nearest neighbour, so the 2:1 diagonal stays 2:1 and only
the pixel detail is lost) and re-seats it on its edge. Detail loss is accepted
deliberately: the source renders were not kept, so a faithful redraw needs a
new render pass, and correct-and-chunky beats wrong-and-detailed for launch.

Slope is measured, not assumed, and the expected slopes were read off the
game rather than reasoned about: in Tiles1x.pack, fencing_01_5 / _17 / _21
(WallN, WallNTrans) all descend left to right and sit at x 29..62, while
fencing_01_4 / _16 / _20 (WallW, WallWTrans) all ascend and sit at x 1..34.
Six for six.

Our facings were also backwards against that: every *_n file held ascending
(west-shaped) art and every *_e file descending (north-shaped) art, so a wire
built on a north edge drew the west sprite. This swaps them, because the
tilesheet indices in DeadwireConfig.Sprites come from the ALPHABETICAL filename
order, so the art has to move rather than the mapping.
"""
import re
import sys
from pathlib import Path
from PIL import Image

TEX = Path("Contents/mods/Deadwire/42/media/textures")

# Matching vanilla's 2px inset (fencing_01_4/5) rather than butting the art
# hard against the diamond's vertices.
NORTH_LEFT, WEST_LEFT, BASELINE = 30, 1, 110
CELL = (64, 128)


def slope(img):
    """+1 if the art descends left to right, -1 if it ascends, 0 if flat.

    Compares the mean row of opaque pixels in the left third against the right
    third. Derived from the pixels so a mis-named file is caught rather than
    silently seated on the wrong edge.
    """
    a = img.split()[3]
    w, h = img.size
    means = []
    for x0, x1 in ((0, w // 3), (w - w // 3, w)):
        ys = [y for y in range(h) for x in range(x0, x1) if a.getpixel((x, y)) > 8]
        if not ys:
            return 0
        means.append(sum(ys) / len(ys))
    diff = means[1] - means[0]
    return 0 if abs(diff) < 2 else (1 if diff > 0 else -1)


def main():
    paths = sorted(TEX.glob("deadwire_*.png"))
    if not paths:
        print("No sprites found under", TEX, file=sys.stderr)
        return 1

    kinds, problems = {}, []
    for p in paths:
        m = re.fullmatch(r"deadwire_(.+)_([en])", p.stem)
        if not m:
            problems.append(f"{p.name}: name is not deadwire_<kind>_<e|n>")
            continue
        img = Image.open(p).convert("RGBA")
        if img.size != CELL:
            problems.append(f"{p.name}: {img.size}, expected {CELL}")
            continue
        bb = img.getbbox()
        if not bb:
            problems.append(f"{p.name}: fully transparent")
            continue
        kinds.setdefault(m.group(1), {})[m.group(2)] = (p, img.crop(bb), bb)

    writes = []
    for kind, pair in sorted(kinds.items()):
        if set(pair) != {"e", "n"}:
            problems.append(f"{kind}: needs both _e and _n, found {sorted(pair)}")
            continue
        by_slope = {}
        for side, (p, art, bb) in pair.items():
            by_slope.setdefault(slope(art), []).append((side, p, art, bb))
        if sorted(by_slope) != [-1, 1] or any(len(v) != 1 for v in by_slope.values()):
            problems.append(
                f"{kind}: need one ascending and one descending sprite, got "
                + ", ".join(f"{s}={'descends' if k == 1 else 'ascends' if k == -1 else 'flat'}"
                            for k, v in by_slope.items() for s, *_ in v))
            continue
        # Descending art belongs on the north edge, ascending on the west,
        # regardless of which file it currently lives in.
        writes.append((pair["n"][0], by_slope[1][0], True))
        writes.append((pair["e"][0], by_slope[-1][0], False))

    if problems:
        print("Refusing to write. Fix these first:", file=sys.stderr)
        for m in problems:
            print("  " + m, file=sys.stderr)
        return 1

    for dest, (src_side, src_path, art, bb), is_north in writes:
        small = art.resize((max(1, art.width // 2), max(1, art.height // 2)), Image.NEAREST)
        cell = Image.new("RGBA", CELL, (0, 0, 0, 0))
        cell.paste(small, (NORTH_LEFT if is_north else WEST_LEFT, BASELINE - small.height))
        swapped = "" if src_path == dest else f"  (art taken from {src_path.name})"
        cell.save(dest)
        print(f"{dest.name:34s} {bb} -> {cell.getbbox()}{swapped}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
