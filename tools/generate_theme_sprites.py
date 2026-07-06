#!/usr/bin/env python3
"""
Neon Grimoire theme — regenerates every HUD icon, rank badge, and adds
missing item / effect sprites. Run from repo root:

    python3 tools/generate_theme_sprites.py

All output PNGs are RGBA and hand-authored pixel-art at the sizes used by
the existing scenes so callers do not need to change texture sizes.
"""
from __future__ import annotations
import math
import os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

REPO = Path(__file__).resolve().parent.parent
UI_DIR = REPO / "assets" / "sprites" / "ui"
ITEMS_DIR = REPO / "assets" / "sprites" / "items"
FX_DIR = REPO / "assets" / "sprites" / "effects"

# Neon Grimoire palette (matches scripts/ui/SynGridPalette.gd).
VOID       = (10, 10, 15, 255)
PANEL      = (20, 20, 26, 255)
PANEL_HI   = (30, 30, 40, 255)
TEAL       = (0, 245, 212, 255)
TEAL_DIM   = (0, 245, 212, 90)
PURPLE     = (123, 47, 190, 255)
PURPLE_DIM = (123, 47, 190, 110)
AMBER      = (212, 130, 62, 255)
SILVER     = (184, 196, 208, 255)
GOLD       = (242, 199, 74, 255)
GOLD_HI    = (255, 232, 140, 255)
GOLD_LO    = (168, 128, 32, 255)
BRONZE     = (198, 128, 74, 255)
BRONZE_HI  = (230, 168, 112, 255)
BRONZE_LO  = (138, 78, 42, 255)
SILVER_HI  = (232, 240, 248, 255)
SILVER_LO  = (120, 132, 148, 255)
DANGER     = (217, 26, 26, 255)
DANGER_HI  = (255, 90, 90, 255)
PARCHMENT  = (232, 228, 216, 255)
TEXT_DIM   = (139, 146, 155, 255)


def _new(size: int) -> Image.Image:
    return Image.new("RGBA", (size, size), (0, 0, 0, 0))


def _outer_glow(img: Image.Image, color, radius: int = 3, alpha: int = 90) -> Image.Image:
    """Composite a soft neon glow underneath img."""
    mask = img.split()[-1]
    glow = Image.new("RGBA", img.size, (color[0], color[1], color[2], 0))
    solid = Image.new("RGBA", img.size, (color[0], color[1], color[2], alpha))
    glow.paste(solid, (0, 0), mask)
    glow = glow.filter(ImageFilter.GaussianBlur(radius))
    return Image.alpha_composite(glow, img)


# ---------- HUD ICONS (32x32) ----------

def icon_gold() -> Image.Image:
    """Engraved coin with a rune on face — replaces flat gold coin."""
    img = _new(32)
    d = ImageDraw.Draw(img)
    # Outer coin body — 3-tone metallic disc
    d.ellipse((2, 2, 29, 29), fill=GOLD_LO)
    d.ellipse((3, 3, 28, 28), fill=GOLD)
    # Top-left highlight (chrome bevel)
    d.ellipse((4, 4, 20, 20), fill=GOLD_HI)
    d.ellipse((7, 7, 26, 26), fill=GOLD)
    # Inner engraved rim
    d.ellipse((6, 6, 25, 25), outline=GOLD_LO, width=1)
    # Rune on face — a "grid + dot" glyph (matches app identity)
    d.rectangle((13, 11, 18, 12), fill=GOLD_LO)
    d.rectangle((13, 19, 18, 20), fill=GOLD_LO)
    d.rectangle((13, 13, 14, 18), fill=GOLD_LO)
    d.rectangle((17, 13, 18, 18), fill=GOLD_LO)
    d.rectangle((15, 15, 16, 16), fill=GOLD_HI)
    return img


def icon_life() -> Image.Image:
    """Crystal-heart glyph. Not a soft cartoon heart — an angular arcane one."""
    img = _new(32)
    d = ImageDraw.Draw(img)
    heart_lo = (150, 20, 20, 255)
    heart_hi = (255, 90, 90, 255)
    # Diamond-heart silhouette: two peaks + a V-point
    poly = [(16, 6), (10, 8), (5, 12), (5, 17), (10, 23), (16, 29),
            (22, 23), (27, 17), (27, 12), (22, 8)]
    d.polygon(poly, fill=DANGER)
    d.polygon(poly, outline=heart_lo, width=1)
    # Facet highlights (crystal edges)
    d.line([(10, 8), (12, 14)], fill=heart_hi, width=1)
    d.line([(22, 8), (20, 14)], fill=heart_hi, width=1)
    d.line([(16, 29), (16, 14)], fill=heart_lo, width=1)
    # Center rune spark
    d.rectangle((15, 13, 16, 14), fill=heart_hi)
    return img


def icon_triumph() -> Image.Image:
    """Orbital laurel — an arcane orb inside a ring, teal neon."""
    img = _new(32)
    d = ImageDraw.Draw(img)
    # Outer laurel ring (dim teal)
    d.ellipse((2, 2, 29, 29), outline=TEAL_DIM, width=2)
    # Six laurel "leaves" positioned around the ring
    for i in range(6):
        a = (i / 6.0) * 2 * math.pi
        cx = 16 + math.cos(a) * 12
        cy = 16 + math.sin(a) * 12
        d.ellipse((cx - 2, cy - 2, cx + 2, cy + 2), fill=TEAL)
    # Inner orb — solid teal with a purple core
    d.ellipse((10, 10, 21, 21), fill=(0, 60, 55, 255))
    d.ellipse((11, 11, 20, 20), fill=TEAL)
    d.ellipse((13, 13, 18, 18), fill=PURPLE)
    d.rectangle((15, 15, 16, 16), fill=(255, 255, 255, 220))
    return _outer_glow(img, TEAL, radius=2, alpha=80)


def icon_round() -> Image.Image:
    """New icon for the ROUND pill — a segmented arcane compass."""
    img = _new(32)
    d = ImageDraw.Draw(img)
    d.ellipse((3, 3, 28, 28), outline=(200, 210, 220, 255), width=1)
    d.ellipse((6, 6, 25, 25), fill=PANEL_HI)
    # 4 cardinal notches
    for a in [0, 90, 180, 270]:
        rad = math.radians(a)
        x1 = 16 + math.cos(rad) * 10
        y1 = 16 + math.sin(rad) * 10
        x2 = 16 + math.cos(rad) * 13
        y2 = 16 + math.sin(rad) * 13
        d.line([(x1, y1), (x2, y2)], fill=TEAL, width=2)
    # Rotating needle pointing NE
    d.line([(16, 16), (22, 10)], fill=PURPLE, width=2)
    d.line([(16, 16), (13, 20)], fill=(90, 90, 100, 255), width=2)
    d.ellipse((14, 14, 18, 18), fill=TEAL)
    return img


# ---------- RANK BADGES (100x100) ----------

def _rank_badge(hi, mid, lo, label: str, glow_color) -> Image.Image:
    """Circular tier medal with a laurel wreath + roman numeral core."""
    img = _new(100)
    d = ImageDraw.Draw(img)
    # Outer medallion (3-tone metal)
    d.ellipse((6, 6, 93, 93), fill=lo)
    d.ellipse((8, 8, 91, 91), fill=mid)
    # Top highlight bevel
    d.ellipse((10, 10, 55, 55), fill=hi)
    d.ellipse((14, 14, 87, 87), fill=mid)
    # Inner recess
    d.ellipse((20, 20, 79, 79), fill=lo)
    d.ellipse((22, 22, 77, 77), fill=mid)
    # Laurel wreath — small dots around the outer edge
    for i in range(24):
        a = (i / 24.0) * 2 * math.pi
        cx = 50 + math.cos(a) * 44
        cy = 50 + math.sin(a) * 44
        d.ellipse((cx - 2, cy - 2, cx + 2, cy + 2), fill=hi)
    # Small stars/notches at cardinals
    for a_deg in [90, 270]:  # top & bottom "clasps"
        a = math.radians(a_deg)
        cx = 50 + math.cos(a) * 44
        cy = 50 + math.sin(a) * 44
        d.polygon([(cx, cy - 5), (cx + 4, cy + 3), (cx - 4, cy + 3)], fill=hi)
    # Center label (roman numeral) - drawn as chunky pixels
    _draw_pixel_roman(d, label, 50, 50, hi, lo)
    return _outer_glow(img, glow_color, radius=4, alpha=110)


def _draw_pixel_roman(d: ImageDraw.ImageDraw, label: str, cx: int, cy: int, fg, shadow) -> None:
    """Very small pixel-art roman numeral rendering for I / II / III."""
    # 5x9 bar strokes; center each I at cx.
    bars = list(label)
    width_per = 6
    total_w = len(bars) * width_per - 2
    start_x = cx - total_w // 2
    for i, ch in enumerate(bars):
        if ch != "I":
            continue
        x = start_x + i * width_per
        # shadow
        d.rectangle((x + 1, cy - 12 + 1, x + 4 + 1, cy + 12 + 1), fill=shadow)
        # main bar
        d.rectangle((x, cy - 12, x + 4, cy + 12), fill=fg)
        # top/bottom serifs
        d.rectangle((x - 2, cy - 12, x + 6, cy - 10), fill=fg)
        d.rectangle((x - 2, cy + 10, x + 6, cy + 12), fill=fg)


def badge_gold() -> Image.Image:
    return _rank_badge(GOLD_HI, GOLD, GOLD_LO, "I", GOLD)


def badge_silver() -> Image.Image:
    return _rank_badge(SILVER_HI, SILVER, SILVER_LO, "II", SILVER)


def badge_bronze() -> Image.Image:
    return _rank_badge(BRONZE_HI, BRONZE, BRONZE_LO, "III", BRONZE)


# ---------- ITEM ICONS (64x64) ----------
# Standardized 64x64 3-tone pixel art. Handles + blades + hafts + fletching.
# Sizes match the existing 64x64 items so ItemCard.tscn needs no code change.

def _shade_line(d, pts, base):
    d.line(pts, fill=base, width=2)


def _bg_frame(cat_tint, radius=6) -> Image.Image:
    """Optional soft category-tint radial bg baked into the icon."""
    img = _new(64)
    d = ImageDraw.Draw(img)
    # Very subtle radial darkening — helps items pop on any panel
    for r, a in [(30, 45), (24, 30), (18, 15)]:
        d.ellipse((32 - r, 32 - r, 32 + r, 32 + r),
                  fill=(cat_tint[0], cat_tint[1], cat_tint[2], a))
    return img


CAT_MELEE = (192, 76, 64)   # warm crimson
CAT_RANGED = (89, 166, 89)  # forest
CAT_ARCANE = (123, 47, 190)  # purple
CAT_SHIELD = (108, 132, 168)  # steel


def _mount(base_glyph: Image.Image, cat_tint) -> Image.Image:
    """Composite item glyph on a subtle radial category tint bg."""
    return Image.alpha_composite(_bg_frame(cat_tint), base_glyph)


def item_iron_sword() -> Image.Image:
    img = _new(64)
    d = ImageDraw.Draw(img)
    # Handle grip (bottom-left to center)
    d.line([(48, 48), (36, 36)], fill=(102, 66, 32, 255), width=4)
    d.line([(48, 48), (36, 36)], fill=(140, 92, 48, 255), width=2)
    # Crossguard
    d.rectangle((30, 30, 40, 34), fill=SILVER_LO)
    d.rectangle((30, 30, 40, 32), fill=SILVER)
    # Blade (mid-body → tip toward upper-right)
    for w, col in [(6, SILVER_LO), (4, SILVER), (2, SILVER_HI)]:
        d.line([(34, 32), (14, 12)], fill=col, width=w)
    # Tip point
    d.polygon([(12, 10), (16, 8), (14, 14)], fill=SILVER_HI)
    # Pommel dot
    d.ellipse((46, 46, 52, 52), fill=SILVER_LO)
    d.ellipse((47, 47, 51, 51), fill=GOLD)
    return _mount(img, CAT_MELEE)


def item_shortsword() -> Image.Image:
    img = _new(64)
    d = ImageDraw.Draw(img)
    d.line([(46, 46), (38, 38)], fill=(102, 66, 32, 255), width=4)
    d.rectangle((32, 32, 44, 36), fill=SILVER_LO)
    d.rectangle((32, 32, 44, 34), fill=SILVER)
    for w, col in [(5, SILVER_LO), (3, SILVER), (1, SILVER_HI)]:
        d.line([(36, 34), (18, 16)], fill=col, width=w)
    d.polygon([(16, 14), (20, 12), (18, 18)], fill=SILVER_HI)
    return _mount(img, CAT_MELEE)


def item_dagger() -> Image.Image:
    img = _new(64)
    d = ImageDraw.Draw(img)
    d.line([(46, 48), (40, 42)], fill=(80, 40, 20, 255), width=3)
    d.rectangle((36, 36, 44, 40), fill=SILVER_LO)
    for w, col in [(4, SILVER_LO), (2, SILVER), (1, SILVER_HI)]:
        d.line([(40, 38), (26, 24)], fill=col, width=w)
    d.polygon([(24, 22), (28, 20), (26, 26)], fill=SILVER_HI)
    d.ellipse((46, 46, 50, 50), fill=PURPLE)
    return _mount(img, CAT_MELEE)


def item_war_hammer() -> Image.Image:
    img = _new(64)
    d = ImageDraw.Draw(img)
    # Handle (long, diagonal)
    d.line([(48, 50), (24, 26)], fill=(102, 66, 32, 255), width=4)
    d.line([(48, 50), (24, 26)], fill=(140, 92, 48, 255), width=2)
    # Hammer head (top)
    d.rectangle((14, 12, 34, 26), fill=SILVER_LO)
    d.rectangle((15, 13, 33, 25), fill=SILVER)
    d.rectangle((15, 13, 33, 16), fill=SILVER_HI)
    # Rivets
    d.ellipse((18, 18, 20, 20), fill=(60, 60, 70, 255))
    d.ellipse((27, 18, 29, 20), fill=(60, 60, 70, 255))
    # Pommel
    d.ellipse((46, 48, 52, 54), fill=GOLD_LO)
    return _mount(img, CAT_MELEE)


def item_greatsword() -> Image.Image:
    img = _new(64)
    d = ImageDraw.Draw(img)
    d.line([(50, 52), (44, 46)], fill=(80, 40, 20, 255), width=5)
    d.rectangle((28, 42, 50, 46), fill=SILVER_LO)
    d.rectangle((28, 42, 50, 44), fill=SILVER)
    for w, col in [(7, SILVER_LO), (5, SILVER), (2, SILVER_HI)]:
        d.line([(40, 44), (14, 10)], fill=col, width=w)
    d.polygon([(12, 8), (18, 6), (16, 14)], fill=SILVER_HI)
    d.ellipse((48, 50, 54, 56), fill=GOLD)
    return _mount(img, CAT_MELEE)


def item_longbow() -> Image.Image:
    img = _new(64)
    d = ImageDraw.Draw(img)
    # Bow arc (arc drawn as polyline through control points)
    arc_pts = []
    for i in range(20):
        t = i / 19.0
        y = 8 + t * 48
        x = 44 - math.sin(t * math.pi) * 24
        arc_pts.append((x, y))
    for w, col in [(5, (80, 44, 20, 255)), (3, (140, 92, 48, 255))]:
        d.line(arc_pts, fill=col, width=w)
    # Bowstring
    d.line([(44, 10), (44, 54)], fill=PARCHMENT, width=1)
    # Arrow nocked
    d.line([(46, 32), (22, 32)], fill=(210, 200, 180, 255), width=1)
    d.polygon([(22, 30), (18, 32), (22, 34)], fill=SILVER_HI)
    # Fletching
    d.polygon([(48, 30), (52, 28), (50, 32)], fill=(220, 100, 100, 255))
    d.polygon([(48, 34), (52, 36), (50, 32)], fill=(220, 100, 100, 255))
    return _mount(img, CAT_RANGED)


def item_crossbow() -> Image.Image:
    img = _new(64)
    d = ImageDraw.Draw(img)
    # Stock
    d.rectangle((14, 32, 50, 40), fill=(102, 66, 32, 255))
    d.rectangle((14, 32, 50, 34), fill=(140, 92, 48, 255))
    # Prod arms
    d.line([(24, 20), (24, 52)], fill=(40, 40, 48, 255), width=2)
    d.line([(24, 20), (44, 24)], fill=(60, 60, 70, 255), width=2)
    d.line([(24, 52), (44, 48)], fill=(60, 60, 70, 255), width=2)
    # String
    d.line([(44, 24), (44, 48)], fill=PARCHMENT, width=1)
    # Bolt
    d.line([(28, 36), (14, 36)], fill=SILVER, width=1)
    d.polygon([(14, 34), (10, 36), (14, 38)], fill=SILVER_HI)
    return _mount(img, CAT_RANGED)


def item_arcane_staff() -> Image.Image:
    img = _new(64)
    d = ImageDraw.Draw(img)
    # Shaft
    d.line([(48, 52), (20, 20)], fill=(80, 44, 108, 255), width=4)
    d.line([(48, 52), (20, 20)], fill=(120, 84, 158, 255), width=2)
    # Wrapping bands
    for t in [0.3, 0.55, 0.75]:
        cx = 48 - (48 - 20) * t
        cy = 52 - (52 - 20) * t
        d.ellipse((cx - 3, cy - 3, cx + 3, cy + 3), fill=GOLD_LO)
    # Orb at top
    d.ellipse((10, 10, 26, 26), fill=(60, 20, 80, 255))
    d.ellipse((11, 11, 25, 25), fill=PURPLE)
    d.ellipse((13, 13, 20, 20), fill=(180, 120, 240, 255))
    d.ellipse((15, 15, 17, 17), fill=PARCHMENT)
    return _outer_glow(_mount(img, CAT_ARCANE), PURPLE, radius=2, alpha=80)


def item_ember_wand() -> Image.Image:
    img = _new(64)
    d = ImageDraw.Draw(img)
    d.line([(48, 52), (24, 28)], fill=(80, 44, 108, 255), width=3)
    d.line([(48, 52), (24, 28)], fill=(120, 84, 158, 255), width=1)
    # Ember tip
    d.ellipse((14, 18, 28, 32), fill=(220, 100, 40, 255))
    d.ellipse((16, 20, 26, 30), fill=(255, 160, 60, 255))
    d.ellipse((19, 22, 23, 26), fill=(255, 230, 140, 255))
    return _outer_glow(_mount(img, CAT_ARCANE), (255, 130, 60, 255), radius=2, alpha=80)


def item_frost_orb() -> Image.Image:
    img = _new(64)
    d = ImageDraw.Draw(img)
    # Frozen orb centered
    d.ellipse((14, 14, 50, 50), fill=(80, 130, 180, 255))
    d.ellipse((16, 16, 48, 48), fill=(140, 200, 240, 255))
    d.ellipse((20, 20, 34, 34), fill=(220, 240, 255, 255))
    # Ice cracks
    d.line([(24, 24), (44, 44)], fill=(255, 255, 255, 200), width=1)
    d.line([(44, 24), (24, 44)], fill=(255, 255, 255, 200), width=1)
    return _outer_glow(_mount(img, CAT_ARCANE), (140, 200, 240, 255), radius=2, alpha=80)


def item_tome() -> Image.Image:
    img = _new(64)
    d = ImageDraw.Draw(img)
    # Book cover
    d.rectangle((12, 14, 52, 52), fill=(88, 40, 40, 255))
    d.rectangle((14, 16, 50, 50), fill=(160, 60, 60, 255))
    # Spine highlight
    d.rectangle((14, 16, 18, 50), fill=(200, 90, 90, 255))
    # Corner clasps
    d.rectangle((12, 12, 18, 18), fill=GOLD)
    d.rectangle((46, 12, 52, 18), fill=GOLD)
    d.rectangle((12, 48, 18, 54), fill=GOLD)
    d.rectangle((46, 48, 52, 54), fill=GOLD)
    # Center rune
    d.polygon([(32, 22), (40, 32), (32, 42), (24, 32)], fill=GOLD)
    d.rectangle((30, 30, 34, 34), fill=(60, 20, 20, 255))
    return _mount(img, CAT_ARCANE)


def item_healing_draught() -> Image.Image:
    img = _new(64)
    d = ImageDraw.Draw(img)
    # Neck
    d.rectangle((28, 12, 36, 22), fill=(220, 210, 190, 255))
    d.rectangle((28, 10, 36, 14), fill=(100, 60, 40, 255))  # cork
    # Bulb
    d.ellipse((16, 22, 48, 54), fill=(180, 180, 200, 255))
    d.ellipse((18, 24, 46, 52), fill=(220, 230, 245, 255))
    # Liquid (red glow)
    d.ellipse((22, 32, 42, 50), fill=(220, 40, 60, 255))
    d.ellipse((26, 36, 32, 42), fill=(255, 120, 140, 255))
    # Highlight streak
    d.line([(22, 26), (24, 34)], fill=(255, 255, 255, 200), width=2)
    return _outer_glow(_mount(img, CAT_SHIELD), (220, 40, 60, 255), radius=2, alpha=70)


def item_iron_buckler() -> Image.Image:
    img = _new(64)
    d = ImageDraw.Draw(img)
    d.ellipse((10, 10, 54, 54), fill=(60, 40, 20, 255))
    d.ellipse((11, 11, 53, 53), fill=(140, 96, 60, 255))
    d.ellipse((14, 14, 50, 50), fill=(90, 60, 32, 255))
    # Plank lines
    for x in [22, 32, 42]:
        d.line([(x, 12), (x, 52)], fill=(60, 40, 20, 255), width=1)
    # Iron rim & boss
    d.ellipse((10, 10, 54, 54), outline=SILVER_LO, width=1)
    d.ellipse((24, 24, 40, 40), fill=SILVER_LO)
    d.ellipse((25, 25, 39, 39), fill=SILVER)
    d.ellipse((28, 28, 34, 34), fill=SILVER_HI)
    return _mount(img, CAT_SHIELD)


def item_tower_shield() -> Image.Image:
    img = _new(64)
    d = ImageDraw.Draw(img)
    # Tall kite shield silhouette
    poly = [(24, 8), (40, 8), (48, 20), (48, 44), (32, 56), (16, 44), (16, 20)]
    d.polygon(poly, fill=(88, 100, 128, 255))
    d.polygon([(28, 12), (36, 12), (42, 22), (42, 42), (32, 50), (22, 42), (22, 22)],
              fill=SILVER_LO)
    d.polygon([(30, 16), (34, 16), (38, 22), (38, 40), (32, 46), (26, 40), (26, 22)],
              fill=SILVER)
    # Cross emblem
    d.rectangle((30, 20, 34, 42), fill=GOLD)
    d.rectangle((22, 28, 42, 32), fill=GOLD)
    return _mount(img, CAT_SHIELD)


def item_leather_armor() -> Image.Image:
    img = _new(64)
    d = ImageDraw.Draw(img)
    # Chest silhouette (mailed vest)
    poly = [(20, 14), (44, 14), (48, 22), (48, 46), (44, 52), (20, 52), (16, 46), (16, 22)]
    d.polygon(poly, fill=(90, 58, 34, 255))
    d.polygon(poly, outline=(50, 30, 16, 255), width=1)
    # Neck opening
    d.polygon([(28, 14), (36, 14), (34, 24), (30, 24)], fill=(50, 30, 16, 255))
    # Straps
    d.rectangle((22, 16, 26, 50), fill=(160, 110, 60, 255))
    d.rectangle((38, 16, 42, 50), fill=(160, 110, 60, 255))
    # Buckle
    d.rectangle((30, 34, 34, 40), fill=GOLD_LO)
    return _mount(img, CAT_SHIELD)


def item_chain_mail() -> Image.Image:
    img = _new(64)
    d = ImageDraw.Draw(img)
    poly = [(20, 14), (44, 14), (48, 22), (48, 46), (44, 52), (20, 52), (16, 46), (16, 22)]
    d.polygon(poly, fill=(60, 68, 82, 255))
    # Ring texture
    for y in range(18, 52, 3):
        for x in range(18, 48, 3):
            if (x + y) % 2 == 0:
                d.ellipse((x, y, x + 2, y + 2), fill=SILVER_LO)
            else:
                d.ellipse((x, y, x + 2, y + 2), fill=(100, 108, 122, 255))
    d.polygon(poly, outline=(30, 34, 42, 255), width=1)
    return _mount(img, CAT_SHIELD)


# ---------- EFFECTS (particle textures) ----------

def fx_ring(size=64) -> Image.Image:
    """Radial ring particle — used for grid snap + crit sparks."""
    img = _new(size)
    d = ImageDraw.Draw(img)
    cx = size // 2
    d.ellipse((4, 4, size - 4, size - 4), outline=(255, 255, 255, 255), width=2)
    return img.filter(ImageFilter.GaussianBlur(2))


def fx_spark(size=32) -> Image.Image:
    img = _new(size)
    d = ImageDraw.Draw(img)
    c = size // 2
    d.line([(c, 2), (c, size - 2)], fill=(255, 255, 255, 255), width=2)
    d.line([(2, c), (size - 2, c)], fill=(255, 255, 255, 255), width=2)
    d.line([(c - 8, c - 8), (c + 8, c + 8)], fill=(255, 255, 255, 200), width=1)
    d.line([(c + 8, c - 8), (c - 8, c + 8)], fill=(255, 255, 255, 200), width=1)
    return img.filter(ImageFilter.GaussianBlur(1))


def fx_dot(size=16) -> Image.Image:
    img = _new(size)
    d = ImageDraw.Draw(img)
    c = size // 2
    d.ellipse((2, 2, size - 2, size - 2), fill=(255, 255, 255, 255))
    return img.filter(ImageFilter.GaussianBlur(1))


def fx_hitmark(size=48) -> Image.Image:
    """Combat impact hitmark — 4-corner brackets."""
    img = _new(size)
    d = ImageDraw.Draw(img)
    L = 12
    T = 3
    # Top-left
    d.line([(2, 2), (2 + L, 2)], fill=(255, 255, 255, 255), width=T)
    d.line([(2, 2), (2, 2 + L)], fill=(255, 255, 255, 255), width=T)
    # Top-right
    d.line([(size - 2 - L, 2), (size - 2, 2)], fill=(255, 255, 255, 255), width=T)
    d.line([(size - 2, 2), (size - 2, 2 + L)], fill=(255, 255, 255, 255), width=T)
    # Bottom-left
    d.line([(2, size - 2 - L), (2, size - 2)], fill=(255, 255, 255, 255), width=T)
    d.line([(2, size - 2), (2 + L, size - 2)], fill=(255, 255, 255, 255), width=T)
    # Bottom-right
    d.line([(size - 2 - L, size - 2), (size - 2, size - 2)], fill=(255, 255, 255, 255), width=T)
    d.line([(size - 2, size - 2 - L), (size - 2, size - 2)], fill=(255, 255, 255, 255), width=T)
    return img


# ---------- MAIN ----------

def _save(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    print(f"  wrote {path.relative_to(REPO)}  ({img.size[0]}x{img.size[1]})")


def main() -> None:
    print("Neon Grimoire — regenerating theme sprites")
    print("HUD icons:")
    _save(icon_gold(),     UI_DIR / "icon_gold.png")
    _save(icon_life(),     UI_DIR / "icon_life.png")
    _save(icon_triumph(),  UI_DIR / "icon_triumph.png")
    _save(icon_round(),    UI_DIR / "icon_round.png")

    print("Rank badges:")
    _save(badge_gold(),   UI_DIR / "badge_gold.png")
    _save(badge_silver(), UI_DIR / "badge_silver.png")
    _save(badge_bronze(), UI_DIR / "badge_bronze.png")

    print("Item icons:")
    _save(item_iron_sword(),      ITEMS_DIR / "icon_melee_iron_sword.png")
    _save(item_shortsword(),      ITEMS_DIR / "icon_melee_shortsword.png")
    _save(item_dagger(),          ITEMS_DIR / "icon_melee_dagger.png")
    _save(item_war_hammer(),      ITEMS_DIR / "icon_melee_war_hammer.png")
    _save(item_greatsword(),      ITEMS_DIR / "icon_melee_greatsword.png")
    _save(item_longbow(),         ITEMS_DIR / "icon_ranged_longbow.png")
    _save(item_crossbow(),        ITEMS_DIR / "icon_ranged_crossbow.png")
    _save(item_arcane_staff(),    ITEMS_DIR / "icon_arcane_arcane_staff.png")
    _save(item_ember_wand(),      ITEMS_DIR / "icon_arcane_ember_wand.png")
    _save(item_frost_orb(),       ITEMS_DIR / "icon_arcane_frost_orb.png")
    _save(item_tome(),            ITEMS_DIR / "icon_arcane_tome.png")
    _save(item_healing_draught(), ITEMS_DIR / "icon_shield_healing_draught.png")
    _save(item_iron_buckler(),    ITEMS_DIR / "icon_shield_iron_buckler.png")
    _save(item_tower_shield(),    ITEMS_DIR / "icon_shield_tower_shield.png")
    _save(item_leather_armor(),   ITEMS_DIR / "icon_shield_leather_armor.png")
    _save(item_chain_mail(),      ITEMS_DIR / "icon_shield_chain_mail.png")

    print("Effects:")
    _save(fx_ring(),     FX_DIR / "ring.png")
    _save(fx_spark(),    FX_DIR / "spark.png")
    _save(fx_dot(),      FX_DIR / "dot.png")
    _save(fx_hitmark(),  FX_DIR / "hitmark.png")

    print("Done.")


if __name__ == "__main__":
    main()
