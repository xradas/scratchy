extends RefCounted
## Authored arrival waves. Positions are actor feet, in the existing room's world
## coordinates; these are deliberately clear of the original spawn grid.
const WAVES := {
	"pale_ward_01": {
		"control:local_power": [
			{"kind":"infected_security", "position":Vector3(-9,-1.13,-72)},
			{"kind":"unsealed", "position":Vector3(8,-1.13,-72)},
		],
		"pickup:brass": [
			{"kind":"infected_security", "position":Vector3(70,2.87,8)},
			{"kind":"unsealed", "position":Vector3(89,2.87,8)},
		],
	},
	"pale_ward_02": {
		"control:isolation_a": [
			{"kind":"infected_security", "position":Vector3(-45,2.87,-34)},
			{"kind":"unsealed", "position":Vector3(-35,2.87,-34)},
		],
		"control:isolation_b": [
			{"kind":"infected_security", "position":Vector3(45,6.87,-34)},
			{"kind":"unsealed", "position":Vector3(35,6.87,-34)},
		],
	},
}

static func for_level(level_id: String) -> Dictionary:
	return WAVES.get(level_id, {})
