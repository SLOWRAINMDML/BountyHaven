extends Node2D
## Application shell: lifecycle/UI only. All transactions live in Game.
const UI = preload("res://scripts/ui/palette.gd")
const Habitat = preload("res://scripts/world/habitat.gd")
const Space = preload("res://scripts/space/space_world.gd")
const Ship = preload("res://scripts/space/ship_visual.gd")
var world: Node2D
var canvas: CanvasLayer
var hud: Control
var panel: PanelContainer
var panel_body: VBoxContainer
var panel_kind: String = ""
var screen: String = "port"
var title_label: Label
var location_label: Label
var status_label: Label
var mission_label: Label
var hint_label: Label
var toast_label: Label
var toast_box: PanelContainer
var toast_time: float = 0.0
var radio_label: Label
var bars: Dictionary = {}
var skill_buttons: Array = []
var slot: int = 0
var mode: String = "pilot"
var capture_mode: bool = false
var end_pending: bool = false
var current_report: Dictionary = {}

func _ready() -> void:
	bind_inputs()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	Game.persistence = not ("--self-test" in args or "--capture-all" in args)
	Game.reset(false)
	if "--self-test" in args:
		Sfx.enabled = false
		var runner = load("res://tests/test_runner.gd").new()
		add_child(runner)
		runner.run.call_deferred()
		return
	capture_mode = "--capture-all" in args
	if not capture_mode:
		Game.load_game()
	canvas = CanvasLayer.new()
	add_child(canvas)
	Game.changed.connect(refresh_status)
	show_habitat("port")
	if capture_mode:
		Sfx.enabled = false
		capture_all.call_deferred()
	else:
		toast("작은 배, 커다란 여행. 길드에서 파일럿 모집에 지원하거나 술집에서 동료를 만나 보세요.",9.0)
		if not Game.last_storage_error.is_empty():
			toast(Game.last_storage_error,10.0)

func bind_inputs() -> void:
	var map: Dictionary = {"left":[KEY_A,KEY_LEFT],"right":[KEY_D,KEY_RIGHT],"up":[KEY_W,KEY_UP],"down":[KEY_S,KEY_DOWN],"interact":[KEY_E],"rotate":[KEY_R],"skill_1":[KEY_1],"skill_2":[KEY_2],"skill_3":[KEY_3],"skill_4":[KEY_4],"save":[KEY_F5],"delete_furniture":[KEY_DELETE]}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in map[action]:
			var event = InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action,event)

func clear_world() -> void:
	Input.action_release("interact")
	close_panel()
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	world = null
	if is_instance_valid(hud):
		canvas.remove_child(hud)
		hud.queue_free()
	bars.clear()
	skill_buttons.clear()
	toast_box = null
	toast_label = null
	radio_label = null

func show_habitat(kind: String) -> void:
	clear_world()
	screen = kind
	world = Habitat.new()
	world.place_kind = kind
	world.interaction.connect(interact_with)
	world.feedback.connect(toast)
	add_child(world)
	if kind == "port":
		var docked = Ship.new()
		docked.modules = Game.s.equipped.duplicate()
		docked.position = Vector2(253,702)
		docked.rotation = 0.7
		docked.scale = Vector2(2.7,2.7)
		docked.z_index = -15
		world.add_child(docked)
	build_hud()
	refresh_status()

func build_hud() -> void:
	hud = Control.new()
	hud.name = "Interface"
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.theme = UI.theme()
	canvas.add_child(hud)
	var top = panel_at(Rect2(0,0,1600,86), Color("eeeade") if screen!="space" else Color("152b38"))
	top.mouse_filter = Control.MOUSE_FILTER_STOP
	var row = HBoxContainer.new()
	top.add_child(row)
	var brand = VBoxContainer.new()
	brand.add_theme_constant_override("separation",0)
	row.add_child(brand)
	brand.add_child(UI.label("B O U N T Y   H A V E N",24,UI.INK if screen!="space" else UI.PAPER))
	brand.add_child(UI.label("A SHIP TO CALL HOME     /     SLOWRAIN GAMES",11,UI.MUTED))
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	status_label = UI.label("",18,UI.INK if screen!="space" else UI.PAPER)
	row.add_child(status_label)
	row.add_child(UI.button("기록",func():open_panel("journal")))
	row.add_child(UI.button("저장",save_now,screen=="space"))
	row.add_child(UI.button("≡",func():open_panel("menu")))
	location_label = UI.label("",13,UI.MUTED)
	location_label.position = Vector2(42,117)
	hud.add_child(location_label)
	title_label = UI.label("",37,UI.INK if screen!="space" else UI.PAPER)
	title_label.position = Vector2(40,139)
	hud.add_child(title_label)
	mission_label = UI.label("",17,UI.INK if screen!="space" else UI.PAPER,true)
	mission_label.position = Vector2(940,117)
	mission_label.size = Vector2(610,82)
	mission_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(mission_label)
	var bottom = panel_at(Rect2(0,806,1600,94),Color("eeeade") if screen!="space" else Color("182f3b"))
	var stack = VBoxContainer.new()
	stack.add_theme_constant_override("separation",5)
	bottom.add_child(stack)
	var commands = HBoxContainer.new()
	commands.add_theme_constant_override("separation",9)
	stack.add_child(commands)
	if screen=="space":
		build_combat_controls(commands)
	elif screen=="port":
		for entry in [["01  길드 · 계약","guild"],["02  술집 · 동료","tavern"],["03  항로 조사","records"],["04  정비소","outfitter"],["05  내 우주선","ship"]]:
			var key: String = entry[1]
			var b = UI.button(entry[0],func():route_to(key))
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			commands.add_child(b)
		commands.add_child(UI.button("항로 지도",func():open_panel("map")))
	else:
		for entry in [["가구 구입 · 배치","housing"],["함선 파츠","outfitter"],["조종석 · 출항","launch"]]:
			var key: String = entry[1]
			var b = UI.button(entry[0],func():interact_with(key))
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			commands.add_child(b)
		commands.add_child(UI.button("가구 옮기기",edit_furniture))
		commands.add_child(UI.button("함께 휴식",func():apply_result(Game.rest())))
		commands.add_child(UI.button("항구로",func():show_habitat("port")))
	hint_label = UI.label("",14,UI.MUTED)
	stack.add_child(hint_label)
	hint_label.text = "WASD / 방향키 또는 바닥 클릭: 이동     E: 가까운 곳 조사     아래 버튼: 해당 장소로 걸어가기     Esc: 메뉴"
	if screen=="cabin":
		hint_label.text = "내 배에서 쉬어 갑니다.  가구 배치: 클릭 / R 회전 / 우클릭 선택 해제 / Delete 선택 가구 판매 / Esc 종료"
	elif screen=="space":
		hint_label.text = "WASD 이동  ·  마우스 조준 / 왼쪽 클릭 제압포  ·  1–4 장비  ·  E 스캔·접현·회수  ·  Esc 일시정지"
	toast_box = panel_at(Rect2(345,714,910,76),Color(0.94,0.92,0.86,0.96))
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label = UI.label("",18,UI.INK,true)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_box.add_child(toast_label)
	toast_box.hide()

func panel_at(rect: Rect2, fill: Color) -> PanelContainer:
	var box = PanelContainer.new()
	box.position = rect.position
	box.size = rect.size
	box.add_theme_stylebox_override("panel",UI.style(fill,Color("bcc6b7"),0))
	hud.add_child(box)
	return box

func refresh_status() -> void:
	if not is_instance_valid(status_label) or Game.s.is_empty():
		return
	var hunter: String = Game.active_hunter()
	var crew: String = BHCatalog.HUNTERS[hunter].name if not hunter.is_empty() else "혼자 항해 중"
	status_label.text = "%s Cr     컨디션 %d     %s    " % [format_credit(int(Game.s.credits)),Game.s.condition,crew]
	if screen=="port":
		title_label.text = BHCatalog.PORTS[Game.s.port].name
		location_label.text = BHCatalog.PORTS[Game.s.port].subtitle
	elif screen=="cabin":
		title_label.text = "당신의 배, 작은 안식처"
		location_label.text = "THE WAYFARER / LIVING DECK    ·    쾌적도 %d / 40" % Game.comfort()
	else:
		title_label.text = "폐함선 항로" if Game.s.port=="rust" else "유리 궤도 외곽"
		location_label.text = "LIVE OPERATION / CAPTAIN AT THE HELM"
	if screen!="space":
		if Game.s.mission.is_empty():
			mission_label.text = "다음 여정은 어디로?\n길드에서 의뢰를 찾거나 술집에서 동료를 만나세요."
		else:
			mission_label.text = "%s  /  %s\n보수 %d Cr  ·  %s" % [BHCatalog.CONTRACTS[Game.s.mission.id].title,"파일럿 계약" if Game.s.mission.mode=="pilot" else "선장 주도",Game.estimated_reward(),"항로 기록 확보" if Game.s.mission.intel else "출항 전 항로를 조사할 수 있습니다"]

func format_credit(value: int) -> String:
	var digits: String = str(value)
	var output: String = ""
	for i in range(digits.length()):
		if i>0 and (digits.length()-i)%3==0:
			output += ","
		output += digits[i]
	return output

func route_to(kind: String) -> void:
	close_panel()
	if world is BHHabitat:
		world.stop_build()
		world.go_to(kind)
		toast("선장이 해당 장소로 이동합니다.",2.0)

func interact_with(kind: String) -> void:
	Sfx.play("click")
	match kind:
		"ship": show_habitat("cabin")
		"port": show_habitat("port")
		"rest": apply_result(Game.rest())
		_: open_panel(kind)

func close_panel() -> void:
	if is_instance_valid(panel):
		hud.remove_child(panel)
		panel.queue_free()
	panel = null
	panel_kind = ""
	if is_instance_valid(world):
		world.controls_enabled = true
		if world is BHSpace:
			world.simulation_paused = false

func open_panel(kind: String) -> void:
	Input.action_release("interact")
	close_panel()
	panel_kind = kind
	if world is BHHabitat:
		world.stop_build()
		world.player.path.clear()
	world.controls_enabled = false
	if world is BHSpace:
		world.simulation_paused = true
	panel = panel_at(Rect2(1030,207,528,580),UI.PAPER)
	panel.add_theme_stylebox_override("panel",UI.style(UI.PAPER,UI.MUTED,4))
	var stack = VBoxContainer.new()
	panel.add_child(stack)
	var title_row = HBoxContainer.new()
	stack.add_child(title_row)
	var titles: Dictionary = {"guild":"길드 · 계약 게시판","tavern":"항구의 술집","outfitter":"정비소 · 모듈 장착","records":"항로 기록 보관소","housing":"우리 배의 생활 공간","launch":"조종석 · 출항 준비","map":"항로 지도","journal":"선장의 기록","menu":"항해 잠시 멈춤","new_confirm":"새 항해 시작","report":"작전 정산"}
	var heading = UI.label(titles.get(kind,kind),24)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(heading)
	title_row.add_child(UI.button("닫기",close_panel))
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	panel_body = VBoxContainer.new()
	panel_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_body.add_theme_constant_override("separation",14)
	scroll.add_child(panel_body)
	match kind:
		"guild": guild_panel()
		"tavern": tavern_panel()
		"outfitter": outfitter_panel()
		"housing": housing_panel()
		"records": records_panel()
		"launch": launch_panel()
		"map": map_panel()
		"journal": journal_panel()
		"menu": menu_panel()
		"new_confirm": new_confirm_panel()
		"report": report_panel()

func para(text: String, size: int = 18, color: Color = UI.MUTED) -> void:
	panel_body.add_child(UI.label(text,size,color,true))

func apply_result(response: Dictionary, reopen: String = "") -> void:
	Sfx.play("click" if response.ok else "hit")
	toast(str(response.message))
	if not reopen.is_empty():
		open_panel(reopen)

func guild_panel() -> void:
	if not Game.s.mission.is_empty():
		var contract: Dictionary = BHCatalog.CONTRACTS[Game.s.mission.id]
		var content = UI.card(panel_body,contract.title,contract.brief)
		content.add_child(UI.label("계약 중 · 예상 보수 %d Cr" % Game.estimated_reward(),20))
		content.add_child(UI.button("항로를 조사하러 가기",func():route_to("records")))
		content.add_child(UI.button("내 우주선으로",func():show_habitat("cabin")))
		content.add_child(UI.button("출항 전 계약 취소",func():apply_result(Game.cancel(),"guild")))
		return
	para("추적자의 파일럿 모집에 지원하거나, 동료를 고용해 직접 현상금을 맡으세요.")
	var tabs = HBoxContainer.new()
	panel_body.add_child(tabs)
	for entry in [["파일럿으로 지원","pilot"],["선장 주도 계약","captain"]]:
		var id: String = entry[1]
		var b = UI.button(("✓ " if mode==id else "")+entry[0],func():mode=id;open_panel("guild"))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)
	for id in Game.available_contracts():
		var contract: Dictionary = BHCatalog.CONTRACTS[id]
		var content = UI.card(panel_body,contract.title,contract.brief)
		var reward: int = int(contract.reward)
		var detail: String = "현상금 %d Cr / 고용 동료와 지분 정산" % reward
		if mode=="pilot" and id!="salvage":
			reward = 800+int(contract.danger)*150
			detail = "파일럿 보수 %d Cr / 추적자 임시 동승 포함" % reward
		if id=="salvage":
			detail = "보수 420 Cr / 전투 없음 / 동료 불필요"
		content.add_child(UI.label(detail,17,UI.INK,true))
		content.add_child(UI.label("출항료 %d Cr · 수리비 최대 100 Cr · 긴급 철수 가능" % (0 if id=="salvage" else 100),15,UI.MUTED,true))
		var cid: String = id
		var blocked: bool = mode=="captain" and Game.s.crew=="" and id!="salvage"
		content.add_child(UI.button("술집에서 동료 고용 필요" if blocked else "계약 수락",func():apply_result(Game.accept(cid,mode),"guild"),blocked))

func tavern_panel() -> void:
	para("처음에는 계약 동료. 언젠가는 같은 배를 집이라고 부를 사람들.")
	for id in BHCatalog.HUNTERS:
		var hunter: Dictionary = BHCatalog.HUNTERS[id]
		var content = UI.card(panel_body,hunter.name+"  /  "+hunter.role,"“"+hunter.intro+"”")
		content.add_child(UI.label(hunter.perk,17,UI.INK,true))
		content.add_child(UI.label("합류비 %d Cr · 현상금 지분 %d%% · 신뢰 %d" % [hunter.fee,int(hunter.share*100),Game.s.trust[id]],16,UI.MUTED,true))
		var hid: String = id
		var disabled: bool = Game.s.crew==id or not Game.s.mission.is_empty() or int(Game.s.credits)<int(hunter.fee)
		content.add_child(UI.button("함께 항해 중" if Game.s.crew==id else "동행 계약",func():apply_result(Game.hire(hid),"tavern"),disabled))
	para("파일럿 계약의 임시 동승자는 정산 후 떠납니다. 직접 고용한 동료는 선내에 남습니다.",16)

func outfitter_panel() -> void:
	para("파츠는 실제 스킬과 외형을 바꿉니다. 장착할 슬롯을 먼저 선택하세요.")
	para("원자로  %d / %d" % [Game.power_load(),Game.MAX_POWER],22,UI.INK)
	var slots = HBoxContainer.new()
	panel_body.add_child(slots)
	for index in range(4):
		var index_copy: int = index
		var b = UI.button(("✓ " if slot==index else "")+str(index+1)+" "+BHCatalog.MODULES[Game.s.equipped[index]].key,func():slot=index_copy;open_panel("outfitter"))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size",15)
		slots.add_child(b)
	var viewport = SubViewport.new()
	viewport.size = Vector2i(450,150)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var preview = SubViewportContainer.new()
	preview.custom_minimum_size = Vector2(450,150)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(viewport)
	panel_body.add_child(preview)
	var ship_preview = Ship.new()
	ship_preview.position = Vector2(225,77)
	ship_preview.scale = Vector2(1.8,1.8)
	ship_preview.rotation = PI*0.5
	ship_preview.modules = Game.s.equipped.duplicate()
	viewport.add_child(ship_preview)
	for id in BHCatalog.MODULES:
		var data: Dictionary = BHCatalog.MODULES[id]
		var content = UI.card(panel_body,data.name+"  ·  전력 "+str(data.power),data.text)
		var mid: String = id
		content.add_child(UI.label("에너지 %d / 발열 %d / 대기 %.1f초" % [data.energy,data.heat,data.cooldown],16,UI.MUTED))
		if id in Game.s.owned:
			content.add_child(UI.button("%d번 슬롯에 장착" % (slot+1),func():apply_result(Game.equip(mid,slot),"outfitter")))
		else:
			content.add_child(UI.button("구입 · %d Cr" % data.cost,func():apply_result(Game.buy_module(mid),"outfitter"),int(Game.s.credits)<int(data.cost)))

func housing_panel() -> void:
	para("쾌적도 %d / 40  ·  같은 종류의 효과는 가장 높은 것만 적용됩니다." % Game.comfort())
	para("실제 선내 바닥에 가구를 배치합니다. 중앙 통로와 출입구는 비워 두세요. 구입비는 유효한 위치에 놓을 때만 지불합니다.",16)
	for id in BHCatalog.FURNITURE:
		var data: Dictionary = BHCatalog.FURNITURE[id]
		var content = UI.card(panel_body,data.name+"  ·  %d Cr" % data.cost,data.text)
		var fid: String = id
		var actions = HBoxContainer.new()
		content.add_child(actions)
		var choose = UI.button("직접 배치",func():close_panel();world.start_build(fid),int(Game.s.credits)<int(data.cost))
		choose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(choose)
		actions.add_child(UI.button("빈자리 배치",func():auto_place(fid),int(Game.s.credits)<int(data.cost)))

func auto_place(id: String) -> void:
	var cell: Vector2i = Game.nearest_cell(id,Vector2i(8,0),false)
	apply_result(Game.place(id,cell),"housing")

func edit_furniture() -> void:
	close_panel()
	world.start_build("plant")
	world.selected_item = ""
	world.ghost.hide()
	toast("옮길 가구를 클릭하세요. R 회전 · Delete 판매 · 우클릭 선택 해제",8.0)

func records_panel() -> void:
	para("희미한 연료 흔적, 정비 기록, 항구의 목격담. 좌표가 아니라 유리한 출발점을 얻습니다.")
	if Game.s.mission.is_empty():
		para("아직 맡은 계약이 없습니다. 길드에서 의뢰를 수락하십시오.")
		panel_body.add_child(UI.button("길드로",func():route_to("guild")))
		return
	para(BHCatalog.CONTRACTS[Game.s.mission.id].hint,20,UI.INK)
	panel_body.add_child(UI.button("기록 확보 완료" if Game.s.mission.intel else "항로 기록 조사",func():apply_result(Game.investigate(),"records"),Game.s.mission.intel))
	para("사전 조사 시 첫 번째 신호가 분석된 상태로 출항합니다. 나머지 흔적은 직접 찾아야 합니다.",16)
	panel_body.add_child(UI.button("내 우주선으로",func():show_habitat("cabin")))

func launch_panel() -> void:
	if Game.s.mission.is_empty():
		para("배는 준비되어 있습니다. 먼저 길드에서 다음 의뢰를 선택하세요.")
		panel_body.add_child(UI.button("항구로 돌아가기",func():show_habitat("port")))
		return
	var c: Dictionary = BHCatalog.CONTRACTS[Game.s.mission.id]
	para(c.title,27,UI.INK)
	para(c.brief)
	para("보수 %d Cr / 출항료 %d Cr\n컨디션 %d / 원자로 %d·12" % [Game.estimated_reward(),0 if Game.s.mission.id=="salvage" or Game.s.mission.paid else 100,Game.s.condition,Game.power_load()],20,UI.INK)
	para("컨디션 85 이상이면 냉각·에너지 회복 효율 +12%. 생포 임무는 엔진 제압 → 접현 → 중계기 파괴 → 엄호 → 포드 회수로 진행됩니다.",16)
	panel_body.add_child(UI.button("함께 쉬고 준비하기",func():apply_result(Game.rest(),"launch")))
	panel_body.add_child(UI.button("출항 · 직접 조종",launch))

func launch() -> void:
	var response: Dictionary = Game.launch()
	if not response.ok:
		apply_result(response)
		return
	enter_space()

func enter_space() -> void:
	clear_world()
	screen = "space"
	end_pending = false
	world = Space.new()
	world.ended.connect(on_operation_ended)
	add_child(world)
	build_hud()
	refresh_status()
	toast(world.latest_radio,6.0)

func build_combat_controls(commands: HBoxContainer) -> void:
	for i in range(4):
		var index: int = i
		var button = UI.button("",func():world.use_skill(index))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		commands.add_child(button)
		skill_buttons.append(button)
	var interact_button = UI.button("E  상호작용",func():world.interact())
	interact_button.button_down.connect(func():Input.action_press("interact"))
	interact_button.button_up.connect(func():Input.action_release("interact"))
	commands.add_child(interact_button)
	var meters = HBoxContainer.new()
	meters.position = Vector2(40,220)
	meters.size = Vector2(530,58)
	meters.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(meters)
	for entry in [["hull","선체",100],["armor","실드",45],["energy","에너지",100],["heat","발열",100]]:
		var column = VBoxContainer.new()
		column.custom_minimum_size.x = 120
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		meters.add_child(column)
		var text = UI.label(entry[1],14,UI.PAPER)
		column.add_child(text)
		var bar = ProgressBar.new()
		bar.custom_minimum_size = Vector2(115,7)
		bar.max_value = entry[2]
		bar.show_percentage = false
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(bar)
		bars[entry[0]] = {"bar":bar,"label":text,"name":entry[1]}
	radio_label = UI.label("",17,UI.PAPER,true)
	radio_label.position = Vector2(44,756)
	radio_label.size = Vector2(1510,45)
	hud.add_child(radio_label)

func on_operation_ended(success: bool, hull: float) -> void:
	if end_pending:
		return
	end_pending = true
	settle_operation.call_deferred(success,hull)

func settle_operation(success: bool, hull: float) -> void:
	current_report = Game.finish(success,hull)
	show_habitat("cabin")
	open_panel("report")

func report_panel() -> void:
	para("모두를 데려왔습니다." if current_report.get("success",false) else "배는 무사히 돌아왔습니다.",26,UI.INK)
	para(current_report.get("message","정산할 내역이 없습니다."),20)
	para("가구와 함선은 그대로입니다. 잠시 쉬고 다음 항해를 준비하세요. 성공한 현상금은 새로운 항로를 엽니다.")
	panel_body.add_child(UI.button("선내에서 쉬기",func():close_panel();apply_result(Game.rest())))
	panel_body.add_child(UI.button("배 꾸미기",func():open_panel("housing")))
	panel_body.add_child(UI.button("다음 항구 알아보기",func():open_panel("map")))

func map_panel() -> void:
	para("두 항구를 연결하는 첫 항로. 현재 프로토타입의 항구 간 이동은 무료입니다.")
	for id in BHCatalog.PORTS:
		var port: Dictionary = BHCatalog.PORTS[id]
		var content = UI.card(panel_body,port.name,port.text)
		var pid: String = id
		var locked: bool = id=="glass" and int(Game.s.completed)<1
		content.add_child(UI.button("첫 현상금 성공 후 개방" if locked else ("현재 항구" if id==Game.s.port else "이 항구로 이동"),func():travel_to(pid),locked or id==Game.s.port or not Game.s.mission.is_empty()))
	if not Game.s.mission.is_empty():
		para("진행 중인 계약을 정산하거나 취소한 뒤 항구를 이동할 수 있습니다.",16)

func travel_to(id: String) -> void:
	var response: Dictionary = Game.travel(id)
	if response.ok:
		show_habitat("port")
	apply_result(response)

func journal_panel() -> void:
	para("검거 완료 %d건 · 함께 돌아온 기억들" % Game.s.completed,20,UI.INK)
	var entries: Array = Game.s.journal.duplicate()
	entries.reverse()
	for line in entries:
		UI.card(panel_body,str(line))
	panel_body.add_child(UI.button("오픈소스 크레딧",func():toast("가구·경로 탐색: Space Station 14 UlamSpiral (MIT) GDScript 이식. 전체 출처는 THIRD_PARTY_NOTICES.md",12.0)))

func menu_panel() -> void:
	para("우주에서는 이 메뉴를 열면 전투가 일시정지됩니다. Esc로 돌아가세요.")
	para("이동 WASD / 방향키 · 조사 E\n사격 마우스 · 장비 1–4\n가구 회전 R · 선택 가구 판매 Delete",18,UI.INK)
	panel_body.add_child(UI.button("효과음: "+("켜짐" if Sfx.enabled else "꺼짐"),func():Sfx.enabled=not Sfx.enabled;open_panel("menu")))
	if screen=="space":
		panel_body.add_child(UI.button("긴급 철수 · 이번 계약 보수 포기",func():close_panel();world.finish(false)))
	else:
		panel_body.add_child(UI.button("저장하기",save_now))
		panel_body.add_child(UI.button("새 항해 시작…",func():open_panel("new_confirm")))
	panel_body.add_child(UI.button("게임 종료",func():get_tree().quit()))
	para("v0.1 · Godot 4.7.2 · 플레이 가능한 초기 샘플\n우주 중 종료 시 정박 체크포인트에서 재출항합니다. 추가 출항료는 없습니다.",15)

func new_confirm_panel() -> void:
	para("현재 저장을 새 항해로 바꿉니다. 크레딧, 배치, 관계, 진행 중인 계약이 초기화됩니다.",20,UI.INK)
	panel_body.add_child(UI.button("취소 · 계속 항해",close_panel))
	panel_body.add_child(UI.button("초기화하고 새로 시작",func():Game.reset();show_habitat("port")))

func save_now() -> void:
	if Game.s.phase!="dock":
		toast("진행 중인 작전은 출항 체크포인트로 저장되어 있습니다.")
		return
	if not Game.persistence:
		return
	toast("저장했습니다." if Game.save_game() else Game.last_storage_error,6.0)

func toast(message: String, duration: float = 5.0) -> void:
	if not is_instance_valid(toast_label):
		return
	toast_label.text = message
	toast_time = duration
	toast_box.show()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if is_instance_valid(panel):
			close_panel()
		elif world is BHHabitat and world.build_mode:
			world.stop_build()
		else:
			open_panel("menu")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("save"):
		save_now()
	elif event.is_action_pressed("delete_furniture") and world is BHHabitat and world.build_mode and world.moving_uid>=0:
		apply_result(Game.remove_furniture(world.moving_uid))
		world.stop_build()

func _process(delta: float) -> void:
	if is_instance_valid(toast_box):
		toast_time -= delta
		toast_box.visible = toast_time>0.0 and not is_instance_valid(panel)
	if world is BHSpace and is_instance_valid(mission_label):
		mission_label.text = world.objective()
		if world.phase=="pursuit" and world.engine>0:
			mission_label.text += "\n도약까지 %d초  /  표적 엔진 %d" % [maxi(0,int(world.jump_limit-world.pursuit_timer)),world.engine]
		for key in bars:
			bars[key].bar.value = world.get(key)
			bars[key].label.text = bars[key].name+" %d" % world.get(key)
		for i in range(skill_buttons.size()):
			var id: String = Game.s.equipped[i]
			var name: String = BHCatalog.MODULES[id].name
			var cooldown: float = world.cooldowns[i]
			skill_buttons[i].text = "%d   %s  %s" % [i+1,name,"%.1fs" % cooldown if cooldown>0 else "준비"]
			skill_buttons[i].disabled = cooldown>0 or world.energy<float(BHCatalog.MODULES[id].energy) or is_instance_valid(panel)
		if is_instance_valid(radio_label):
			radio_label.text = world.latest_radio
	if Game.persistence and not Game.last_storage_error.is_empty() and is_instance_valid(hint_label):
		hint_label.text = "저장 주의: "+Game.last_storage_error

func capture(name: String) -> void:
	toast_time = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path: String = "res://artifacts/"+name+".png"
	var error: Error = get_viewport().get_texture().get_image().save_png(path)
	if error!=OK:
		push_error("Capture failed: "+name)
		get_tree().quit(1)
	print("CAPTURE "+path)

func capture_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var ignore = FileAccess.open("res://artifacts/.gdignore",FileAccess.WRITE)
	if ignore!=null:
		ignore.close()
	await get_tree().create_timer(0.5).timeout
	await capture("01_rust_harbor")
	open_panel("guild")
	await capture("02_contracts")
	close_panel()
	Game.hire("voss")
	for id in ["sofa","plant","desk","table"]:
		var cell: Vector2i = Game.nearest_cell(id,Vector2i(8,0),false)
		Game.place(id,cell)
	show_habitat("cabin")
	await get_tree().create_timer(0.5).timeout
	await capture("03_living_deck")
	open_panel("outfitter")
	await capture("04_ship_modules")
	close_panel()
	Game.rest()
	Game.accept("mechanic","captain")
	Game.launch()
	enter_space()
	world.simulation_paused = true
	for marker in world.markers:
		world.complete_scan(marker)
	world.position_ship = Vector2(720,485)
	world.ship.position = world.position_ship
	world.target_pos = Vector2(1050,410)
	world.quarry.position = world.target_pos
	world.aim = world.position_ship.direction_to(world.target_pos)
	world.ship.rotation = world.aim.angle()+PI*0.5
	world.active = {"shield":2.0,"tether":3.0}
	world.ship.active = world.active
	world.engine = 63
	world.queue_redraw()
	await capture("05_pursuit")
	world.phase = "boarding"
	world.engine = 0
	world.relay_pos = world.target_pos+Vector2(-67,-45)
	world.latest_radio = "바스: 진입했어. 분홍색 중계기를 쏴 줘! 이후 근처에서 엄호해!"
	world.active = {}
	world.ship.active = {}
	world.queue_redraw()
	await capture("06_boarding")
	print("CAPTURE COMPLETE: 6 real Godot viewport renders; isolated in-memory state.")
	get_tree().quit(0)
