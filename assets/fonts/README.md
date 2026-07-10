# Fonts

All fonts here are licensed under the **SIL Open Font License 1.1** (see `OFL.txt`),
which permits bundling and redistribution inside this application.

The three web fonts below were added to match the Figma Make design reference exactly
(`docs/design-tokens-neon-grimoire.md` — the design's `index.css` `@theme` block declares
`--font-display: Orbitron`, `--font-body: Inter`, `--font-mono: JetBrains Mono`). Godot cannot
load fonts from a Google Fonts CDN the way the web design does, so the TTFs are vendored here.
All three are **variable fonts** (weight axis), so one file per family covers every weight the
design uses via `FontVariation` in `ThemeBuilder` (Orbitron 400/700/900, Inter 400–700,
JetBrains Mono 400/700).

| File | Family | Role in the theme | Author / copyright |
|---|---|---|---|
| `Orbitron.ttf` | Orbitron | Display — logo, headings, buttons | Matt McInerney (The Orbitron Project Authors) |
| `Inter.ttf` | Inter | Body — labels, descriptions | Rasmus Andersson (The Inter Project Authors) |
| `JetBrainsMono.ttf` | JetBrains Mono | Mono — numbers, stats, IDs, tickers | JetBrains (The JetBrains Mono Project Authors) |
| `syn_grid_pixel.ttf` | Press Start 2P | Legacy pixel font (superseded by Orbitron for display; retained until every screen is migrated) | CodeMan38 (The Press Start 2P Project Authors) |

Source: Google Fonts (`github.com/google/fonts`, `ofl/` directory). Each family carries its own
OFL copyright line; the full OFL 1.1 text in `OFL.txt` applies to all of them.
