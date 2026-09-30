extends Node3D
## BountyHaven WW-style protagonist preview + engine verification.
## godot --path <repo> res://art/generated/protagonist_ww3d/godot/hero_ww_preview.tscn -- --capture <dir>
## Rebuilds every imported surface as the toon ShaderMaterial (+ outline pass) from exports/palette.json,
## plays the GLB animations and drives the shader VFX (sigil, slash arcs, sparks).

const BASE := "res://art/generated/protagonist_ww3d/"
const TOON := preload(BASE + "godot/ww_toon.gdshader")
const OUTLINE := preload(BASE + "godot/ww_outline.gdshader")
const SIGIL := preload(BASE + "godot/ww_sigil.gdshader")
const SLASH := preload(BASE + "godot/ww_slash.gdshader")

@onready var cam: Camera3D = $Camera3D
var hero: Node3D
var anim: AnimationPlayer
var palette := {}
var vfx_root := Node3D.new()


func _ready() -> void:
	palette = JSON.parse_string(FileAccess.get_file_as_string(BASE + "exports/palette.json"))
	hero = (load(BASE + "exports/bountyhaven_hero_ww.glb") as PackedScene).instantiate()
	add_child(hero)
	_apply_toon(hero)
	anim = hero.find_child("AnimationPlayer", true, false)
	_build_vfx()
	add_child(vfx_root)
	var args := OS.get_cmdline_user_args()
	var i := args.find("--capture")
	if i >= 0 and i + 1 < args.size():
		_capture(args[i + 1])
	elif anim:
		anim.play("Slash")


func _c8(a: Array) -> Color:
	if a.size() < 3:
		return Color.WHITE
	var m := 255.0 if (a[0] > 1.0 or a[1] > 1.0 or a[2] > 1.0) else 1.0
	return Color(a[0] / m, a[1] / m, a[2] / m)


func _material(name: String) -> Material:
	var key := name
	if not palette.has(key):
		for k in palette.keys():
			if name.begins_with(k):
				key = k
	if not palette.has(key):
		return null
	var p: Dictionary = palette[key]
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("lit_color", _c8(p["lit"]))
	m.set_shader_parameter("shade_color", _c8(p["shade"]))
	m.set_shader_parameter("rim", float(p["rim"]))
	if key == "Face":
		m.set_shader_parameter("ramp", Vector2(0.22, 0.34))
	if p["tex"] != "":
		m.set_shader_parameter("detail_tex", load(BASE + "exports/textures/" + p["tex"]))
		m.set_shader_parameter("tex_mix", float(p["tex_mix"]))
	if p["emit"].size() == 4:
		m.set_shader_parameter("emit_color", _c8(p["emit"].slice(0, 3)))
		m.set_shader_parameter("emit_strength", float(p["emit"][3]) * 0.35)
	if key.begins_with("Cloak") or key.begins_with("Scarf"):
		m.set_shader_parameter("double_sided", 1.0)
		m.render_priority = 0
	var ol := ShaderMaterial.new()
	ol.shader = OUTLINE
	var oc: Array = p["outline"]
	ol.set_shader_parameter("outline_color", Color(pow(oc[0], 1.0 / 2.2), pow(oc[1], 1.0 / 2.2), pow(oc[2], 1.0 / 2.2)))
	ol.set_shader_parameter("thickness", 0.0045 if key.begins_with("Hair") else 0.0032)
	if p["emit"].size() != 4:
		m.next_pass = ol
	return m


func _apply_toon(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			var mname := src.resource_name if src else ""
			var m := _material(mname)
			if m:
				mi.set_surface_override_material(s, m)
		if mi.name.begins_with("Cloak"):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_apply_toon(c)


func _arc_mesh(radius: float, width: float, a0: float, a1: float, segs := 64) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segs:
		for k in [[i, 0], [i + 1, 0], [i + 1, 1], [i, 0], [i + 1, 1], [i, 1]]:
			var t := float(k[0]) / segs
			var a := lerpf(a0, a1, t)
			var w := width * pow(sin(PI * t), 0.6)
			var r := radius + (float(k[1]) - 0.5) * w
			st.set_uv(Vector2(t, k[1]))
			st.add_vertex(Vector3(cos(a) * r, 0.0, sin(a) * r))
	return st.commit()


func _build_vfx() -> void:
	# ground sigil (Codex sigil texture)
	var sig := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2.6, 2.6)
	sig.mesh = pm
	var sm := ShaderMaterial.new()
	sm.shader = SIGIL
	sm.set_shader_parameter("sigil", load(BASE + "concepts/05_ww_sigil.png"))
	sm.set_shader_parameter("intensity", 1.2)
	sig.material_override = sm
	sig.position.y = 0.01
	vfx_root.add_child(sig)
	# slash arcs
	for spec in [[1.0, 0.26, Vector3(-12, 18, 78), Vector3(0, 1.2, 0), 0.0, Color(1, 0.8, 0.45)],
			[0.85, 0.16, Vector3(8, 0, 12), Vector3(0, 0.35, 0), 0.45, Color(1, 0.45, 0.2)]]:
		var arc := MeshInstance3D.new()
		arc.mesh = _arc_mesh(spec[0], spec[1], -0.2, 3.9)
		var am := ShaderMaterial.new()
		am.shader = SLASH
		am.set_shader_parameter("phase", spec[4])
		am.set_shader_parameter("core", spec[5])
		arc.material_override = am
		arc.position = spec[3]
		arc.rotation_degrees = spec[2]
		vfx_root.add_child(arc)
	# sparks
	var p := GPUParticles3D.new()
	p.amount = 180
	p.lifetime = 1.2
	p.preprocess = 1.0
	var ppm := ParticleProcessMaterial.new()
	ppm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	ppm.emission_ring_radius = 0.9
	ppm.emission_ring_inner_radius = 0.2
	ppm.emission_ring_height = 0.1
	ppm.emission_ring_axis = Vector3.UP
	ppm.direction = Vector3(0, 1, 0)
	ppm.spread = 60.0
	ppm.initial_velocity_min = 1.0
	ppm.initial_velocity_max = 3.2
	ppm.gravity = Vector3(0, -2.5, 0)
	ppm.scale_min = 0.5
	ppm.scale_max = 1.2
	p.process_material = ppm
	var q := QuadMesh.new()
	q.size = Vector2(0.008, 0.05)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	ppm.particle_flag_align_y = true
	qm.albedo_color = Color(1.0, 0.7, 0.35)
	q.material = qm
	p.draw_pass_1 = q
	vfx_root.add_child(p)


func _shot(dir: String, name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(name + ".png"))
	print("CAPTURED ", name)


func _capture(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	vfx_root.visible = false
	if anim:
		anim.play("Idle")
	await get_tree().create_timer(0.6).timeout
	for v in [["front", Vector3(0, 0.95, 4.2)], ["q34", Vector3(2.7, 0.95, 3.2)], ["side", Vector3(4.2, 0.95, 0)],
			["back", Vector3(0, 0.95, -4.2)]]:
		cam.position = v[1]
		cam.look_at(Vector3(0, 0.9, 0))
		await _shot(dir, "godot_" + v[0])
	cam.position = Vector3(0.3, 1.63, 1.1)
	cam.look_at(Vector3(0, 1.62, 0))
	await _shot(dir, "godot_face")
	vfx_root.visible = true
	if anim:
		anim.play("Slash")
		anim.seek(0.6, true)
		anim.pause()
	cam.position = Vector3(1.9, 0.85, 3.9)
	cam.look_at(Vector3(-0.15, 0.95, 0))
	await get_tree().create_timer(0.7).timeout
	await _shot(dir, "godot_vfx")
	print("ANIMS ", anim.get_animation_list() if anim else [])
	print("CAPTURE_DONE")
	get_tree().quit()
