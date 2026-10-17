extends "res://verification/intake-v7/audio/pickup_fixture.gd"
## Controlled final Ward01 receipt/shortcut dispatch; not a physically played route.
var ward_records: Array[Dictionary] = []
func ward_pickup(node_name: String, kind: String) -> void:
	pending_item=app.world.get_node_or_null(node_name)
	check(is_instance_valid(pending_item),"real authored final Ward pickup "+node_name)
	if not is_instance_valid(pending_item):return
	if kind=="pistol":app.combat.ammo_pistol=95
	elif kind=="shells":app.combat.ammo_shotgun=39
	elif kind in ["health","armor"]:app.combat.set(kind,99.0)
	elif kind=="brass_key":app.world.flags["power"]=true;app.world.flags["breaker"]=true
	var before:=cue_count(kind); events.clear(); app.world.collect(pending_item)
	check(count("item_collected")==1 and cue_count(kind)==before+1,"one post-mutation receipt for "+node_name)
	var voice: Node=app.combat_audio.voices.back()
	check(voice is AudioStreamPlayer and not voice is AudioStreamPlayer3D and voice.bus==&"UI" and voice.get_meta("role")=="item_collected","actual UI bus voice "+node_name)
	app.world.collect(pending_item)
	check(count("item_collected")==1 and cue_count(kind)==before+1,"repeat collect no second receipt "+node_name)
	ward_records.append({"node":node_name,"kind":kind,"position":str(pending_item.global_position),"cue_count_delta":cue_count(kind)-before,"events":events.duplicate(true)})
func ward_shortcut() -> Dictionary:
	var door:Node3D=app.world.get_node("Door_shortcut_one")
	var anchor:Vector3=door.get_parent().to_global(door.origin+door.get_meta("use_anchor",Vector3.ZERO))
	var normal:Vector3=door.get_meta("first_open_normal")
	var counts:Dictionary=app.combat_audio.cue_counts.duplicate(true)
	app.player.global_position=anchor-normal*1.4
	await physics_frame;await physics_frame
	check(app.world.nearest_mechanism()==door,"shortcut use selects real door from entry side")
	check(not app.world.try_use() and not door.opened,"first opening rejected from entry side")
	check(app.combat_audio.cue_counts==counts,"rejected shortcut has no false audio")
	app.player.global_position=anchor+normal*1.4
	await physics_frame;await physics_frame
	check(app.world.nearest_mechanism()==door,"shortcut use selects real door from supply side")
	check(app.world.try_use() and door.opened and app.world.shortcuts.has("shortcut_one"),"actual Stage E-use accepts powered brass supply-side opening")
	check(app.combat_audio.cue_counts==counts,"accepted existing door has no invented combat or pickup voice")
	return {"rejected_side":str(anchor-normal*1.4),"accepted_side":str(anchor+normal*1.4),"actual_stage_try_use":true,"door_opened":door.opened,"audio_cue_count_delta":0,"door_audio_present":false,"note":"Existing 57-cue profile has no door cue or door event; this is an explicit known limitation, not a once-only door-audio pass."}
func run() -> void:
	var preserved:=preservation()
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);app.automated_input=true
	app.start_new_campaign();freeze()
	check(String(app.campaign.current_level().id)=="pale_ward_01","actual current campaign Intake scene")
	ward_pickup("Key_brass_key","brass_key")
	ward_pickup("Supply_pistol_return_store","pistol")
	ward_pickup("Supply_shells_return_store","shells")
	ward_pickup("Supply_health_return_store","health")
	ward_pickup("Supply_armor_return_store","armor")
	var shortcut:Dictionary=await ward_shortcut()
	reset_main();pending_item=find("twin_shotgun");app.combat.grant_weapon(&"twin_shotgun",100);events.clear();var before:=total_receipts();var arena:=String(pending_item.get_meta("bait_arena"));app.world.collect(pending_item)
	check(not pending_item.visible and app.world.traps[arena].triggered,"Ward saturated owned bait still activates its actual triage trap")
	check(events.is_empty() and total_receipts()==before,"Ward saturated owned bait produces no false item cue")
	await lifecycle()
	app.menu_music.stop();app.menu_music.stream=null;app.combat_audio.stop_all();app.free();app=null;pending_item=null;paused=false
	await create_timer(.4,true).timeout
	var report:Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"preservation":preserved,"actual_collections":ward_records,"shortcut":shortcut,"pause_playback_drift_seconds":paused_drift,"scene_sha256":FileAccess.get_sha256("res://scenes/campaign/pale_ward_01.tscn"),"scope":"Controlled actual Main final Intake scene: authored brass key and four sterile-supply pickups collected directly, explicit inventory/power prerequisites, Stage.try_use with real selection and physics LOS from opposite shortcut sides. No human input, physical route completion, subjective audibility or stereo recording claimed."}
	var file:=FileAccess.open("res://verification/intake-v7/audio/ward.json",FileAccess.WRITE);if file:file.store_string(JSON.stringify(report,"  ")+"\n");file.close()
	print("INTAKE_AUDIO_%s: %d checks"%["OK" if failures.is_empty() else "FAILED",checks]);quit(0 if failures.is_empty() else 1)
