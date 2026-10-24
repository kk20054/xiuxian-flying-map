# Blender tools (Blender 4.2+ / 5.x)

- `import_world.py` — build a region of the exported world in Blender: terrain (with the demo's colours), water, the
  sect/city GLBs, places, roads/rivers and every tree as an instanced point (swap the "XY Tree Kinds" collection for
  your asset-library trees). `blender --background --python import_world.py -- --sect luoyun --out luoyun.blend`
- `bake_ink_layout.py` — give any mesh the facet ink-line vertex layout used by `godot/shaders/facet.gdshader`.
  `blender hall.blend --background --python bake_ink_layout.py -- --angle 25 --out hall_ink.glb`

Details: [../../docs/godot/01-pipeline-and-blender.md](../../docs/godot/01-pipeline-and-blender.md).
