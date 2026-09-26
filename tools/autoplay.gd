extends Node
## Real-time smoke playthrough driven through the actual input map (not staged state).
## Run: godot --path . --audio-driver Dummy --resolution 1600x900 -- --autoplay
## Walks the harbor, launches a pilot contract, flies, scans, and fights with live input.
## Writes artifacts/autoplay_*.png. Never touches the real user save.
var main: Node
var clock: float = 0.0
var stage: String = "harbor"
var shots: Array = [["autoplay_1_harbor",1.6],["autoplay_2_survey",6.0],["autoplay_3_pursuit",14.0],["autoplay_4_battle",21.0],["autoplay_5_battle",26.0]]
var fired: bool = false

func _process(delta: float) -> void:
	clock += delta
	if not shots.is_empty() and clock>=float(shots[0][1]):
		var entry: Array = shots.pop_front()
		snap(str(entry[0]))
	if stage=="harbor":
		Input.action_press("right")
		Input.action_press("sprint")
		if clock>2.0:
			Input.action_release("right")
			Input.action_release("sprint")
			Game.accept("mechanic","pilot")
			Game.investigate()
			main.launch()
			stage = "space"
		return
	var world = main.world
	if not (world is BHSpace) or world.finished:
		if clock>4.0 and shots.is_empty():
			finish()
		return
	var goal: Vector2 = world.position_ship
	if world.phase=="survey":
		for marker in world.markers:
			if not marker.done:
				goal = marker.pos
				break
		if world.position_ship.distance_to(goal)<60:
			Input.action_press("interact")
		else:
			Input.action_release("interact")
	else:
		Input.action_release("interact")
		# Circle the quarry at a firing distance while suppressing its engine.
		var around: Vector2 = world.target_pos+Vector2.from_angle(clock*0.5+PI)*300
		goal = around
		aim_at(world.target_pos)
		if not fired and world.position_ship.distance_to(world.target_pos)<400:
			world.use_skill(1)
			fired = true
	steer(world.position_ship,goal)
	if shots.is_empty():
		finish()

func steer(from: Vector2, to: Vector2) -> void:
	var d: Vector2 = to-from
	for pair in [["right",d.x>25],["left",d.x<-25],["down",d.y>25],["up",d.y<-25]]:
		if pair[1]:
			Input.action_press(pair[0])
		else:
			Input.action_release(pair[0])

func aim_at(point: Vector2) -> void:
	get_viewport().warp_mouse(point)
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = point
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(press)

func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("res://artifacts/"+name+".png")
	var world = main.world
	var detail: String = ""
	if world is BHSpace:
		detail = " phase=%s hull=%d engine=%d hornets=%d mines=%d particles=%d" % [world.phase,world.hull,world.engine,world.hornets.size(),world.mines.size(),world.vfx.parts.size()]
	print("AUTOPLAY %s t=%.1f%s" % [name,clock,detail])

func finish() -> void:
	set_process(false)
	await get_tree().create_timer(0.3).timeout
	print("AUTOPLAY COMPLETE")
	get_tree().quit(0)
