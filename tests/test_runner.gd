extends Node
## Deterministic headless integration suite. Never reads or writes the real user save.
var passed: int = 0
var failures: Array = []
var checks: Array = []

func check(condition: bool, name: String) -> void:
	checks.append({"name":name,"passed":condition})
	if condition:
		passed += 1
		print("PASS "+name)
	else:
		failures.append(name)
		print("TEST FAIL "+name)

func run() -> void:
	Game.persistence = false
	Game.storage_path = "user://bh_test_%d.json" % Time.get_ticks_usec()
	Sfx.enabled = false
	spiral_tests()
	contract_tests()
	housing_tests()
	module_tests()
	save_tests()
	await appearance_tests()
	await rig_editor_tests()
	await combat_tests()
	await hazard_tests()
	await view3d_tests()
	await navigation_tests()
	for suffix in ["",".tmp",".bak"]:
		if FileAccess.file_exists(Game.storage_path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.storage_path+suffix))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var ignore = FileAccess.open("res://artifacts/.gdignore",FileAccess.WRITE)
	if ignore!=null:
		ignore.close()
	var report: Dictionary = {"engine":Engine.get_version_info().string,"passed":passed,"failed":failures.size(),"checks":checks,"scope":"domain + in-engine combat/navigation integration; automated, not a human playtest"}
	var file = FileAccess.open("res://artifacts/test-results.json",FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify(report,"\t"))
		file.close()
	print("TEST SUMMARY: %d passed; %d failed" % [passed,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func spiral_tests() -> void:
	check(BHSpiral.point(1)==Vector2i.ZERO,"SS14 spiral origin")
	check(BHSpiral.point(2)==Vector2i(1,0),"SS14 spiral first neighbor")
	var occupied: Dictionary = {}
	for i in range(1,BHSpiral.points_for_max_distance(5)+1):
		occupied[BHSpiral.point(i)] = true
	check(occupied.size()==121,"SS14 spiral covers 121 unique cells")
	check(occupied.has(Vector2i(-5,-5)) and occupied.has(Vector2i(5,5)),"SS14 spiral covers extreme corners")

func contract_tests() -> void:
	Game.reset(false)
	check(Game.validate_save(Game.s),"fresh state validates")
	check(not Game.accept("mechanic","captain").ok,"captain contract requires recruited hunter")
	check(not Game.accept("courier","pilot").ok,"wrong-port contract rejected")
	check(not Game.travel("glass").ok,"second port locked before bounty completion")
	check(Game.hire("voss").ok and Game.s.credits==1420,"recruitment charges exact fee")
	var money: int = Game.s.credits
	check(not Game.hire("voss").ok and Game.s.credits==money,"duplicate recruitment rejected without charge")
	check(Game.accept("mechanic","captain").ok and Game.active_hunter()=="voss","captain retains recruited hunter")
	check(not Game.hire("rio").ok,"hunter cannot change during active contract")
	check(not Game.accept("salvage","pilot").ok,"only one active contract")
	check(Game.investigate().ok and Game.s.mission.intel,"records produce persisted intel")
	check(not Game.investigate().ok,"intel cannot duplicate")
	check(Game.estimated_reward()==1088,"captain payout uses hunter share")
	check(Game.launch().ok and Game.s.credits==1320,"departure fee charged once")
	check(not Game.launch().ok and Game.s.credits==1320,"repeat launch rejected")
	check(not Game.investigate().ok,"records unavailable during flight")
	check(not Game.cancel().ok,"active flight cannot be cancelled without settlement")
	check(not Game.travel("glass").ok,"flight cannot travel through port menu")
	var settlement: Dictionary = Game.finish(true,80)
	check(settlement.ok and settlement.gross==1088 and settlement.repairs==20,"settlement itemizes reward and repairs")
	money = Game.s.credits
	check(money==2388 and Game.s.completed==1 and Game.s.trust.voss==1,"settlement applies progression and credits")
	check(not Game.finish(true,80).ok and Game.s.credits==money,"duplicate settlement cannot award money")
	check(Game.travel("glass").ok,"successful bounty unlocks second port")
	check(Game.available_contracts().has("courier"),"new port exposes courier contract")
	Game.reset(false)
	check(Game.accept("mechanic","pilot").ok and Game.active_hunter()=="voss" and Game.s.crew=="","pilot contract supplies temporary hunter")
	check(Game.estimated_reward()==950,"pilot fixed reward differs from captain share")
	check(Game.cancel().ok and Game.active_hunter()=="","temporary hunter departs when contract cancelled")
	Game.s.credits = 0
	check(Game.accept("salvage","captain").ok and Game.launch().ok,"zero-credit player can launch recovery contract")
	check(Game.finish(true,100).ok and Game.s.credits==420,"recovery contract breaks poverty lock")
	check(Game.s.completed==0,"salvage does not bypass bounty gate")
	Game.accept("mechanic","pilot")
	Game.launch()
	check(Game.finish(false,-200).repairs==100,"damage repair cost bounded at full hull")
	check(Game.s.credits>=0 and Game.s.phase=="dock","failure returns safely without debt or ship deletion")

func housing_tests() -> void:
	Game.reset(false)
	check(Game.comfort()==17,"starter furniture provides comfort")
	check(not Game.can_place("bed",Vector2i(7,1),true),"rotated furniture cannot block central aisle")
	check(not Game.can_place("plant",Vector2i(0,0),false),"airlock column reserved")
	check(not Game.can_place("bed",Vector2i(16,3),false),"cockpit column reserved")
	check(not Game.can_place("plant",Vector2i(-1,4),false),"negative placement rejected")
	check(not Game.can_place("plant",Vector2i(2,0),false),"overlapping placement rejected")
	var money: int = Game.s.credits
	check(not Game.place("bed",Vector2i(2,0)).ok and Game.s.credits==money,"invalid placement does not spend money")
	check(Game.place("bed",Vector2i(7,3),false,1).ok and Game.s.credits==money,"moving owned furniture is free")
	check(not Game.place("bed",Vector2i(10,3),false,12345).ok,"unknown furniture move rejected")
	check(Game.place("plant",Vector2i(10,3)).ok and Game.s.credits==money-70,"valid placement pays exact price")
	var comfort: int = Game.comfort()
	Game.place("plant",Vector2i(11,3))
	check(Game.comfort()==comfort,"duplicate decoration does not stack category bonus")
	var spot: Vector2i = Game.nearest_cell("desk",Vector2i(7,2),false)
	check(spot!=Vector2i(-1,-1) and Game.can_place("desk",spot,false),"upstream spiral finds legal housing placement")
	Game.s.condition = 30
	Game.rest()
	check(Game.s.condition==60+12+Game.comfort(),"housing changes actual recovery amount")
	Game.rest()
	check(Game.s.condition==100,"rest condition capped")
	money = Game.s.credits
	check(Game.remove_furniture(1).ok and Game.s.credits==money+135,"selling furniture refunds seventy-five percent")
	check(not Game.remove_furniture(1).ok,"sold furniture cannot be refunded twice")
	Game.s.credits = 0
	check(not Game.place("desk",Vector2i(7,3)).ok,"placement respects budget")
	check(Game.validate_save(Game.s),"mutated housing state remains valid")

func module_tests() -> void:
	Game.reset(false)
	check(Game.power_load()==10,"starter load uses ten power")
	check(not Game.equip("rail",0).ok,"unowned module cannot be equipped")
	check(Game.buy_module("rail").ok and Game.s.credits==920,"module purchase exact cost")
	var money: int = Game.s.credits
	check(not Game.buy_module("rail").ok and Game.s.credits==money,"duplicate module purchase blocked")
	check(not Game.equip("rail",0).ok and Game.power_load()==10,"over-capacity fit rejected atomically")
	check(Game.equip("rail",1).ok and Game.power_load()==12,"tradeoff fit meets power limit")
	check(Game.equip("rail",2).ok and Game.s.equipped[1]=="shield" and Game.s.equipped[2]=="rail","already fitted module swaps slots without duplication")
	check(Game.validate_save(Game.s),"fitted loadout validates")
	Game.accept("mechanic","pilot")
	Game.launch()
	check(not Game.equip("emp",0).ok and not Game.buy_module("drone").ok,"loadout locked during flight")

func appearance_tests() -> void:
	Game.reset(false)
	check(BHAppearance.valid(Game.s.look) and Game.s.look.hair=="base","new captain starts with the cutout-sheet look")
	check(Game.set_look("hair","hair_08_tied_high").ok and Game.s.look.hair=="hair_08_tied_high","hairstyle choice persists in state")
	check(not Game.set_look("hair","hair_99").ok and Game.s.look.hair=="hair_08_tied_high","unknown hairstyle rejected")
	check(not Game.set_look("cloth",12).ok and not Game.set_look("cloth",-1).ok and not Game.set_look("cloth",1.5).ok,"cloth colour out of catalog rejected")
	check(not Game.set_look("goggles","yes").ok and not Game.set_look("wings",true).ok,"gear toggles only accept known booleans")
	check(Game.set_look("cloth",9).ok and Game.set_look("cap",true).ok and Game.validate_save(Game.s),"customized look validates for save")
	var parser = JSON.new()
	parser.parse(JSON.stringify(Game.s))
	check(Game.validate_save(parser.data),"look survives JSON number conversion")
	var old: Dictionary = parser.data.duplicate(true)
	old.erase("look")
	check(Game.validate_save(old),"saves from before customization still load")
	var broken: Dictionary = parser.data.duplicate(true)
	broken.look = {"hair":"base"}
	check(not Game.validate_save(broken),"malformed look rejected on load")
	var rig: Dictionary = BHRig.load_file(BHPuppet.DEFAULT_RIG)
	var missing: Array = []
	var custom: Dictionary = rig.get("customize",{})
	for id in BHAppearance.hair_ids():
		var hair: String = str(custom.base_head) if id=="base" else id
		if BHRig.attachment(rig,str(custom.hair_slot),hair,"front").is_empty():
			missing.append(id)
	for slot in rig.slots:
		for att_name in rig.skins.default.get(slot.name,{}):
			for view in rig.skins.default[slot.name][att_name]:
				if BHRig.texture(rig,str(rig.skins.default[slot.name][att_name][view].image))==null:
					missing.append(att_name)
	check(missing.is_empty() and rig.slots.size()==19,"every rig attachment and hairstyle has a transparent PNG")
	check(BHRig.problems(rig).is_empty() and rig.animations.has("idle") and rig.animations.has("walk") and rig.animations.has("run"),"captain rig is well formed with idle, walk and run")
	check(BHRig.view_for(Vector2.DOWN)==["front",false] and BHRig.view_for(Vector2.LEFT)==["side",true] and BHRig.view_for(Vector2(1,-1))==["back34",false] and BHRig.view_for(Vector2(-1,1))==["front34",true],"eight directions map to five drawn views plus mirrors")
	check(BHRig.effective_view(rig,"side")=="front","undrawn views borrow the drawn view")
	var keys: Array = [[0.0,0.0,"linear"],[1.0,10.0,"step"],[2.0,20.0,"linear"]]
	check(is_equal_approx(BHRig.sample(keys,0.5,2.0,false,1)[0],5.0) and is_equal_approx(BHRig.sample(keys,1.5,2.0,false,1)[0],10.0) and is_equal_approx(BHRig.sample(keys,3.0,2.0,false,1)[0],20.0),"keyframe curves: linear, step and hold")
	var loop_keys: Array = [[0.0,0.0,"linear"],[0.5,10.0,"linear"]]
	check(is_equal_approx(BHRig.sample(loop_keys,0.75,1.0,true,1)[0],5.0),"looping clips wrap from the last key to the first")
	var override_rig: Dictionary = rig.duplicate(true)
	override_rig.views = ["front","side"]
	override_rig.animations.walk.tracks["side"] = {"thigh_l":{"rotate":[[0.0,33.0,"linear"]]}}
	check(is_equal_approx(BHRig.pose(override_rig,"walk","side",0.1).thigh_l.rotate,33.0) and not is_equal_approx(BHRig.pose(override_rig,"walk","front",0.1).thigh_l.rotate,33.0),"view-specific tracks override the shared clip")
	var doll = BHPuppet.new()
	doll.look = Game.s.look.duplicate()
	add_child(doll)
	await get_tree().process_frame
	check(doll.sprites.size()==19 and doll.sprites.head.texture.resource_path.ends_with("hair_08_tied_high.png"),"puppet builds all slots with chosen hair")
	check(doll.sprites.cap.visible and not doll.sprites.goggles.visible,"puppet shows only equipped gear")
	var rest_boot: Vector2 = doll.sprites.boot_l.position
	doll.moving = true
	doll.speed = 160.0
	for n in range(6):
		doll._process(0.05)
	check(doll.clip=="walk" and doll.sprites.boot_l.position.distance_to(rest_boot)>4.0,"walking plays the walk clip and moves the legs")
	doll.speed = 265.0
	doll._process(0.05)
	check(doll.clip=="run" and doll.fade<1.0,"sprinting cross-fades into the run clip")
	doll.set_direction(Vector2.LEFT)
	doll.refresh()
	check(doll.mirrored and doll.doll.scale.x<0.0,"walking left mirrors the side view")
	doll.apply_look(BHAppearance.defaults())
	check(doll.sprites.head.texture.resource_path.ends_with("head_front.png") and not doll.sprites.cap.visible,"puppet swaps look live")
	doll.queue_free()
	var partial: Dictionary = rig.duplicate(true)
	partial.views = ["front","side"]
	partial.skins.default.head.head["side"] = partial.skins.default.head.head.front.duplicate(true)
	var sided = BHPuppet.new()
	sided.rig = partial
	sided.look = Game.s.look.duplicate()
	add_child(sided)
	sided.set_direction(Vector2.RIGHT)
	sided.refresh()
	check(sided.view=="side" and sided.sprites.head.visible and sided.sprites.head.texture.resource_path.ends_with("head_front.png") and not sided.sprites.thigh_l.visible,"undrawn hairstyle falls back to the base head; parts missing in a drawn view hide")
	sided.queue_free()
	Game.reset(false)

func rig_editor_tests() -> void:
	var editor = BHRigEditor.new()
	add_child(editor)
	await get_tree().process_frame
	editor.rig_path = "user://rig_editor_test_%d.json" % Time.get_ticks_usec()
	check(editor.rig.bones.size()==20 and editor.puppet.sprites.size()==19,"rig editor opens the captain rig")
	editor.set_mode("bone")
	editor.select_bone("arm_l")
	var before: float = float(BHRig.setup(editor.rig,editor.bones().arm_l,"front").x)
	var joint: Vector2 = editor.to_canvas(editor.world().arm_l.origin)
	editor.begin_drag(joint,false)
	editor.continue_drag(joint+Vector2(17,0))
	editor.drag = {}
	var moved: float = float(BHRig.setup(editor.rig,editor.bones().arm_l,"front").x)-before
	check(is_equal_approx(snappedf(moved,0.1),snappedf(17.0/editor.zoom,0.1)),"dragging a joint moves the bone in rig space")
	editor.set_mode("anim")
	editor.set_clip("walk")
	editor.set_time(0.1)
	editor.key_value("rotate",[25.0])
	check(is_equal_approx(BHRig.pose(editor.rig,"walk","front",0.1).arm_l.rotate,25.0),"editing a pose sets a key at the current time")
	editor.undo()
	check(not is_equal_approx(BHRig.pose(editor.rig,"walk","front",0.1).arm_l.rotate,25.0),"undo removes the key")
	editor.redo()
	check(is_equal_approx(BHRig.pose(editor.rig,"walk","front",0.1).arm_l.rotate,25.0),"redo restores the key")
	editor.set_view("side")
	check("side" in editor.rig.views and editor.bones().thigh_l.setup.has("side"),"a new view starts as a copy of the first view")
	editor.toggle_scope()
	editor.select_bone("thigh_l")
	editor.key_value("rotate",[40.0])
	check(is_equal_approx(BHRig.pose(editor.rig,"walk","side",0.1).thigh_l.rotate,40.0) and not is_equal_approx(BHRig.pose(editor.rig,"walk","front",0.1).thigh_l.rotate,40.0),"view-only track changes one direction")
	editor.save()
	var saved: Dictionary = BHRig.load_file(editor.rig_path,true)
	check("side" in saved.get("views",[]) and BHRig.problems(saved).is_empty() and not editor.dirty,"editor saves a valid rig file")
	check(not "side" in BHRig.load_file(BHPuppet.DEFAULT_RIG).views,"editing does not touch the game's loaded rig until saved to it")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(editor.rig_path))
	editor.queue_free()
	await get_tree().process_frame

func save_tests() -> void:
	Game.reset(false)
	Game.hire("rio")
	Game.place("plant",Vector2i(10,3))
	Game.accept("mechanic","captain")
	Game.investigate()
	var snapshot: String = JSON.stringify(Game.s)
	check(Game.save_game(),"atomic save writes isolated test file")
	Game.reset(false)
	check(Game.load_game() and Game.s.crew=="rio" and Game.s.mission.intel and Game.s.layout.size()==3,"save/load restores contract crew and exact furniture")
	check(Game.validate_save(Game.s),"JSON numeric conversion accepted safely")
	Game.launch()
	var credits: int = Game.s.credits
	check(Game.save_game(),"flight checkpoint saved")
	Game.reset(false)
	check(Game.load_game() and Game.s.phase=="dock" and Game.s.mission.paid,"interrupted flight restores departure checkpoint")
	check(Game.launch().ok and Game.s.credits==credits,"relaunch does not double-charge fee")
	Game.finish(false,95)
	Game.save_game()
	# Deliberate corruption: original backup still contains a valid checkpoint.
	var file = FileAccess.open(Game.storage_path,FileAccess.WRITE)
	file.store_string("broken test payload")
	file.close()
	Game.reset(false)
	check(Game.load_game() and not Game.last_storage_error.is_empty(),"corrupt primary recovers backup and warns")
	var parser = JSON.new()
	parser.parse(snapshot)
	var clean: Dictionary = parser.data
	for key in ["credits","condition","schema","next_uid","sequence","completed"]:
		var invalid: Dictionary = clean.duplicate(true)
		invalid[key] = {"bad":"type"}
		check(not Game.validate_save(invalid),"reject malformed numeric field: "+key)
	var invalid: Dictionary = clean.duplicate(true)
	invalid.layout.append({"id":"bed"})
	check(not Game.validate_save(invalid),"malformed later furniture cannot crash collision validation")
	invalid = clean.duplicate(true)
	invalid.equipped = ["boost","boost","boost","boost"]
	check(not Game.validate_save(invalid),"duplicate equipped IDs rejected")
	invalid = clean.duplicate(true)
	invalid.schema = 999
	check(not Game.validate_save(invalid),"unknown save schema rejected")
	invalid = clean.duplicate(true)
	invalid.mission.hunter = ""
	check(not Game.validate_save(invalid),"hunterless bounty save rejected")
	invalid = clean.duplicate(true)
	invalid.layout[0].rotated = "false"
	check(not Game.validate_save(invalid),"string boolean rejected in layout")
	invalid = clean.duplicate(true)
	invalid.layout[0].x = 3.5
	check(not Game.validate_save(invalid),"fractional housing cell rejected")
	invalid = clean.duplicate(true)
	invalid.mission = {}
	invalid.phase = "flight"
	check(not Game.validate_save(invalid),"orphan flight state rejected")
	var payload: String = JSON.stringify(clean)
	file = FileAccess.open(Game.storage_path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":1,"payload":payload,"sha256":"wrong"}))
	file.close()
	check(Game.decode_save(Game.storage_path).is_empty(),"checksum detects modified payload")

func combat_tests() -> void:
	Game.reset(false)
	Game.accept("mechanic","pilot")
	Game.investigate()
	Game.launch()
	var battle = BHSpace.new()
	add_child(battle)
	battle.set_physics_process(false)
	check(battle.scans==1 and battle.markers[0].done,"preflight intel really changes encounter")
	check(battle.ship.modules==Game.s.equipped,"fitted modules reach rendered ship")
	var energy: float = battle.energy
	check(not battle.use_skill(1) and battle.energy==energy,"invalid tether does not consume energy")
	battle.complete_scan(battle.markers[1])
	check(battle.phase=="pursuit" and battle.enemies.size()==2,"final clue begins actual pursuit and escorts")
	battle.position_ship = battle.target_pos+Vector2(-240,0)
	check(battle.use_skill(1) and battle.active.tether==5.0,"tether casts when in range")
	energy = battle.energy
	check(not battle.use_skill(1) and battle.energy==energy,"cooldown prevents duplicate activation")
	battle.projectiles = [{"pos":battle.target_pos-Vector2(110,0),"vel":Vector2(1000,0),"life":1.0,"enemy":false,"damage":100.0}]
	battle.update_projectiles(0.22)
	check(battle.engine==0 and battle.quarry.disabled,"swept projectile hits target without tunneling")
	battle.position_ship = Vector2(100,400)
	battle.interact()
	check(battle.phase=="pursuit","boarding range enforced")
	battle.position_ship = battle.target_pos-Vector2(130,0)
	battle.interact()
	check(battle.phase=="boarding" and battle.enemies.size()==3,"boarding creates support objective and bounded reinforcement")
	battle.spawn_enemy(Vector2.ZERO)
	check(battle.enemies.size()==3,"escort population capped")
	battle.projectiles = [{"pos":battle.relay_pos-Vector2(80,0),"vel":Vector2(800,0),"life":1.0,"enemy":false,"damage":40.0}]
	battle.update_projectiles(0.2)
	check(battle.relay_hp==0,"actual projectile destroys boarding relay")
	battle.position_ship = Vector2(50,50)
	battle.update_objective(20)
	check(battle.phase=="boarding" and battle.boarding_timer==0,"boarding cannot finish while pilot abandons support radius")
	battle.position_ship = battle.target_pos-Vector2(140,0)
	battle.update_objective(12.1)
	check(battle.phase=="extraction","Voss boarding support reaches extraction")
	var emitted: Array = []
	battle.ended.connect(func(success: bool, health: float):emitted.append([success,health]))
	battle.position_ship = battle.pod_pos
	battle.interact()
	battle.finish(true)
	check(emitted.size()==1 and emitted[0][0] and battle.finished,"extraction and repeated finish emit settlement once")
	battle.queue_free()
	await get_tree().process_frame
	# Defensive geometry: incoming from the front is blocked; rear fire is not.
	Game.reset(false)
	Game.accept("mechanic","pilot")
	Game.launch()
	battle = BHSpace.new()
	add_child(battle)
	battle.set_physics_process(false)
	battle.aim = Vector2.RIGHT
	battle.active.shield = 4.0
	battle.armor = 0
	battle.projectiles = [{"pos":battle.position_ship+Vector2(70,0),"vel":Vector2(-700,0),"life":1.0,"enemy":true,"damage":20.0}]
	battle.update_projectiles(0.2)
	check(battle.hull==100,"directional shield blocks front projectiles")
	battle.projectiles = [{"pos":battle.position_ship-Vector2(70,0),"vel":Vector2(700,0),"life":1.0,"enemy":true,"damage":20.0}]
	battle.update_projectiles(0.2)
	check(battle.hull==80,"directional shield does not block rear projectiles")
	battle.simulation_paused = true
	energy = battle.energy
	check(not battle.use_skill(0) and battle.energy==energy,"paused battle blocks skill transactions")
	battle.queue_free()
	await get_tree().process_frame
	Game.reset(false)
	Game.s.credits = 0
	Game.accept("salvage","pilot")
	Game.launch()
	battle = BHSpace.new()
	add_child(battle)
	battle.set_physics_process(false)
	for marker in battle.markers:
		battle.complete_scan(marker)
	check(battle.finished and battle.enemies.is_empty(),"all recovery crates complete a noncombat mission")
	battle.queue_free()
	await get_tree().process_frame

func hazard_tests() -> void:
	# Raider drones, mines, asteroid cover and VFX run through the real combat node.
	Game.reset(false)
	Game.accept("mechanic","pilot")
	Game.launch()
	var battle = BHSpace.new()
	add_child(battle)
	battle.set_physics_process(false)
	battle.controls_enabled = false
	for marker in battle.markers:
		battle.complete_scan(marker)
	check(battle.hornets.is_empty() and battle.mines.is_empty(),"pursuit starts without extra hazards")
	var rock: Dictionary = battle.asteroids[0]
	battle.projectiles = [{"pos":rock.pos-Vector2(float(rock.r)+60,0),"vel":Vector2(900,0),"life":1.0,"enemy":true,"damage":12.0}]
	battle.update_projectiles(0.2)
	check(battle.projectiles.is_empty() and battle.hull==100,"asteroid absorbs fire as cover")
	battle.spawn_hornet(battle.position_ship+Vector2(120,0))
	var drone: Dictionary = battle.hornets[0]
	drone.state = "dash"
	drone.timer = 0.5
	drone.dir = Vector2.LEFT
	drone.vel = Vector2(-780,0)
	battle.armor = 0
	battle.update_hornets(0.12)
	battle.update_hornets(0.01)
	check(battle.hull==90 and drone.state=="recover","raider dash deals contact damage once")
	battle.projectiles = [{"pos":drone.pos-Vector2(60,0),"vel":Vector2(800,0),"life":1.0,"enemy":false,"damage":20.0}]
	battle.update_projectiles(0.15)
	check(battle.hornets.is_empty(),"raider drone destroyed by suppression fire")
	battle.drop_mine()
	check(battle.mines.size()==1,"quarry drops a proximity mine")
	battle.mines[0].pos = battle.position_ship+Vector2(60,0)
	battle.mines[0].arm = 0.0
	battle.update_mines(0.1)
	check(float(battle.mines[0].fuse)>0,"armed mine starts a visible fuse near the ship")
	battle.update_mines(0.6)
	check(battle.mines.is_empty() and battle.hull==76,"mine detonates and damages the ship in radius")
	battle.drop_mine()
	battle.mines[0].pos = battle.position_ship+Vector2(150,0)
	battle.cooldowns = [0.0,0.0,0.0,0.0]
	battle.energy = 100
	battle.heat = 0
	var emp_slot: int = Game.s.equipped.find("emp")
	check(emp_slot>=0 and battle.use_skill(emp_slot) and battle.mines.is_empty(),"EMP fizzles nearby mines safely")
	battle.hull = 1000000.0
	for i in range(900):
		battle._physics_process(1.0/60.0)
	check(not battle.hornets.is_empty() and battle.hornets.size()<=2,"raider drones arrive during a live pursuit and stay capped")
	check(battle.mines.size()<=4 and battle.vfx.parts.size()<=BHVfx.LIMIT,"hazards and particles stay bounded over 15 simulated seconds")
	# Inertial flight: with no thrust the hull keeps drifting instead of stopping dead.
	battle.position_ship = Vector2(0,-1200)
	battle.velocity_ship = Vector2(BHSpace.CRUISE,0)
	for i in range(30):
		battle._physics_process(1.0/60.0)
	check(battle.velocity_ship.length()>250.0 and battle.position_ship.x>150.0,"released controls leave the ship drifting on momentum")
	battle.position_ship = BHSpace.WORLD.end+Vector2(500,500)
	battle._physics_process(1.0/60.0)
	check(BHSpace.WORLD.has_point(battle.position_ship),"ship stays inside the operation area boundary")
	var spread: float = battle.markers[0].pos.distance_to(battle.markers[1].pos)
	check(BHSpace.WORLD.size.x>=1600*3 and spread>1200.0 and battle.asteroids.size()>20,"operation area spans several screens with distant signals and asteroid fields")
	battle.queue_free()
	await get_tree().process_frame
	Game.reset(false)
	Game.accept("salvage","pilot")
	Game.launch()
	battle = BHSpace.new()
	add_child(battle)
	battle.set_physics_process(false)
	battle.controls_enabled = false
	for i in range(900):
		battle._physics_process(1.0/60.0)
	check(battle.hornets.is_empty() and battle.mines.is_empty(),"noncombat salvage never spawns raiders or mines")
	battle.queue_free()
	await get_tree().process_frame

func view3d_tests() -> void:
	# The quarter-view renderer mirrors simulation state without owning any of it.
	Game.reset(false)
	Game.accept("mechanic","pilot")
	Game.launch()
	var battle = BHSpace.new()
	battle.three_d = true
	var view = load("res://scripts/space3d/space_view3d.gd").new()
	view.sim = battle
	add_child(view)
	add_child(battle)
	battle.set_physics_process(false)
	battle.controls_enabled = false
	check(battle.vfx is BHVfx3D and battle.ship.modulate.a==0.0,"3D mode swaps in the 3D effect layer and hides 2D sprites")
	for marker in battle.markers:
		battle.complete_scan(marker)
	battle.drop_mine()
	battle.spawn_hornet(Vector2(900,400))
	battle.vfx.explosion(Vector2(800,477),1.0)
	for i in range(3):
		view._process(1.0/60.0)
	check(view.escorts.size()==battle.enemies.size() and view.drones.size()==1 and view.mine_nodes.size()==1,"3D view mirrors escorts, raider drones and mines")
	check(view.quarry.visible and view.ship.visible and view.rocks.size()==battle.asteroids.size(),"3D view shows the revealed quarry, player ship and cover rocks")
	var probe: Vector3 = BHVfx3D.to3d(Vector2(1200,300))
	check(is_equal_approx(probe.x,20.0) and is_equal_approx(probe.z,-8.85),"simulation pixels map onto the 3D flight plane")
	battle.hornets[0].hp = 1.0
	battle.damage_hornet(0,5.0)
	view._process(1.0/60.0)
	check(view.drones.is_empty(),"destroyed raider model is removed from the 3D scene")
	# Wide operation area: the follow camera and endless backdrop travel with the ship.
	battle.position_ship = Vector2(3200,1900)
	battle.velocity_ship = Vector2.ZERO
	for i in range(3):
		view._process(1.0/60.0)
	var focus3: Vector3 = BHVfx3D.to3d(battle.position_ship)
	check(absf(view.camera.position.x-focus3.x)<6.0 and view.camera.position.z>focus3.z,"follow camera tracks the ship across the operation area")
	var tiles_ok: bool = true
	for layer in view.tiled_layers:
		if absf(layer.position.x-focus3.x)>float(layer.get_meta("tile")):
			tiles_ok = false
	check(tiles_ok and view.gates.size()==BHSpace.GATES.size() and not view.buoys.is_empty(),"star and dust tiles follow the camera and lane landmarks exist")
	battle.queue_free()
	view.queue_free()
	await get_tree().process_frame

func navigation_tests() -> void:
	Game.reset(false)
	var habitat = BHHabitat.new()
	habitat.place_kind = "port"
	add_child(habitat)
	habitat.set_physics_process(false)
	for kind in habitat.hotspots:
		habitat.route(habitat.player,habitat.hotspots[kind])
		check(not habitat.player.path.is_empty() and habitat.player.path[-1].distance_to(habitat.hotspots[kind])<42,"walkable port interaction: "+kind)
	check(not habitat.is_walkable(Vector2(150,650)),"canal is not a walkable floor")
	habitat.queue_free()
	await get_tree().process_frame
	habitat = BHHabitat.new()
	habitat.place_kind = "cabin"
	Game.hire("voss")
	add_child(habitat)
	habitat.set_physics_process(false)
	check(habitat.npcs.size()==1 and habitat.npcs[0].role_id=="voss","recruited hunter exists as independent cabin actor")
	check(not habitat.is_walkable(BHHabitat.GRID_ORIGIN+Vector2(2.5,0.5)*60),"furniture is an actual navigation obstacle")
	habitat.route(habitat.player,habitat.hotspots.launch)
	check(not habitat.player.path.is_empty(),"reserved aisle keeps cockpit accessible")
	Game.place("desk",Vector2i(10,3))
	check(habitat.props.size()==3,"successful housing transaction rebuilds visible props")
	check(not habitat.is_walkable(BHHabitat.GRID_ORIGIN+Vector2(10.5,3.5)*60),"newly placed furniture changes navigation")
	habitat.queue_free()
	await get_tree().process_frame
