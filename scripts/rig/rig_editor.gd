class_name BHRigEditor
extends Control
## BountyHaven rig editor: a Spine-style cutout animation tool that edits BHRig files.
## Run it with `godot --path . -- --rig-editor` or open scenes/rig_editor.tscn and press F6.
##
## Modes
##   뼈 셋업    drag a joint to move the bone, Shift+drag (or right-drag) to rotate it.
##   파츠 셋업  drag a part to move it on its bone, Shift+drag to rotate it.
##   애니메이션 drag to rotate a bone, Shift+drag to move it; every change sets a key.
## Views are edited one at a time; a new view starts as a copy of the first drawn view and
## its images are replaced from assets/generated/<character>/views/<view>/<attachment>.png.
const UI = preload("res://scripts/ui/palette.gd")
const RIG_DIR: String = "res://assets/characters/"
const FRAME: float = 1.0/30.0
const VIEW_SECTOR: Dictionary = {"front":2,"front34":1,"side":0,"back34":7,"back":6}
const BG = Color("20343d")
const PANEL = Color("ece8da")
const HILITE = Color("e0873f")

var rig_path: String = BHPuppet.DEFAULT_RIG
var rig: Dictionary = {}
var mode: String = "bone"
var view: String = "front"
var mirror_preview: bool = false
var ring_preview: bool = false
var clip: String = "walk"
var scope_shared: bool = true
var time: float = 0.0
var playing: bool = false
var selected_bone: String = "chest"
var selected_slot: String = ""
var zoom: float = 0.85
var origin: Vector2 = Vector2(500,612)
var undo_stack: Array = []
var redo_stack: Array = []
var last_change_tag: String = ""
var last_change_time: float = -10.0
var dirty: bool = false
var drag: Dictionary = {}
var images: Array = []

var canvas: Control
var puppet: BHPuppet
var overlay: Control
var ring: Node2D
var timeline: Control
var bone_tree: Tree
var slot_list: ItemList
var inspector: VBoxContainer
var fields: Dictionary = {}
var view_buttons: Dictionary = {}
var mode_buttons: Dictionary = {}
var clip_select: OptionButton
var duration_spin: SpinBox
var loop_check: CheckBox
var speed_spin: SpinBox
var scope_button: Button
var play_button: Button
var time_label: Label
var status_label: Label
var file_label: Label
var name_edit: LineEdit

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = editor_theme()
	rig = BHRig.load_file(rig_path,true).duplicate(true)
	view = BHRig.first_view(rig)
	if not rig.get("animations",{}).has(clip):
		clip = str(rig.get("animations",{}).keys().front()) if not rig.get("animations",{}).is_empty() else ""
	scan_images()
	build_layout()
	refresh_all()
	status("리그를 열었습니다. 뼈를 클릭해 고르고 드래그해 움직이세요. Ctrl+S 저장, Ctrl+Z 되돌리기.")

# ---------------------------------------------------------------- layout

func editor_theme() -> Theme:
	var value: Theme = UI.theme()
	value.default_font_size = 15
	var tight := func(fill: Color, edge: Color) -> StyleBoxFlat:
		var box: StyleBoxFlat = UI.style(fill,edge,3)
		box.content_margin_left = 8
		box.content_margin_right = 8
		box.content_margin_top = 4
		box.content_margin_bottom = 4
		return box
	value.set_stylebox("normal","Button",tight.call(Color("e9e6d8"),Color("b9beb0")))
	value.set_stylebox("hover","Button",tight.call(Color("d7e0d4"),Color("6c918a")))
	value.set_stylebox("pressed","Button",tight.call(Color("456f71"),Color("456f71")))
	value.set_stylebox("disabled","Button",tight.call(Color("e3e3d8"),Color("ccd0c4")))
	value.set_constant("separation","VBoxContainer",6)
	value.set_constant("separation","HBoxContainer",6)
	value.set_color("font_color","CheckBox",UI.INK)
	for kind in ["Tree","ItemList"]:
		value.set_stylebox("panel",kind,tight.call(Color("f7f4ea"),Color("c6ccbf")))
		value.set_stylebox("focus",kind,tight.call(Color(0,0,0,0),Color("c6ccbf")))
		value.set_stylebox("selected",kind,tight.call(Color("d9b48f"),Color("d9b48f")))
		value.set_stylebox("selected_focus",kind,tight.call(Color("e0873f"),Color("e0873f")))
		value.set_color("font_color",kind,UI.INK)
		value.set_color("font_selected_color",kind,Color("1d2b30"))
		value.set_color("font_hovered_color",kind,Color("1d2b30"))
	value.set_color("guide_color","Tree",Color(0,0,0,0.06))
	value.set_color("relationship_line_color","Tree",Color("b9beb0"))
	return value

func panel(rect: Rect2, fill: Color = PANEL) -> PanelContainer:
	var box = PanelContainer.new()
	box.position = rect.position
	box.size = rect.size
	var style: StyleBoxFlat = UI.style(fill,Color("bcc6b7"),0)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	box.add_theme_stylebox_override("panel",style)
	add_child(box)
	return box

func button(text: String, callback: Callable, tip: String = "") -> Button:
	var b = Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(callback)
	return b

func label(text: String, size: int = 15, color: Color = UI.INK) -> Label:
	return UI.label(text,size,color)

func hint(text: String) -> Label:
	var l: Label = UI.label(text,12,UI.MUTED,true)
	l.custom_minimum_size.x = 250
	return l

func build_layout() -> void:
	var bg = ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# Canvas first so the panels draw over it.
	canvas = Control.new()
	canvas.position = Vector2(290,52)
	canvas.size = Vector2(1020,650)
	canvas.clip_contents = true
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.gui_input.connect(on_canvas_input)
	canvas.draw.connect(draw_canvas_back)
	add_child(canvas)
	puppet = BHPuppet.new()
	puppet.rig = rig
	puppet.auto_direction = false
	puppet.set_process(false)
	puppet.look = {"hair":"base","cloth":0,"scarf":true,"cloak":true,"goggles":true,"cap":false,"satchel":true,"charm":true}
	canvas.add_child(puppet)
	ring = Node2D.new()
	canvas.add_child(ring)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(draw_overlay)
	canvas.add_child(overlay)

	var top = panel(Rect2(0,0,1600,52))
	var bar = HBoxContainer.new()
	top.add_child(bar)
	bar.add_child(label("리그 에디터",19))
	file_label = label("",13,UI.MUTED)
	bar.add_child(file_label)
	bar.add_child(button("저장",save,"Ctrl+S"))
	bar.add_child(button("다시 읽기",reload_rig,"저장하지 않은 변경은 사라집니다"))
	bar.add_child(VSeparator.new())
	for entry in [["bone","뼈 셋업"],["part","파츠 셋업"],["anim","애니메이션"]]:
		var id: String = entry[0]
		var b = button(entry[1],func():set_mode(id))
		b.toggle_mode = true
		mode_buttons[id] = b
		bar.add_child(b)
	bar.add_child(VSeparator.new())
	for v in BHRig.VIEWS:
		var id: String = v
		var b = button(BHRig.VIEW_NAMES[v],func():set_view(id))
		b.toggle_mode = true
		view_buttons[v] = b
		bar.add_child(b)
	bar.add_child(VSeparator.new())
	var mirror = CheckBox.new()
	mirror.text = "좌우 반전"
	mirror.focus_mode = Control.FOCUS_NONE
	mirror.toggled.connect(func(on):mirror_preview=on;refresh_canvas())
	bar.add_child(mirror)
	var ring_check = CheckBox.new()
	ring_check.text = "8방향 미리보기"
	ring_check.focus_mode = Control.FOCUS_NONE
	ring_check.toggled.connect(func(on):set_ring(on))
	bar.add_child(ring_check)

	var left = panel(Rect2(0,52,290,650))
	var left_stack = VBoxContainer.new()
	left.add_child(left_stack)
	left_stack.add_child(label("뼈 (클릭해서 선택)",15,UI.MUTED))
	bone_tree = Tree.new()
	bone_tree.custom_minimum_size = Vector2(0,300)
	bone_tree.hide_root = true
	bone_tree.item_selected.connect(func():
		var item: TreeItem = bone_tree.get_selected()
		if item!=null:
			select_bone(item.get_text(0),false))
	left_stack.add_child(bone_tree)
	left_stack.add_child(label("슬롯 · 그리기 순서 (위가 뒤)",15,UI.MUTED))
	slot_list = ItemList.new()
	slot_list.custom_minimum_size = Vector2(0,210)
	slot_list.item_selected.connect(func(index):select_slot(slot_list.get_item_metadata(index),false))
	left_stack.add_child(slot_list)
	var order_row = HBoxContainer.new()
	left_stack.add_child(order_row)
	order_row.add_child(button("앞으로",func():move_slot(1),"이 방향에서 선택한 슬롯을 한 칸 앞으로 그립니다"))
	order_row.add_child(button("뒤로",func():move_slot(-1),"이 방향에서 선택한 슬롯을 한 칸 뒤로 그립니다"))

	var right = panel(Rect2(1310,52,290,650))
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	inspector = VBoxContainer.new()
	inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inspector)

	var bottom = panel(Rect2(0,702,1600,198))
	var bottom_stack = VBoxContainer.new()
	bottom.add_child(bottom_stack)
	var anim_row = HBoxContainer.new()
	bottom_stack.add_child(anim_row)
	anim_row.add_child(label("동작"))
	clip_select = OptionButton.new()
	clip_select.focus_mode = Control.FOCUS_NONE
	clip_select.custom_minimum_size.x = 120
	clip_select.item_selected.connect(func(index):set_clip(clip_select.get_item_text(index)))
	anim_row.add_child(clip_select)
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "새 이름"
	name_edit.custom_minimum_size.x = 110
	anim_row.add_child(name_edit)
	anim_row.add_child(button("새 동작",new_clip,"이름 칸의 이름으로 빈 동작을 만듭니다"))
	anim_row.add_child(button("복제",duplicate_clip,"현재 동작을 이름 칸의 이름으로 복제합니다"))
	anim_row.add_child(button("삭제",delete_clip))
	anim_row.add_child(label("길이(초)"))
	duration_spin = spin(0.1,20.0,0.01,func(v):change_clip("duration",v))
	anim_row.add_child(duration_spin)
	loop_check = CheckBox.new()
	loop_check.text = "반복"
	loop_check.focus_mode = Control.FOCUS_NONE
	loop_check.toggled.connect(func(on):change_clip("loop",on))
	anim_row.add_child(loop_check)
	anim_row.add_child(label("기준 속도"))
	speed_spin = spin(0.0,1000.0,1.0,func(v):change_clip("ref_speed",v))
	speed_spin.tooltip_text = "게임에서 이 속도(px/초)로 움직일 때 1배속으로 재생됩니다. 0이면 속도와 무관."
	anim_row.add_child(speed_spin)
	anim_row.add_child(VSeparator.new())
	scope_button = button("",toggle_scope,"공유 트랙은 모든 방향에 쓰입니다. 방향 전용 트랙은 이 방향에서 공유 트랙을 대신합니다.")
	anim_row.add_child(scope_button)
	var key_row = HBoxContainer.new()
	bottom_stack.add_child(key_row)
	play_button = button("재생",toggle_play,"Space")
	key_row.add_child(play_button)
	key_row.add_child(button("◀",func():step(-1),"한 프레임 뒤 (←)"))
	key_row.add_child(button("▶",func():step(1),"한 프레임 앞 (→)"))
	time_label = label("",15)
	time_label.custom_minimum_size.x = 120
	key_row.add_child(time_label)
	key_row.add_child(button("키 설정",key_selected,"K: 선택한 뼈의 지금 포즈를 키로 저장"))
	key_row.add_child(button("모든 뼈 키",key_all,"모든 뼈의 지금 포즈를 키로 저장"))
	key_row.add_child(button("키 삭제",delete_key,"Delete: 선택한 뼈의 이 시간 키 삭제"))
	key_row.add_child(button("이전 키",func():jump_key(-1)))
	key_row.add_child(button("다음 키",func():jump_key(1)))
	key_row.add_child(button("방향 전용 트랙 비우기",clear_view_tracks,"이 방향 전용 트랙을 지우고 공유 트랙으로 돌아갑니다"))
	timeline = Timeline.new()
	timeline.editor = self
	timeline.custom_minimum_size = Vector2(0,62)
	bottom_stack.add_child(timeline)
	status_label = label("",13,UI.MUTED)
	bottom_stack.add_child(status_label)

func spin(lo: float, hi: float, step_value: float, callback: Callable) -> SpinBox:
	var s = SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step_value
	s.allow_greater = true
	s.allow_lesser = true
	s.custom_minimum_size.x = 92
	s.value_changed.connect(callback)
	return s

# ---------------------------------------------------------------- state helpers

func status(text: String) -> void:
	if status_label!=null:
		status_label.text = text

func snapshot(tag: String = "") -> void:
	var now: float = Time.get_ticks_msec()/1000.0
	if not tag.is_empty() and tag==last_change_tag and now-last_change_time<1.0:
		last_change_time = now
		return
	last_change_tag = tag
	last_change_time = now
	undo_stack.append(rig.duplicate(true))
	if undo_stack.size()>80:
		undo_stack.pop_front()
	redo_stack.clear()
	dirty = true

func undo() -> void:
	if undo_stack.is_empty():
		return
	redo_stack.append(rig.duplicate(true))
	replace_rig(undo_stack.pop_back())
	status("되돌렸습니다.")

func redo() -> void:
	if redo_stack.is_empty():
		return
	undo_stack.append(rig.duplicate(true))
	replace_rig(redo_stack.pop_back())
	status("다시 실행했습니다.")

func replace_rig(value: Dictionary) -> void:
	rig = value
	puppet.rig = rig
	last_change_tag = ""
	puppet.rebuild()
	refresh_all()

func save() -> void:
	var issues: Array = BHRig.problems(rig)
	if not issues.is_empty():
		status("저장하지 않았습니다: "+str(issues[0]))
		return
	var error: Error = BHRig.save_file(rig_path,rig.duplicate(true))
	if error!=OK:
		status("저장 실패: "+error_string(error))
		return
	dirty = false
	status("저장했습니다: "+rig_path)
	refresh_header()

func reload_rig() -> void:
	snapshot()
	replace_rig(BHRig.load_file(rig_path,true).duplicate(true))
	dirty = false
	status("파일에서 다시 읽었습니다.")

func bones() -> Dictionary:
	return BHRig.bone_map(rig)

func slots() -> Dictionary:
	return BHRig.slot_map(rig)

func clip_data() -> Dictionary:
	return rig.get("animations",{}).get(clip,{})

func scope() -> String:
	return "*" if scope_shared else view

func setup_for_edit(bone: Dictionary) -> Dictionary:
	if not bone.setup.has(view):
		bone.setup[view] = BHRig.setup(rig,bone,view).duplicate()
	return bone.setup[view]

func current_pose() -> Dictionary:
	if mode!="anim" or clip.is_empty():
		return {}
	return BHRig.pose(rig,clip,view,time)

func pose_value(bone: String, property: String) -> Variant:
	var entry: Dictionary = current_pose().get(bone,{})
	match property:
		"rotate": return float(entry.get("rotate",0.0))
		"translate": return entry.get("translate",Vector2.ZERO)
		_: return entry.get("scale",Vector2.ONE)

## The editable key array for a bone property in the current scope. A view-specific track
## starts as a copy of the shared one so the override begins identical.
func edit_track(bone: String, property: String) -> Array:
	var data: Dictionary = clip_data()
	if not data.has("tracks"):
		data.tracks = {}
	if not data.tracks.has(scope()):
		data.tracks[scope()] = {}
	var table: Dictionary = data.tracks[scope()]
	if not table.has(bone):
		table[bone] = {}
	if not table[bone].has(property):
		var shared: Variant = data.tracks.get("*",{}).get(bone,{}).get(property,null)
		table[bone][property] = shared.duplicate(true) if scope()!="*" and shared is Array else []
	return table[bone][property]

func set_key(keys: Array, t: float, values: Array) -> void:
	t = snappedf(t,0.001)
	for key in keys:
		if absf(float(key[0])-t)<FRAME*0.5:
			var curve: String = str(key[values.size()+1]) if key.size()>values.size()+1 else "smooth"
			key.clear()
			key.append(t)
			key.append_array(values)
			key.append(curve)
			return
	var fresh: Array = [t]
	fresh.append_array(values)
	fresh.append("smooth")
	keys.append(fresh)
	keys.sort_custom(func(a,b):return float(a[0])<float(b[0]))

func key_times(bone: String) -> Array:
	var out: Array = []
	var data: Dictionary = clip_data()
	for property in BHRig.TRACK_WIDTH:
		for key in BHRig.track(data,view,bone,property):
			var t: float = float(key[0])
			var found: bool = false
			for existing in out:
				if absf(existing-t)<0.0005:
					found = true
			if not found:
				out.append(t)
	out.sort()
	return out

# ---------------------------------------------------------------- refresh

func refresh_all() -> void:
	refresh_header()
	refresh_tree()
	refresh_slots()
	refresh_clip_row()
	build_inspector()
	refresh_canvas()

func refresh_header() -> void:
	file_label.text = rig_path.get_file()+(" *" if dirty else "")
	for id in mode_buttons:
		mode_buttons[id].set_pressed_no_signal(id==mode)
	var drawn: Array = rig.get("views",[])
	for v in view_buttons:
		view_buttons[v].set_pressed_no_signal(v==view)
		view_buttons[v].text = BHRig.VIEW_NAMES[v]+("" if v in drawn else " +")
		view_buttons[v].tooltip_text = "" if v in drawn else "아직 없는 방향입니다. 누르면 첫 방향을 복사해서 시작합니다."

func refresh_tree() -> void:
	bone_tree.clear()
	var root: TreeItem = bone_tree.create_item()
	var items: Dictionary = {}
	for bone in rig.get("bones",[]):
		var parent: TreeItem = items.get(str(bone.parent),root)
		var item: TreeItem = bone_tree.create_item(parent)
		item.set_text(0,bone.name)
		items[bone.name] = item
		if bone.name==selected_bone:
			item.select(0)

func refresh_slots() -> void:
	slot_list.clear()
	var order: Array = BHRig.draw_order(rig,view)
	for slot in order:
		var index: int = slot_list.add_item("%s  (z %d)" % [slot.name,BHRig.slot_z(rig,slot,view)])
		slot_list.set_item_metadata(index,slot.name)
		if slot.name==selected_slot:
			slot_list.select(index)

func refresh_clip_row() -> void:
	clip_select.clear()
	var names: Array = rig.get("animations",{}).keys()
	for i in names.size():
		clip_select.add_item(names[i])
		if names[i]==clip:
			clip_select.select(i)
	var data: Dictionary = clip_data()
	duration_spin.set_value_no_signal(float(data.get("duration",1.0)))
	loop_check.set_pressed_no_signal(bool(data.get("loop",true)))
	speed_spin.set_value_no_signal(float(data.get("ref_speed",0.0)))
	scope_button.text = "트랙: 모든 방향 공유" if scope_shared else "트랙: "+BHRig.VIEW_NAMES[view]+" 전용"
	refresh_time()

func refresh_time() -> void:
	time_label.text = "%.2f / %.2f초" % [time,float(clip_data().get("duration",0.0))]
	play_button.text = "정지" if playing else "재생"
	timeline.queue_redraw()

func refresh_canvas() -> void:
	puppet.position = origin
	puppet.doll_scale = zoom
	puppet.direction = BHRig.sector_direction(VIEW_SECTOR[view])
	if mirror_preview:
		puppet.direction = Vector2(-puppet.direction.x,puppet.direction.y)
	puppet.pose_override = current_pose()
	puppet.clip = clip
	puppet.clip_time = time
	puppet.refresh()
	puppet.queue_redraw()
	puppet.visible = not ring_preview
	overlay.queue_redraw()
	canvas.queue_redraw()
	refresh_ring()

# ---------------------------------------------------------------- inspector

func build_inspector() -> void:
	for child in inspector.get_children():
		inspector.remove_child(child)
		child.queue_free()
	fields.clear()
	var bone: Dictionary = bones().get(selected_bone,{})
	if bone.is_empty():
		inspector.add_child(label("뼈를 선택하세요.",15,UI.MUTED))
		return
	inspector.add_child(label("뼈 · "+selected_bone,18))
	if mode=="anim":
		inspector.add_child(label("지금 시간의 포즈 (키로 저장)",13,UI.MUTED))
		var rot: float = pose_value(selected_bone,"rotate")
		var tr: Vector2 = pose_value(selected_bone,"translate")
		var sc: Vector2 = pose_value(selected_bone,"scale")
		field("rotate","회전",rot,func(v):key_value("rotate",[v]))
		field("tx","이동 x",tr.x,func(v):key_value("translate",[v,float(fields.ty.value)]))
		field("ty","이동 y",tr.y,func(v):key_value("translate",[float(fields.tx.value),v]))
		field("sx","크기 x",sc.x,func(v):key_value("scale",[v,float(fields.sy.value)]),0.01)
		field("sy","크기 y",sc.y,func(v):key_value("scale",[float(fields.sx.value),v]),0.01)
		inspector.add_child(label("키 곡선 (지금 시간의 키)",13,UI.MUTED))
		var curves = HBoxContainer.new()
		inspector.add_child(curves)
		for entry in [["smooth","부드럽게"],["linear","직선"],["step","계단"]]:
			var id: String = entry[0]
			curves.add_child(button(entry[1],func():set_curve(id)))
	else:
		var s: Dictionary = BHRig.setup(rig,bone,view)
		inspector.add_child(label(BHRig.VIEW_NAMES[view]+" 방향 기본 자세",13,UI.MUTED))
		field("x","x",float(s.get("x",0)),func(v):setup_value("x",v))
		field("y","y",float(s.get("y",0)),func(v):setup_value("y",v))
		field("rotation","회전",float(s.get("rotation",0)),func(v):setup_value("rotation",v))
		field("scale_x","크기 x",float(s.get("scale_x",1)),func(v):setup_value("scale_x",v),0.01)
		field("scale_y","크기 y",float(s.get("scale_y",1)),func(v):setup_value("scale_y",v),0.01)
		var parent_row = HBoxContainer.new()
		inspector.add_child(parent_row)
		parent_row.add_child(label("부모"))
		var parent_pick = OptionButton.new()
		parent_pick.focus_mode = Control.FOCUS_NONE
		parent_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var names: Array = [""]
		for b in rig.bones:
			if b.name!=selected_bone and not is_descendant(str(b.name),selected_bone):
				names.append(b.name)
		for n in names:
			parent_pick.add_item("(없음)" if n=="" else n)
			if n==str(bone.parent):
				parent_pick.select(parent_pick.item_count-1)
		parent_pick.item_selected.connect(func(i):reparent_bone(names[i]))
		parent_row.add_child(parent_pick)
		var bone_row = HBoxContainer.new()
		inspector.add_child(bone_row)
		bone_row.add_child(button("자식 뼈 추가",add_bone,"이름 칸(아래 동작 줄)의 이름으로 새 뼈를 만듭니다"))
		bone_row.add_child(button("뼈 삭제",delete_bone))
	inspector.add_child(HSeparator.new())
	build_slot_inspector()

func build_slot_inspector() -> void:
	var slot: Dictionary = slots().get(selected_slot,{})
	if slot.is_empty():
		for s in rig.get("slots",[]):
			if s.bone==selected_bone:
				slot = s
				selected_slot = s.name
				break
	if slot.is_empty():
		inspector.add_child(label("이 뼈에는 파츠가 없습니다.",15,UI.MUTED))
		inspector.add_child(image_picker("파츠 이미지 붙이기",func(path):add_slot(path)))
		return
	inspector.add_child(label("파츠 · "+str(slot.name),18))
	var skin: Dictionary = rig.skins.default.get(slot.name,{})
	var row = HBoxContainer.new()
	inspector.add_child(row)
	row.add_child(label("기본"))
	var pick = OptionButton.new()
	pick.focus_mode = Control.FOCUS_NONE
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var names: Array = skin.keys()
	for n in names:
		pick.add_item(n)
		if n==str(slot.get("attachment","")):
			pick.select(pick.item_count-1)
	pick.item_selected.connect(func(i):
		snapshot()
		slot.attachment = names[i]
		puppet.rebuild()
		refresh_all())
	row.add_child(pick)
	var att_name: String = str(slot.get("attachment",""))
	var att: Dictionary = BHRig.attachment(rig,slot.name,att_name,view)
	var z = HBoxContainer.new()
	inspector.add_child(z)
	var dye = CheckBox.new()
	dye.text = "옷감 염색"
	dye.button_pressed = bool(slot.get("dye",false))
	dye.focus_mode = Control.FOCUS_NONE
	dye.toggled.connect(func(on):
		snapshot()
		slot.dye = on
		puppet.rebuild()
		refresh_canvas())
	z.add_child(dye)
	if att.is_empty():
		inspector.add_child(label(BHRig.VIEW_NAMES[view]+" 방향에서 숨겨진 파츠",13,UI.MUTED))
		inspector.add_child(button("이 방향에 표시",func():show_in_view(slot.name,att_name)))
	else:
		inspector.add_child(hint(str(att.image)))
		var pivot: Array = att.get("pivot",[0,0])
		var scale: Array = att.get("scale",[1,1])
		field("px","피벗 x",float(pivot[0]),func(v):att_value("pivot",0,v))
		field("py","피벗 y",float(pivot[1]),func(v):att_value("pivot",1,v))
		field("arot","회전",float(att.get("rotation",0)),func(v):att_value("rotation",-1,v))
		field("asx","크기 x",float(scale[0]),func(v):att_value("scale",0,v),0.01)
		field("asy","크기 y",float(scale[1]),func(v):att_value("scale",1,v),0.01)
		inspector.add_child(image_picker("이미지 바꾸기",func(path):replace_image(slot.name,att_name,path)))
		inspector.add_child(button("이 방향에서 숨기기",func():hide_in_view(slot.name,att_name)))
	inspector.add_child(HSeparator.new())
	inspector.add_child(label("방향 이미지 가져오기",15))
	inspector.add_child(hint("%sviews/%s/ 폴더에 파츠 이름과 같은 PNG(예: thigh_l.png)를 넣고 누르면 이 방향 파츠를 한 번에 바꿉니다." % [rig.get("part_root",""),view]))
	inspector.add_child(button("폴더에서 가져오기",import_view_folder))

func field(key: String, text: String, value: float, callback: Callable, step_value: float = 0.1) -> void:
	var row = HBoxContainer.new()
	inspector.add_child(row)
	var l = label(text)
	l.custom_minimum_size.x = 70
	row.add_child(l)
	var s: SpinBox = spin(-100000.0,100000.0,step_value,callback)
	s.set_value_no_signal(value)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(s)
	fields[key] = s

func image_picker(text: String, callback: Callable) -> Control:
	var box = VBoxContainer.new()
	box.add_child(label(text,13,UI.MUTED))
	var pick = OptionButton.new()
	pick.focus_mode = Control.FOCUS_NONE
	pick.fit_to_longest_item = false
	pick.add_item("(이미지 선택)")
	for path in images:
		pick.add_item(path)
	pick.item_selected.connect(func(i):
		if i>0:
			callback.call(images[i-1]))
	box.add_child(pick)
	return box

func sync_fields() -> void:
	var bone: Dictionary = bones().get(selected_bone,{})
	if bone.is_empty() or fields.is_empty():
		return
	if mode=="anim":
		var tr: Vector2 = pose_value(selected_bone,"translate")
		var sc: Vector2 = pose_value(selected_bone,"scale")
		for pair in [["rotate",pose_value(selected_bone,"rotate")],["tx",tr.x],["ty",tr.y],["sx",sc.x],["sy",sc.y]]:
			if fields.has(pair[0]):
				fields[pair[0]].set_value_no_signal(float(pair[1]))
	else:
		var s: Dictionary = BHRig.setup(rig,bone,view)
		for key in ["x","y","rotation","scale_x","scale_y"]:
			if fields.has(key):
				fields[key].set_value_no_signal(float(s.get(key,0.0)))
	var att: Dictionary = selected_attachment()
	if not att.is_empty() and fields.has("px"):
		fields.px.set_value_no_signal(float(att.pivot[0]))
		fields.py.set_value_no_signal(float(att.pivot[1]))
		fields.arot.set_value_no_signal(float(att.get("rotation",0.0)))

# ---------------------------------------------------------------- edits

func set_mode(id: String) -> void:
	mode = id
	playing = false
	refresh_all()
	status({"bone":"뼈 셋업: 관절을 드래그해 옮기고, Shift+드래그로 돌립니다.","part":"파츠 셋업: 파츠를 드래그해 뼈 위 위치를 잡고, Shift+드래그로 돌립니다.","anim":"애니메이션: 드래그로 뼈를 돌리고 Shift+드래그로 옮기면 지금 시간에 키가 생깁니다."}[id])

func set_view(id: String) -> void:
	if not id in rig.views:
		snapshot()
		add_view(id)
		status(BHRig.VIEW_NAMES[id]+" 방향을 첫 방향 복사본으로 만들었습니다. 이미지를 바꾸고 관절을 맞추세요.")
	view = id
	if not scope_shared and view==BHRig.first_view(rig):
		scope_shared = true
	refresh_all()

## Start a new view from the first drawn view: bone setup, draw order and attachments are
## copied so the character stays visible while its images are replaced one by one.
func add_view(id: String) -> void:
	var base: String = BHRig.first_view(rig)
	rig.views.append(id)
	var ordered: Array = []
	for v in BHRig.VIEWS:
		if v in rig.views:
			ordered.append(v)
	rig.views = ordered
	for bone in rig.bones:
		bone.setup[id] = BHRig.setup(rig,bone,base).duplicate()
	for slot in rig.slots:
		slot.z[id] = BHRig.slot_z(rig,slot,base)
	for slot_name in rig.skins.default:
		for att_name in rig.skins.default[slot_name]:
			var entry: Dictionary = rig.skins.default[slot_name][att_name]
			if entry.has(base):
				entry[id] = entry[base].duplicate(true)
	puppet.rebuild()

func set_ring(on: bool) -> void:
	ring_preview = on
	if on and not playing:
		toggle_play()
	refresh_canvas()

func refresh_ring() -> void:
	for child in ring.get_children():
		if not ring_preview:
			ring.remove_child(child)
			child.queue_free()
	if not ring_preview:
		return
	if ring.get_child_count()==0:
		for i in 8:
			var p = BHPuppet.new()
			p.rig = rig
			p.auto_direction = false
			p.set_process(false)
			p.look = puppet.look
			ring.add_child(p)
	var center := Vector2(510,400)
	for i in 8:
		var p: BHPuppet = ring.get_child(i)
		var dir: Vector2 = BHRig.sector_direction(i)
		p.position = center+Vector2(dir.x*350,dir.y*200)
		p.doll_scale = 0.25
		p.direction = dir
		p.clip = clip
		p.clip_time = time
		p.pose_override = null
		p.fade = 1.0
		p.refresh()

func toggle_scope() -> void:
	if view==BHRig.first_view(rig) and scope_shared:
		status("첫 방향은 공유 트랙을 편집합니다. 다른 방향에서 전용 트랙을 만드세요.")
		return
	scope_shared = not scope_shared
	refresh_clip_row()

func setup_value(key: String, value: float) -> void:
	var bone: Dictionary = bones().get(selected_bone,{})
	if bone.is_empty():
		return
	snapshot("setup:"+selected_bone+key)
	setup_for_edit(bone)[key] = value
	refresh_canvas()

func key_value(property: String, values: Array) -> void:
	if clip.is_empty():
		return
	snapshot("key:"+selected_bone+property+str(time))
	set_key(edit_track(selected_bone,property),time,values)
	refresh_canvas()
	timeline.queue_redraw()

func att_value(key: String, index: int, value: float) -> void:
	var att: Dictionary = selected_attachment()
	if att.is_empty():
		return
	snapshot("att:"+selected_slot+key+str(index))
	if index<0:
		att[key] = value
	else:
		att[key][index] = value
	refresh_canvas()

func selected_attachment() -> Dictionary:
	var slot: Dictionary = slots().get(selected_slot,{})
	if slot.is_empty():
		return {}
	return BHRig.attachment(rig,slot.name,puppet.chosen_attachment(slot),view)

func set_curve(curve: String) -> void:
	var changed: bool = false
	snapshot()
	var data: Dictionary = clip_data()
	for property in BHRig.TRACK_WIDTH:
		var keys: Array = data.get("tracks",{}).get(scope(),{}).get(selected_bone,{}).get(property,[])
		for key in keys:
			if absf(float(key[0])-time)<FRAME*0.5:
				key[key.size()-1] = curve
				changed = true
	status("키 곡선을 바꿨습니다." if changed else "지금 시간에 선택한 뼈의 키가 없습니다.")
	refresh_canvas()

func key_selected() -> void:
	if clip.is_empty():
		return
	snapshot()
	key_bone(selected_bone)
	status(selected_bone+" 키를 %.2f초에 저장했습니다." % time)
	refresh_canvas()
	timeline.queue_redraw()

func key_bone(name: String) -> void:
	var r: float = pose_value(name,"rotate")
	var tr: Vector2 = pose_value(name,"translate")
	var sc: Vector2 = pose_value(name,"scale")
	set_key(edit_track(name,"rotate"),time,[snappedf(r,0.01)])
	if tr.length()>0.001 or not BHRig.track(clip_data(),view,name,"translate").is_empty():
		set_key(edit_track(name,"translate"),time,[snappedf(tr.x,0.01),snappedf(tr.y,0.01)])
	if not sc.is_equal_approx(Vector2.ONE) or not BHRig.track(clip_data(),view,name,"scale").is_empty():
		set_key(edit_track(name,"scale"),time,[snappedf(sc.x,0.001),snappedf(sc.y,0.001)])

func key_all() -> void:
	if clip.is_empty():
		return
	snapshot()
	for bone in rig.bones:
		key_bone(bone.name)
	status("모든 뼈의 키를 %.2f초에 저장했습니다." % time)
	refresh_canvas()

func delete_key() -> void:
	var removed: int = 0
	snapshot()
	var table: Dictionary = clip_data().get("tracks",{}).get(scope(),{}).get(selected_bone,{})
	for property in table:
		var keys: Array = table[property]
		for i in range(keys.size()-1,-1,-1):
			if absf(float(keys[i][0])-time)<FRAME*0.5:
				keys.remove_at(i)
				removed += 1
	status("키 %d개를 지웠습니다." % removed if removed>0 else "지금 시간에 이 트랙의 키가 없습니다.")
	refresh_canvas()
	sync_fields()

func jump_key(direction: int) -> void:
	var times: Array = key_times(selected_bone)
	var target: float = time
	if direction>0:
		for t in times:
			if t>time+0.0005:
				target = t
				break
	else:
		for i in range(times.size()-1,-1,-1):
			if times[i]<time-0.0005:
				target = times[i]
				break
	set_time(target)

func clear_view_tracks() -> void:
	var tracks: Dictionary = clip_data().get("tracks",{})
	if not tracks.has(view):
		status("이 방향 전용 트랙이 없습니다.")
		return
	snapshot()
	tracks.erase(view)
	scope_shared = true
	refresh_all()
	status(BHRig.VIEW_NAMES[view]+" 전용 트랙을 지웠습니다.")

func change_clip(key: String, value: Variant) -> void:
	var data: Dictionary = clip_data()
	if data.is_empty():
		return
	snapshot("clip:"+key)
	data[key] = value
	refresh_time()

func set_clip(name: String) -> void:
	clip = name
	time = 0.0
	refresh_clip_row()
	build_inspector()
	refresh_canvas()

func new_clip() -> void:
	var name: String = name_edit.text.strip_edges()
	if name.is_empty() or rig.animations.has(name):
		status("동작 이름을 새로 적어 주세요.")
		return
	snapshot()
	rig.animations[name] = {"duration":1.0,"loop":true,"tracks":{"*":{}}}
	name_edit.text = ""
	set_clip(name)

func duplicate_clip() -> void:
	var name: String = name_edit.text.strip_edges()
	if name.is_empty() or rig.animations.has(name) or clip.is_empty():
		status("복제할 새 이름을 적어 주세요.")
		return
	snapshot()
	rig.animations[name] = clip_data().duplicate(true)
	name_edit.text = ""
	set_clip(name)

func delete_clip() -> void:
	if clip in ["idle","walk","run"]:
		status("idle, walk, run은 게임이 쓰는 동작이라 지울 수 없습니다.")
		return
	snapshot()
	rig.animations.erase(clip)
	set_clip(str(rig.animations.keys().front()))

func toggle_play() -> void:
	playing = not playing
	refresh_time()

func step(frames: int) -> void:
	playing = false
	set_time(time+frames*FRAME)

func set_time(value: float) -> void:
	var duration: float = float(clip_data().get("duration",1.0))
	time = clampf(value,0.0,duration)
	refresh_time()
	refresh_canvas()
	sync_fields()

func is_descendant(name: String, ancestor: String) -> bool:
	var map: Dictionary = bones()
	var current: String = name
	while map.has(current) and not str(map[current].parent).is_empty():
		current = str(map[current].parent)
		if current==ancestor:
			return true
	return false

func reparent_bone(parent: String) -> void:
	var bone: Dictionary = bones().get(selected_bone,{})
	if bone.is_empty() or parent==str(bone.parent):
		return
	snapshot()
	# Keep the bone where it is on screen in every view.
	var world_before: Dictionary = {}
	for v in rig.views:
		world_before[v] = BHRig.solve(rig,v,{})
	bone.parent = parent
	for v in rig.views:
		var parent_t: Transform2D = world_before[v].get(parent,Transform2D.IDENTITY) if not parent.is_empty() else Transform2D.IDENTITY
		var local: Transform2D = parent_t.affine_inverse()*world_before[v][bone.name]
		var s: Dictionary = setup_for_edit_view(bone,v)
		s.x = snappedf(local.origin.x,0.01)
		s.y = snappedf(local.origin.y,0.01)
		s.rotation = snappedf(rad_to_deg(local.get_rotation()),0.01)
	sort_bones()
	refresh_all()

func setup_for_edit_view(bone: Dictionary, v: String) -> Dictionary:
	if not bone.setup.has(v):
		bone.setup[v] = BHRig.setup(rig,bone,v).duplicate()
	return bone.setup[v]

## Parents before children, keeping the existing order otherwise.
func sort_bones() -> void:
	var out: Array = []
	var placed: Dictionary = {}
	var pending: Array = rig.bones.duplicate()
	while not pending.is_empty():
		var progressed: bool = false
		for bone in pending.duplicate():
			if str(bone.parent).is_empty() or placed.has(bone.parent):
				out.append(bone)
				placed[bone.name] = true
				pending.erase(bone)
				progressed = true
		if not progressed:
			out.append_array(pending)
			break
	rig.bones = out

func add_bone() -> void:
	var name: String = name_edit.text.strip_edges()
	if name.is_empty() or bones().has(name):
		status("아래 동작 줄의 이름 칸에 새 뼈 이름을 적어 주세요.")
		return
	snapshot()
	var setup: Dictionary = {}
	for v in rig.views:
		setup[v] = {"x":0.0,"y":40.0,"rotation":0.0,"scale_x":1.0,"scale_y":1.0}
	var index: int = rig.bones.find(bones()[selected_bone])+1
	rig.bones.insert(index,{"name":name,"parent":selected_bone,"length":40,"setup":setup})
	name_edit.text = ""
	selected_bone = name
	selected_slot = ""
	refresh_all()
	status(name+" 뼈를 만들었습니다. 파츠 이미지를 붙이거나 관절을 옮기세요.")

func delete_bone() -> void:
	var map: Dictionary = bones()
	if selected_bone=="root" or not map.has(selected_bone):
		status("루트 뼈는 지울 수 없습니다.")
		return
	for bone in rig.bones:
		if str(bone.parent)==selected_bone:
			status("자식 뼈가 있는 뼈는 지울 수 없습니다. 자식부터 지우세요.")
			return
	snapshot()
	var name: String = selected_bone
	rig.bones.erase(map[name])
	for slot in rig.slots.duplicate():
		if slot.bone==name:
			rig.slots.erase(slot)
			rig.skins.default.erase(slot.name)
	for clip_name in rig.animations:
		for scope_name in rig.animations[clip_name].get("tracks",{}):
			rig.animations[clip_name].tracks[scope_name].erase(name)
	selected_bone = str(map[name].parent)
	selected_slot = ""
	puppet.rebuild()
	refresh_all()

func add_slot(path: String) -> void:
	snapshot()
	var name: String = selected_bone
	while slots().has(name):
		name += "_part"
	var att_name: String = path.get_file().get_basename()
	var z: Dictionary = {}
	for v in rig.views:
		z[v] = 45
	rig.slots.append({"name":name,"bone":selected_bone,"attachment":att_name,"dye":false,"z":z})
	var tex: Texture2D = BHRig.texture(rig,path)
	var size: Vector2 = tex.get_size() if tex!=null else Vector2.ZERO
	var entry: Dictionary = {}
	for v in rig.views:
		entry[v] = {"image":path,"pivot":[size.x*0.5,size.y*0.5],"rotation":0.0,"scale":[1.0,1.0]}
	rig.skins.default[name] = {att_name:entry}
	selected_slot = name
	puppet.rebuild()
	refresh_all()

func replace_image(slot_name: String, att_name: String, path: String) -> void:
	var entry: Dictionary = rig.skins.default[slot_name][att_name]
	if not entry.has(view):
		return
	snapshot()
	retarget(entry[view],path)
	refresh_canvas()
	build_inspector()

## Point an attachment at a new image, keeping its pivot at the same relative spot.
func retarget(att: Dictionary, path: String) -> void:
	var old: Texture2D = BHRig.texture(rig,str(att.image))
	BHRig.forget_texture(rig,path)
	var fresh: Texture2D = BHRig.texture(rig,path)
	if old!=null and fresh!=null:
		var old_size: Vector2 = old.get_size()
		var region: Variant = att.get("region",null)
		if region is Array:
			old_size = Vector2(region[2],region[3])
		var fraction := Vector2(float(att.pivot[0])/maxf(old_size.x,1.0),float(att.pivot[1])/maxf(old_size.y,1.0))
		att.pivot = [snappedf(fraction.x*fresh.get_width(),0.1),snappedf(fraction.y*fresh.get_height(),0.1)]
	att.erase("region")
	att.image = path

func hide_in_view(slot_name: String, att_name: String) -> void:
	snapshot()
	rig.skins.default[slot_name][att_name].erase(view)
	refresh_canvas()
	build_inspector()

func show_in_view(slot_name: String, att_name: String) -> void:
	var entry: Dictionary = rig.skins.default[slot_name][att_name]
	var source: Dictionary = entry.get(BHRig.first_view(rig),{})
	if source.is_empty() and not entry.is_empty():
		source = entry.values().front()
	if source.is_empty():
		return
	snapshot()
	entry[view] = source.duplicate(true)
	refresh_canvas()
	build_inspector()

## Replace every attachment image in this view whose name has a PNG in views/<view>/.
func import_view_folder() -> void:
	scan_images()
	var folder: String = "views/%s/" % view
	var found: int = 0
	snapshot()
	for slot_name in rig.skins.default:
		for att_name in rig.skins.default[slot_name]:
			var path: String = folder+att_name+".png"
			if not path in images:
				continue
			var entry: Dictionary = rig.skins.default[slot_name][att_name]
			if not entry.has(view):
				var source: Dictionary = entry.get(BHRig.first_view(rig),{})
				if source.is_empty():
					continue
				entry[view] = source.duplicate(true)
			retarget(entry[view],path)
			found += 1
	status("%s: 이미지 %d개를 가져왔습니다. (%s%s)" % [BHRig.VIEW_NAMES[view],found,rig.get("part_root",""),folder])
	refresh_all()

func move_slot(direction: int) -> void:
	var order: Array = BHRig.draw_order(rig,view)
	var index: int = -1
	for i in order.size():
		if order[i].name==selected_slot:
			index = i
	var other: int = index+direction
	if index<0 or other<0 or other>=order.size():
		return
	snapshot()
	# Renumber this view's z values from the new order so swaps are always visible.
	var moved: Dictionary = order[index]
	order.remove_at(index)
	order.insert(other,moved)
	for i in order.size():
		order[i].z[view] = i*2
	puppet.rebuild()
	refresh_all()

func scan_images() -> void:
	images.clear()
	collect_images(str(rig.get("part_root","res://")),"")
	images.sort()

func collect_images(root: String, relative: String) -> void:
	var dir = DirAccess.open(root+relative)
	if dir==null:
		return
	for file in dir.get_files():
		if file.get_extension().to_lower()=="png":
			images.append(relative+file)
	for sub in dir.get_directories():
		collect_images(root,relative+sub+"/")

func select_bone(name: String, update_tree: bool = true) -> void:
	if name==selected_bone and not update_tree:
		return
	selected_bone = name
	var slot_names: Array = []
	for slot in rig.get("slots",[]):
		if slot.bone==name:
			slot_names.append(slot.name)
	if not selected_slot in slot_names:
		selected_slot = slot_names[0] if not slot_names.is_empty() else ""
	if update_tree:
		refresh_tree()
	refresh_slots()
	build_inspector()
	overlay.queue_redraw()
	timeline.queue_redraw()

func select_slot(name: String, update_list: bool = true) -> void:
	selected_slot = name
	var slot: Dictionary = slots().get(name,{})
	if not slot.is_empty():
		selected_bone = slot.bone
	refresh_tree()
	if update_list:
		refresh_slots()
	build_inspector()
	overlay.queue_redraw()

# ---------------------------------------------------------------- canvas

func to_rig(point: Vector2) -> Vector2:
	return puppet.doll.get_global_transform().affine_inverse()*(canvas.get_global_transform()*point)

func to_canvas(point: Vector2) -> Vector2:
	return canvas.get_global_transform().affine_inverse()*(puppet.doll.get_global_transform()*point)

func world() -> Dictionary:
	return BHRig.solve(rig,view,current_pose())

func draw_canvas_back() -> void:
	var step_px: float = 100.0*zoom
	var color := Color(1,1,1,0.05)
	var x: float = fposmod(origin.x,step_px)
	while x<canvas.size.x:
		canvas.draw_line(Vector2(x,0),Vector2(x,canvas.size.y),color)
		x += step_px
	var y: float = fposmod(origin.y,step_px)
	while y<canvas.size.y:
		canvas.draw_line(Vector2(0,y),Vector2(canvas.size.x,y),color)
		y += step_px
	canvas.draw_line(Vector2(0,origin.y),Vector2(canvas.size.x,origin.y),Color(0.62,0.8,0.76,0.35),1.5)

func draw_overlay() -> void:
	if ring_preview:
		var f: Font = get_theme_default_font()
		overlay.draw_string(f,Vector2(16,28),"8방향 미리보기 · "+clip,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color(0.9,0.9,0.85))
		for p in ring.get_children():
			var pick: Array = BHRig.view_for(p.direction)
			var drawn: bool = pick[0] in rig.views
			var text: String = BHRig.VIEW_NAMES[pick[0]]+(" 반전" if pick[1] else "")+("" if drawn else " · "+BHRig.VIEW_NAMES[BHRig.first_view(rig)]+" 대체")
			overlay.draw_string(f,p.position+Vector2(-90,20),text,HORIZONTAL_ALIGNMENT_CENTER,180,13,Color(0.85,0.9,0.85) if drawn else Color(0.95,0.7,0.5))
		return
	var font: Font = get_theme_default_font()
	overlay.draw_string(font,Vector2(16,28),"%s · %s%s" % [BHRig.VIEW_NAMES[view],{"bone":"뼈 셋업","part":"파츠 셋업","anim":"애니메이션 "+clip}[mode]," · 좌우 반전 보기" if mirror_preview else ""],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color(0.9,0.9,0.85))
	var solved: Dictionary = world()
	var children: Dictionary = {}
	for bone in rig.bones:
		if not str(bone.parent).is_empty():
			if not children.has(bone.parent):
				children[bone.parent] = []
			children[bone.parent].append(bone.name)
	for bone in rig.bones:
		var p: Vector2 = to_canvas(solved[bone.name].origin)
		var chosen: bool = bone.name==selected_bone
		var color: Color = HILITE if chosen else Color(0.75,0.95,0.9,0.75)
		for child in children.get(bone.name,[]):
			var q: Vector2 = to_canvas(solved[child].origin)
			var d: Vector2 = q-p
			if d.length()<2.0:
				continue
			var n: Vector2 = d.orthogonal().normalized()*minf(7.0,d.length()*0.12)
			var shape := PackedVector2Array([p,p+d*0.18+n,q,p+d*0.18-n])
			overlay.draw_colored_polygon(shape,Color(color,0.22 if not chosen else 0.4))
			overlay.draw_polyline(PackedVector2Array([p,p+d*0.18+n,q,p+d*0.18-n,p]),color,1.2,true)
		overlay.draw_circle(p,5.0 if chosen else 3.5,color)
	if not selected_slot.is_empty() and puppet.sprites.has(selected_slot):
		var sprite: Sprite2D = puppet.sprites[selected_slot]
		if sprite.visible and sprite.texture!=null:
			var size: Vector2 = sprite.region_rect.size if sprite.region_enabled else sprite.texture.get_size()
			var t: Transform2D = canvas.get_global_transform().affine_inverse()*sprite.get_global_transform()
			var box := PackedVector2Array([t*Vector2.ZERO,t*Vector2(size.x,0),t*size,t*Vector2(0,size.y),t*Vector2.ZERO])
			overlay.draw_polyline(box,Color(1,0.8,0.4,0.8),1.0)
	if mode=="anim" and not clip.is_empty():
		overlay.draw_string(font,Vector2(16,52),"트랙: "+("모든 방향 공유" if scope_shared else BHRig.VIEW_NAMES[view]+" 전용"),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(0.8,0.85,0.8))

func hit_bone(point: Vector2) -> String:
	var solved: Dictionary = world()
	var best: String = ""
	var best_d: float = 12.0
	for bone in rig.bones:
		var d: float = to_canvas(solved[bone.name].origin).distance_to(point)
		if d<best_d:
			best_d = d
			best = bone.name
	return best

func hit_slot(point: Vector2) -> String:
	var global: Vector2 = canvas.get_global_transform()*point
	for i in range(puppet.doll.get_child_count()-1,-1,-1):
		var sprite: Sprite2D = puppet.doll.get_child(i)
		if not sprite.visible or sprite.texture==null:
			continue
		var local: Vector2 = sprite.get_global_transform().affine_inverse()*global
		var rect := Rect2(Vector2.ZERO,sprite.region_rect.size if sprite.region_enabled else sprite.texture.get_size())
		if not rect.has_point(local):
			continue
		var image: Image = sprite.texture.get_image()
		if image==null:
			continue
		var px: Vector2i = Vector2i(local+(sprite.region_rect.position if sprite.region_enabled else Vector2.ZERO))
		if px.x>=0 and px.y>=0 and px.x<image.get_width() and px.y<image.get_height() and image.get_pixelv(px).a>0.3:
			return sprite.name
	return ""

func on_canvas_input(event: InputEvent) -> void:
	if ring_preview:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index==MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom_at(mb.position,1.1)
		elif mb.button_index==MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom_at(mb.position,1.0/1.1)
		elif mb.button_index==MOUSE_BUTTON_MIDDLE:
			drag = {"kind":"pan","start":mb.position,"origin":origin} if mb.pressed else {}
		elif mb.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
			if mb.pressed:
				begin_drag(mb.position,mb.shift_pressed or mb.button_index==MOUSE_BUTTON_RIGHT)
			else:
				if not drag.is_empty() and drag.get("kind","")!="pan":
					sync_fields()
					timeline.queue_redraw()
				drag = {}
	elif event is InputEventMouseMotion and not drag.is_empty():
		continue_drag((event as InputEventMouseMotion).position)

func zoom_at(point: Vector2, factor: float) -> void:
	var new_zoom: float = clampf(zoom*factor,0.2,4.0)
	origin = point+(origin-point)*(new_zoom/zoom)
	zoom = new_zoom
	refresh_canvas()

func begin_drag(point: Vector2, alternate: bool) -> void:
	# Setup modes: drag moves, Shift rotates. Animate mode: drag rotates, Shift moves.
	var rotate: bool = alternate if mode!="anim" else not alternate
	var bone_name: String = hit_bone(point)
	if mode=="part" or bone_name.is_empty():
		var slot_name: String = hit_slot(point)
		if not slot_name.is_empty() and (mode=="part" or bone_name.is_empty()):
			select_slot(slot_name)
			bone_name = selected_bone
	if bone_name.is_empty():
		drag = {"kind":"pan","start":point,"origin":origin}
		return
	if bone_name!=selected_bone:
		select_bone(bone_name)
	var solved: Dictionary = world()
	var bone: Dictionary = bones()[selected_bone]
	var rig_point: Vector2 = to_rig(point)
	var bone_world: Transform2D = solved[selected_bone]
	drag = {"kind":mode+(":rotate" if rotate else ":move"),"start":rig_point,"bone_world":bone_world,
		"parent_world":BHRig.parent_world(solved,bone),"angle":(rig_point-bone_world.origin).angle()}
	if mode=="bone":
		snapshot()
		var s: Dictionary = setup_for_edit(bone)
		drag.value = Vector2(float(s.x),float(s.y))
		drag.rotation = float(s.rotation)
	elif mode=="part":
		var att: Dictionary = selected_attachment()
		if att.is_empty():
			drag = {}
			return
		snapshot()
		drag.value = Vector2(float(att.pivot[0]),float(att.pivot[1]))
		drag.rotation = float(att.get("rotation",0.0))
		drag.pivot_world = bone_world*BHRig.attachment_transform(att)*Vector2(float(att.pivot[0]),float(att.pivot[1]))
		drag.angle = (rig_point-drag.pivot_world).angle()
	else:
		if clip.is_empty():
			drag = {}
			return
		snapshot()
		drag.value = pose_value(selected_bone,"translate")
		drag.rotation = pose_value(selected_bone,"rotate")

func continue_drag(point: Vector2) -> void:
	if drag.kind=="pan":
		origin = drag.origin+(point-drag.start)
		refresh_canvas()
		return
	var rig_point: Vector2 = to_rig(point)
	var delta: Vector2 = rig_point-drag.start
	var bone: Dictionary = bones()[selected_bone]
	var center: Vector2 = drag.get("pivot_world",drag.bone_world.origin)
	var turn: float = rad_to_deg(angle_difference(drag.angle,(rig_point-center).angle()))
	match drag.kind:
		"bone:move":
			var local: Vector2 = drag.parent_world.basis_xform_inv(delta)
			var s: Dictionary = setup_for_edit(bone)
			s.x = snappedf(drag.value.x+local.x,0.1)
			s.y = snappedf(drag.value.y+local.y,0.1)
		"bone:rotate":
			setup_for_edit(bone).rotation = snappedf(drag.rotation+turn,0.1)
		"part:move":
			var att: Dictionary = selected_attachment()
			var inside: Vector2 = (drag.bone_world*BHRig.attachment_transform(att)).basis_xform_inv(delta)
			att.pivot = [snappedf(drag.value.x-inside.x,0.1),snappedf(drag.value.y-inside.y,0.1)]
		"part:rotate":
			selected_attachment().rotation = snappedf(drag.rotation+turn,0.1)
		"anim:move":
			var local: Vector2 = drag.parent_world.basis_xform_inv(delta)
			set_key(edit_track(selected_bone,"translate"),time,[snappedf(drag.value.x+local.x,0.1),snappedf(drag.value.y+local.y,0.1)])
		"anim:rotate":
			set_key(edit_track(selected_bone,"rotate"),time,[snappedf(drag.rotation+turn,0.1)])
	refresh_canvas()
	sync_fields()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	var key: InputEventKey = event
	if key.ctrl_pressed and key.keycode==KEY_S:
		save()
	elif key.ctrl_pressed and key.keycode==KEY_Z:
		if key.shift_pressed:
			redo()
		else:
			undo()
	elif key.ctrl_pressed and key.keycode==KEY_Y:
		redo()
	elif key.keycode==KEY_SPACE:
		toggle_play()
	elif key.keycode==KEY_K and mode=="anim":
		key_selected()
	elif key.keycode==KEY_DELETE and mode=="anim":
		delete_key()
	elif key.keycode==KEY_LEFT:
		step(-1)
	elif key.keycode==KEY_RIGHT:
		step(1)
	else:
		return
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if playing and not clip.is_empty():
		var data: Dictionary = clip_data()
		var duration: float = maxf(float(data.get("duration",1.0)),0.01)
		time += delta
		if time>duration:
			time = fposmod(time,duration) if bool(data.get("loop",true)) else duration
			if not bool(data.get("loop",true)):
				playing = false
		refresh_time()
		refresh_canvas()

# ---------------------------------------------------------------- timeline

class Timeline extends Control:
	var editor: BHRigEditor
	var dragging_key: float = -1.0

	func span() -> Rect2:
		return Rect2(Vector2(150,4),Vector2(size.x-160,size.y-8))

	func x_of(t: float) -> float:
		var r: Rect2 = span()
		return r.position.x+r.size.x*t/maxf(float(editor.clip_data().get("duration",1.0)),0.01)

	func t_of(x: float) -> float:
		var r: Rect2 = span()
		return clampf((x-r.position.x)/r.size.x,0.0,1.0)*float(editor.clip_data().get("duration",1.0))

	func _draw() -> void:
		var r: Rect2 = span()
		var font: Font = get_theme_default_font()
		draw_rect(Rect2(Vector2.ZERO,size),Color("dcd8c9"))
		draw_rect(r,Color("f4f1e6"))
		var duration: float = maxf(float(editor.clip_data().get("duration",1.0)),0.01)
		var frames: int = int(duration/BHRigEditor.FRAME)
		for f in frames+1:
			var x: float = x_of(f*BHRigEditor.FRAME)
			var major: bool = f%10==0
			draw_line(Vector2(x,r.position.y),Vector2(x,r.position.y+(10 if major else 5)),Color(0.4,0.45,0.45,0.6 if major else 0.3))
		var row_all: float = r.position.y+20
		var row_bone: float = r.position.y+42
		draw_string(font,Vector2(8,row_all+5),"모든 뼈",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("6c817e"))
		draw_string(font,Vector2(8,row_bone+5),editor.selected_bone,HORIZONTAL_ALIGNMENT_LEFT,140,13,Color("294950"))
		for bone in editor.rig.get("bones",[]):
			for t in editor.key_times(bone.name):
				draw_line(Vector2(x_of(t),row_all-5),Vector2(x_of(t),row_all+5),Color(0.35,0.45,0.45,0.5),1.0)
		var own: Dictionary = editor.clip_data().get("tracks",{}).get(editor.view,{}).get(editor.selected_bone,{})
		for t in editor.key_times(editor.selected_bone):
			var p := Vector2(x_of(t),row_bone)
			var shape := PackedVector2Array([p+Vector2(0,-7),p+Vector2(7,0),p+Vector2(0,7),p+Vector2(-7,0)])
			var special: bool = not own.is_empty()
			draw_colored_polygon(shape,Color("e0873f") if absf(t-editor.time)<BHRigEditor.FRAME*0.5 else (Color("6d5a9e") if special else Color("456f71")))
		var cursor: float = x_of(editor.time)
		draw_line(Vector2(cursor,0),Vector2(cursor,size.y),Color("c0392b"),2.0)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging_key = -1.0
				var r: Rect2 = span()
				if absf(event.position.y-(r.position.y+42))<9.0:
					for t in editor.key_times(editor.selected_bone):
						if absf(x_of(t)-event.position.x)<7.0:
							dragging_key = t
							editor.snapshot()
				editor.playing = false
				editor.set_time(t_of(event.position.x) if dragging_key<0.0 else dragging_key)
			else:
				dragging_key = -1.0
		elif event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT:
			var t: float = snappedf(t_of(event.position.x),BHRigEditor.FRAME)
			if dragging_key>=0.0:
				editor.move_keys(dragging_key,t)
				dragging_key = t
			editor.set_time(t)

func move_keys(from_t: float, to_t: float) -> void:
	var table: Dictionary = clip_data().get("tracks",{}).get(scope(),{}).get(selected_bone,{})
	for property in table:
		for key in table[property]:
			if absf(float(key[0])-from_t)<0.0005:
				key[0] = snappedf(to_t,0.001)
		table[property].sort_custom(func(a,b):return float(a[0])<float(b[0]))
