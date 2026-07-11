# Design reference - Neon Grimoire Figma Make export

`figma-make/` is a vendored copy of the Figma Make design source (React + Tailwind v4), exported Jul 2026.
It is the canonical reference for exact visual values: read colors, spacing, type scale, motion timings, and layout composition directly from this source instead of eyeballing screenshots or inspecting computed styles.

Live rendered mirror (public, republished Jul 2026, matches this export): https://surly-spout-45387130.figma.site/

## How to read it

- `styles/tokens.css` - the full token set (primitives, semantic aliases, type scale, radii, glow recipes, motion curves, z-index stack). Start here.
- `App.tsx` - screen inventory and navigation flow between the 13 screen variants.
- `screens/*.tsx` - one file per screen; utility classes resolve in `index.css` and `styles/*.css`.
- `components/*.tsx` - the shared component recipes (HUDPill, AuroraButton, ItemCard, TabBar, ProfileModal, RuneField).

## Rules

- This directory is a reference snapshot, not client code. Never import from it, never "fix" it.
- When the design changes, re-export from Figma Make and replace the whole snapshot in one commit.
- Godot implementation maps tokens through `scripts/ui/SynGridPalette.gd` and `scripts/ui/ThemeBuilder.gd`; do not hardcode hex values from here directly in scenes.
- Motion and audio behavior remain governed by `docs/juice_manual.md`; this reference only adds static visual truth and layout composition.
