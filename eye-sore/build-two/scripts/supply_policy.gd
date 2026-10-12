extends Resource
## Campaign carrying limits. Standalone/calibration encounters bypass this policy.
@export var pistol_capacity: int = 96
@export var shells_capacity: int = 40
@export var rivets_capacity: int = 160
@export var rockets_capacity: int = 12

func capacity(kind: StringName) -> int:
	match kind:
		&"pistol", &"ammo_pistol": return maxi(0, pistol_capacity)
		&"shells", &"shotgun", &"ammo_shotgun": return maxi(0, shells_capacity)
		&"rivets", &"ammo_rivets": return maxi(0, rivets_capacity)
		&"rockets", &"ammo_rockets": return maxi(0, rockets_capacity)
	return -1
