#!/usr/bin/env python3
"""Generate the AngelCode BMFont pair Connect IQ needs for the clock digits.

Connect IQ has no runtime font rasteriser, so a custom face has to ship as a
`.fnt` descriptor plus a `_0.png` glyph atlas. This bakes the Chivo digits into
that pair.

    python3 tools/make_clock_font.py                     # default: 66 px, weight 700
    python3 tools/make_clock_font.py --px 95 --weight 700 --name Chivo95
    python3 tools/make_clock_font.py --out resources-round-280x280/fonts --name Chivo72

Chivo is under the SIL Open Font License; tools/fonts/OFL.txt is the licence and
tools/fonts/Chivo[wght].ttf the source. Only the digits and a space are baked in
(the face never draws a colon).
"""

import argparse
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
TTF = os.path.join(HERE, "fonts", "Chivo[wght].ttf")
CHARSET = "0123456789 "
ATLAS = 256  # page size; the digits use only a small corner of it


def build(px, weight, out_dir, name):
    font = ImageFont.truetype(TTF, px)
    try:
        font.set_variation_by_axes([weight])
    except Exception:
        pass  # not a variable build; weight baked in already

    ascent, descent = font.getmetrics()
    line_height = ascent + descent

    # Render each glyph tight, remember where it sits relative to the pen.
    glyphs = []
    for ch in CHARSET:
        if ch == " ":
            glyphs.append((ch, None, 0, 0, round(font.getlength(ch))))
            continue
        box = font.getbbox(ch)  # (l, t, r, b), pen at top-left of the line box
        w, h = box[2] - box[0], box[3] - box[1]
        tile = Image.new("L", (box[2] + 2, box[3] + 2), 0)
        ImageDraw.Draw(tile).text((0, 0), ch, font=font, fill=255)
        glyph = tile.crop((box[0], box[1], box[2], box[3]))
        glyphs.append((ch, glyph, box[0], box[1], round(font.getlength(ch))))

    # Shelf-pack into the atlas.
    atlas = Image.new("L", (ATLAS, ATLAS), 0)
    pen_x, pen_y, shelf_h = 1, 1, 0
    placed = []
    for ch, glyph, xoff, yoff, xadv in glyphs:
        if glyph is None:
            placed.append((ch, 0, 0, 0, 0, xoff, yoff, xadv))
            continue
        w, h = glyph.size
        if pen_x + w + 1 > ATLAS:
            pen_x, pen_y, shelf_h = 1, pen_y + shelf_h + 1, 0
        if pen_y + h + 1 > ATLAS:
            raise SystemExit("atlas too small for %d px; raise ATLAS" % px)
        atlas.paste(glyph, (pen_x, pen_y))
        placed.append((ch, pen_x, pen_y, w, h, xoff, yoff, xadv))
        pen_x += w + 1
        shelf_h = max(shelf_h, h)

    os.makedirs(os.path.join(HERE, os.pardir, out_dir), exist_ok=True)
    png_name = "%s_0.png" % name
    atlas.save(os.path.join(HERE, os.pardir, out_dir, png_name))

    lines = [
        'info face="Chivo" size=%d bold=%d italic=0 charset="" unicode=1 '
        'stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=1,1 outline=0'
        % (px, 1 if weight >= 700 else 0),
        'common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0 '
        'alphaChnl=1 redChnl=0 greenChnl=0 blueChnl=0'
        % (line_height, ascent, ATLAS, ATLAS),
        'page id=0 file="%s"' % png_name,
        "chars count=%d" % len(placed),
    ]
    for ch, x, y, w, h, xoff, yoff, xadv in placed:
        lines.append(
            "char id=%-4d x=%-5d y=%-5d width=%-5d height=%-5d "
            "xoffset=%-5d yoffset=%-5d xadvance=%-5d page=0 chnl=15"
            % (ord(ch), x, y, w, h, xoff, yoff, xadv)
        )
    fnt_path = os.path.join(HERE, os.pardir, out_dir, "%s.fnt" % name)
    with open(fnt_path, "w") as fh:
        fh.write("\n".join(lines) + "\n")

    print("wrote %s/%s.fnt + %s  (lineHeight=%d base=%d)"
          % (out_dir, name, png_name, line_height, ascent))


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--px", type=int, default=66, help="nominal em size (default 66)")
    ap.add_argument("--weight", type=int, default=700, help="Chivo weight 100-900 (default 700)")
    ap.add_argument("--out", default="resources/fonts", help="output dir, relative to the repo root")
    ap.add_argument("--name", default=None, help="font base name (default Chivo<px>)")
    args = ap.parse_args()
    build(args.px, args.weight, args.out, args.name or ("Chivo%d" % args.px))


if __name__ == "__main__":
    main()
