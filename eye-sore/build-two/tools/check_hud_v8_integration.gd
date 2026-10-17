extends SceneTree
## Independent source Main integration evidence. Never replaces/injects a HUD.
## Run with fresh XDG_DATA_HOME=/tmp/eyesore-hud-v8-... and --automated-input.
var app: Control
var failures: Array[String] = []
var checks := 0
var snapshots: Array[Dictionary] = []
var capture := false
const OUTPUT := "res://verification/production-v8/hud-main"

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures.append(label)
  push_error("HUD_MAIN_V8: " + label)
func boot() -> Control:
 var result: Control = load("res://scenes/main.tscn").instantiate()
 root.add_child(result)
 return result
func retire() -> void:
 if is_instance_valid(app.menu_music): app.menu_music.stop()
 if is_instance_valid(app.combat_audio): app.combat_audio.stop_all()
 app.free()
func map_toggle() -> CheckButton:
 for child in app.menu.find_children("*", "CheckButton", true, false):
  if child.text == "Visited-area mini-map": return child
 return null
func freeze() -> void:
 app.player.set_physics_process(false)
 app.world.set_physics_process(false)
 app.combat.set_physics_process(false)
 for enemy in app.combat.enemies: enemy.set_physics_process(false)
func frame() -> void:
 await process_frame
 await process_frame
func screen(label: String) -> void:
 if not capture: return
 await frame()
 RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png(OUTPUT + "/" + label + ".png")
func menu_fits() -> bool:
 return Rect2(Vector2.ZERO, Vector2(root.size)).encloses(app.menu.get_rect())
func check_scroll_controls(window_size: Vector2i) -> void:
 var scrolls: Array = app.menu.find_children("*", "ScrollContainer", true, false).filter(func(node): return node.get_parent() == app.menu)
 check(scrolls.size() == 1, "%s actual menu uses one scrolling viewport" % window_size)
 if scrolls.is_empty(): return
 var scroll: ScrollContainer = scrolls[0]
 check(app.menu.get_global_rect().encloses(scroll.get_global_rect()), "%s scrolling viewport stays inside menu frame" % window_size)
 check(scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED and scroll.follow_focus, "%s menu clips horizontal overflow and follows keyboard focus" % window_size)
 var reached := 0
 for child in app.menu.find_children("*", "Control", true, false):
  if not child.is_visible_in_tree() or child.focus_mode == Control.FOCUS_NONE: continue
  if not (child is BaseButton or child is Slider): continue
  child.grab_focus()
  await frame()
  check(scroll.get_global_rect().grow(1).encloses(child.get_global_rect()), "%s keyboard focus scrolls %s fully into view" % [window_size, child.text if child is BaseButton else "slider"])
  reached += 1
 check(reached >= 8, "%s all actual menu actions/settings reachable by focus" % window_size)
 if window_size == Vector2i(640,360): await screen("pause-640x360-scrolled")
 scroll.scroll_vertical = 0
func run() -> void:
 capture = "--capture-hud-v8-main" in OS.get_cmdline_user_args()
 if not OS.get_environment("XDG_DATA_HOME").begins_with("/tmp/eyesore-hud-v8-"):
  push_error("Use a fresh /tmp/eyesore-hud-v8-* XDG_DATA_HOME to protect real settings")
  quit(2); return
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 app = boot(); await frame()
 check(app.hud.get_script().resource_path == "res://scripts/industrial_hud_v8.gd", "actual Main owns new HUD instance")
 check(not app.started and not app.hud.visible and app.title_art.visible, "title hides instrumentation")
 check(app.minimap_enabled and app.hud.minimap_enabled and map_toggle().button_pressed, "clean profile defaults mini-map on in settings/HUD")
 map_toggle().button_pressed = false
 var config := ConfigFile.new()
 check(config.load(app.SETTINGS_PATH) == OK and config.get_value("display", "minimap", true) == false, "actual settings toggle persists disabled to isolated profile")
 check(not app.minimap_enabled and not app.hud.minimap_enabled, "actual toggle disables HUD mini-map")
 retire(); await frame()
 app = boot(); await frame()
 check(not app.minimap_enabled and not app.hud.minimap_enabled and not map_toggle().button_pressed, "second actual Main boot loads disabled setting consistently")
 map_toggle().button_pressed = true
 retire(); await frame()
 app = boot(); await frame()
 check(app.minimap_enabled and app.hud.minimap_enabled and map_toggle().button_pressed, "third actual Main boot restores re-enabled setting")
 root.size = Vector2i(640, 360); await frame(); app.layout_view()
 await screen("title-640x360")
 if not app.campaign_mode: app.start_new_campaign()
 else: app.enter_combat()
 await physics_frame; await physics_frame
 freeze(); await frame()
 check(app.hud.visible and not app.title_art.visible and not app.menu.visible, "enter play shows actual HUD and removes title/menu")
 check(app.hud.text.contains("HEALTH %d" % app.combat.health), "Main binds real combat health")
 check(app.hud.active_ammunition().capacity == app.combat.ammo_capacity(&"pistol"), "Main binds real campaign pistol capacity")
 check(app.hud.visible_map_rooms().size() == app.world.get_level_state().map_rooms.size(), "Main binds actual visited room subset")
 for id in [&"shotgun", &"twin_shotgun", &"rivet_cannon", &"siege_launcher"]: app.combat.grant_weapon(id, 7)
 app.combat.select_weapon(&"twin_shotgun")
 app.combat._physics_process(0.3)
 app.combat.health = 67; app.combat.armor = 42
 app.world.flags.power = true
 var key_receipts: Array[String] = []
 for pickup in app.world.pickups:
  var kind := String(pickup.get_meta("stage_pickup", ""))
  if kind in ["brass", "red", "brass_key", "red_key"]:
   app.world.collect(pickup); key_receipts.append(kind)
 await frame()
 check(app.hud.inventory_slots()[3].owned and app.hud.inventory_slots()[3].selected and not app.hud.inventory_slots()[4].selected, "Main refreshes newly owned inventory and selected Twin distinctly")
 check(app.hud.held_keys() == ["brass", "red"], "actual authored key collection updates both icons")
 check(app.hud.text.contains("HEALTH 67") and app.hud.text.contains("ARMOR 42"), "Main refreshes damage and armor values")
 var initial_shells: int = app.combat.ammo_shotgun
 app.combat.ammo_shotgun -= 2
 await frame()
 check(app.hud.active_ammunition().amount == initial_shells - 2, "Main refreshes partial active shell reserve")
 var sizes := [Vector2i(1280, 720), Vector2i(1024, 768), Vector2i(1440, 900), Vector2i(800, 600), Vector2i(640, 360)]
 for window_size in sizes:
  root.size = window_size; await frame(); app.layout_view(); await frame()
  var layout: Dictionary = app.hud.layout_snapshot()
  check(Rect2(Vector2.ZERO, Vector2(window_size)).encloses(app.hud.get_rect()), "%s actual Main HUD stays in window" % window_size)
  for name in ["health", "armor", "ammo", "inventory", "utility", "map"]:
   check(Rect2(Vector2.ZERO, app.hud.size).encloses(layout[name]), "%s actual Main %s panel stays within HUD" % [window_size, name])
  if window_size == Vector2i(640, 360): check(app.hud.position.y == 304 and app.hud.size.y == 56, "actual minimum window uses56pxbar at304")
  if window_size in [Vector2i(1024,768), Vector2i(800,600)]: check(app.hud.position.y >= app.world_image.get_rect().end.y, "%s actual lower letterbox retains receiver" % window_size)
  await screen("play-%dx%d" % [window_size.x, window_size.y])
  app.set_paused(true); await frame()
  check(app.hud.visible and app.menu.visible and not app.status.visible and not app.automap.visible, "%s pause preserves instrumentation and menu visibility" % window_size)
  check(menu_fits(), "%s actual Pause/menu fits window" % window_size)
  snapshots.append({"window":window_size,"hud_rect":app.hud.get_rect(),"world_rect":app.world_image.get_rect(),"menu_rect":app.menu.get_rect(),"layout":layout})
  if window_size == Vector2i(640,360): await screen("pause-640x360")
  await check_scroll_controls(window_size)
  app.set_paused(false)
 var event := InputEventKey.new(); event.pressed = true; event.keycode = KEY_TAB
 app._input(event); await frame()
 check(app.automap.visible and app.hud.minimap_enabled, "Tab full map opens independently from mini-map")
 app._input(event); await frame()
 check(not app.automap.visible and app.hud.minimap_enabled, "Tab full map closes without disabling mini-map")
 var carried: Dictionary = app.campaign.capture(app.combat)
 app.level_complete = true; app.continue_campaign(); freeze(); await frame()
 check(app.campaign.current_level().id == "pale_ward_02" and app.hud.inventory_slots()[3].selected and app.hud.inventory_slots()[3].owned, "actual Main carry refreshes selected owned Twin")
 check(app.hud.active_ammunition().amount == carried.ammo_shotgun and app.hud.held_keys().is_empty(), "actual carry refreshes ammunition and clears chapter-local keys")
 app.combat.health = 1; app.combat.currentweapon = &"pistol"
 app.restart_combat(); freeze(); await frame()
 check(app.hud.text.contains("HEALTH %d" % carried.health) and app.hud.inventory_slots()[3].selected, "actual Main Retry restores HUD health and selected carried weapon")
 check(app.hud.held_keys().is_empty() and app.hud.visible_map_rooms().size() <= 1, "actual Retry clears keys and visited map history")
 app.return_to_title(); await frame()
 check(not app.hud.visible and app.title_art.visible and app.menu.visible, "return to title removes instrumentation")
 var report := {"status":"passed" if failures.is_empty() else "failed","checks":checks,"failures":failures,"snapshots":snapshots,"key_receipts":key_receipts,"settings_profile":OS.get_user_data_dir(),"source_main_sha256":FileAccess.get_sha256("res://scripts/main.gd"),"scope":"Actual integrated source Main HUD/settings. No replacement HUD or injected display state. Fresh temporary XDG profile; real CheckButton signal/save and two subsequent Main loads. Controlled actual weapon grants/select, authored key collects after power fixture, direct health/armor/ammo fixture changes. Actor/world AI physics frozen. Actual pause/title/Tab/carry/Retry and five window layouts. Not live traversal or human visual acceptance."}
 var file := FileAccess.open(OUTPUT+"/checks.json", FileAccess.WRITE);file.store_string(JSON.stringify(report,"  ")+"\n");file.close()
 print("HUD_MAIN_V8 ",report.status," ",checks," ",failures)
 await app.quit_game()
 quit(0 if failures.is_empty() else 1)
