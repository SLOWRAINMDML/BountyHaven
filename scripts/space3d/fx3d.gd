class_name BHVfx3D
extends Node3D
## 3D counterpart of BHVfx with the same call surface, so BHSpace drives either one.
## Particles live in simulation pixels (x, y) plus a height, and render through four
## MultiMesh pools (glow billboards, smoke billboards, oriented sparks, lit shards),
## a ring pool, one ribbon mesh for bolts/beams/afterimages, and Label3D damage numbers.
const LIMIT: int = 1400
const SCALE: float = 20.0
const CENTER = Vector2(800,477)
var parts: Array = []
var rings: Array = []
var ribbons: Array = []
var texts: Array = []
var rng = RandomNumberGenerator.new()
var frozen: bool = false
var flash: float = 0.0
var flash_color: Color = Color.WHITE
var vignette: float = 0.0
var vignette_color: Color = Color("a0513f")
var glow_mm: MultiMesh
var smoke_mm: MultiMesh
var spark_mm: MultiMesh
var shard_mm: MultiMesh
var ring_nodes: Array = []
var ribbon_mesh: ImmediateMesh
var label_pool: Array = []
var font: Font

static func to3d(p: Vector2, h: float = 0.0) -> Vector3:
	return Vector3((p.x-CENTER.x)/SCALE,h,(p.y-CENTER.y)/SCALE)

func _ready() -> void:
	rng.seed = 4401
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Noto Sans CJK KR","Malgun Gothic","Apple SD Gothic Neo","NanumGothic"])
	var soft = GradientTexture2D.new()
	var g = Gradient.new()
	g.set_color(0,Color(1,1,1,1))
	g.set_color(1,Color(1,1,1,0))
	g.add_point(0.35,Color(1,1,1,0.55))
	soft.gradient = g
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5,0.5)
	soft.fill_to = Vector2(1.0,0.5)
	soft.width = 64
	soft.height = 64
	glow_mm = make_pool(quad(),billboard_material(soft,true))
	smoke_mm = make_pool(quad(),billboard_material(soft,false))
	var spark_mat = StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_mat.vertex_color_use_as_albedo = true
	var spark_mesh = BoxMesh.new()
	spark_mesh.size = Vector3(0.06,0.06,1.0)
	spark_mm = make_pool(spark_mesh,spark_mat)
	var shard_mat = StandardMaterial3D.new()
	shard_mat.vertex_color_use_as_albedo = true
	shard_mat.roughness = 0.8
	shard_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var shard_mesh = PrismMesh.new()
	shard_mesh.size = Vector3(1,1,0.35)
	shard_mm = make_pool(shard_mesh,shard_mat)
	var torus = TorusMesh.new()
	torus.inner_radius = 0.93
	torus.outer_radius = 1.0
	torus.rings = 48
	torus.ring_segments = 4
	for i in range(28):
		var node = MeshInstance3D.new()
		node.mesh = torus
		var m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		node.material_override = m
		node.visible = false
		add_child(node)
		ring_nodes.append(node)
	ribbon_mesh = ImmediateMesh.new()
	var ribbon_node = MeshInstance3D.new()
	ribbon_node.mesh = ribbon_mesh
	var rm = StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rm.vertex_color_use_as_albedo = true
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	ribbon_node.material_override = rm
	add_child(ribbon_node)
	for i in range(24):
		var label = Label3D.new()
		label.font = font
		label.font_size = 52
		label.pixel_size = 0.012
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.outline_size = 10
		label.outline_modulate = Color(0.06,0.1,0.13,0.8)
		label.visible = false
		add_child(label)
		label_pool.append(label)

func quad() -> QuadMesh:
	var q = QuadMesh.new()
	q.size = Vector2(1,1)
	return q

func billboard_material(texture: Texture2D, additive: bool) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.albedo_texture = texture
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.no_depth_test = false
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return m

func make_pool(mesh: Mesh, material: Material) -> MultiMesh:
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = LIMIT
	mm.visible_instance_count = 0
	var node = MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return mm

func emit(kind: String, pos: Vector2, vel: Vector2, life: float, size: float, color: Color, extra: Dictionary = {}) -> void:
	if kind=="ring":
		rings.append({"pos":pos,"radius":size,"life":life,"max":life,"color":color,"width":float(extra.get("width",1.4))})
		if rings.size()>ring_nodes.size():
			rings.remove_at(0)
		return
	if kind in ["bolt","beam"]:
		var r: Dictionary = {"kind":kind,"pos":pos,"life":life,"max":life,"size":size,"color":color}
		if extra.has("points"):
			r.points = extra.points
		if extra.has("end"):
			r.end = extra.end
		ribbons.append(r)
		return
	if parts.size()>=LIMIT:
		parts.remove_at(0)
	var up: float = float(extra.get("up",0.0))
	parts.append({"kind":kind,"pos":pos,"vel":vel,"h":float(extra.get("h",0.6)),"vh":up,"life":life,"max":life,"size":size,"color":color,
		"drag":float(extra.get("drag",1.6)),"grow":float(extra.get("grow",0.0)),"gravity":extra.get("gravity",Vector2.ZERO),
		"rot":Vector3(rng.randf()*TAU,rng.randf()*TAU,0),"spin":rng.randf_range(-7.0,7.0)})

func burst(pos: Vector2, color: Color, count: int, speed_min: float, speed_max: float, life: float, size: float, kind: String = "spark", direction: float = 0.0, spread: float = TAU, extra: Dictionary = {}) -> void:
	for i in range(count):
		var angle: float = direction+rng.randf_range(-spread*0.5,spread*0.5)
		var speed: float = rng.randf_range(speed_min,speed_max)
		var e: Dictionary = extra.duplicate()
		e.up = float(extra.get("up",0.0))+rng.randf_range(-speed,speed)*0.02
		emit(kind,pos,Vector2.from_angle(angle)*speed,life*rng.randf_range(0.6,1.15),size*rng.randf_range(0.7,1.25),color,e)

func ring(pos: Vector2, color: Color, radius: float, life: float = 0.45, width: float = 2.0) -> void:
	emit("ring",pos,Vector2.ZERO,life,radius,color,{"width":width})

func smoke(pos: Vector2, color: Color = Color("5d6f73"), size: float = 11.0, drift: Vector2 = Vector2.ZERO) -> void:
	emit("puff",pos+Vector2(rng.randf_range(-4,4),rng.randf_range(-4,4)),drift+Vector2(rng.randf_range(-14,14),rng.randf_range(-14,14)),rng.randf_range(0.9,1.6),size,Color(color,0.5),{"grow":size*1.4,"drag":1.2,"up":rng.randf_range(0.3,0.9)})

func sparks(pos: Vector2, color: Color, direction: float, count: int = 7, speed: float = 320.0) -> void:
	burst(pos,color,count,speed*0.45,speed,0.32,1.0,"spark",direction,1.6,{"drag":4.0})

func muzzle(pos: Vector2, direction: float, color: Color) -> void:
	emit("bloom",pos,Vector2.ZERO,0.09,14.0,Color(color,1.0),{"grow":50.0})
	burst(pos,color.lightened(0.3),4,160,340,0.14,1.0,"spark",direction,0.7,{"drag":6.0})

func floating_text(pos: Vector2, value: String, color: Color) -> void:
	texts.append({"pos":pos+Vector2(rng.randf_range(-8,8)+30,0),"h":1.5,"text":value,"life":0.9,"max":0.9,"color":color})
	if texts.size()>label_pool.size():
		texts.remove_at(0)

func explosion(pos: Vector2, scale_value: float = 1.0, hot: Color = Color("ffb070"), ink: Color = Color("4b5a5c")) -> void:
	emit("bloom",pos,Vector2.ZERO,0.16,30.0*scale_value,Color(1,0.93,0.8,0.9),{"grow":110.0*scale_value,"h":1.0})
	for i in range(int(12*scale_value)+5):
		var dir: Vector2 = Vector2.from_angle(rng.randf()*TAU)
		emit("bloom",pos+dir*rng.randf_range(0,14)*scale_value,dir*rng.randf_range(30,140)*scale_value,rng.randf_range(0.35,0.75),rng.randf_range(14,28)*scale_value,
			[hot,hot.lightened(0.3),Color("ff7a45"),Color("ffd98a")][i%4],{"grow":rng.randf_range(18,40)*scale_value,"drag":3.2,"up":rng.randf_range(-1.5,2.5)})
	burst(pos,Color("fff0c8"),int(20*scale_value)+8,200,600*scale_value,0.55,1.0,"spark",0.0,TAU,{"drag":2.6})
	burst(pos,Color("7c858a"),int(12*scale_value)+4,90,320*scale_value,1.3,9.0*scale_value,"shard",0.0,TAU,{"drag":1.2})
	for i in range(int(7*scale_value)+3):
		smoke(pos,ink.lightened(0.1),20.0*scale_value,Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(10,70))
	ring(pos,Color(hot,0.9),95*scale_value,0.5,2.4)
	ring(pos,Color(0.8,0.9,1.0,0.35),150*scale_value,0.8,1.0)

func bolt(a: Vector2, b: Vector2, color: Color, life: float = 0.22) -> void:
	var points = PackedVector2Array([a])
	var steps: int = maxi(3,int(a.distance_to(b)/26.0))
	var normal: Vector2 = (b-a).orthogonal().normalized()
	for i in range(1,steps):
		points.append(a.lerp(b,float(i)/steps)+normal*rng.randf_range(-13,13))
	points.append(b)
	emit("bolt",a,Vector2.ZERO,life,1.0,color,{"points":points})

func beam(a: Vector2, b: Vector2, color: Color, width: float, life: float) -> void:
	emit("beam",a,Vector2.ZERO,life,width,color,{"end":b})

func afterimage(pos: Vector2, yaw: float, scale_value: float, color: Color) -> void:
	ribbons.append({"kind":"ghost","pos":pos,"yaw":yaw,"life":0.3,"max":0.3,"size":scale_value,"color":color})

func hit_flash(color: Color, amount: float) -> void:
	flash_color = color
	flash = maxf(flash,amount)

func _process(delta: float) -> void:
	if not frozen:
		advance(delta)
	render()

func advance(delta: float) -> void:
	flash = maxf(0.0,flash-delta*2.6)
	for i in range(parts.size()-1,-1,-1):
		var p: Dictionary = parts[i]
		p.life -= delta
		if p.life<=0.0:
			parts.remove_at(i)
			continue
		p.vel = p.vel*maxf(0.0,1.0-p.drag*delta)+p.gravity*delta
		p.pos += p.vel*delta
		p.h += p.vh*delta
		p.vh *= maxf(0.0,1.0-p.drag*delta)
		p.size += p.grow*delta
		p.rot += Vector3(p.spin,p.spin*0.7,0)*delta
	for list in [rings,ribbons,texts]:
		for i in range(list.size()-1,-1,-1):
			list[i].life -= delta
			if list[i].life<=0.0:
				list.remove_at(i)
	for t in texts:
		t.h += delta*2.0

func render() -> void:
	var counts: Dictionary = {"glow":0,"smoke":0,"spark":0,"shard":0}
	for p in parts:
		var t: float = 1.0-p.life/p.max
		var fade: float = 1.0-t
		var at: Vector3 = to3d(p.pos,p.h)
		var c: Color = p.color
		match p.kind:
			"spark":
				var dir3: Vector3 = Vector3(p.vel.x,p.vh*SCALE,p.vel.y)
				var length: float = clampf(dir3.length()*0.0022,0.12,1.6)
				if dir3.length()<0.01:
					dir3 = Vector3.FORWARD
				var basis: Basis = Basis.looking_at(dir3.normalized(),Vector3.UP if absf(dir3.normalized().y)<0.95 else Vector3.RIGHT)
				basis = basis.scaled_local(Vector3(1.0,1.0,length))
				spark_mm.set_instance_transform(counts.spark,Transform3D(basis,at))
				spark_mm.set_instance_color(counts.spark,Color(c,c.a*fade))
				counts.spark += 1
			"puff":
				var s: float = p.size/SCALE*2.0
				smoke_mm.set_instance_transform(counts.smoke,Transform3D(Basis().scaled(Vector3(s,s,s)),at))
				smoke_mm.set_instance_color(counts.smoke,Color(c,c.a*fade*0.8))
				counts.smoke += 1
			"shard":
				var s2: float = p.size/SCALE
				var b2: Basis = Basis.from_euler(p.rot).scaled(Vector3(s2,s2,s2))
				shard_mm.set_instance_transform(counts.shard,Transform3D(b2,at))
				shard_mm.set_instance_color(counts.shard,Color(c,fade))
				counts.shard += 1
			_:
				var s3: float = p.size/SCALE*(1.5 if p.kind=="bloom" else 1.3)
				var alpha: float = c.a*(sin(t*PI) if p.kind=="mote" else fade)
				glow_mm.set_instance_transform(counts.glow,Transform3D(Basis().scaled(Vector3(s3,s3,s3)),at))
				glow_mm.set_instance_color(counts.glow,Color(c,alpha))
				counts.glow += 1
	glow_mm.visible_instance_count = counts.glow
	smoke_mm.visible_instance_count = counts.smoke
	spark_mm.visible_instance_count = counts.spark
	shard_mm.visible_instance_count = counts.shard
	for i in range(ring_nodes.size()):
		var node: MeshInstance3D = ring_nodes[i]
		if i>=rings.size():
			node.visible = false
			continue
		var r: Dictionary = rings[i]
		var t2: float = 1.0-r.life/r.max
		var eased: float = 1.0-pow(1.0-t2,3.0)
		var radius: float = maxf(0.05,r.radius*eased/SCALE)
		node.visible = true
		node.position = to3d(r.pos,0.3)
		node.scale = Vector3(radius,1.0+r.width,radius)
		node.material_override.albedo_color = Color(r.color,r.color.a*(1.0-t2))
	ribbon_mesh.clear_surfaces()
	if not ribbons.is_empty():
		ribbon_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for r in ribbons:
			var fade2: float = r.life/r.max
			match r.kind:
				"beam":
					strip(PackedVector2Array([r.pos,r.end]),r.size*2.6*fade2+2.0,Color(r.color,0.35*fade2),1.0)
					strip(PackedVector2Array([r.pos,r.end]),r.size*0.9*fade2+1.0,Color(r.color,0.9*fade2),1.02)
					strip(PackedVector2Array([r.pos,r.end]),maxf(1.0,r.size*0.3*fade2),Color(1,0.98,0.9,fade2),1.04)
				"bolt":
					strip(r.points,4.0,Color(r.color,fade2),1.0)
					strip(r.points,1.6,Color(1,1,1,fade2*0.8),1.02)
				"ghost":
					var outline: PackedVector2Array = PackedVector2Array()
					for v in [Vector2(0,-45),Vector2(34,10),Vector2(34,40),Vector2(-34,40),Vector2(-34,10),Vector2(0,-45)]:
						outline.append(r.pos+(v*r.size).rotated(r.yaw))
					strip(outline,3.0,Color(r.color,r.color.a*fade2),0.6)
		ribbon_mesh.surface_end()
	for i in range(label_pool.size()):
		var label: Label3D = label_pool[i]
		if i>=texts.size():
			label.visible = false
			continue
		var tx: Dictionary = texts[i]
		label.visible = true
		label.text = tx.text
		label.position = to3d(tx.pos,tx.h)
		label.modulate = Color(tx.color,tx.life/tx.max)
		label.outline_modulate = Color(0.06,0.1,0.13,0.8*tx.life/tx.max)

## Flat ribbon along a 2D polyline at a given height, widths in simulation pixels.
func strip(points: PackedVector2Array, width: float, color: Color, h: float) -> void:
	for i in range(points.size()-1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i+1]
		var n: Vector2 = (b-a).orthogonal().normalized()*width*0.5
		var a1: Vector3 = to3d(a+n,h)
		var a2: Vector3 = to3d(a-n,h)
		var b1: Vector3 = to3d(b+n,h)
		var b2: Vector3 = to3d(b-n,h)
		for v in [a1,a2,b1,b1,a2,b2]:
			ribbon_mesh.surface_set_color(color)
			ribbon_mesh.surface_add_vertex(v)
