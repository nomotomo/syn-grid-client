---
name: godot-engine-core
description: Use for Godot engine tasks involving scenes, nodes, signals, autoloads, resources, and core Godot API usage.
---

## Scope
Use this skill for any Godot-specific engine work: scene composition, node hierarchy, signals, autoloads, resources, and lifecycle methods (_ready, _process, _physics_process).

## Core rules
- Treat scenes as reusable, self-contained units.
- Prefer composition (child nodes) over deep inheritance chains.
- Use signals for decoupled communication between nodes; avoid direct cross-node references when possible.
- Use autoloads (singletons) only for truly global state (game manager, audio bus, event bus). Do not overuse autoloads.
- Use Resource (.tres) classes for shared/config data instead of hardcoding values in scripts.
- Prefer static typing in GDScript (e.g. `var health: int = 100`, typed function signatures).
- Keep _process/_physics_process logic minimal; delegate to helper functions.

## Patterns to use
- Scene bootstrapper / main scene pattern for game startup.
- Event bus autoload for global signals (e.g. player_died, score_changed).
- State machine pattern for player/enemy behavior.
- Component-style child nodes (e.g. HealthComponent, HitboxComponent) attached to entities.

## Anti-patterns to avoid
- Deep node path references like get_node("../../../UI/HUD") — use signals, groups, or exported NodePaths instead.
- Putting all game logic in one giant script.
- Overusing autoloads for things that belong to a single scene.
- Untyped variables and functions where types are known.

## Examples
- "Create a player scene with a StateMachine child node for idle/run/jump states."
- "Add a signal-based event bus autoload for score updates."
- "Refactor this script to use typed GDScript."