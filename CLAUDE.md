# Nuthouse Games — Claude Code Context

## Project
- **Repo**: git@github.com:flatbil/Nuthouse-Games.git
- **Location**: /Volumes/T7 Shield/GamesDev/Nuthouse-Games/
- **Engine**: Godot 4.6 (mobile renderer, ETC2/ASTC texture compression)
- **Targets**: Android (primary), iOS (port)

## Game 01 — "Compound"
- **Path**: game_01/
- **Main scene**: scenes/Game.tscn
- **Viewport**: 390×844 (iPhone-sized), stretch mode: canvas_items/expand, portrait orientation
- **Autoloads**: EventBus, SaveManager, GameManager, AdManager

## Storage & Git
- Drive is exFAT (T7 Shield via USB) — `core.fileMode = false` is set
- Android SDK/NDK and Xcode must remain on internal SSD (~/Library paths)
- Do NOT store build artifacts or export templates on this drive if avoidable

## Workflow Notes
- Always invoke `claude` from within a project subdirectory (e.g. game_01/) for focused context
- GDScript is the scripting language — prefer idiomatic Godot 4.x patterns
- Mobile-first: test on both Android and iOS profiles
