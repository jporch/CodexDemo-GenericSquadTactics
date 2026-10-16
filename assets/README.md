# Placeholder visuals

All current art is original code-drawn pixel art. There are no downloaded art assets or audio.

- `scripts/unit_placeholder.gd` and `scenes/unit_placeholder.tscn`: character silhouettes, the Knight’s tall tower shield, type markers, and HP bars. Replace the visual scene/script when finished sprites exist.
- `scripts/attack_effect_placeholder.gd` and `scenes/attack_effect_placeholder.tscn`: red melee slash and travelling/dissipating yellow ranged spark.
- `scripts/board_placeholder.gd`: grid, stone walls, crates, highlights, and temporary patrol flags/area outlines.

Keep `_placeholder` before the extension in replacement placeholder filenames. Game rules are independent of these visuals in `scripts/battle_model.gd`.

The game currently uses Godot's bundled fallback font. No external font is required.
