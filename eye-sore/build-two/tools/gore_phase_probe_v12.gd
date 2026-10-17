extends "res://scripts/combat_gore.gd"
## Tool-only inherited component: all behavior delegates unchanged to production.
var phase_records: Array[Dictionary] = []
var physics_records: Array[Dictionary] = []
var support_details: Array[Dictionary] = []
var support_calls := 0
var support_ms := 0.0
var support_successes := 0
func handle_event(event: Dictionary) -> void:
	var started:=Time.get_ticks_usec()
	super.handle_event(event)
	if phase_records.size()<512:
		phase_records.append({"phase":"event","type":String(event.type),"shot_id":event.get("shot_id",0),"target":event.get("target_id",""),"ms":(Time.get_ticks_usec()-started)/1000.0,"flying":particles.size(),"settled":remains.size(),"physics_tick":Engine.get_physics_frames()})
func _physics_process(delta: float) -> void:
	support_calls=0;support_ms=0;support_successes=0
	var started:=Time.get_ticks_usec();var initial_live:=particles.size()
	super._physics_process(delta)
	if physics_records.size()<4096:
		physics_records.append({"phase":"physics","ms":(Time.get_ticks_usec()-started)/1000.0,"initial_live":initial_live,"live":particles.size(),"settled":remains.size(),"support_calls":support_calls,"support_ms":support_ms,"support_successes":support_successes,"physics_tick":Engine.get_physics_frames()})
func settle_gib(p: Dictionary, hit: Dictionary) -> bool:
	var started:=Time.get_ticks_usec();var success:=super.settle_gib(p,hit)
	var elapsed:float=(Time.get_ticks_usec()-started)/1000.0
	support_calls+=1;support_ms+=elapsed
	if success:support_successes+=1
	if elapsed>1.0 and support_details.size()<256:
		support_details.append({"ms":elapsed,"success":success,"part":p.part,"age":p.age,"bounces":p.bounces,"position":str(p.node.global_position),"physics_tick":Engine.get_physics_frames()})
	return success
func phase_summary() -> Dictionary:
	var slow_events:=phase_records.duplicate();slow_events.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.ms>b.ms)
	var slow_physics:=physics_records.duplicate();slow_physics.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.ms>b.ms)
	return {"scope":"Tool-only inherited productiongore; event/superphysics/settle calls separately timed. No behavior changes.","events":phase_records,"slowest_events":slow_events.slice(0,20),"slowest_physics":slow_physics.slice(0,30),"support_details":support_details,"physics_samples":physics_records.size()}
