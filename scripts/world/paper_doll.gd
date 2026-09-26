class_name BHPaperDoll
extends BHWalker
## The protagonist as a cutout "paper doll" built from the supplied character sheets.
## Parts are transparent PNGs cut by tools/art/extract_parts.py; the joint layout comes
## from assets/generated/protagonist/v01/rig.json (tools/art/build_rig.py). Each frame the
## pose is solved in rig space (forward kinematics) and written to flat Sprite2D children,
## so draw order is simply child order and the doll sorts with the world like any walker.
const RIG_PATH: String = "res://assets/generated/protagonist/v01/rig.json"
const PART_DIR: String = "res://assets/generated/protagonist/v01/parts/"
const CLOTH_SHADER: String = """
shader_type canvas_item;
uniform vec4 target : source_color = vec4(0.66, 0.28, 0.23, 1.0);
uniform float amount = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float sat = mx > 0.001 ? (mx - mn) / mx : 0.0;
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	// Re-dye the woven red while keeping its shading; pale prints and holes stay as drawn.
	vec3 dyed = clamp(target.rgb * (lum / 0.36), 0.0, 1.0);
	COLOR = vec4(mix(c.rgb, dyed, amount * smoothstep(0.18, 0.4, sat)), c.a);
}
"""
static var rig: Dictionary = {}
static var textures: Dictionary = {}
static var cloth_shader: Shader
## Rig pixels to world pixels. 0.16 makes the doll about 105 px tall in the harbor.
var doll_scale: float = 0.16
var look: Dictionary = {}
var clock: float = 0.0
var doll: Node2D
var nodes: Dictionary = {}
var order: Array = []
var sprites: Dictionary = {}
var pose: Dictionary = {}
var lift: float = 0.0
var cloth_material: ShaderMaterial

static func load_rig() -> Dictionary:
	if rig.is_empty():
		var text: String = FileAccess.get_file_as_string(RIG_PATH)
		var parsed: Variant = JSON.parse_string(text)
		rig = parsed if parsed is Dictionary else {}
	return rig

static func part_texture(part: String) -> Texture2D:
	if not textures.has(part):
		textures[part] = load(PART_DIR+part+".png")
	return textures[part]

func _ready() -> void:
	load_rig()
	if cloth_shader==null:
		cloth_shader = Shader.new()
		cloth_shader.code = CLOTH_SHADER
	cloth_material = ShaderMaterial.new()
	cloth_material.shader = cloth_shader
	doll = Node2D.new()
	add_child(doll)
	var entries: Array = []
	for n in rig.get("nodes",[]):
		entries.append(n)
	for a in rig.get("attachments",[]):
		var entry: Dictionary = a.duplicate()
		entry["attachment"] = true
		entry["region"] = null
		entries.append(entry)
	for entry in entries:
		nodes[entry.name] = entry
	entries.sort_custom(func(a,b): return int(a.z)<int(b.z))
	for entry in entries:
		var sprite = Sprite2D.new()
		sprite.centered = false
		sprite.texture = part_texture(entry.part)
		if entry.region!=null:
			sprite.region_enabled = true
			sprite.region_rect = Rect2(entry.region[0],entry.region[1],entry.region[2],entry.region[3])
		doll.add_child(sprite)
		sprites[entry.name] = sprite
		order.append(entry.name)
		if entry.name in ["scarf","cloak"]:
			sprite.material = cloth_material
	apply_look(look if not look.is_empty() else (Game.s.get("look",BHAppearance.defaults()) if is_player else BHAppearance.defaults()))
	queue_redraw()

## Swap head art, toggle gear and dye the cloth. Safe to call at any time.
func apply_look(new_look: Dictionary) -> void:
	look = new_look.duplicate()
	if sprites.is_empty():
		return
	var hair: String = str(look.get("hair","base"))
	var head: Sprite2D = sprites.head
	head.texture = part_texture("head_front" if hair=="base" else hair)
	for gear in ["scarf","cloak","goggles","cap","satchel","charm"]:
		if sprites.has(gear):
			sprites[gear].visible = bool(look.get(gear,false))
	var cloth: int = clampi(int(look.get("cloth",0)),0,BHAppearance.CLOTH.size()-1)
	cloth_material.set_shader_parameter("target",Color(BHAppearance.CLOTH[cloth][1]))
	cloth_material.set_shader_parameter("amount",0.0 if cloth==0 else 1.0)
	solve()

## Sprite placement inside its joint: base parts use the rig pivot; hair-sheet heads are
## scaled and sit on the neck line from the rig's head settings.
func sprite_frame(name: String) -> Dictionary:
	var entry: Dictionary = nodes[name]
	var pivot := Vector2(entry.pivot[0],entry.pivot[1])
	var scale_value := Vector2(float(entry.get("scale_x",1.0)),1.0)
	if entry.get("attachment",false):
		scale_value = Vector2.ONE*float(entry.scale)
	if entry.region!=null:
		pivot -= Vector2(entry.region[0],entry.region[1])
	if name=="head" and str(look.get("hair","base"))!="base":
		var tex: Texture2D = sprites.head.texture
		var head_scale: float = float(rig.get("head_scale",1.3))
		var lift_to_neck: float = float(rig.get("head_joint_y",-534))-float(entry.joint[1])
		scale_value = Vector2.ONE*head_scale
		pivot = Vector2(tex.get_width()*0.5,tex.get_height()-lift_to_neck/head_scale)
	return {"pivot":pivot,"scale":scale_value}

## Forward kinematics in rig space, then one flat transform per sprite.
func solve() -> void:
	var world: Dictionary = {}
	for name in order:
		world[name] = joint_transform(name,world)
	for name in order:
		var frame: Dictionary = sprite_frame(name)
		var sprite: Sprite2D = sprites[name]
		var local := Transform2D(0.0,frame.scale,0.0,Vector2.ZERO).translated_local(-frame.pivot)
		sprite.transform = world[name]*local

func joint_transform(name: String, world: Dictionary) -> Transform2D:
	if world.has(name):
		return world[name]
	var entry: Dictionary = nodes[name]
	var joint := Vector2(entry.joint[0],entry.joint[1])
	var angle: float = float(pose.get(name,0.0))+float(entry.get("rotation",0.0))
	var parent: String = str(entry.parent)
	var t: Transform2D
	if parent.is_empty():
		t = Transform2D(angle,joint+Vector2(0,lift))
	else:
		var parent_t: Transform2D = joint_transform(parent,world)
		var parent_joint := Vector2(nodes[parent].joint[0],nodes[parent].joint[1])
		t = parent_t*Transform2D(angle,joint-parent_joint)
	world[name] = t
	return t

func _process(delta: float) -> void:
	clock += delta
	phase += delta*(8.5 if moving else 1.6)
	var s: float = sin(phase)
	if moving:
		pose = {
			"thigh_l":0.2*s,"thigh_r":-0.2*s,
			"shin_l":0.22*maxf(0.0,-s),"shin_r":0.22*maxf(0.0,s),
			"boot_l":-0.1*maxf(0.0,-s),"boot_r":-0.1*maxf(0.0,s),
			"arm_l":-0.17*s,"arm_r":-0.17*s,"fore_l":-0.1-0.08*absf(s),"fore_r":-0.1-0.08*absf(s),
			"chest":0.015*s,"head":0.02*sin(phase*0.5),
			"cloak":0.05+0.06*sin(phase*0.8),"satchel":0.12*s,"charm":0.2*s,
		}
		lift = -absf(cos(phase))*9.0
	else:
		pose = {
			"arm_l":0.03*sin(clock*1.3),"arm_r":-0.03*sin(clock*1.3),"fore_l":-0.04,"fore_r":-0.04,
			"head":0.02*sin(clock*0.7),"cloak":0.03*sin(clock*1.1),"charm":0.08*sin(clock*1.7),
		}
		lift = -2.0*(0.5+0.5*sin(clock*1.6))
	doll.scale = Vector2(doll_scale*facing,doll_scale)
	solve()

func _draw() -> void:
	var r: float = 420.0*doll_scale*0.17
	draw_set_transform(Vector2(0,-1),0,Vector2(1,0.3))
	draw_circle(Vector2.ZERO,r,Color(0.1,0.14,0.15,0.22))
	if is_player:
		draw_arc(Vector2.ZERO,r+5,0,TAU,32,Color(0.31,0.55,0.55,0.5),1.5,true)
	draw_set_transform(Vector2.ZERO)
