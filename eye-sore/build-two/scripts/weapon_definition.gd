class_name WeaponDefinition
extends Resource
@export var identifier: StringName
@export var display_name: String
@export var damage: float = 0.0
@export var cooldown_seconds: float = 0.35
@export var fire_seconds: float = 0.09
@export var pellets: int = 1
@export var spread_degrees: float = 0.0
@export var vertical_spread_degrees: float = 0.0
@export var range_units: float = 60.0
@export var ammo_key: StringName = &"ammo_pistol"
@export var audio_bus: StringName = &"Weapons"
# Generic accepted-shot settings. Legacy resources retain their historical defaults.
@export var ammo_cost: int = 1
@export var recoil: float = -1.0
@export_enum("hitscan", "projectile") var fire_mode: String = "hitscan"
@export var projectile_speed: float = 26.0
@export var projectile_lifetime: float = 4.0
@export var blast_damage: float = 90.0
@export var blast_radius: float = 4.8
