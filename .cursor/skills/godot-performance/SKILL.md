---
name: godot-performance
description: Use for Godot performance optimization, profiling, frame drops, memory usage, and reducing per-frame overhead.
---

## Scope
Use this skill when diagnosing or improving performance: frame rate drops, stutter, memory growth, or inefficient per-frame code.

## Core rules
- Use static typing everywhere possible; it improves GDScript performance and catches bugs early.
- Prefer signals over per-frame polling in `_process`/`_physics_process`.
- Cache node references in `_ready()` instead of calling `get_node()` repeatedly in `_process`.
- Use object pooling for frequently spawned/destroyed objects (bullets, particles, enemies).
- Use the Godot profiler and frame time monitor before optimizing — measure first, don't guess.
- Minimize work inside `_process`; move non-time-critical logic to timers or signals.

## Patterns
- Object pool manager for reusable instances (bullets, VFX).
- Timer-based periodic checks instead of per-frame checks for non-critical logic.
- Batching similar draw calls; using MultiMeshInstance for repeated visuals.

## Anti-patterns to avoid
- Calling `get_node()` or `find_child()` every frame.
- Instantiating/freeing nodes every frame instead of pooling.
- Untyped GDScript in performance-critical paths.
- Optimizing without profiling first.

## Examples
- "Diagnose why frame rate drops when many enemies spawn."
- "Add object pooling for the bullet system."
- "Refactor this script to use static typing for performance."