class_name GoreProfile
extends Resource
@export var pools: Texture2D
@export var remains: Texture2D
@export var blood_color := Color(0.52, 0.012, 0.009)
@export var spray_counts: Dictionary = {"pistol": 11, "shotgun": 30, "melee": 9}
@export var death_counts: Dictionary = {"pistol": 20, "shotgun": 48, "melee": 16}
@export var gib_overkill: float = 16.0
@export var max_stains: int = 640
@export var max_remains: int = 640
@export var max_particles: int = 256
@export var gravity: float = 18.0

## Optional original species art: {kind:{texture:Texture2D,columns:4,rows:2,
## regions:{head:Rect2,...},parts:[{name,cell,material,size:Vector2},...]}}.
## A named region overrides its atlas cell. Empty entries use the existing raster.
@export var species_atlases: Dictionary = {}
@export var corpse_integrity_fraction: float = 0.4
@export var corpse_integrity_minimum: float = 38.0
@export var gib_counts: Dictionary = {"unsealed":12,"vessel":14,"ironbound":14,"censer":15,"reaver":12,"surveyor":13}
