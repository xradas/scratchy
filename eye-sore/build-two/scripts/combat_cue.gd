class_name CombatCue
extends Resource
## A licensed, designed contact or voice cue. Gameplay owns the trigger.
@export var identifier: StringName
@export var bus: StringName = &"World"
@export var variations: Array[AudioStream] = []
@export var gain_db: float = 0.0
@export var spatial: bool = true

