class_name WeaponDefinition
extends Resource
## Schema only. No weapon content or firing behavior before identity selection.
@export var identifier: StringName
@export var display_name: String
@export var damage: float = 0.0
@export var cooldown_seconds: float = 0.1
@export var audio_bus: StringName = &"Weapons"
