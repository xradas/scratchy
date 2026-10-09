class_name GoreProfile
extends Resource
@export var pools: Texture2D
@export var remains: Texture2D
@export var blood_color := Color(0.52, 0.012, 0.009)
@export var spray_counts: Dictionary = {"pistol": 7, "shotgun": 18, "melee": 6}
@export var death_counts: Dictionary = {"pistol": 12, "shotgun": 28, "melee": 10}
@export var gib_overkill: float = 16.0
@export var max_stains: int = 160
@export var max_remains: int = 144
@export var max_particles: int = 160
@export var gravity: float = 18.0
