extends SceneTree
## Actual Main shot/cue ownership at native combat cadence; no mock audio node.
var app: Control
var expected: Dictionary
var report_path := ""
var failures: Array[String] = []
var checks := 0
var events: Array[Dictionary] = []
var shots: Array[Dictionary] = []
func _initialize() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--expected="): expected=JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--expected=")))
  if arg.begins_with("--report="): report_path=arg.trim_prefix("--report=")
 call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);push_error("SELECTED_AUDIO_V10: "+label)
func freeze_actors() -> void:
 app.player.set_physics_process(false);app.world.set_physics_process(false)
 for node in app.world.find_children("*", "Node", true, false):
  if node!=app.combat and not app.combat.is_ancestor_of(node):node.set_physics_process(false)
 # Combat's real _physics_process keeps natural cooldown/phase timing.
 app.combat.set_physics_process(true)
func cue_count(id: String) -> int:return int(app.combat_audio.cue_counts.get(StringName(id),0))
func event_count(kind: String) -> int:
 var count:=0
 for event in events:
  if String(event.type)==kind:count+=1
 return count
func mute_button() -> CheckButton:
 for child in app.menu.find_children("*", "CheckButton", true, false):
  if child.text=="Mute all audio":return child
 return null
func frame() -> void:await process_frame;await process_frame
func run() -> void:
 app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
 if not app.campaign_mode:app.start_new_campaign()
 else:app.enter_combat()
 freeze_actors()
 app.combat.combat_event.connect(func(event:Dictionary):events.append(event.duplicate(true)))
 # Aim the actual gameplay camera into empty space to isolate firing cues from
 # legitimate wall/creature contact cues. Actors remain in the authored Intake.
 app.player.camera.global_position=Vector3(0,200,0)
 app.player.camera.look_at(Vector3(0,200,-100))
 var baseline: Resource=load(expected.baseline_profile_path)
 var baseline_cues: Dictionary={}
 for cue in baseline.cues:baseline_cues[String(cue.identifier)]=cue
 check(app.combat_audio.profile.cues.size()==57,"actual Main loads exactly57 cues")
 var chosen: Dictionary={}
 for item in expected.selected:chosen[item.cue]=item
 var preserved:=0
 for cue in app.combat_audio.profile.cues:
  var id:=String(cue.identifier)
  var before: Resource=baseline_cues[id]
  check(cue.bus==before.bus and cue.spatial==before.spatial,id+" native bus/spatial preserved")
  if chosen.has(id):
   var item:Dictionary=chosen[id]
   check(cue.variations.size()==1 and cue.variations[0].resource_path==item.runtime_file,id+" exact selected native path")
   check(is_equal_approx(cue.gain_db,float(item.gain_db)),id+" exact selected common4dB gain")
  else:
   check(cue.gain_db==before.gain_db and cue.variations.size()==before.variations.size(),id+" unselected native gain/variation count preserved")
   for i in cue.variations.size():check(cue.variations[i].resource_path==before.variations[i].resource_path,id+" unselected native stream preserved")
   preserved+=1
 check(preserved==54,"all54 other native cues preserved")
 check(app.combat_audio.profile.music_gain_db==baseline.music_gain_db and app.combat_audio.profile.music.resource_path==baseline.music.resource_path,"actual Main music registration/gain unchanged")
 # Warm both simulation and audio scheduling before the first measured trigger.
 for i in 8:await process_frame
 await create_timer(.25,true).timeout
 for kind in [&"pistol",&"shells"]:app.combat.add_ammo(kind,100)
 app.combat.grant_weapon(&"twin_shotgun",0)
 for item in expected.selected:
  var weapon:=StringName(item.weapon)
  if app.combat.currentweapon!=weapon:
   check(app.combat.select_weapon(weapon),String(weapon)+" real weapon switch accepted")
   await create_timer(.30,true).timeout
  var definition:Resource=app.combat.weapons[weapon]
  var cadence:float=definition.cooldown_seconds
  var previous_msec:=-1
  var previous_physics_frame:=-1
  for repeat in 4:
   events.clear()
   var before_ammo:int=app.combat.ammo_amount(definition.ammo_key)
   var before_cues:=cue_count(item.cue)
   var now:=Time.get_ticks_msec()
   var current_physics_frame:=Engine.get_physics_frames()
   var accepted:bool=app.combat.try_fire()
   check(accepted and event_count("shot")==1,String(weapon)+" repeat%d accepted shot emits one authoritative event"%repeat)
   check(before_ammo-app.combat.ammo_amount(definition.ammo_key)==definition.ammo_cost,String(weapon)+" repeat%d exact ammo cost"%repeat)
   check(cue_count(item.cue)==before_cues+1,String(weapon)+" repeat%d one selected firing cue"%repeat)
   check(events.size()==1,String(weapon)+" empty-space fixture has no material contact cue/event")
   var voice:Node=app.combat_audio.voices.back()
   check(voice is AudioStreamPlayer and voice.stream.resource_path==item.runtime_file and is_equal_approx(voice.volume_db,float(item.gain_db)) and voice.bus==&"Weapons",String(weapon)+" accepted native voice uses selected stream/gain/Weapons bus")
   var after_ammo:int=app.combat.ammo_amount(definition.ammo_key)
   check(not app.combat.try_fire() and cue_count(item.cue)==before_cues+1 and app.combat.ammo_amount(definition.ammo_key)==after_ammo,String(weapon)+" immediate cooldown duplicate is silent and costs no ammo")
   var event:Dictionary=events[0]
   app.combat_audio.handle_event(event)
   check(cue_count(item.cue)==before_cues+1,String(weapon)+" replayed accepted-event identity cannot create duplicate firing voice")
   if previous_physics_frame>=0:check(float(current_physics_frame-previous_physics_frame)/Engine.physics_ticks_per_second>=cadence-1.0/Engine.physics_ticks_per_second,String(weapon)+" repeats respect authoritative physics cadence within one step")
   shots.append({"weapon":weapon,"repeat":repeat,"cue":item.cue,"stream":voice.stream.resource_path,"gain_db":voice.volume_db,"ammo_cost":definition.ammo_cost,"accepted_msec":now,"physics_frame":Engine.get_physics_frames(),"configured_cadence":cadence})
   previous_msec=now
   previous_physics_frame=current_physics_frame
   await create_timer(cadence+.045,true).timeout
 # Fresh real Twin voice remains long enough to measure pause/mute transitions.
 var item:Dictionary=expected.selected[2]
 check(app.combat.try_fire(),"fresh Twin shot accepted before pause")
 var owner:Node=app.combat_audio
 var voice:Node=owner.voices.back()
 await create_timer(.08,true).timeout
 var before_pause_position:float=voice.get_playback_position()
 var before_pause_playing:bool=voice.playing
 app.set_paused(true)
 var paused_position:float=voice.get_playback_position()
 var paused_playing:bool=voice.playing
 check(before_pause_position>0 and before_pause_playing,"fresh selected Twin voice is advancing before pause measurement")
 var paused_count:=cue_count(item.cue)
 var paused_ammo:int=app.combat.ammo_shotgun
 await create_timer(.12,true).timeout
 var pause_drift:=absf(voice.get_playback_position()-paused_position)
 check(not voice.can_process() and pause_drift<.04,"pause freezes selected voice playback within audio-buffer tolerance")
 check(not app.combat.try_fire() and cue_count(item.cue)==paused_count and app.combat.ammo_shotgun==paused_ammo,"paused shot rejection produces no selected cue/ammo cost")
 mute_button().button_pressed=true
 app.set_paused(false)
 var resumed_position:float=voice.get_playback_position()
 await create_timer(.10,true).timeout
 var mute_metrics := {"before_pause_position":before_pause_position,"before_pause_playing":before_pause_playing,"paused_voice_playing":paused_playing,"paused_position":paused_position,"resumed_position":resumed_position,"after_resume_position":voice.get_playback_position(),"voice_can_process":voice.can_process(),"master_muted":AudioServer.is_bus_mute(0),"voice_playing":voice.playing,"stream_paused":voice.stream_paused,"stream_length":voice.stream.get_length(),"mix_rate":AudioServer.get_mix_rate()}
 check(AudioServer.is_bus_mute(0) and voice.can_process() and voice.get_playback_position()>resumed_position,"mute changes audibility only; selected voice keeps processing after resume")
 check(app.combat.ammo_shotgun==paused_ammo and cue_count(item.cue)==paused_count,"mute toggle cannot emit firing events or alter ammo")
 mute_button().button_pressed=false
 app.restart_combat();freeze_actors();await frame()
 check(not is_instance_valid(owner) and not is_instance_valid(voice),"Retry frees selected gameplay voices and their old owner")
 check(app.combat_audio.voices.is_empty() and app.combat_audio.seen_events.is_empty() and app.combat_audio.cue_counts.is_empty(),"Retry resets voice list/event dedup/count ownership")
 for item_after in expected.selected:
  var cue:Resource=app.combat_audio.cue_map[StringName(item_after.cue)]
  check(cue.variations[0].resource_path==item_after.runtime_file and is_equal_approx(cue.gain_db,float(item_after.gain_db)),String(item_after.weapon)+" selected stream/gain survives Retry")
 var report:Dictionary={"status":"passed" if failures.is_empty() else "failed","checks":checks,"failures":failures,"repeated_shots":shots,"pause_playback_drift_seconds":pause_drift,"mute_metrics":mute_metrics,"other_native_cues_preserved":preserved,"cadence_clock":"Engine physics frames, one-step tolerance; wall timestamps retained as diagnostics. Initial headless startup catch-up example preserved separately.","scope":"Actual source/packed Main, authored Intake and real combat timers; manual accepted trigger calls, no forced cooldown stepping. Actual camera aimed into empty sky to isolate firing cue from legitimate impact audio; actors/world physics frozen while combat timers run. Controlled full ammo/Twin grant, real pause/mute CheckButton/Retry. No subjective listening, actual ELF execution, player-route or stereo recording claim."}
 FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
 print("SELECTED_AUDIO_V10 ",report.status," ",checks," ",failures)
 await app.quit_game();quit(0 if failures.is_empty() else 1)
