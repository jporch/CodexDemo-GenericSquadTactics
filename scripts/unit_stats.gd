extends Resource
## Tune a unit type in the Inspector without editing battle rules.
@export var display_name: String = "Unit"
@export_range(1, 100) var hp: int = 5
@export_range(1, 100) var attack: int = 1
@export_range(0, 100) var defense: int = 0
@export_range(0, 16) var move: int = 2
@export_range(1, 16) var attack_range: int = 1
@export_range(1, 16) var minimum_attack_range: int = 1
@export_range(0, 32) var perception: int = 0
