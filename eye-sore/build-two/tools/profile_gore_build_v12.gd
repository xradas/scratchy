extends SceneTree
const Chunk := preload("res://scripts/gore_chunk_v12.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var profile: GoreProfile=load("res://resources/gore_profile.tres")
	var gore:=preload("res://scripts/combat_gore.gd").new();root.add_child(gore);gore.setup(null,profile);gore.set_physics_process(false)
	var rng:=RandomNumberGenerator.new();rng.seed=120012
	Chunk.clear_cache()
	var records:=[]
	for phase in ["cold","warm"]:
		for kind in profile.species_atlases:
			var total:=0.0;var maximum:=0.0;var parts:=[]
			for index in int(profile.gib_counts[kind]):
				var part:Dictionary=gore.part_spec(kind,index,true)
				var start:=Time.get_ticks_usec();var node:=Chunk.create(part,rng);node.free()
				var elapsed:float=(Time.get_ticks_usec()-start)/1000.0;total+=elapsed;maximum=maxf(maximum,elapsed)
				parts.append({"name":part.name,"ms":elapsed})
			records.append({"phase":phase,"kind":kind,"total_ms":total,"max_part_ms":maximum,"parts":parts})
			await process_frame
	var folder:="res://verification/production-v12/bursts-performance";DirAccess.make_dir_recursive_absolute(folder)
	var suffix:="headless" if DisplayServer.get_name()=="headless" else "native"
	var report:={"scope":"Production profile/part_spec and Chunk.create cold/warm resource construction only; noCombat damage/settlement/scene work. Main phase profiler separate.","helper_sha256":FileAccess.get_sha256("res://scripts/gore_chunk_v12.gd"),"records":records,"cache":Chunk.cache_state()}
	FileAccess.open(folder+"/build-"+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	for record in records: print(record.phase," ",record.kind," total_ms=",record.total_ms," max_part_ms=",record.max_part_ms)
	quit()
