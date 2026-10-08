class_name EnemyDefinition
extends Resource
## Schema only. No enemy content or AI before identity selection.
@export var identifier: StringName
@export var display_name: String
@export var health: float = 1.0
@export var speed: float = 1.0
@export var audio_bus: StringName = &"Creatures"
