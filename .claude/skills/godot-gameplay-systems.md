---
name: godot-gameplay-systems
description: Use for building core gameplay systems in Godot such as player movement, combat, inventory, state machines, and save/load.
---

## Scope
Use this skill for gameplay logic: player controllers, enemy AI, combat, inventory, quests, checkpoints, and save/load systems.

## Core rules
- Use a state machine (enum or class-based) for any entity with distinct behavior modes (idle, run, attack, dead).
- Keep gameplay data (stats, items, config) in Resource classes, separate from behavior scripts.
- Use signals to notify systems of state changes (health_changed, item_picked_up, quest_completed) rather than polling.
- Design save/load around serializable Resource data, not raw scene state.
- Keep enemy AI modular: separate perception (detection), decision (state/behavior tree), and action (movement/attack).

## Patterns
- Finite state machine for player/enemy behavior.
- Component nodes: HealthComponent, HitboxComponent, InventoryComponent, attached to entities as children.
- Event bus autoload for cross-system gameplay events.
- Resource-based save system (custom Resource with `@export` fields, saved via ResourceSaver).

## Anti-patterns to avoid
- Giant switch/if-else chains for entity behavior instead of a state machine.
- Storing save data directly as scene tree state.
- Tight coupling between unrelated systems (e.g. UI directly modifying player stats).

## Examples
- "Build a player state machine with idle, run, jump, and attack states."
- "Add an inventory system using a Resource-based item database."
- "Implement save/load using Resource serialization."