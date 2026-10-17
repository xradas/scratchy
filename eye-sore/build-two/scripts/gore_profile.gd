class_name GoreProfile
extends Resource
@export var pools: Texture2D
@export var remains: Texture2D
@export var blood_color := Color(0.52, 0.012, 0.009)
@export var spray_counts: Dictionary = {"pistol":16,"shotgun":36,"twin_shotgun":52,"rivet_cannon":24,"siege_launcher":64,"melee":12}
@export var death_counts: Dictionary = {"pistol":26,"shotgun":56,"twin_shotgun":72,"rivet_cannon":38,"siege_launcher":80,"melee":22}
@export var gib_overkill: float = 16.0
@export var max_stains: int = 384
@export var max_remains: int = 128
@export var max_particles: int = 256
@export var gravity: float = 18.0

## Optional original species art: {kind:{texture:Texture2D,columns:4,rows:2,
## regions:{head:Rect2,...},parts:[{name,cell,material,size:Vector2},...]}}.
## A named region overrides its atlas cell. Empty entries use the existing raster.
@export var species_atlases: Dictionary = {}
@export var corpse_integrity_fraction: float = 0.4
@export var corpse_integrity_minimum: float = 38.0
@export var gib_counts: Dictionary = {"unsealed":12,"vessel":14,"ironbound":14,"censer":15,"reaver":12,"surveyor":13}

## Cosmetic only: explicit weapon identities never alter authoritative damage.
@export var spark_counts: Dictionary = {"pistol":3,"shotgun":7,"twin_shotgun":10,"rivet_cannon":5,"siege_launcher":12,"melee":3}
@export var weapon_bursts: Dictionary = {
 "pistol":{"speed":Vector2(5,9),"spread":0.32,"size":1.1,"chunk_force":3.4},
 "shotgun":{"speed":Vector2(6,11),"spread":0.48,"size":1.2,"chunk_force":4.8},
 "twin_shotgun":{"speed":Vector2(7,12),"spread":0.56,"size":1.35,"chunk_force":5.8},
 "rivet_cannon":{"speed":Vector2(8,13),"spread":0.2,"size":1.15,"chunk_force":4.2},
 "siege_launcher":{"speed":Vector2(8,14),"spread":0.72,"size":1.5,"chunk_force":6.6},
 "melee":{"speed":Vector2(3,6),"spread":0.62,"size":1.05,"chunk_force":3.0}}
@export var rupture_extra_drops: int = 24
@export var max_burst_drops: int = 96
@export var max_drop_stains_per_burst: int = 6
