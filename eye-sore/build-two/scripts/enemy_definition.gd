class_name EnemyDefinition
extends Resource
@export var identifier: StringName
@export var display_name: String
@export var health: float = 60.0
@export var speed: float = 2.6
@export var ranged: bool = false
@export var damage: float = 12.0
@export var attack_range: float = 1.8
@export var windup_seconds: float = 0.6
@export var recovery_seconds: float = 0.8
@export var pain_seconds: float = 0.22
@export var projectile_speed: float = 9.0
@export var hit_material: StringName = &"flesh"
@export var audio_bus: StringName = &"Creatures"
