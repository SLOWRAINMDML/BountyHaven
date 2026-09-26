class_name BHSpaceView3D
extends Node3D
## Quarter-view 3D presentation of BHSpace. The 2D simulation stays authoritative and
## fully testable; this node only reads its state every frame and renders it with
## lit low-poly models, a tilted perspective camera and a 3D particle layer.
const Models = preload("res://scripts/space3d/models.gd")
const Fx = preload("res://scripts/space3d/fx3d.gd")
var sim: BHSpace
var camera: Camera3D
var fx: BHVfx3D
var clock: float = 0.0
var ship: Node3D
var quarry: Node3D
var relay: Node3D
var pod: Node3D
var escorts: Dictionary = {}
var drones: Dictionary = {}
var mine_nodes: Dictionary = {}
var rocks: Array = []
var beacons: Array = []
var beacon_labels: Array = []
var shots: Array = []
var overlay: ImmediateMesh
var station: Node3D
var planet: Node3D
var engine_label: Label3D
var relay_label: Label3D
var pod_label: Label3D
var bank: float = 0.0
var font: Font
## Follow camera: a lagging focus point that leads the ship's motion and pulls back with speed.
var cam_focus: Vector2 = Vector2.INF
var cam_zoom: float = 1.0
## Backdrop layers. Far scenery drifts with the camera (feels immense); star, dust and
## debris tiles repeat endlessly so there is always something streaming past.
var far_layer: Node3D
var tiled_layers: Array = []
var grid_node: MeshInstance3D
var gates: Array = []
var buoys: Array = []
var wrecks: Array = []
var landmarks_built: bool = false
const CAMERA_BASE = Vector3(0,41,29)
const CAMERA_LOOK = Vector3(0,0,1.8)

func _ready() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Noto Sans CJK KR","Malgun Gothic","Apple SD Gothic Neo","NanumGothic"])
	build_environment()
	build_backdrop()
	fx = Fx.new()
	add_child(fx)
	if is_instance_valid(sim):
		sim.vfx = fx
		sim.mouse_provider = mouse_to_sim
	var overlay_node = MeshInstance3D.new()
	overlay = ImmediateMesh.new()
	overlay_node.mesh = overlay
	var om = StandardMaterial3D.new()
	om.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	om.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	om.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	om.vertex_color_use_as_albedo = true
	om.cull_mode = BaseMaterial3D.CULL_DISABLED
	overlay_node.material_override = om
	add_child(overlay_node)
	engine_label = label3d(34)
	relay_label = label3d(30)
	pod_label = label3d(34)

func label3d(size: int) -> Label3D:
	var label = Label3D.new()
	label.font = font
	label.font_size = size
	label.pixel_size = 0.02
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 8
	label.outline_modulate = Color(0.04,0.08,0.11,0.85)
	label.visible = false
	add_child(label)
	return label

func build_environment() -> void:
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0a1822")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("6c8594")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# Glow is unreliable on the Compatibility renderer (washes the frame out), so emissive
	# parts and additive particles carry the brightness instead.
	env.glow_enabled = false
	env.glow_intensity = 0.55
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.95
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	var world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0,0.9,0.78)
	sun.light_energy = 1.35
	sun.rotation = Vector3(deg_to_rad(-55),deg_to_rad(40),0)
	add_child(sun)
	var fill = DirectionalLight3D.new()
	fill.light_color = Color(0.45,0.7,0.85)
	fill.light_energy = 0.45
	fill.rotation = Vector3(deg_to_rad(-30),deg_to_rad(-140),0)
	add_child(fill)
	camera = Camera3D.new()
	camera.fov = 40
	camera.position = CAMERA_BASE
	camera.far = 600
	add_child(camera)
	camera.look_at(CAMERA_LOOK)
	camera.current = true

func soft_texture() -> GradientTexture2D:
	var soft = GradientTexture2D.new()
	var g = Gradient.new()
	g.set_color(0,Color(1,1,1,1))
	g.set_color(1,Color(1,1,1,0))
	soft.gradient = g
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5,0.5)
	soft.fill_to = Vector2(1.0,0.5)
	return soft

func build_backdrop() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 91
	# Deep starfield well below the play plane, so the tilted camera sees true parallax.
	var star_mat = StandardMaterial3D.new()
	star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	star_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	star_mat.albedo_texture = soft_texture()
	star_mat.vertex_color_use_as_albedo = true
	star_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	star_mat.billboard_keep_scale = true
	var quad = QuadMesh.new()
	quad.size = Vector2(1,1)
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = 420
	for i in range(420):
		var depth: float = rng.randf_range(25,110)
		var at = Vector3(rng.randf_range(-100,100),-depth,rng.randf_range(-100,100))
		var s: float = rng.randf_range(0.12,0.38)*(1.0+depth*0.01)
		if rng.randf()<0.04:
			s *= 2.2
		mm.set_instance_transform(i,Transform3D(Basis().scaled(Vector3(s,s,s)),at))
		var tint: Color = [Color(0.85,0.92,1.0),Color(1.0,0.9,0.78),Color(0.75,0.95,0.92)][i%3]
		mm.set_instance_color(i,Color(tint,rng.randf_range(0.25,0.8)))
	tiled_layers.append(tile_layer(func():
		var node = MultiMeshInstance3D.new()
		node.multimesh = mm
		node.material_override = star_mat
		return node,200.0))
	# Near-plane space dust: tiny motes just above and below the flight plane. Being
	# close to the camera they sweep past fastest and carry most of the sense of speed.
	var dust_mm = MultiMesh.new()
	dust_mm.transform_format = MultiMesh.TRANSFORM_3D
	dust_mm.use_colors = true
	dust_mm.mesh = quad
	dust_mm.instance_count = 90
	for i in range(90):
		var at = Vector3(rng.randf_range(-50,50),rng.randf_range(-7,3),rng.randf_range(-50,50))
		var s: float = rng.randf_range(0.05,0.13)
		dust_mm.set_instance_transform(i,Transform3D(Basis().scaled(Vector3(s,s,s)),at))
		dust_mm.set_instance_color(i,Color(0.8,0.92,0.9,rng.randf_range(0.25,0.6)))
	tiled_layers.append(tile_layer(func():
		var node = MultiMeshInstance3D.new()
		node.multimesh = dust_mm
		node.material_override = star_mat
		return node,100.0))
	# Distant debris on lower planes, repeating in tiles for depth everywhere on the map.
	var debris = Node3D.new()
	for i in range(7):
		var far = Models.asteroid(rng.randf_range(0.6,2.4),900+i)
		far.position = Vector3(rng.randf_range(-70,70),rng.randf_range(-24,-7),rng.randf_range(-70,70))
		far.rotation = Vector3(rng.randf()*TAU,rng.randf()*TAU,0)
		debris.add_child(far)
	tiled_layers.append(tile_layer(func():return debris.duplicate(),140.0))
	debris.free()
	far_layer = Node3D.new()
	add_child(far_layer)
	# Nebula washes: large noise-textured sheets tinted teal, rose and amber.
	for data in [[Vector3(-30,-38,-10),Color(0.28,0.62,0.66),90.0],[Vector3(40,-50,-50),Color(0.72,0.38,0.52),110.0],[Vector3(-60,-60,-80),Color(0.8,0.6,0.35),120.0],[Vector3(20,-32,30),Color(0.3,0.5,0.7),80.0]]:
		var tex = NoiseTexture2D.new()
		var noise = FastNoiseLite.new()
		noise.seed = rng.randi()
		noise.frequency = 0.006
		noise.fractal_octaves = 5
		tex.noise = noise
		tex.width = 256
		tex.height = 256
		var ramp = Gradient.new()
		ramp.set_color(0,Color(0,0,0,0))
		ramp.set_color(1,Color(data[1],0.17))
		ramp.add_point(0.5,Color(data[1],0.0))
		tex.color_ramp = ramp
		var sheet_mat = StandardMaterial3D.new()
		sheet_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sheet_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sheet_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		sheet_mat.albedo_texture = tex
		var plane = PlaneMesh.new()
		plane.size = Vector2(data[2],data[2])
		Models.part(far_layer,plane,sheet_mat,data[0],Vector3(0,rng.randf()*TAU,0))
	# Gas giant with banded texture, atmosphere halo and a thin tilted ring.
	planet = Node3D.new()
	planet.position = Vector3(92,-70,-130)
	far_layer.add_child(planet)
	var bands = NoiseTexture2D.new()
	var band_noise = FastNoiseLite.new()
	band_noise.seed = 7
	band_noise.frequency = 0.02
	bands.noise = band_noise
	bands.width = 256
	bands.height = 128
	var band_ramp = Gradient.new()
	band_ramp.set_color(0,Color("2f5a63"))
	band_ramp.set_color(1,Color("8fb9b0"))
	band_ramp.add_point(0.5,Color("4f7f82"))
	bands.color_ramp = band_ramp
	var pm = StandardMaterial3D.new()
	pm.albedo_texture = bands
	pm.roughness = 1.0
	pm.uv1_scale = Vector3(1,6,1)
	Models.part(planet,Models.sphere(26,48,24),pm,Vector3.ZERO,Vector3(0,0,0.4))
	Models.part(planet,Models.sphere(27.5,48,24),Models.glow("atmo",Color(0.5,0.85,0.9),0.08),Vector3.ZERO)
	Models.part(planet,Models.torus(33,41,96),Models.glow("planet_ring",Color(0.75,0.85,0.8),0.06),Vector3.ZERO,Vector3(0.35,0,0.25),Vector3(1,0.02,1))
	# Derelict ring station turning slowly in the middle distance.
	station = Node3D.new()
	station.position = Vector3(-26,-34,-78)
	far_layer.add_child(station)
	var hull = Models.mat("station",Color("8f9a96"),0.0,0.7,0.4)
	Models.part(station,Models.torus(6.4,7.2,64),hull,Vector3.ZERO,Vector3.ZERO,Vector3(1,1.6,1))
	Models.part(station,Models.cyl(0.9,0.9,4.0,12),Models.mat("station_core",Color("6f7a78")),Vector3.ZERO)
	for s in range(6):
		var spoke = Models.part(station,Models.box(Vector3(6.6,0.25,0.25)),hull,Vector3.ZERO,Vector3(0,s*PI/3.0,0))
		spoke.position = Vector3.ZERO
	for s in range(4):
		var light = Models.part(station,Models.sphere(0.22,6,4),Models.mat("station_light",Color("ff9a6a"),5.0),Vector3(cos(s*PI*0.5)*6.8,0.5,sin(s*PI*0.5)*6.8))
		light.name = "Beacon%d" % s
	# A faint tactical grid on the flight plane anchors depth and speed.
	var grid = ImmediateMesh.new()
	grid.surface_begin(Mesh.PRIMITIVE_LINES)
	for x in range(-72,73,4):
		grid.surface_set_color(Color(0.55,0.75,0.78,0.05 if x%12!=0 else 0.1))
		grid.surface_add_vertex(Vector3(x,-0.6,-60))
		grid.surface_add_vertex(Vector3(x,-0.6,36))
	for z in range(-60,37,4):
		grid.surface_set_color(Color(0.55,0.75,0.78,0.05 if z%12!=0 else 0.1))
		grid.surface_add_vertex(Vector3(-72,-0.6,z))
		grid.surface_add_vertex(Vector3(72,-0.6,z))
	grid.surface_end()
	var gm = StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.vertex_color_use_as_albedo = true
	grid_node = MeshInstance3D.new()
	grid_node.mesh = grid
	grid_node.material_override = gm
	add_child(grid_node)

## Nine copies of a layer around the camera; snapping the group by whole tiles keeps the
## pattern seamless, so the layer never runs out however far the ship flies.
func tile_layer(make: Callable, tile: float) -> Node3D:
	var group = Node3D.new()
	group.set_meta("tile",tile)
	for i in range(-1,2):
		for j in range(-1,2):
			var node: Node3D = make.call()
			node.position = Vector3(i*tile,0,j*tile)
			group.add_child(node)
	add_child(group)
	return group

## Fixed landmarks in the operation area: traffic gates on the survey lanes, rows of lane
## buoys between signals, and derelicts drifting under the plane.
func build_landmarks() -> void:
	landmarks_built = true
	for entry in BHSpace.GATES:
		var g = Models.gate()
		g.position = Fx.to3d(entry[0],0.0)
		g.rotation.y = -float(entry[1])
		add_child(g)
		gates.append(g)
	var route: Array = [sim.position_ship]
	for marker in sim.markers:
		route.append(marker.pos)
	var index: int = 0
	for leg in range(route.size()-1):
		var a: Vector2 = route[leg]
		var b: Vector2 = route[leg+1]
		var side: Vector2 = (b-a).orthogonal().normalized()*150.0
		var count: int = int(a.distance_to(b)/320.0)
		for k in range(1,count):
			var at: Vector2 = a.lerp(b,float(k)/count)
			for sign in [-1.0,1.0]:
				var buoy = Models.buoy()
				buoy.position = Fx.to3d(at+side*sign,-0.9)
				buoy.set_meta("order",index)
				add_child(buoy)
				buoys.append(buoy)
			index += 1
	for i in range(BHSpace.WRECKS.size()):
		var w = Models.wreck(70+i)
		w.position = Fx.to3d(BHSpace.WRECKS[i],-11.0-i*2.0)
		w.rotation = Vector3(0.1*i,i*1.7,0.15)
		add_child(w)
		wrecks.append(w)

func snap_camera() -> void:
	cam_focus = Vector2.INF

func mouse_to_sim() -> Vector2:
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var origin: Vector3 = camera.project_ray_origin(mouse)
	var normal: Vector3 = camera.project_ray_normal(mouse)
	if absf(normal.y)<0.0001:
		return sim.position_ship
	var t: float = -origin.y/normal.y
	var hit: Vector3 = origin+normal*t
	return Vector2(hit.x*Fx.SCALE+Fx.CENTER.x,hit.z*Fx.SCALE+Fx.CENTER.y)

func with_hurt_overlay(root: Node3D) -> StandardMaterial3D:
	var overlay_mat = StandardMaterial3D.new()
	overlay_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	overlay_mat.albedo_color = Color(1,0.95,0.85,0)
	for node in root.find_children("*","MeshInstance3D",true,false):
		if node.material_override is StandardMaterial3D and node.material_override.shading_mode!=BaseMaterial3D.SHADING_MODE_UNSHADED:
			node.material_overlay = overlay_mat
	root.set_meta("hurt",overlay_mat)
	return overlay_mat

func set_hurt(root: Node3D, amount: float) -> void:
	if root.has_meta("hurt"):
		root.get_meta("hurt").albedo_color.a = clampf(amount,0.0,1.0)*0.7

func yaw_of(node2d: Node2D) -> float:
	return -node2d.rotation

func _process(delta: float) -> void:
	if not is_instance_valid(sim):
		return
	if not sim.simulation_paused:
		clock += delta
	# The simulation lays out its signals in its own _ready, which runs after ours.
	if not landmarks_built and sim.is_inside_tree():
		build_landmarks()
	sync_camera(delta)
	sync_backdrop(delta)
	sync_ship(delta)
	sync_quarry()
	sync_escorts()
	sync_drones()
	sync_mines()
	sync_rocks()
	sync_objectives()
	sync_projectiles()
	draw_overlay()

func sync_camera(delta: float) -> void:
	# Lead the ship along its velocity and aim so there is room to see what is coming.
	var goal: Vector2 = sim.position_ship+sim.velocity_ship*0.45+sim.aim*60.0
	if cam_focus==Vector2.INF or cam_focus.distance_to(goal)>1500.0:
		cam_focus = goal
	else:
		cam_focus = cam_focus.lerp(goal,1.0-exp(-delta*2.8))
	var speed_k: float = clampf((sim.velocity_ship.length()-200.0)/650.0,0.0,1.0)
	cam_zoom = lerpf(cam_zoom,1.0+speed_k*0.3,1.0-exp(-delta*1.8))
	camera.fov = 40.0+(cam_zoom-1.0)*16.0
	var focus: Vector3 = Fx.to3d(cam_focus)
	var shake: Vector3 = Vector3(randf_range(-1,1),randf_range(-1,1),randf_range(-1,1))*sim.shake*0.035
	camera.position = focus+CAMERA_LOOK+(CAMERA_BASE-CAMERA_LOOK)*cam_zoom+shake
	camera.look_at(focus+CAMERA_LOOK+shake*0.5)

func sync_backdrop(delta: float) -> void:
	var focus: Vector3 = Fx.to3d(cam_focus)
	far_layer.position = Vector3(focus.x*0.88,0,focus.z*0.88)
	for layer in tiled_layers:
		var tile: float = layer.get_meta("tile")
		layer.position = Vector3(roundf(focus.x/tile)*tile,0,roundf(focus.z/tile)*tile)
	grid_node.position = Vector3(snappedf(focus.x,12.0),0,snappedf(focus.z,12.0))
	for g in gates:
		g.get_node("Field").rotation.y = clock*0.3
		for i in range(8):
			g.get_node("Lamp%d" % i).visible = fposmod(clock*1.2-i*0.125,1.0)<0.5
	# Lane buoys pulse in a chase pattern that runs toward the next signal.
	for b in buoys:
		var on: bool = fposmod(clock*1.4-int(b.get_meta("order"))*0.12,1.0)<0.3
		b.get_node("Lamp").visible = on
		b.get_node("Halo").visible = on
	for w in wrecks:
		w.rotation.y += delta*0.01
		w.get_node("Lamp").visible = fposmod(clock*0.7,1.0)<0.15
	station.rotation.y += delta*0.06
	for s in range(4):
		station.get_node("Beacon%d" % s).visible = fposmod(clock*1.3+s*0.4,1.0)<0.55
	planet.rotation.y += delta*0.004

func sync_ship(delta: float) -> void:
	if ship==null:
		ship = Models.player_ship(Game.s.equipped)
		add_child(ship)
		with_hurt_overlay(ship)
	ship.visible = sim.hull>0
	ship.position = Fx.to3d(sim.position_ship,0.0)+Vector3(0,sin(clock*1.6)*0.08,0)
	var heading: Vector2 = sim.aim
	var right: Vector2 = Vector2(-heading.y,heading.x)
	var lateral: float = sim.velocity_ship.dot(right)/BHSpace.CRUISE
	bank = lerpf(bank,clampf(-lateral*0.55,-0.6,0.6),minf(1.0,delta*6.0))
	ship.rotation = Vector3(0,atan2(-heading.x,-heading.y),bank)
	set_hurt(ship,sim.ship.hurt)
	var thrust: float = clampf(sim.velocity_ship.length()/BHSpace.CRUISE,0.0,2.4)+(0.5 if sim.afterburner else 0.0)
	for side in ["L","R"]:
		var flame: Node3D = ship.get_node("Flame"+side)
		var length: float = 0.25+thrust*0.75+sin(clock*40.0)*0.05
		flame.scale = Vector3(1.0+thrust*0.15,length,1.0+thrust*0.15)
		flame.position.z = 2.5+0.8*length
		ship.get_node("Tip"+side).visible = fposmod(clock,1.2)<0.6
	ship.get_node("Mast").visible = fposmod(clock*0.8,1.0)<0.2
	for child in ship.get_children():
		if not child.name.begins_with("Hardpoint"):
			continue
		var id: String = child.get_meta("module")
		var on: bool = float(sim.active.get(id,0.0))>0.0
		var deploy: Node3D = child.get_node("Deploy")
		match id:
			"boost":
				deploy.get_node("Plume").visible = on
				deploy.get_node("Plume").scale = Vector3(1,1.0+sin(clock*50.0)*0.15,1)
				for vane in ["VaneA","VaneB"]:
					var pivot: Node3D = child.get_node(vane)
					var vane_side: float = -1.0 if vane=="VaneA" else 1.0
					pivot.rotation.y = lerpf(pivot.rotation.y,vane_side*(0.95 if on else 0.0),minf(1.0,delta*14))
			"tether": deploy.position.z = lerpf(deploy.position.z,-0.5 if on else 0.0,minf(1.0,delta*10))
			"shield":
				var spinner: Node3D = deploy.get_node("Spinner")
				spinner.rotation.y += delta*(14.0 if on else 1.5)
				spinner.scale = Vector3.ONE*(1.4 if on else 1.0)
			"emp":
				var dish: Node3D = deploy.get_node("Dish")
				dish.position.y = lerpf(dish.position.y,0.55 if on else 0.22,minf(1.0,delta*8))
				dish.rotation.y += delta*(10.0 if on else 0.6)
			"rail": deploy.position.z = lerpf(deploy.position.z,-0.7 if on else 0.0,minf(1.0,delta*10))
			"drone":
				var hatch: Node3D = child.get_node("Hatch")
				hatch.rotation.x = lerpf(hatch.rotation.x,-1.2 if on else 0.0,minf(1.0,delta*8))
				for n in range(2):
					var bot: Node3D = deploy.get_node("Bot%d" % n)
					bot.visible = on
					bot.position = Vector3(cos(clock*3+n*PI)*1.6,0.6,sin(clock*3+n*PI)*1.6) if on else Vector3(0,0.3,0)

func sync_quarry() -> void:
	if quarry==null:
		quarry = Models.quarry()
		add_child(quarry)
		with_hurt_overlay(quarry)
	quarry.visible = sim.quarry.visible and sim.phase!="survey"
	quarry.position = Fx.to3d(sim.target_pos,0.0)+Vector3(0,sin(clock*1.1)*0.1,0)
	quarry.rotation.y = yaw_of(sim.quarry)
	quarry.rotation.z = sin(clock*0.7)*0.04 if sim.engine>0 else 0.12
	set_hurt(quarry,sim.quarry.hurt)
	for child in quarry.get_children():
		if child.name.begins_with("Flame"):
			child.visible = sim.engine>0
			child.scale = Vector3(1,0.4+clampf(sim.quarry.thrust,0,1.5)*0.8+sin(clock*35+child.position.x)*0.05,1)
	engine_label.visible = quarry.visible
	engine_label.position = quarry.position+Vector3(0,2.6,-2.6)
	engine_label.text = "엔진 %d%%" % int(sim.engine)
	engine_label.modulate = Color("f1e6c6") if sim.engine>0 else Color("a8d6cb")

func sync_escorts() -> void:
	var alive: Dictionary = {}
	for enemy in sim.enemies:
		var id: int = enemy.node.get_instance_id()
		alive[id] = true
		if not escorts.has(id):
			var model = Models.escort()
			add_child(model)
			with_hurt_overlay(model)
			escorts[id] = model
		var node: Node3D = escorts[id]
		node.position = Fx.to3d(enemy.pos,0.2)+Vector3(0,sin(clock*2.0+id)*0.12,0)
		var toward: Vector2 = enemy.pos.direction_to(sim.position_ship)
		node.rotation = Vector3(0,atan2(-toward.x,-toward.y),sin(clock*1.7+id)*0.08)
		if float(enemy.stun)>0:
			node.rotation.z = sin(clock*18.0)*0.25
		set_hurt(node,enemy.node.hurt)
		var charge: Node3D = node.get_node("Charge")
		charge.visible = enemy.warning and float(enemy.stun)<=0
		if charge.visible:
			var k: float = clampf(1.0-float(enemy.timer)/1.15,0,1)
			charge.scale = Vector3.ONE*(0.4+k*1.2+sin(clock*30)*0.1)
	for id in escorts.keys():
		if not alive.has(id):
			escorts[id].queue_free()
			escorts.erase(id)

func sync_drones() -> void:
	var alive: Dictionary = {}
	for h in sim.hornets:
		var id: int = h.node.get_instance_id()
		alive[id] = true
		if not drones.has(id):
			var model = Models.hornet()
			model.scale = Vector3.ONE*1.3
			add_child(model)
			with_hurt_overlay(model)
			drones[id] = model
		var node: Node3D = drones[id]
		node.position = Fx.to3d(h.pos,0.5)+Vector3(0,sin(clock*5.0+id)*0.15,0)
		node.rotation = Vector3(0,yaw_of(h.node),0)
		set_hurt(node,h.node.hurt)
		var flap: float = sin(clock*40.0)*(0.15 if h.state=="dash" else 0.55)
		node.get_node("WingL").rotation.z = flap
		node.get_node("WingR").rotation.z = -flap
		node.get_node("Eye").scale = Vector3.ONE*(1.0+h.node.charging*1.6+(0.8 if h.state=="dash" else 0.0))
	for id in drones.keys():
		if not alive.has(id):
			drones[id].queue_free()
			drones.erase(id)

func sync_mines() -> void:
	var alive: Dictionary = {}
	for m in sim.mines:
		var id: int = int(m.get("id",0))
		alive[id] = true
		if not mine_nodes.has(id):
			var model = Models.mine()
			add_child(model)
			mine_nodes[id] = model
		var node: Node3D = mine_nodes[id]
		node.position = Fx.to3d(m.pos,0.3)+Vector3(0,sin(float(m.clock)*2.0)*0.12,0)
		node.rotation = Vector3(float(m.clock)*0.6,float(m.clock)*0.9,0)
		var armed: bool = float(m.arm)<=0
		var blink: float = 0.5+0.5*sin(float(m.clock)*(22.0 if float(m.fuse)>=0 else 5.0))
		node.get_node("Core").scale = Vector3.ONE*((0.6+blink*0.9) if armed else 0.5)
	for id in mine_nodes.keys():
		if not alive.has(id):
			mine_nodes[id].queue_free()
			mine_nodes.erase(id)

func sync_rocks() -> void:
	if rocks.is_empty():
		for i in range(sim.asteroids.size()):
			var rock: Dictionary = sim.asteroids[i]
			var model = Models.asteroid(float(rock.r)/Fx.SCALE*1.05,300+i*17)
			var holder = Node3D.new()
			holder.add_child(model)
			add_child(holder)
			with_hurt_overlay(holder)
			rocks.append(holder)
		# Distant non-colliding rocks on lower planes for depth.
		var rng = RandomNumberGenerator.new()
		rng.seed = 55
		for i in range(18):
			var far = Models.asteroid(rng.randf_range(0.6,2.2),900+i)
			far.position = Vector3(rng.randf_range(-70,70),rng.randf_range(-22,-6),rng.randf_range(-45,25))
			far.rotation = Vector3(rng.randf()*TAU,rng.randf()*TAU,0)
			add_child(far)
	for i in range(rocks.size()):
		var rock: Dictionary = sim.asteroids[i]
		var holder: Node3D = rocks[i]
		holder.position = Fx.to3d(rock.pos,-0.2)
		holder.rotation = Vector3(clock*0.05*(i%3-1),-float(rock.rot),clock*0.04)
		set_hurt(holder,float(rock.hurt)*0.5)

func sync_objectives() -> void:
	while beacons.size()<sim.markers.size():
		var b = Models.beacon(Color("e1c58e") if sim.salvage else Color("8fe0d4"))
		add_child(b)
		beacons.append(b)
		var l = label3d(30)
		beacon_labels.append(l)
	for i in range(beacons.size()):
		var marker: Dictionary = sim.markers[i]
		var show: bool = sim.phase=="survey" and not marker.done
		beacons[i].visible = show
		beacon_labels[i].visible = show
		if show:
			beacons[i].position = Fx.to3d(marker.pos,-0.3)
			beacons[i].get_node("RingA").rotation.y = clock*0.4
			beacons[i].get_node("RingB").scale = Vector3.ONE*(1.0+sin(clock*2.0)*0.1)
			beacon_labels[i].position = beacons[i].position+Vector3(0,1.8,2.6)
			beacon_labels[i].text = ("화물 %d" if sim.salvage else "신호 %d") % (i+1)
			beacon_labels[i].modulate = Color("d8e6dc")
	if relay==null:
		relay = Models.relay()
		add_child(relay)
		pod = Models.pod()
		add_child(pod)
	relay.visible = sim.phase=="boarding" and sim.relay_hp>0
	relay.position = Fx.to3d(sim.relay_pos,1.4)+Vector3(0,sin(clock*3.0)*0.15,0)
	relay.get_node("Crystal").rotation.y = clock*2.0
	relay.get_node("Ring").rotation = Vector3(0.6,clock*1.5,0.3)
	relay_label.visible = relay.visible
	relay_label.position = relay.position+Vector3(0,1.6,0)
	relay_label.text = "중계기"
	relay_label.modulate = Color("f1cfe2")
	pod.visible = sim.phase=="extraction"
	pod.position = Fx.to3d(sim.pod_pos,0.5)+Vector3(0,sin(clock*2.0)*0.2,0)
	pod.rotation.y = clock*0.5
	pod_label.visible = pod.visible
	pod_label.position = pod.position+Vector3(0,1.4,1.4)
	pod_label.text = "[E] 회수"
	pod_label.modulate = Color("eeeec6")

func sync_projectiles() -> void:
	while shots.size()<sim.projectiles.size():
		var node = Node3D.new()
		var cap = CapsuleMesh.new()
		cap.radius = 0.09
		cap.height = 1.1
		cap.radial_segments = 8
		cap.rings = 2
		Models.part(node,cap,Models.glow("shot_core",Color(1,1,0.95),1.0),Vector3.ZERO,Vector3(PI*0.5,0,0),Vector3.ONE,"Core")
		var halo = CapsuleMesh.new()
		halo.radius = 0.24
		halo.height = 1.6
		halo.radial_segments = 8
		halo.rings = 2
		Models.part(node,halo,Models.glow("shot_halo_p",Color(0.5,0.95,0.85),0.45),Vector3.ZERO,Vector3(PI*0.5,0,0),Vector3.ONE,"Halo")
		add_child(node)
		shots.append(node)
	for i in range(shots.size()):
		var node: Node3D = shots[i]
		if i>=sim.projectiles.size():
			node.visible = false
			continue
		var shot: Dictionary = sim.projectiles[i]
		node.visible = true
		node.position = Fx.to3d(shot.pos,0.3)
		var dir: Vector2 = shot.vel.normalized()
		node.rotation = Vector3(0,atan2(-dir.x,-dir.y),0)
		node.get_node("Halo").material_override = Models.glow("shot_halo_e",Color(1.0,0.55,0.3),0.55) if shot.enemy else Models.glow("shot_halo_p",Color(0.5,0.95,0.85),0.45)

## Per-frame flat indicators on the flight plane: telegraphs, tether, shield, rings, bars.
func draw_overlay() -> void:
	overlay.clear_surfaces()
	overlay.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var any: bool = false
	var t: float = clock
	for enemy in sim.enemies:
		if enemy.warning and float(enemy.stun)<=0:
			var k: float = clampf(1.0-float(enemy.timer)/1.15,0,1)
			fx_strip(PackedVector2Array([enemy.pos,enemy.pos+enemy.aim*800]),3.0+k*5.0,Color(1.0,0.5,0.32,0.12+0.3*k),0.25)
			circle(enemy.pos,40,2.0,Color(1.0,0.6,0.4,0.6),0.3,k)
			any = true
		if float(enemy.stun)>0:
			circle(enemy.pos,38,2.0,Color(0.8,0.7,1.0,0.6),0.8,1.0)
			any = true
	for h in sim.hornets:
		if h.state=="charge":
			var k2: float = clampf(1.0-float(h.timer)/0.8,0,1)
			for n in range(10):
				var a: Vector2 = h.pos+h.dir*429.0*n/10.0
				fx_strip(PackedVector2Array([a,a+h.dir*22]),4.0+k2*6,Color(1.0,0.6,0.42,0.2+0.6*k2),0.3)
			any = true
	for m in sim.mines:
		if float(m.fuse)>=0:
			circle(m.pos,100,3.0,Color(1.0,0.45,0.35,0.35+0.4*(0.5+0.5*sin(float(m.clock)*22))),0.2,1.0)
			any = true
		elif float(m.arm)<=0:
			circle(m.pos,85,1.5,Color(1.0,0.55,0.45,0.12),0.2,1.0)
			any = true
	if sim.phase in ["pursuit","boarding","extraction"] and quarry.visible:
		circle(sim.target_pos,78,2.0,Color(0.95,0.8,0.55,0.35),0.1,1.0)
		var base: Vector2 = sim.target_pos+Vector2(-50,80)
		fx_strip(PackedVector2Array([base,base+Vector2(100,0)]),6,Color(0.3,0.4,0.45,0.5),0.15)
		fx_strip(PackedVector2Array([base,base+Vector2(100*sim.engine/100.0,0)]),6,Color(1.0,0.85,0.55,0.8),0.2)
		any = true
	if sim.phase=="boarding" and sim.relay_hp>0:
		fx_strip(PackedVector2Array([sim.target_pos,sim.relay_pos]),2.0,Color(0.95,0.6,0.85,0.5),0.8)
		any = true
	if sim.phase=="boarding" and sim.relay_hp<=0:
		circle(sim.target_pos,480,2.0,Color(0.7,0.9,0.85,0.12+0.05*sin(t*3)),0.1,1.0)
		any = true
	if sim.phase=="extraction":
		circle(sim.pod_pos,100,2.5,Color(0.95,0.95,0.65,0.4+0.2*sin(t*3)),0.1,1.0)
		any = true
	if sim.phase=="survey":
		for marker in sim.markers:
			if not marker.done and sim.position_ship.distance_to(marker.pos)<90 and sim.scan_progress>0:
				circle(marker.pos,52,6.0,Color(1.0,0.85,0.55,0.9),0.2,minf(1.0,sim.scan_progress/0.9))
				any = true
			elif not marker.done:
				circle(marker.pos,90,1.5,Color(0.6,0.9,0.85,0.25),0.05,1.0)
				any = true
	if float(sim.active.get("tether",0.0))>0:
		var pts = PackedVector2Array()
		var normal: Vector2 = (sim.target_pos-sim.position_ship).orthogonal().normalized()
		for k3 in range(25):
			var u: float = k3/24.0
			pts.append(sim.position_ship.lerp(sim.target_pos,u)+normal*sin(u*PI*3+t*14)*6*sin(u*PI))
		fx_strip(pts,9,Color(0.95,0.85,0.5,0.25),0.5)
		fx_strip(pts,3,Color(1.0,0.95,0.75,0.9),0.52)
		for k4 in range(3):
			var u2: float = fposmod(t*1.4+k4/3.0,1.0)
			circle(sim.position_ship.lerp(sim.target_pos,u2),6,6,Color(1,0.97,0.8,0.9),0.55,1.0)
		any = true
	if float(sim.active.get("shield",0.0))>0:
		var from: float = sim.aim.angle()-deg_to_rad(70)
		var to: float = sim.aim.angle()+deg_to_rad(70)
		var steps: int = 20
		for k5 in range(steps):
			var a1: float = lerpf(from,to,float(k5)/steps)
			var a2: float = lerpf(from,to,float(k5+1)/steps)
			var p1: Vector3 = Fx.to3d(sim.position_ship+Vector2.from_angle(a1)*70)
			var p2: Vector3 = Fx.to3d(sim.position_ship+Vector2.from_angle(a2)*70)
			var shimmer: float = 0.25+0.15*sin(t*8+k5)
			quad3(p1+Vector3(0,-0.6,0),p2+Vector3(0,-0.6,0),p2+Vector3(0,1.6,0),p1+Vector3(0,1.6,0),Color(0.6,0.95,0.9,shimmer))
		any = true
	if not any:
		# ImmediateMesh surfaces must not be empty.
		fx_strip(PackedVector2Array([Vector2.ZERO,Vector2(0.01,0)]),0.01,Color(0,0,0,0),-50)
	overlay.surface_end()

func fx_strip(points: PackedVector2Array, width: float, color: Color, h: float) -> void:
	for i in range(points.size()-1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i+1]
		var n: Vector2 = (b-a).orthogonal().normalized()*width*0.5
		quad3(Fx.to3d(a+n,h),Fx.to3d(a-n,h),Fx.to3d(b-n,h),Fx.to3d(b+n,h),color)

func circle(center: Vector2, radius: float, width: float, color: Color, h: float, portion: float) -> void:
	var steps: int = 48
	var pts = PackedVector2Array()
	for i in range(int(steps*portion)+1):
		var a: float = -PI*0.5+TAU*float(i)/steps
		pts.append(center+Vector2.from_angle(a)*radius)
	if pts.size()>1:
		fx_strip(pts,width,color,h)

func quad3(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	for v in [a,b,c,a,c,d]:
		overlay.surface_set_color(color)
		overlay.surface_add_vertex(v)
