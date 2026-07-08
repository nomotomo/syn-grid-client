---
name: godot-project-structure
description: Use for organizing Godot project folders, file naming, and scene/script placement conventions.
---

## Scope
Use this skill when creating new scenes, scripts, or assets, or when reorganizing a Godot project.

## Folder conventions
- Root folders: `scenes/`, `scripts/`, `assets/`, `addons/`, `resources/`, `autoloads/`, `ui/`.
- Group by feature, not by file type, for gameplay content: `scenes/player/`, `scenes/enemies/`, `scenes/levels/`.
- Keep a scene's script, sub-scenes, and unique assets in the same feature folder when they're not reused elsewhere.
- Shared/reusable assets (fonts, common textures, shared audio) go in `assets/shared/`.
- Third-party plugins stay isolated inside `addons/`.

## Naming rules
- Use snake_case for files and folders: `player_controller.gd`, `enemy_slime.tscn`.
- Use PascalCase for class_name declarations inside scripts.
- Name scenes after the entity they represent, not generic names like `Scene1.tscn`.
- Prefix UI scenes clearly: `ui_main_menu.tscn`, `ui_pause_menu.tscn`.

## Anti-patterns to avoid
- Dumping all scripts into one flat `scripts/` folder with no subfolders.
- Mixing unrelated assets into the root directory.
- Inconsistent naming (mixing PascalCase and snake_case for files).

## Examples
- "Set up folder structure for a new enemy type called Slime."
- "Move this UI scene into the correct folder convention."