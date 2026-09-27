extends Node3D
## Preview / smoke test for the 3D protagonist.
## Run:  godot --path <project> res://art/generated/protagonist_3d/godot/hero_preview.tscn
## With `-- --capture <dir>` it cycles outfits, hair, expressions and animations,
## saves PNG screenshots into <dir> and quits (used as the engine verification).

@onready var hero: HeroCustomizer = $Hero
@onready var cam: Camera3D = $Camera3D


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--capture")
	if i >= 0 and i + 1 < args.size():
		_capture(args[i + 1])


func _shot(dir: String, name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(name + ".png"))
	print("CAPTURED ", name)


func _capture(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	await get_tree().create_timer(0.5).timeout
	cam.position = Vector3(0.8, 1.25, 2.7)
	cam.look_at(Vector3(0, 0.92, 0))
	for o in 4:
		hero.set_look(o, [0, 1, 2, 5][o])
		hero.play("idle", 0.0)
		await get_tree().create_timer(0.3).timeout
		await _shot(dir, "outfit_%d" % o)
	hero.set_look(0, 0)
	cam.position = Vector3(0.25, 1.62, 0.95)
	cam.look_at(Vector3(0, 1.62, 0))
	for e in HeroCustomizer.EXPRESSIONS.size():
		hero.expression = e
		await _shot(dir, "expr_%d" % e)
	hero.expression = 0
	cam.position = Vector3(0.8, 1.25, 2.7)
	cam.look_at(Vector3(0, 0.92, 0))
	for anim in ["walk", "run", "attack", "shoot", "gadget", "guard", "hit", "death", "victory"]:
		hero.weapon = 2 if anim == "shoot" else 1
		hero.play(anim, 0.0)
		await get_tree().create_timer(0.45).timeout
		await _shot(dir, "anim_" + anim)
	print("CAPTURE_DONE")
	get_tree().quit()
