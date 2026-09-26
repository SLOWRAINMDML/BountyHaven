class_name BHHabitat
extends Node2D
const Ink = preload("res://scripts/world/ink_art.gd")
const Walker = preload("res://scripts/world/walker.gd")
const Decor = preload("res://scripts/world/furniture.gd")
const Ambient = preload("res://scripts/world/ambient.gd")
const Prop = preload("res://scripts/world/port_prop.gd")
const GRID_ORIGIN = Vector2(260,486)
const CELL: float = 60.0
const NAV_CELL: float = 20.0
signal interaction(kind: String)
signal feedback(message: String)
var place_kind: String = "port"
var controls_enabled: bool = true
var player: BHWalker
var npcs: Array = []
var nav = AStarGrid2D.new()
var walk_polygon: PackedVector2Array
var layers: Array = []
var people: Node2D
var props: Array = []
var hotspots: Dictionary = {}
var queued_interaction: String = ""
var timer: float = 0.0
var npc_timer: float = 0.0
var selected_item: String = ""
var selected_rotated: bool = false
var moving_uid: int = -1
var ghost: BHDecor
var build_mode: bool = false
var nearest: String = ""
var font: Font
var ambient: BHAmbient
## Distance walked since the last dust puff, per actor.
var stride_left: Dictionary = {}
var last_pos: Dictionary = {}

func _ready() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Noto Sans CJK KR","Malgun Gothic","Apple SD Gothic Neo","NanumGothic"])
	var material = ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/pigment.gdshader")
	if place_kind == "port":
		for name in ["sky","city","ground"]:
			var sprite = Sprite2D.new()
			sprite.texture = Ink.texture(str(Game.s.port),name)
			sprite.centered = false
			sprite.z_index = -20 + layers.size()
			sprite.material = material
			add_child(sprite)
			layers.append(sprite)
		var water = Polygon2D.new()
		water.polygon = PackedVector2Array([Vector2(0,622),Vector2(380,611),Vector2(475,644),Vector2(154,831),Vector2(0,889)])
		water.uv = PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,0.3),Vector2(0.3,1),Vector2(0,1)])
		var water_mat = ShaderMaterial.new()
		water_mat.shader = preload("res://assets/shaders/water.gdshader")
		water.material = water_mat
		water.z_index = -17
		add_child(water)
		var front = Sprite2D.new()
		front.texture = Ink.texture(str(Game.s.port),"foreground")
		front.centered = false
		front.z_index = 10
		front.material = material
		add_child(front)
		walk_polygon = PackedVector2Array([Vector2(185,808),Vector2(491,653),Vector2(650,611),Vector2(1202,631),Vector2(1487,722),Vector2(1520,808)])
		hotspots = {"guild":Vector2(662,665),"tavern":Vector2(1102,681),"outfitter":Vector2(1408,744),"records":Vector2(815,691),"ship":Vector2(385,748)}
	else:
		var sprite = Sprite2D.new()
		sprite.texture = Ink.texture("interior","cabin")
		sprite.centered = false
		sprite.material = material
		sprite.z_index = -20
		add_child(sprite)
		walk_polygon = PackedVector2Array([Vector2(215,501),Vector2(1390,501),Vector2(1390,774),Vector2(215,774)])
		hotspots = {"launch":Vector2(230,636),"port":Vector2(1365,635),"rest":Vector2(530,620)}
	people = Node2D.new()
	people.y_sort_enabled = true
	people.z_index = 2
	add_child(people)
	ambient = Ambient.new()
	ambient.place_kind = place_kind
	ambient.z_index = 1
	add_child(ambient)
	if place_kind == "port":
		for data in [["crates",Vector2(520,641)],["cat",Vector2(512,595)],["board",Vector2(606,618)],["barrels",Vector2(1246,640)],["plant",Vector2(1046,621)],["plant",Vector2(760,612)],["bollard",Vector2(256,760)],["bollard",Vector2(374,701)]]:
			var prop = Prop.new()
			prop.kind = data[0]
			prop.position = data[1]
			if data[0]=="cat":
				prop.z_index = 1
			people.add_child(prop)
	player = Walker.new()
	player.is_player = true
	player.position = Vector2(748,752) if place_kind == "port" else Vector2(753,645)
	people.add_child(player)
	spawn_npcs()
	rebuild_props()
	rebuild_navigation()
	Game.changed.connect(on_state_changed)

func spawn_npcs() -> void:
	for npc in npcs:
		npc.queue_free()
	npcs.clear()
	var ids: Array = ["voss","rio"] if place_kind == "port" else [Game.active_hunter()]
	for id in ids:
		if str(id).is_empty():
			continue
		var npc = Walker.new()
		npc.role_id = id
		npc.tint = Color(BHCatalog.HUNTERS[id].color)
		npc.position = (Vector2(1000,707) if id=="voss" else Vector2(1170,724)) if place_kind == "port" else Vector2(920,638)
		npc.scale = Vector2(0.94,0.94)
		people.add_child(npc)
		npcs.append(npc)

func on_state_changed() -> void:
	if place_kind == "cabin":
		var id: String = Game.active_hunter()
		if (npcs.is_empty() and not id.is_empty()) or (not npcs.is_empty() and npcs[0].role_id != id):
			spawn_npcs()
		rebuild_props()
		rebuild_navigation()

func rebuild_props() -> void:
	for prop in props:
		prop.queue_free()
	props.clear()
	if place_kind != "cabin":
		return
	for item in Game.s.layout:
		var prop = Decor.new()
		prop.item_id = str(item.id)
		prop.rotated = bool(item.rotated)
		prop.uid = int(item.uid)
		prop.position = GRID_ORIGIN + Vector2(float(item.x),float(item.y))*CELL
		people.add_child(prop)
		props.append(prop)

func rebuild_navigation() -> void:
	nav.region = Rect2i(0,0,80,45)
	nav.cell_size = Vector2(NAV_CELL,NAV_CELL)
	nav.offset = Vector2(NAV_CELL*0.5,NAV_CELL*0.5)
	nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	nav.update()
	for y in range(45):
		for x in range(80):
			var p: Vector2 = Vector2(x,y)*NAV_CELL+nav.offset
			var blocked: bool = not Geometry2D.is_point_in_polygon(p,walk_polygon)
			if not blocked and place_kind == "cabin":
				for item in Game.s.layout:
					var rect = Rect2(GRID_ORIGIN+Vector2(float(item.x),float(item.y))*CELL,Vector2(BHCatalog.furniture_size(str(item.id),bool(item.rotated)))*CELL)
					if rect.grow(5).has_point(p):
						blocked = true
				nav.set_point_solid(Vector2i(x,y),blocked)
			else:
				nav.set_point_solid(Vector2i(x,y),blocked)
	# Moving an object cannot strand a character inside a newly blocked cell.
	for actor in [player] + npcs:
		actor.path = PackedVector2Array()
		if not is_walkable(actor.position):
			actor.position = nav.get_point_position(closest_cell(actor.position))

func closest_cell(pos: Vector2) -> Vector2i:
	var origin: Vector2i = Vector2i((pos-nav.offset)/NAV_CELL)
	for n in range(1,2602):
		var cell: Vector2i = origin+BHSpiral.point(n)
		if nav.is_in_boundsv(cell) and not nav.is_point_solid(cell):
			return cell
	return Vector2i(37,32)

func is_walkable(pos: Vector2) -> bool:
	var cell: Vector2i = Vector2i(pos/NAV_CELL)
	return nav.is_in_boundsv(cell) and not nav.is_point_solid(cell)

func route(actor: BHWalker, destination: Vector2) -> void:
	actor.path = nav.get_point_path(closest_cell(actor.position),closest_cell(destination))

func go_to(kind: String) -> void:
	if not hotspots.has(kind):
		return
	queued_interaction = kind
	route(player,hotspots[kind])

func start_build(id: String) -> void:
	build_mode = true
	selected_item = id
	selected_rotated = false
	moving_uid = -1
	if is_instance_valid(ghost):
		ghost.queue_free()
	ghost = Decor.new()
	ghost.item_id = id
	ghost.ghost = true
	ghost.modulate.a = 0.75
	ghost.z_index = 11
	add_child(ghost)
	player.path.clear()
	feedback.emit("클릭: 배치 / R: 회전 / 빈 선택 상태에서 가구 클릭: 이동 / 우클릭: 선택 해제 / Esc: 종료")

func stop_build() -> void:
	build_mode = false
	selected_item = ""
	moving_uid = -1
	if is_instance_valid(ghost):
		ghost.queue_free()
		ghost = null

func furniture_at(pos: Vector2) -> int:
	for item in Game.s.layout:
		var bounds = Rect2(GRID_ORIGIN+Vector2(float(item.x),float(item.y))*CELL,Vector2(BHCatalog.furniture_size(str(item.id),bool(item.rotated)))*CELL)
		if bounds.has_point(pos):
			return int(item.uid)
	return -1

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event.is_action_pressed("interact") and not build_mode and not nearest.is_empty():
		interaction.emit(nearest)
		get_viewport().set_input_as_handled()
	if build_mode:
		if event.is_action_pressed("rotate"):
			selected_rotated = not selected_rotated
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				selected_item = ""
				moving_uid = -1
				if is_instance_valid(ghost):
					ghost.hide()
			elif event.button_index == MOUSE_BUTTON_LEFT:
				var pos: Vector2 = get_global_mouse_position()
				if selected_item.is_empty():
					var uid: int = furniture_at(pos)
					for item in Game.s.layout:
						if int(item.uid) == uid:
							start_build(str(item.id))
							moving_uid = uid
							selected_rotated = bool(item.rotated)
				else:
					var cell = Vector2i(floor((pos.x-GRID_ORIGIN.x)/CELL),floor((pos.y-GRID_ORIGIN.y)/CELL))
					var response: Dictionary = Game.place(selected_item,cell,selected_rotated,moving_uid)
					feedback.emit(response.message)
					if response.ok:
						moving_uid = -1
						selected_item = ""
						ghost.hide()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2 = get_global_mouse_position()
		queued_interaction = ""
		for kind in hotspots:
			if pos.distance_to(hotspots[kind]) < 47:
				go_to(kind)
				return
		route(player,pos)
		ambient.ripple(nav.get_point_position(closest_cell(pos)))

func _physics_process(delta: float) -> void:
	if controls_enabled and not build_mode:
		var input: Vector2 = Input.get_vector("left","right","up","down")
		if input.length() > 0.0:
			player.path.clear()
			queued_interaction = ""
			var movement: Vector2 = input*(265.0 if Input.is_action_pressed("sprint") else 160.0)*delta
			var before: Vector2 = player.position
			if is_walkable(player.position+Vector2(movement.x,0)):
				player.position.x += movement.x
			if is_walkable(player.position+Vector2(0,movement.y)):
				player.position.y += movement.y
			player.moving = before.distance_to(player.position)>0.1
			if absf(input.x)>0.01:
				player.facing = signf(input.x)
		else:
			advance(player,delta,160.0)
	else:
		player.moving = false
	if not queued_interaction.is_empty() and player.position.distance_to(hotspots[queued_interaction]) < 42 and controls_enabled:
		var action: String = queued_interaction
		queued_interaction = ""
		player.path.clear()
		interaction.emit(action)
	for npc in npcs:
		advance(npc,delta,55.0)
	for actor in [player]+npcs:
		track_steps(actor)
	nearest = ""
	var distance: float = 85.0
	for kind in hotspots:
		var d: float = player.position.distance_to(hotspots[kind])
		if d < distance:
			distance = d
			nearest = kind

func track_steps(actor: BHWalker) -> void:
	var id: int = actor.get_instance_id()
	var previous: Vector2 = last_pos.get(id,actor.position)
	last_pos[id] = actor.position
	stride_left[id] = float(stride_left.get(id,0.0))+previous.distance_to(actor.position)
	if float(stride_left[id])>26.0:
		stride_left[id] = 0.0
		ambient.footstep(actor.position,Color(0.72,0.66,0.55) if place_kind=="port" else Color(0.80,0.76,0.66))

func advance(actor: BHWalker, delta: float, speed: float) -> void:
	actor.moving = not actor.path.is_empty()
	if actor.path.is_empty():
		return
	var next: Vector2 = actor.path[0]
	if actor.position.distance_to(next)<speed*delta+1.0:
		actor.position = next
		actor.path.remove_at(0)
	else:
		var dir: Vector2 = actor.position.direction_to(next)
		actor.position += dir*speed*delta
		if absf(dir.x)>0.1:
			actor.facing = signf(dir.x)

func _process(delta: float) -> void:
	timer += delta
	npc_timer += delta
	if place_kind == "port" and not layers.is_empty():
		var look: Vector2 = (get_global_mouse_position()-Vector2(800,450))*0.003
		layers[0].position = look
	if npc_timer > 8.0:
		npc_timer = 0.0
		for npc in npcs:
			var dest = Vector2(940+sin(timer*0.23)*145,714+cos(timer*0.34)*35)
			if place_kind == "cabin":
				dest = Vector2(540+sin(timer*0.13)*240,637)
				if not props.is_empty():
					var item = props[int(timer/8.0)%props.size()]
					dest = item.position + Vector2(20,85)
			route(npc,dest)
	if build_mode and is_instance_valid(ghost) and not selected_item.is_empty():
		var pos: Vector2 = get_global_mouse_position()
		var cell = Vector2i(floor((pos.x-GRID_ORIGIN.x)/CELL),floor((pos.y-GRID_ORIGIN.y)/CELL))
		ghost.position = GRID_ORIGIN+Vector2(cell)*CELL
		ghost.rotated = selected_rotated
		ghost.valid_ghost = Game.can_place(selected_item,cell,selected_rotated,moving_uid)
		ghost.queue_redraw()
	queue_redraw()

func _draw() -> void:
	if place_kind == "port":
		# Thin drifting mist; never distorts the painted stonework.
		for i in range(5):
			draw_set_transform(Vector2(240+i*295+sin(timer*0.10+i)*28,559+i%2*24),0,Vector2(1,0.035))
			draw_circle(Vector2.ZERO,140,Color(0.96,0.96,0.89,0.15))
		draw_set_transform(Vector2.ZERO)
		for light in [Vector2(1104,563),Vector2(669,560),Vector2(1568,530)]:
			draw_circle(light,13+sin(timer)*1.5,Color(0.98,0.81,0.49,0.12))
	if build_mode:
		for y in range(5):
			for x in range(18):
				var reserved: bool = y==2 or x==0 or x==17
				var color = Color(0.57,0.36,0.22,0.13) if reserved else Color(0.26,0.46,0.44,0.24)
				draw_rect(Rect2(GRID_ORIGIN+Vector2(x,y)*CELL,Vector2(CELL,CELL)),color,false,0.8)
		return
	var names: Dictionary = {"guild":"길드", "tavern":"술집", "outfitter":"정비소", "records":"항로 기록", "ship":"내 우주선", "launch":"조종석", "port":"항구로", "rest":"휴식"}
	for kind in hotspots:
		var point: Vector2 = hotspots[kind]
		var color = Color("a97e58") if kind == nearest else Color("597f7d")
		draw_arc(point+Vector2(0,-18),7,0,TAU,16,color,1.1,true)
		draw_line(point+Vector2(-3,-18),point+Vector2(3,-18),color,1,true)
		if kind == nearest:
			var text: String = "[E] " + names[kind]
			var size: Vector2 = font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,17)
			draw_rect(Rect2(point+Vector2(-size.x*0.5-8,-55),size+Vector2(16,8)),Color(0.96,0.93,0.86,0.94))
			draw_string(font,point+Vector2(-size.x*0.5,-34),text,HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("344f54"))
