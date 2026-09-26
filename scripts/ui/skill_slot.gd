class_name BHSkillSlot
extends Control
## One combat action slot: illustrated module icon, hotkey badge, energy cost tag,
## radial cooldown sweep with seconds, ready pulse, active glow and activation flash.
const Icons = preload("res://scripts/ui/skill_icons.gd")
signal activated
var module_id: String = "boost"
var hotkey: int = 1
var cooldown: float = 0.0
var cooldown_max: float = 1.0
var energy_cost: float = 0.0
var energy_ok: bool = true
var active_time: float = 0.0
var locked: bool = false
var clock: float = 0.0
var flash: float = 0.0
var hover: bool = false
var icon: Texture2D
var font: Font

func setup(id: String, key: int) -> void:
	module_id = id
	hotkey = key
	var data: Dictionary = BHCatalog.MODULES[id]
	cooldown_max = float(data.cooldown)
	energy_cost = float(data.energy)
	icon = Icons.texture(id,128)
	tooltip_text = "%s\n%s\n에너지 %d · 발열 %d · 재사용 %.1f초" % [data.name,data.text,data.energy,data.heat,data.cooldown]

func _ready() -> void:
	custom_minimum_size = Vector2(88,88)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Noto Sans CJK KR","Malgun Gothic","Apple SD Gothic Neo","NanumGothic"])
	font.font_weight = 700
	mouse_entered.connect(func():hover=true)
	mouse_exited.connect(func():hover=false)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		activated.emit()
		accept_event()

func update_state(cd: float, energy: float, active: float, is_locked: bool) -> void:
	if cd>cooldown+0.5:
		flash = 1.0
	cooldown = cd
	energy_ok = energy>=energy_cost
	active_time = active
	locked = is_locked

func _process(delta: float) -> void:
	clock += delta
	flash = maxf(0.0,flash-delta*3.0)
	queue_redraw()

func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO,size)
	var accent: Color = Icons.ACCENT.get(module_id,Color.WHITE)
	var ready: bool = cooldown<=0.0 and energy_ok and not locked
	var center: Vector2 = r.get_center()
	# Soft drop shadow and accent halo behind the icon.
	draw_rect(r.grow(2).grow_individual(0,0,0,3),Color(0,0,0,0.35))
	if active_time>0.0:
		for i in range(4):
			draw_rect(r.grow(3+i*3),Color(accent,0.22-i*0.05),false,3.0)
	elif ready:
		var pulse: float = 0.5+0.5*sin(clock*2.4)
		draw_rect(r.grow(2),Color(accent,0.25+0.25*pulse),false,2.0)
	var inset: Rect2 = r.grow(-2)
	draw_texture_rect(icon,inset,false,Color(1,1,1,1) if (energy_ok and not locked) else Color(0.55,0.55,0.58,1))
	if cooldown>0.0:
		# Clockwise cooldown sweep: the remaining fraction stays shaded.
		var remain: float = clampf(cooldown/cooldown_max,0.0,1.0)
		var points = PackedVector2Array([center])
		var steps: int = 40
		var start: float = -PI*0.5
		for i in range(steps+1):
			var a: float = start+TAU*(1.0-remain)+TAU*remain*float(i)/steps
			var dir: Vector2 = Vector2.from_angle(a)
			# Project the ray onto the square so the shade fills to the corners.
			var scale_to_edge: float = (inset.size.x*0.5)/maxf(absf(dir.x),absf(dir.y))
			points.append(center+dir*scale_to_edge)
		draw_colored_polygon(points,Color(0.03,0.07,0.1,0.68))
		var edge_angle: float = start+TAU*(1.0-remain)
		draw_line(center,center+Vector2.from_angle(edge_angle)*inset.size.x*0.7,Color(accent,0.9),2.0,true)
		var text: String = ("%.1f" % cooldown) if cooldown<3.0 else str(ceili(cooldown))
		draw_string_outline(font,Vector2(0,center.y+10),text,HORIZONTAL_ALIGNMENT_CENTER,size.x,26,6,Color(0.02,0.05,0.07,0.9))
		draw_string(font,Vector2(0,center.y+10),text,HORIZONTAL_ALIGNMENT_CENTER,size.x,26,Color("f6f1e2"))
	if flash>0.0:
		draw_rect(inset,Color(accent,flash*0.45))
	if hover:
		draw_rect(inset,Color(1,1,1,0.08))
	# Hotkey badge (top-left) and energy cost tag (bottom-right).
	var badge: Vector2 = Vector2(4,4)
	draw_circle(badge+Vector2(11,11),12,Color("0f1d25"))
	draw_arc(badge+Vector2(11,11),12,0,TAU,24,Color("d9b77c"),2.0,true)
	draw_string(font,badge+Vector2(0,17),str(hotkey),HORIZONTAL_ALIGNMENT_CENTER,22,15,Color("f5ead0"))
	var tag: String = str(int(energy_cost))
	var tag_w: float = font.get_string_size(tag,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x+18
	var tag_rect: Rect2 = Rect2(Vector2(size.x-tag_w-4,size.y-21),Vector2(tag_w,17))
	draw_rect(tag_rect,Color("0f1d25") if energy_ok else Color("6a2a22"))
	draw_rect(tag_rect,Color("7fb7c9") if energy_ok else Color("f08a6a"),false,1.2)
	draw_colored_polygon(PackedVector2Array([tag_rect.position+Vector2(5,3),tag_rect.position+Vector2(10,3),tag_rect.position+Vector2(7,8),tag_rect.position+Vector2(11,8),tag_rect.position+Vector2(5,15),tag_rect.position+Vector2(7,9),tag_rect.position+Vector2(4,9)]),Color("9fe0ef") if energy_ok else Color("ffb49a"))
	draw_string(font,tag_rect.position+Vector2(13,13),tag,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("e8f4f6"))
