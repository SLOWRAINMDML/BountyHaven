class_name BHModels
extends RefCounted
## Procedural low-poly 3D models for the quarter-view space scene. Built from primitive
## meshes only (no imported assets). Every model faces -Z (nose forward) at unit scale,
## so one yaw formula orients all of them from the 2D simulation's direction vectors.
static var materials: Dictionary = {}

static func mat(key: String, color: Color, emission: float = 0.0, rough: float = 0.62, metal: float = 0.25) -> StandardMaterial3D:
	if materials.has(key):
		return materials[key]
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if emission>0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	materials[key] = m
	return m

static func glow(key: String, color: Color, alpha: float = 1.0) -> StandardMaterial3D:
	var id: String = "glow_"+key
	if materials.has(id):
		return materials[id]
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color,alpha)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	materials[id] = m
	return m

static func part(parent: Node3D, mesh: Mesh, material: Material, at: Vector3, rot: Vector3 = Vector3.ZERO, scale_value: Vector3 = Vector3.ONE, name: String = "") -> MeshInstance3D:
	var node = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	node.rotation = rot
	node.scale = scale_value
	if not name.is_empty():
		node.name = name
	parent.add_child(node)
	return node

static func box(size: Vector3) -> BoxMesh:
	var m = BoxMesh.new()
	m.size = size
	return m

static func cyl(top: float, bottom: float, height: float, sides: int = 12) -> CylinderMesh:
	var m = CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = sides
	m.rings = 1
	return m

static func sphere(radius: float, segments: int = 16, rings: int = 8) -> SphereMesh:
	var m = SphereMesh.new()
	m.radius = radius
	m.height = radius*2.0
	m.radial_segments = segments
	m.rings = rings
	return m

static func prism(size: Vector3) -> PrismMesh:
	var m = PrismMesh.new()
	m.size = size
	return m

static func torus(inner: float, outer: float, sides: int = 32) -> TorusMesh:
	var m = TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = sides
	m.ring_segments = 8
	return m

const CREAM = Color("e9dfc8")
const CREAM_SHADE = Color("cbbd9f")
const RUST = Color("b8643b")
const RUST_DARK = Color("7f412a")
const STEEL = Color("46545c")
const STEEL_DARK = Color("2b353b")
const GLASS = Color("6fd6ca")

## The player's cream-and-rust courier. Four named hardpoints show the equipped modules.
static func player_ship(modules: Array) -> Node3D:
	var root = Node3D.new()
	var hull = mat("cream",CREAM,0.0,0.55,0.15)
	var shade = mat("cream_shade",CREAM_SHADE,0.0,0.6,0.2)
	var rust = mat("rust",RUST,0.0,0.7,0.3)
	var steel = mat("steel",STEEL,0.0,0.45,0.7)
	# Fuselage, tapered nose and dorsal spine.
	part(root,box(Vector3(1.25,0.62,2.9)),hull,Vector3(0,0,0.35))
	part(root,cyl(0.0,0.72,1.9,6),hull,Vector3(0,0,-1.95),Vector3(-PI*0.5,0,0),Vector3(1.0,1.0,0.62))
	part(root,box(Vector3(0.5,0.28,2.4)),shade,Vector3(0,0.42,0.55))
	part(root,box(Vector3(1.28,0.08,0.5)),rust,Vector3(0,0.31,-0.35))
	# Cockpit canopy.
	part(root,sphere(0.42,12,6),mat("glass",GLASS,1.4,0.1,0.1),Vector3(0,0.36,-1.05),Vector3.ZERO,Vector3(0.9,0.62,1.7))
	# Cargo pods with rust bands.
	for side in [-1.0,1.0]:
		part(root,box(Vector3(0.72,0.66,2.3)),shade,Vector3(side*1.05,-0.05,0.55))
		part(root,box(Vector3(0.74,0.68,0.22)),rust,Vector3(side*1.05,-0.05,-0.15))
		part(root,box(Vector3(0.74,0.68,0.22)),rust,Vector3(side*1.05,-0.05,1.25))
		var wing = part(root,box(Vector3(1.5,0.1,1.05)),steel,Vector3(side*1.95,-0.15,0.95),Vector3(0,side*0.32,0))
		part(wing,box(Vector3(0.3,0.12,1.07)),rust,Vector3(side*0.62,0,0))
		var tip = part(root,sphere(0.09,6,4),mat("tip_"+str(side),Color("ef6a55") if side<0 else Color("8fe39a"),3.0),Vector3(side*2.62,-0.1,1.2))
		tip.name = "Tip"+("L" if side<0 else "R")
		# Twin engines, nozzle glow and thrust flame.
		var engine = part(root,cyl(0.3,0.36,0.9),steel,Vector3(side*0.55,-0.05,2.05),Vector3(PI*0.5,0,0))
		engine.name = "Engine"+("L" if side<0 else "R")
		part(root,cyl(0.26,0.26,0.05),mat("nozzle",Color("a6f3e8"),4.0),Vector3(side*0.55,-0.05,2.52),Vector3(PI*0.5,0,0))
		var flame = part(root,cyl(0.0,0.26,1.6,10),glow("flame_teal",Color(0.45,0.95,0.88),0.8),Vector3(side*0.55,-0.05,3.3),Vector3(PI*0.5,0,0))
		flame.name = "Flame"+("L" if side<0 else "R")
	var mounts: Array = [Vector3(-1.75,0.15,1.3),Vector3(1.75,0.15,1.3),Vector3(-0.95,0.3,-0.55),Vector3(0.95,0.3,-0.55)]
	for i in range(mini(modules.size(),4)):
		var hp = Node3D.new()
		hp.name = "Hardpoint%d" % i
		hp.position = mounts[i]
		hp.set_meta("module",str(modules[i]))
		root.add_child(hp)
		build_module(hp,str(modules[i]))
	return root

## Each module has a stowed shape and a "Deploy" child the view animates when active.
static func build_module(hp: Node3D, id: String) -> void:
	var steel = mat("steel",STEEL,0.0,0.45,0.7)
	var dark = mat("steel_dark",STEEL_DARK,0.0,0.5,0.6)
	var deploy = Node3D.new()
	deploy.name = "Deploy"
	hp.add_child(deploy)
	match id:
		"boost":
			part(hp,box(Vector3(0.36,0.34,0.9)),steel,Vector3.ZERO)
			part(deploy,box(Vector3(0.1,0.3,0.6)),mat("rust",RUST),Vector3(0.24,0,0.1))
			part(deploy,cyl(0.0,0.2,1.2,8),glow("boost",Color(0.6,1.0,0.92),0.9),Vector3(0,0,1.1),Vector3(PI*0.5,0,0),Vector3.ONE,"Plume")
		"tether":
			part(hp,box(Vector3(0.34,0.32,0.7)),mat("brass",Color("c9ad73"),0.0,0.4,0.8),Vector3.ZERO)
			part(deploy,cyl(0.08,0.08,0.9,8),dark,Vector3(0,0.05,-0.6),Vector3(PI*0.5,0,0))
			part(deploy,cyl(0.0,0.14,0.25,6),mat("brass_glow",Color("f2e2a8"),2.0),Vector3(0,0.05,-1.12),Vector3(-PI*0.5,0,0))
		"shield":
			part(hp,cyl(0.2,0.28,0.2),steel,Vector3.ZERO)
			part(deploy,torus(0.22,0.36,16),mat("shield_emit",Color("9be9dc"),2.2),Vector3(0,0.18,0),Vector3.ZERO,Vector3.ONE,"Spinner")
		"emp":
			part(hp,cyl(0.14,0.18,0.25),steel,Vector3.ZERO)
			part(deploy,cyl(0.42,0.08,0.14,14),mat("emp_dish",Color("b9a6d8"),0.6),Vector3(0,0.22,0),Vector3.ZERO,Vector3.ONE,"Dish")
		"rail":
			part(hp,box(Vector3(0.3,0.3,0.7)),steel,Vector3.ZERO)
			part(deploy,cyl(0.07,0.09,1.8,8),dark,Vector3(0,0.05,-1.0),Vector3(PI*0.5,0,0))
			part(deploy,cyl(0.05,0.05,1.6,6),mat("rail_emit",Color("f3dcaa"),2.5),Vector3(0,0.12,-1.0),Vector3(PI*0.5,0,0))
		"drone":
			part(hp,box(Vector3(0.5,0.3,0.55)),mat("olive",Color("98a883")),Vector3.ZERO)
			for n in range(2):
				var bot = part(deploy,sphere(0.12,8,4),mat("drone_emit",Color("d4f0b4"),2.0),Vector3(0,0.3,0))
				bot.name = "Bot%d" % n

## Pirate escort gunship: rust-red, forward-swept, single hot engine.
static func escort() -> Node3D:
	var root = Node3D.new()
	var body = mat("escort",Color("9b4a36"),0.0,0.6,0.35)
	var trim = mat("escort_trim",Color("d6b28a"))
	part(root,box(Vector3(0.8,0.45,2.2)),body,Vector3(0,0,0.2))
	part(root,cyl(0.0,0.45,1.1,6),body,Vector3(0,0,-1.35),Vector3(-PI*0.5,0,0),Vector3(1,1,0.7))
	part(root,sphere(0.25,8,4),mat("escort_glass",Color("f1a071"),1.8),Vector3(0,0.25,-0.6),Vector3.ZERO,Vector3(1,0.6,1.6))
	for side in [-1.0,1.0]:
		part(root,box(Vector3(1.4,0.08,0.7)),body,Vector3(side*0.95,0,0.1),Vector3(0,-side*0.45,0))
		part(root,box(Vector3(0.1,0.12,1.2)),trim,Vector3(side*1.5,0.05,-0.2))
		part(root,cyl(0.05,0.05,1.0,6),mat("steel_dark",STEEL_DARK),Vector3(side*0.55,0.1,-1.0),Vector3(PI*0.5,0,0))
	part(root,cyl(0.28,0.32,0.5),mat("steel",STEEL),Vector3(0,0,1.45),Vector3(PI*0.5,0,0))
	part(root,cyl(0.0,0.26,1.2,10),glow("flame_orange",Color(1.0,0.6,0.35),0.8),Vector3(0,0,2.25),Vector3(PI*0.5,0,0),Vector3.ONE,"FlameC")
	var charge = part(root,sphere(0.3,10,5),glow("charge",Color(1.0,0.62,0.4),0.9),Vector3(0,0.1,-1.95),Vector3.ZERO,Vector3.ONE,"Charge")
	charge.visible = false
	return root

## The bounty target: a boxy mechanic's tug hauling cargo, three engines.
static func quarry() -> Node3D:
	var root = Node3D.new()
	var body = mat("quarry",Color("c7ad86"),0.0,0.65,0.2)
	var dark = mat("quarry_dark",Color("6f5b46"))
	part(root,box(Vector3(2.0,1.0,3.6)),body,Vector3(0,0,0.3))
	part(root,box(Vector3(1.4,0.7,1.1)),body,Vector3(0,0.2,-1.95))
	part(root,box(Vector3(1.2,0.18,0.35)),mat("quarry_glass",Color("8ad0c4"),1.3),Vector3(0,0.42,-2.4))
	for x in [-1.25,1.25]:
		for z in [-0.4,0.9]:
			part(root,box(Vector3(0.7,0.8,1.1)),mat("container_"+str(z),Color("7f9a94") if z<0 else Color("b8643b")),Vector3(x,-0.05,z))
	part(root,box(Vector3(0.12,0.9,1.6)),dark,Vector3(0,0.9,0.6))
	# Bridge dome, antenna mast with a warning light, and hull striping.
	part(root,sphere(0.45,12,6),mat("quarry_dome",Color("9fd8cc"),0.8,0.15,0.2),Vector3(0,0.62,-1.7),Vector3.ZERO,Vector3(1,0.6,1))
	part(root,cyl(0.03,0.04,1.4,6),dark,Vector3(0.55,1.2,-1.4))
	part(root,sphere(0.09,6,4),mat("quarry_warn",Color("ff8a5c"),4.0),Vector3(0.55,1.92,-1.4))
	for z in [-0.9,0.2,1.3]:
		part(root,box(Vector3(2.04,0.12,0.18)),mat("rust",RUST),Vector3(0,0.46,z))
	for side in [-1.0,1.0]:
		part(root,box(Vector3(0.3,0.3,0.6)),mat("steel",STEEL),Vector3(side*1.05,0.1,-2.2))
	for x in [-0.7,0.0,0.7]:
		part(root,cyl(0.28,0.34,0.6),mat("steel",STEEL),Vector3(x,-0.1,2.35),Vector3(PI*0.5,0,0))
		part(root,cyl(0.0,0.26,1.4,10),glow("flame_orange",Color(1.0,0.6,0.35),0.8),Vector3(x,-0.1,3.3),Vector3(PI*0.5,0,0),Vector3.ONE,"Flame%d" % int(x*10+10))
	return root

static func hornet() -> Node3D:
	var root = Node3D.new()
	var body = mat("hornet",Color("c9906f"),0.0,0.5,0.3)
	part(root,sphere(0.32,10,6),body,Vector3.ZERO,Vector3.ZERO,Vector3(0.8,0.6,2.0))
	part(root,cyl(0.0,0.12,0.5,6),mat("steel_dark",STEEL_DARK),Vector3(0,0,-0.85),Vector3(-PI*0.5,0,0))
	var eye = part(root,sphere(0.13,8,4),mat("hornet_eye",Color("ffb07a"),3.0),Vector3(0,0.12,-0.45),Vector3.ZERO,Vector3.ONE,"Eye")
	for side in [-1.0,1.0]:
		var pivot = Node3D.new()
		pivot.name = "Wing"+("L" if side<0 else "R")
		pivot.position = Vector3(side*0.18,0.12,0.05)
		root.add_child(pivot)
		part(pivot,box(Vector3(0.9,0.03,0.45)),glow("wing",Color(0.75,0.9,0.86),0.45),Vector3(side*0.5,0,0.1))
	part(root,sphere(0.12,6,4),glow("hornet_tail",Color(1.0,0.65,0.45),0.9),Vector3(0,0,0.7))
	eye.set_meta("base",Vector3.ONE)
	return root

static func mine() -> Node3D:
	var root = Node3D.new()
	part(root,sphere(0.42,12,6),mat("mine",Color("6e5e52"),0.0,0.5,0.6),Vector3.ZERO)
	var dark = mat("steel_dark",STEEL_DARK)
	for d in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK,Vector3(0.7,0.7,0),Vector3(-0.7,0.7,0)]:
		var spike = part(root,cyl(0.0,0.07,0.38,6),dark,d.normalized()*0.5)
		spike.look_at_from_position(d.normalized()*0.5,d.normalized()*2.0,Vector3.UP if absf(d.normalized().dot(Vector3.UP))<0.9 else Vector3.FORWARD)
		spike.rotate_object_local(Vector3.RIGHT,-PI*0.5)
	part(root,sphere(0.16,8,4),mat("mine_core",Color("ff7a55"),4.0),Vector3(0,0.35,0),Vector3.ZERO,Vector3.ONE,"Core")
	return root

static func relay() -> Node3D:
	var root = Node3D.new()
	part(root,sphere(0.5,4,2),mat("relay",Color("e07ab8"),0.6,0.2,0.3),Vector3.ZERO,Vector3.ZERO,Vector3(0.8,1.4,0.8),"Crystal")
	part(root,torus(0.75,0.85,24),glow("relay_ring",Color(0.95,0.6,0.85),0.8),Vector3.ZERO,Vector3.ZERO,Vector3.ONE,"Ring")
	return root

static func pod() -> Node3D:
	var root = Node3D.new()
	var cap = CapsuleMesh.new()
	cap.radius = 0.35
	cap.height = 1.3
	part(root,cap,mat("cream",CREAM),Vector3.ZERO,Vector3(PI*0.5,0,0))
	part(root,box(Vector3(0.72,0.1,0.3)),mat("rust",RUST),Vector3(0,0,0))
	part(root,sphere(0.12,8,4),mat("pod_light",Color("f0f2b8"),4.0),Vector3(0,0.4,0))
	part(root,cyl(0.5,0.9,6.0,16),glow("pod_beam",Color(0.9,0.95,0.65),0.14),Vector3(0,3.0,0),Vector3.ZERO,Vector3.ONE,"Beam")
	return root

static func beacon(color: Color) -> Node3D:
	var root = Node3D.new()
	part(root,box(Vector3(0.5,0.7,0.5)),mat("beacon_body",Color("b8b79d")),Vector3(0,0.2,0))
	part(root,sphere(0.14,8,4),mat("beacon_light",color,4.0),Vector3(0,0.7,0),Vector3.ZERO,Vector3.ONE,"Light")
	part(root,torus(1.7,1.8,40),glow("beacon_ring",color,0.55),Vector3(0,0.05,0),Vector3.ZERO,Vector3.ONE,"RingA")
	part(root,torus(0.9,0.95,32),glow("beacon_ring2",color,0.35),Vector3(0,0.05,0),Vector3.ZERO,Vector3.ONE,"RingB")
	part(root,cyl(0.25,0.25,5.0,10),glow("beacon_beam",color,0.12),Vector3(0,2.5,0))
	return root

## Faceted rock: a low-poly sphere displaced by deterministic noise, flat shaded.
static func asteroid(radius: float, seed_value: int) -> MeshInstance3D:
	var noise = FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 1.3
	var base: SphereMesh = sphere(1.0,10,7)
	var arrays: Array = base.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	var squash: Vector3 = Vector3(rng.randf_range(0.85,1.15),rng.randf_range(0.6,0.85),rng.randf_range(0.85,1.15))
	for i in indices:
		var v: Vector3 = verts[i]
		var bump: float = 1.0+noise.get_noise_3dv(v*1.7)*0.45
		st.add_vertex(v*bump*squash*radius)
	st.generate_normals()
	var node = MeshInstance3D.new()
	node.mesh = st.commit()
	var tone: float = rng.randf_range(-0.05,0.05)
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(0.47+tone,0.45+tone,0.41+tone)
	m.roughness = 0.95
	m.metallic = 0.05
	node.material_override = m
	return node
