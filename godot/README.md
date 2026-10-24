# Godot 4 port

Open `project.godot` in Godot 4.4+ (verified on 4.7.1) and press F5. Full guide: [../docs/godot/README.md](../docs/godot/README.md).

- `data/world/` — the world exported from the demo by `../tools/export-world` (read at runtime; `.gdignore`d)
- `scripts/`, `shaders/`, `ui/`, `scenes/` — the port; `tools/build_scenes.gd` regenerates the UI scenes and theme
- flags after `--`: `--skip-intro`, `--no-autoquality`, `--shots=<dir>`, `--dump-sun`
