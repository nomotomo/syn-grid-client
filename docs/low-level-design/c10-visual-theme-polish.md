# LLD: C10 - Item/HUD Icon Sprites and Rounded Neon-Glass Theme - Implementation Blueprint

HLD: `docs/high-level-design/c10-visual-theme-polish.md`.
Dependency decisions: `docs/dependency/ui-audio-assets.md`.
Client issue: sync-grid-client #11.
Juice contract: `docs/juice_manual.md` sections 1-3 govern every visual decision below; nothing here
overrides them.

## File inventory

New:
- `assets/sprites/items/*.png` - sourced from Akari21 "RPG Icon Pack (200+)" and Cainos "Pixel Art Icon
  Pack - RPG" (see naming convention below)
- `assets/sprites/items/CREDITS.md` - source URL + license per file, mirrors `assets/audio/README.md`'s
  existing pattern
- `assets/sprites/ui/icon_gold.png`, `icon_life.png`, `icon_triumph.png` - from Kenney "Game Icons" (CC0)
- `assets/sprites/ui/badge_gold.png`, `badge_silver.png`, `badge_bronze.png` - from Kenney "Game Icons"
  (CC0), consumed by issue #7 (C8) LeaderboardScene, not by this issue

Modified:
- `scripts/ui/ItemCard.gd` - `TextureRect` + fallback logic
- `scenes/ui/ItemCard.tscn` - add `%IconTexture` node alongside existing `%IconRect`
- `scenes/ui/StatsHud.tscn` - add icon `TextureRect` per stat panel
- `scripts/ui/ThemeBuilder.gd` - `PANEL_CORNER_RADIUS`, glow border extension
- `scripts/ui/SynGridPalette.gd` - no functional change; add a comment removing the now-stale "until real
  pixel-art sprites are sourced" note once #11 ships

## Item icon naming convention

```
res://assets/sprites/items/icon_<weapon_category>_<slug>.png
```

- `<weapon_category>` is the lowercased server value: `melee`, `ranged`, `arcane`, or `shield` (shields
  arrive with an empty `weapon_category` today per `ItemCardPreviewHarness.gd:12` - treat empty as
  `shield` for icon lookup only, not for gameplay logic).
- `<slug>` is the item's `name` field, lowercased, spaces replaced with `_` (e.g. `"Arcane Staff"` →
  `arcane_staff`).
- Example: `icon_arcane_arcane_staff.png`, `icon_melee_shortsword.png`, `icon_shield_iron_buckler.png`.

## ItemCard.gd contract

```gdscript
@onready var _icon_rect: ColorRect = %IconRect
@onready var _icon_texture: TextureRect = %IconTexture

func _icon_path_for(item: Dictionary) -> String:
    var category := item.get("weapon_category", "").to_lower()
    if category == "":
        category = "shield"
    var slug := item.get("name", "").to_lower().replace(" ", "_")
    return "res://assets/sprites/items/icon_%s_%s.png" % [category, slug]

func set_item(item: Dictionary) -> void:
    var path := _icon_path_for(item)
    if ResourceLoader.exists(path):
        _icon_texture.texture = load(path)
        _icon_texture.visible = true
        _icon_rect.visible = false
    else:
        _icon_texture.visible = false
        _icon_rect.visible = true
        _icon_rect.color = SynGridPalette.tint_for_weapon_category(item.get("weapon_category", ""))
```

`ResourceLoader.exists()` runs once per `set_item()` call, not per frame - negligible cost, no caching
needed at this call volume (bench + grid is at most ~20 cards on screen).

## StatsHud icon wiring

Each stat panel (`RoundPanel`, `GoldPanel`, `LifePanel`, `TriumphPanel`) gets one `TextureRect` inserted
before the existing `VBox`, sized `32x32`, using:

| Panel | Icon source |
|---|---|
| Gold | `assets/sprites/ui/icon_gold.png` (Kenney coin icon) |
| Life | `assets/sprites/ui/icon_life.png` (Kenney heart icon) |
| Triumph | `assets/sprites/ui/icon_triumph.png` (Kenney trophy icon) |

No script change required - this is a pure `.tscn` node addition, since `StatsHud.gd` (if it exists)
already binds by unique-name label, not by full subtree.

## ThemeBuilder rounded neon-glass contract

The current signature is `build_panel_style(border_color: Color, bg_color: Color, shadow_size: int = 0)`,
called positionally by 9 existing sites (`ItemCard.gd:66` passes a real `drag_shadow_size` int, not a
bool). `with_glow` must land as a new **trailing** keyword-style parameter so every existing positional
call keeps compiling unchanged:

```gdscript
const PANEL_CORNER_RADIUS: int = 16   # was 0 - see HLD "Reversing a deliberate prior decision"
const PANEL_GLOW_MARGIN: int = 6      # px of soft outer glow beyond the border, new constant

static func build_panel_style(border_color: Color, bg_color: Color,
        shadow_size: int = 0, with_glow: bool = false) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg_color
    style.border_color = border_color
    style.set_border_width_all(PANEL_BORDER_WIDTH)
    style.set_corner_radius_all(PANEL_CORNER_RADIUS)
    style.content_margin_left = PANEL_CONTENT_MARGIN
    style.content_margin_right = PANEL_CONTENT_MARGIN
    style.content_margin_top = PANEL_CONTENT_MARGIN
    style.content_margin_bottom = PANEL_CONTENT_MARGIN
    if with_glow:
        style.shadow_color = border_color
        style.shadow_color.a = 0.35
        style.shadow_size = PANEL_GLOW_MARGIN
    elif shadow_size > 0:
        style.shadow_size = shadow_size
        style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
    return style
```

`with_glow` and `shadow_size` are mutually exclusive per call (glow wins if both are somehow set) - callers
pick one per panel: glow for HUD pills and item-slot borders per the mockup, the existing plain
`shadow_size` drop-shadow for the drag-lift effect (`ItemCard.gd`) and popovers where a colored glow would
be visually noisy. Every one of the 9 existing call sites (`ItemCard.gd`, `GridCell.gd`, `GridPrepScene.gd`,
`MainMenu.gd`, `LeaderboardScene.gd`) keeps compiling with zero changes; only call sites that opt into the
new HUD/item-slot glow pass `with_glow = true` explicitly.

Content-inset rule to avoid corner-clipping (HLD risk item): every `VBoxContainer`/`Label` inside a themed
panel must keep at least `PANEL_CORNER_RADIUS * 0.5` (8px) of margin from the panel edge. Audit existing
scenes for hardcoded `0`-margin containers when this lands - the PR must fix any found, not just the new
nodes.

## Rank medal badges (feeds #7 / C8, not blocking this issue)

`LeaderboardScene.gd` (from issue #7) shows `badge_gold.png` / `badge_silver.png` / `badge_bronze.png`
next to rank 1/2/3 rows respectively, ranks 4+ show no badge. Source: Kenney "Game Icons" (CC0) medal/star
assets, recolored in an image editor if Kenney's stock colors don't match `SynGridPalette.GOLD` /
`ACCENT_PURPLE` closely enough - do not buy the racing rank-emblem pack (see dependency doc).

## Testing

- `ItemCardPreviewHarness.tscn` under `SYNGRID_SCREENSHOT`: verify all 4 sample items
  (Shortsword/Longbow/Arcane Staff/Iron Buckler) render sprites once assets land, and verify the fallback
  tint still renders correctly for an item name added to the harness with no matching sprite file (keep
  one such case in the harness permanently as a regression check for the fallback path).
- Every existing preview harness (MainMenu/GridPrep/CombatReplay/RoundEnd, all 4 `SYNGRID_RESULT` variants)
  re-run under `SYNGRID_SCREENSHOT` after the `PANEL_CORNER_RADIUS` change - look at the screenshots per
  the PR Review Protocol; a blank or clipped frame is a blocker.
