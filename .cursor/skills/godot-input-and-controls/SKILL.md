---
name: godot-input-and-controls
description: Use for Godot input handling, InputMap actions, player controls, pausing, and gamepad/keyboard support.
---

## Scope
Use this skill for anything involving player input, InputMap actions, control remapping, or pause behavior.

## Core rules
- All gameplay input must go through named InputMap actions (e.g. "move_left", "jump"), never hardcoded KEY_ or JOY_ constants in gameplay code.
- Separate gameplay input handling from UI input handling.
- Support both keyboard and gamepad by mapping multiple devices to the same action.
- Define explicit pause behavior: what pauses, what keeps running (e.g. UI, animations).
- Use `_unhandled_input` for gameplay input and `_gui_input`/Control input for UI, to avoid double-handling.

## Patterns
- Centralized InputManager or PlayerInput component that reads InputMap actions and exposes clean signals/methods.
- Remappable controls stored in a Resource or config file, loaded at startup.
- Pause via `get_tree().paused = true` combined with `process_mode = Node.PROCESS_MODE_ALWAYS` on nodes that must keep running.

## Anti-patterns to avoid
- Hardcoded key codes scattered across multiple scripts.
- Polling `Input.is_key_pressed()` for keys that should be configurable actions.
- No distinction between paused/unpaused input handling.

## Examples
- "Set up InputMap actions for movement and jump, and wire them into the player controller."
- "Add a pause menu that stops gameplay but keeps the UI responsive."
- "Add gamepad support for existing keyboard-only controls."