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
	await combat_tests()
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
