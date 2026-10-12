extends SceneTree
## Controlled real Main/Stage collections and imported recording ownership.
const DIR := "res://concepts/pickups-rooms-v6/audio/"
const TYPES := ["pistol","shells","rivets","rockets","health","armor","brass_key","red_key","weapon"]
const AMMO_FIELDS := {"pistol":"ammo_pistol","shells":"ammo_shotgun","rivets":"ammo_rivets","rockets":"ammo_rockets"}
var checks := 0
var failures: Array[String] = []
var events: Array[Dictionary] = []
var records: Array[Dictionary] = []
var app: Control
var pending_item: Node3D
var paused_drift := 0.0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error("PICKUP_AUDIO_V6_FAILED: "+label)
func count(kind: String) -> int:
	var n := 0
	for e in events:
		if String(e.type)==kind: n+=1
	return n
func cue_count(kind: String) -> int: return int(app.combat_audio.cue_counts.get(StringName("pickup_"+kind),0))
func total_receipts() -> int:
	var total := 0
	for kind in TYPES: total+=cue_count(kind)
	return total
func receive(event: Dictionary) -> void:
	events.append(event.duplicate(true))
	if String(event.type)=="item_collected":
		check(is_instance_valid(pending_item) and not pending_item.visible and app.world.collected.has(pending_item.get_instance_id()), "authoritative receipt emitted after node collection mutation")
func freeze() -> void:
	app.automated_input=true; app.player.set_physics_process(false); app.combat.set_physics_process(false); app.world.set_process(false); app.world.set_physics_process(false)
	for enemy in app.combat.enemies: enemy.set_physics_process(false)
	app.combat.combat_event.connect(receive)
func find(kind: String) -> Node3D:
	for item in app.world.pickups:
		if String(item.get_meta("stage_pickup"))==kind and not app.world.collected.has(item.get_instance_id()): return item
	return null
func reset_main() -> void:
	app.restart_combat(); freeze(); pending_item=null; events.clear()
func preservation() -> Dictionary:
	var prior: CombatAudioProfile=load(DIR+"preservation/profile-before.tres")
	var profile: CombatAudioProfile=load("res://resources/combat_audio.tres")
	check(prior.cues.size()==48 and profile.cues.size()==57,"48 prior +9 additive pickup cues")
	check(prior.music.resource_path==profile.music.resource_path and prior.music_gain_db==profile.music_gain_db,"approved music registration/gain unchanged")
	for i in prior.cues.size():
		var a: CombatCue=prior.cues[i]; var b: CombatCue=profile.cues[i]
		check(a.identifier==b.identifier and a.bus==b.bus and a.gain_db==b.gain_db and a.spatial==b.spatial and a.variations.size()==b.variations.size(),"prior cue values unchanged "+String(a.identifier))
		for j in a.variations.size(): check(a.variations[j].resource_path==b.variations[j].resource_path,"prior recorded stream unchanged "+String(a.identifier))
	var hashes: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DIR+"preservation/runtime-before.json"))
	for path in hashes: check(FileAccess.get_sha256("res://"+path)==hashes[path],"prior source bytes unchanged "+path)
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DIR+"manifest.json")); var seen: Dictionary={}
	for key in manifest.cues:
		var c: Dictionary=manifest.cues[key]; check(FileAccess.get_sha256(c.runtime)==c.runtime_sha256,"new export matches source/edit ledger "+key)
		check(not seen.has(c.runtime_sha256),"distinct designed file "+key); seen[c.runtime_sha256]=true
		var cue: CombatCue=profile.cues[48+TYPES.find(c.item_kind)]
		check(String(cue.identifier)==key and cue.bus==&"UI" and not cue.spatial and cue.variations.size()==1 and cue.variations[0].resource_path==c.runtime,"real UI nonspatial imported recording "+key)
		check(cue.variations[0].get_length()>=.08 and cue.variations[0].get_length()<=.35,"compact recording duration "+key)
	for src in manifest.sources:
		check(FileAccess.get_sha256(DIR+src.original)==src.sha256,"unchanged licensed original "+src.id)
		for evidence in src.license_evidence: check(FileAccess.get_sha256(DIR+evidence.file)==evidence.sha256,"retained existing CC0 evidence "+src.id)
	return {"old_profile_cues":48,"added_cues":9,"prior_audio_files_unchanged":hashes.size(),"distinct_pickup_exports":seen.size(),"source_recordings":manifest.sources.size()}
func accepted_types() -> void:
	for kind in TYPES:
		var actual_kind: String="twin_shotgun" if kind=="weapon" else kind
		pending_item=find(actual_kind); check(is_instance_valid(pending_item),"actual authored Main pickup exists "+kind)
		if not is_instance_valid(pending_item): continue
		var before:=cue_count(kind)
		if AMMO_FIELDS.has(kind):
			app.combat.set(AMMO_FIELDS[kind],app.combat.ammo_capacity(StringName(kind))); events.clear(); app.world.collect(pending_item)
			check(pending_item.visible and events.is_empty() and cue_count(kind)==before,"capped ordinary ammo retained/silent "+kind)
			app.combat.set(AMMO_FIELDS[kind],app.combat.ammo_capacity(StringName(kind))-1)
		elif kind in ["health","armor"]:
			app.combat.set(kind,100.0); events.clear(); app.world.collect(pending_item)
			check(pending_item.visible and events.is_empty() and cue_count(kind)==before,"capped health/armor retained/silent "+kind)
			app.combat.set(kind,99.5)
		elif kind.ends_with("_key"):
			app.world.flags["power"]=false; events.clear(); app.world.collect(pending_item)
			check(pending_item.visible and events.is_empty() and cue_count(kind)==before,"power rejected key is silent "+kind)
			app.world.flags["power"]=true
		events.clear(); app.world.collect(pending_item)
		check(count("item_collected")==1 and cue_count(kind)==before+1,"one accepted receipt without low-level event doubling "+kind)
		var receipt: Dictionary={}
		for e in events:
			if String(e.type)=="item_collected": receipt=e
		check(String(receipt.get("item_kind",""))==kind and int(receipt.get("pickup_id",0))==pending_item.get_instance_id(),"canonical item/node identity "+kind)
		if AMMO_FIELDS.has(kind):check(int(receipt.get("amount",0))==1 and count("ammo_added")==1,"actual partial one-unit ammo reported "+kind)
		if kind in ["health","armor"]:check(is_equal_approx(float(receipt.get("amount",0)),.5),"fractional actual capped health/armor amount "+kind)
		var voice: Node=app.combat_audio.voices.back()
		check(voice is AudioStreamPlayer and not voice is AudioStreamPlayer3D and voice.bus==&"UI" and voice.get_meta("role")=="item_collected","accepted pickup voice belongs to UI receipt "+kind)
		var counts: Dictionary=app.combat_audio.cue_counts.duplicate(); app.world.collect(pending_item)
		check(count("item_collected")==1 and app.combat_audio.cue_counts==counts,"repeat collection generates no receipt "+kind)
		app.combat_audio.handle_event(receipt)
		check(app.combat_audio.cue_counts==counts,"replayed receipt is presentation-deduplicated "+kind)
		records.append({"item_kind":kind,"actual_main_level":String(app.campaign.current_level().id),"pickup_node":String(pending_item.name),"amount":receipt.get("amount"),"new_weapon":receipt.get("new_weapon"),"source_event_count":count("item_collected"),"low_level_ammo_events":count("ammo_added"),"low_level_grant_events":count("weapon_granted"),"receipt_voice_count":cue_count(kind)-before})
func rejection_bait_and_aliases() -> void:
	reset_main(); pending_item=find("pistol"); var before:=total_receipts(); app.combat.ammo_pistol=0
	app.set_paused(true); events.clear(); app.world.collect(pending_item)
	check(pending_item.visible and events.is_empty() and total_receipts()==before,"paused actual collection is silent")
	app.set_paused(false); app.combat.dead=true; app.world.collect(pending_item)
	check(pending_item.visible and events.is_empty() and total_receipts()==before,"dead actual collection is silent"); app.combat.dead=false
	# Full already-owned lure still springs the existing trap but gets no receipt.
	pending_item=find("twin_shotgun"); app.combat.grant_weapon(&"twin_shotgun",100); var arena:=String(pending_item.get_meta("bait_arena")); events.clear(); before=total_receipts(); app.world.collect(pending_item)
	check(not pending_item.visible and app.world.collected.has(pending_item.get_instance_id()) and app.world.traps[arena].triggered,"full saturated owned weapon bait retains physical trap behavior")
	check(events.is_empty() and total_receipts()==before,"full saturated bait adds no grant/ammo/receipt cue")
	reset_main(); app.combat.ammo_shotgun=40; pending_item=find("twin_shotgun"); events.clear(); app.world.collect(pending_item)
	check(count("weapon_granted")==1 and count("ammo_added")==0 and count("item_collected")==1 and cue_count("weapon")==1,"new ownership at saturated ammo still gives exactly one weapon receipt")
	for e in events:
		if String(e.type)=="item_collected":check(bool(e.new_weapon) and int(e.amount)==0,"ownership-only receipt reports zero accepted ammo")
	reset_main(); app.combat.grant_weapon(&"twin_shotgun",100); app.combat.ammo_shotgun=39; pending_item=find("twin_shotgun"); events.clear(); app.world.collect(pending_item)
	check(count("weapon_granted")==1 and count("ammo_added")==1 and count("item_collected")==1 and cue_count("weapon")==1,"already-owned partial weapon cache gives one receipt")
	for e in events:
		if String(e.type)=="item_collected":check(not bool(e.new_weapon) and int(e.amount)==1,"partial duplicate weapon reports accepted unit")
	# Exercise aliases through real authored key nodes, changing only fixture metadata.
	for alias in ["brass","red"]:
		reset_main(); app.world.flags["power"]=true; pending_item=find(alias+"_key"); pending_item.set_meta("stage_pickup",alias); events.clear(); app.world.collect(pending_item)
		check(count("item_collected")==1 and cue_count(alias+"_key")==1,"actual collect canonicalizes "+alias)
		for e in events:
			if String(e.type)=="item_collected":check(String(e.item_kind)==alias+"_key","canonical alias event "+alias)
		var duplicate:=Node3D.new(); app.world.add_child(duplicate); duplicate.set_meta("stage_pickup",alias+"_key"); pending_item=duplicate; events.clear(); before=total_receipts(); app.world.collect(duplicate)
		check(count("item_collected")==0 and total_receipts()==before,"already-owned key alias emits no false receipt "+alias)
func lifecycle() -> void:
	reset_main(); pending_item=find("twin_shotgun"); app.world.collect(pending_item); var owner: Node=app.combat_audio; var voice: Node=owner.voices.back()
	await create_timer(.02,true).timeout; app.set_paused(true); var position: float=voice.get_playback_position(); await create_timer(.07,true).timeout
	paused_drift=absf(voice.get_playback_position()-position)
	check(not voice.can_process() and paused_drift<.04,"pickup UI receipt freezes under gameplay pause")
	var prior_mute:=AudioServer.is_bus_mute(0); AudioServer.set_bus_mute(0,true); app.set_paused(false)
	check(voice.can_process() and AudioServer.is_bus_mute(0),"mute affects audibility only; pickup voice resumes processing")
	AudioServer.set_bus_mute(0,prior_mute); app.restart_combat(); freeze()
	check(not is_instance_valid(owner) and not is_instance_valid(voice) and app.combat_audio.voices.is_empty() and app.combat_audio.seen_events.is_empty(),"Retry frees old UI receipt and resets deduplication owner")
	pending_item=find("twin_shotgun"); app.world.collect(pending_item)
	check(cue_count("weapon")==1,"fresh actual Retry pickup plays once")
	app.return_to_title(); check(app.menu_music.playing and app.combat_audio.voices.is_empty(),"title clears gameplay pickup voices and retains menu music")
func run() -> void:
	var preserved:=preservation()
	app=load("res://scenes/main.tscn").instantiate(); root.add_child(app); app.automated_input=true
	app.campaign_mode=true; app.campaign.seek("ash_citadel_01"); app.stage_id="ash_citadel"; app.replace_world({}); app.campaign.entry_snapshot=app.campaign.capture(app.combat); app.enter_combat(); freeze()
	accepted_types(); rejection_bait_and_aliases(); await lifecycle()
	app.menu_music.stop(); app.menu_music.stream=null; app.combat_audio.stop_all(); app.free(); app=null; pending_item=null; paused=false
	await create_timer(.4,true).timeout
	var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"preservation":preserved,"actual_collections":records,"pause_playback_drift_seconds":paused_drift,"scope":"Controlled real Main authored Ash Citadel pickups through Stage.collect, imported local CC0 UI streams, aliases/full/partial/duplicate/bait/pause/dead/mute/Retry. Inventory and power prerequisites set explicitly; fixture calls collect directly, not route/proximity proof. No subjective listening or stereo capture claimed."}
	var file:=FileAccess.open(DIR+"verification.json",FileAccess.WRITE)
	check(file!=null,"new verification ledger writable")
	if file:report.checks=checks; file.store_string(JSON.stringify(report,"  ")+"\n"); file.close()
	print("PICKUP_AUDIO_V6_%s: %d checks; 9 item receipts, 48 existing cues preserved, real Main collections, silent rejections/full bait, pause/mute/Retry." % ["OK" if failures.is_empty() else "FAILED",checks])
	quit(0 if failures.is_empty() else 1)
