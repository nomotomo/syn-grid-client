---
name: game-ui
description: Syn-Grid Godot 4 client UI/UX design contract. Load whenever building any scene, shader, tween, or audio node. Covers elastic tweening laws, synergy glow shaders, combat log interpolation, screen shake formula, damage floats, and the audio SFX event matrix.
---

# Game UI - Juice & Presentation Contract

This skill is a pointer to the master contract.
Read the full document before generating any client-side code:

```
docs/juice_manual.md
```

## Quick reference: what the contract governs

- **Section 1 - UI Layout**: Dark-first bento-grid. Glassmorphic panels banned on live numbers.
- **Section 2 - Tweening**: No LINEAR. Elastic overshoot for card pops. Drag tilt via velocity vector. Grid snap Y-squish + teal particle ring.
- **Section 3 - Synergy shader**: Fragment shader with neon plasma gradient, `glow_intensity` uniform from `modifier_pct`. Never Line2D.
- **Section 4 - Combat log**: Event queue, one per 0.10s via Timer. 2-frame hit-stop on crit. Damage floats with -15 to +15 degree arc. Crit floats: 1.8x scale, crimson outline.
- **Section 5 - Audio**: BGM cross-fade 0.8s. 14 SFX events mapped to sound design requirements. LPF filter on fatal HP loss. On-demand SFX loading.
- **Section 6 - Asset sources**: Sonniss GDC archive (free commercial), OpenGameArt CC0, itch.io bundles.
- **Section 7 - Checklist**: Verify all 14 items before marking any scene complete.

## Godot 4 GDScript conventions for this project

- `class_name` on every script.
- `@export` on every tunable constant (tween duration, shake scalar, particle colour).
- Signal-based decoupling: scenes emit signals upward, never call parent/sibling nodes.
- `ApiClient` autoload emits all server response signals - scenes connect, never call directly.
- All SFX loaded via `ResourceLoader.load_threaded_request`, cached in `AudioManager`.
- No C#. GDScript only.
