class_name BHPuppet
extends BHWalker
## A skeletal cutout character played from a BHRig file. It picks one of eight directions
## from its own movement (five drawn views, the left-facing three mirrored), plays idle,
## walk or run at a rate matched to its ground speed and cross-fades between clips.
## Appearance (hair, cloth colour, gear) comes from the protagonist look in the save.
const DEFAULT_RIG: String = "res://assets/characters/captain/captain.rig.json"
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
static var cloth_shader: Shader
var rig_path: String = DEFAULT_RIG
var rig: Dictionary = {}
## Rig pixels to world pixels. 0.16 makes the captain about 105 px tall in the harbor.
var doll_scale: float = 0.16
var look: Dictionary = {}
## Screen direction the character faces; set from movement unless auto_direction is off.
var direction: Vector2 = Vector2.DOWN
var auto_direction: bool = true
var view: String = "front"
var mirrored: bool = false
var clip: String = "idle"
var clip_time: float = 0.0
var from_clip: String = ""
var from_time: float = 0.0
var fade: float = 1.0
var fade_length: float = 0.18
var speed: float = 0.0
## Editor hook: when set, this pose is shown instead of the playing clip.
var pose_override: Variant = null
var last_position: Vector2
var doll: Node2D
var sprites: Dictionary = {}
var current_view: String = ""
var cloth_material: ShaderMaterial

func _ready() -> void:
	if cloth_shader==null:
		cloth_shader = Shader.new()
		cloth_shader.code = CLOTH_SHADER
	cloth_material = ShaderMaterial.new()
	cloth_material.shader = cloth_shader
	if rig.is_empty():
		rig = BHRig.load_file(rig_path)
	doll = Node2D.new()
	add_child(doll)
	last_position = position
	if look.is_empty():
		look = Game.s.get("look",BHAppearance.defaults()) if is_player else BHAppearance.defaults()
	rebuild()
	queue_redraw()

## Recreate the sprites after the rig's slots change (the editor calls this).
func rebuild() -> void:
	for child in doll.get_children():
		doll.remove_child(child)
		child.queue_free()
	sprites.clear()
	current_view = ""
	for slot in rig.get("slots",[]):
		var sprite = Sprite2D.new()
		sprite.centered = false
		sprite.name = str(slot.name)
		if bool(slot.get("dye",false)):
			sprite.material = cloth_material
		doll.add_child(sprite)
		sprites[slot.name] = sprite
	apply_look(look)

## Swap the head, toggle gear and dye the cloth. Safe to call at any time.
func apply_look(new_look: Dictionary) -> void:
	look = new_look.duplicate()
	if cloth_material==null:
		return
	var cloth: int = clampi(int(look.get("cloth",0)),0,BHAppearance.CLOTH.size()-1)
	cloth_material.set_shader_parameter("target",Color(BHAppearance.CLOTH[cloth][1]))
	cloth_material.set_shader_parameter("amount",0.0 if cloth==0 else 1.0)
	refresh()

## Attachment a slot shows before clip swaps: the rig default, the chosen hair, or nothing
## for gear that is switched off.
func chosen_attachment(slot: Dictionary) -> String:
	var custom: Dictionary = rig.get("customize",{})
	if slot.name==custom.get("hair_slot",""):
		var hair: String = str(look.get("hair","base"))
		return str(custom.get("base_head",slot.get("attachment",""))) if hair=="base" else hair
	if slot.name in custom.get("gear_slots",[]) and not bool(look.get(slot.name,true)):
		return ""
	return str(slot.get("attachment",""))

func play(name: String, blend_time: float = 0.18) -> void:
	if name==clip or not rig.get("animations",{}).has(name):
		return
	from_clip = clip
	from_time = clip_time
	clip = name
	clip_time = 0.0
	fade = 0.0 if blend_time>0.0 else 1.0
	fade_length = maxf(blend_time,0.001)

func set_direction(value: Vector2) -> void:
	if value.length_squared()>0.0001:
		direction = value.normalized()

func _physics_process(delta: float) -> void:
	if not auto_direction or delta<=0.0:
		return
	var velocity: Vector2 = (position-last_position)/delta
	last_position = position
	speed = lerpf(speed,velocity.length(),0.35)
	if moving and velocity.length()>8.0:
		set_direction(velocity)

func _process(delta: float) -> void:
	var anims: Dictionary = rig.get("animations",{})
	var wanted: String = "idle"
	if moving:
		wanted = "run" if speed>212.0 and anims.has("run") else "walk"
	if auto_direction:
		play(wanted)
	var rate: float = 1.0
	var ref: float = float(anims.get(clip,{}).get("ref_speed",0.0))
	if moving and ref>0.0 and auto_direction:
		rate = clampf(speed/ref,0.6,1.5)
	clip_time += delta*rate
	from_time += delta*rate
	fade = minf(1.0,fade+delta/fade_length)
	refresh()

## Pose the sprites for the current direction, clip and time.
func refresh() -> void:
	if doll==null or rig.is_empty():
		return
	var pick: Array = BHRig.view_for(direction)
	view = BHRig.effective_view(rig,str(pick[0]))
	mirrored = bool(pick[1])
	var offsets: Dictionary
	var swaps: Dictionary = {}
	if pose_override is Dictionary:
		offsets = pose_override
	else:
		offsets = BHRig.pose(rig,clip,view,clip_time)
		if fade<1.0 and not from_clip.is_empty():
			offsets = BHRig.blend(BHRig.pose(rig,from_clip,view,from_time),offsets,smoothstep(0.0,1.0,fade))
		swaps = BHRig.slot_keys(rig,clip,view,clip_time)
	var world: Dictionary = BHRig.solve(rig,view,offsets)
	if view!=current_view:
		current_view = view
		var index: int = 0
		for slot in BHRig.draw_order(rig,view):
			if sprites.has(slot.name):
				doll.move_child(sprites[slot.name],index)
				index += 1
	for slot in rig.get("slots",[]):
		var sprite: Sprite2D = sprites.get(slot.name)
		if sprite==null:
			continue
		var name: String = str(swaps.get(slot.name,chosen_attachment(slot)))
		var att: Dictionary = {} if name.is_empty() else BHRig.attachment(rig,slot.name,name,view)
		if att.is_empty() and not name.is_empty() and slot.name==rig.get("customize",{}).get("hair_slot",""):
			# A hairstyle not yet drawn for this view falls back to the base head.
			att = BHRig.attachment(rig,slot.name,str(rig.customize.get("base_head","")),view)
		var tex: Texture2D = null if att.is_empty() else BHRig.texture(rig,str(att.image))
		sprite.visible = tex!=null
		if tex==null:
			continue
		sprite.texture = tex
		var region: Variant = att.get("region",null)
		sprite.region_enabled = region is Array
		if region is Array:
			sprite.region_rect = Rect2(region[0],region[1],region[2],region[3])
		sprite.transform = world.get(slot.bone,Transform2D.IDENTITY)*BHRig.attachment_transform(att)
	doll.scale = Vector2(doll_scale*(-1.0 if mirrored else 1.0),doll_scale)

func _draw() -> void:
	var r: float = 420.0*doll_scale*0.17
	draw_set_transform(Vector2(0,-1),0,Vector2(1,0.3))
	draw_circle(Vector2.ZERO,r,Color(0.1,0.14,0.15,0.22))
	if is_player:
		draw_arc(Vector2.ZERO,r+5,0,TAU,32,Color(0.31,0.55,0.55,0.5),1.5,true)
	draw_set_transform(Vector2.ZERO)
