@tool
class_name HeroCustomizer
extends Node3D
## Attach to the root of an instanced `bountyhaven_hero.glb` scene.
## The GLB carries every outfit/hair variant; this node shows one of each,
## drives the face blend shapes and plays the baked actions.

const OUTFITS := ["Pilot", "Vest", "Mechanic", "Guild"]
const HAIRS := ["tousled", "windswept", "tied_low", "tidy_crop", "messy_long", "travel_braid"]
const EXPRESSIONS := ["neutral", "focused", "gentle_smile", "determined", "surprised", "battle_ready", "tired", "worried", "eyes_closed"]
const ACCESSORIES := ["Scarf", "Cloak", "Satchel", "Goggles", "Gloves"]
const WEAPONS := ["", "Baton", "Pistol"]
const LOOPING := ["idle", "walk", "run", "guard"]
const WATERCOLOR_SHADER := preload("watercolor_character.gdshader")
## Face decal textures, one per expression (face_<expression>.png).
const HEAD_TEXTURE_DIR := "../exports/textures"

@export_enum("Pilot", "Vest", "Mechanic", "Guild") var outfit := 0:
	set(v):
		outfit = v
		_apply()
@export_enum("tousled", "windswept", "tied_low", "tidy_crop", "messy_long", "travel_braid") var hair := 0:
	set(v):
		hair = v
		_apply()
@export_enum("neutral", "focused", "gentle_smile", "determined", "surprised", "battle_ready", "tired", "worried", "eyes_closed") var expression := 0:
	set(v):
		expression = v
		_apply()
@export_enum("none", "baton", "pistol") var weapon := 1:
	set(v):
		weapon = v
		_apply()
## Accessory toggles (signature scarf/cloak on by default).
@export var accessories := {"Scarf": true, "Cloak": true, "Satchel": true, "Goggles": true, "Gloves": true}:
	set(v):
		accessories = v
		_apply()
## Swap the GLB's standard materials for the ink & watercolor toon shader.
@export var use_watercolor_shader := true

var _anim: AnimationPlayer


func _ready() -> void:
	_anim = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim:
		for name in LOOPING:
			if _anim.has_animation(name):
				_anim.get_animation(name).loop_mode = Animation.LOOP_LINEAR
	if use_watercolor_shader and not Engine.is_editor_hint():
		_convert_materials(self)
	_apply()
	play("idle")


func play(anim_name: String, blend := 0.15) -> void:
	if _anim and _anim.has_animation(anim_name):
		_anim.play(anim_name, blend)


func set_look(p_outfit: int, p_hair: int, p_expression := 0) -> void:
	outfit = p_outfit
	hair = p_hair
	expression = p_expression


func _apply() -> void:
	if not is_inside_tree():
		return
	for mi in find_children("*", "MeshInstance3D", true, false):
		var n: String = mi.name
		if n.begins_with("Outfit_"):
			mi.visible = n.begins_with("Outfit_%s_" % OUTFITS[outfit])
		elif n.begins_with("Hair_"):
			mi.visible = n == "Hair_%s" % HAIRS[hair]
		elif n.begins_with("Weapon_"):
			mi.visible = weapon > 0 and n == "Weapon_%s" % WEAPONS[weapon]
		elif n.begins_with("Acc_"):
			for acc in ACCESSORIES:
				if n.begins_with("Acc_" + acc.trim_suffix("s")):
					mi.visible = accessories.get(acc, true)
		elif n == "FaceDecal":
			_set_expression(mi)


func _set_expression(decal: MeshInstance3D) -> void:
	# ZZZ-style face: eyes/brows/mouth live on a transparent decal over the flat-skin head;
	# each expression is its own decal texture (face_<expression>.png)
	var dir: String = (get_script() as Script).resource_path.get_base_dir().path_join(HEAD_TEXTURE_DIR)
	var path := dir.path_join("face_%s.png" % EXPRESSIONS[expression]).simplify_path()
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	var sm := decal.get_surface_override_material(0) as StandardMaterial3D
	if sm == null:
		sm = (decal.mesh.surface_get_material(0) as StandardMaterial3D).duplicate()
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		decal.set_surface_override_material(0, sm)
	sm.albedo_texture = tex


func _convert_materials(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var src := mesh.surface_get_material(s) as StandardMaterial3D
			if src == null or src.resource_name in ["M_outline", "M_face_decal"]:
				continue  # keep the inverted-hull outline and the transparent face decal as-is
			var m := ShaderMaterial.new()
			m.shader = WATERCOLOR_SHADER
			m.set_shader_parameter("albedo", src.albedo_color)
			if src.resource_name.begins_with("M_paint_"):
				m.set_shader_parameter("shadow_tint", Color(0.80, 0.85, 0.96))  # painted: shading is in the texture
			if src.albedo_texture:
				m.set_shader_parameter("paper_tex", src.albedo_texture)
			else:
				m.set_shader_parameter("paper_strength", 0.0)
			mi.set_surface_override_material(s, m)
