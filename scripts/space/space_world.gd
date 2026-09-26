class_name BHSpace
extends Node2D
const Ship = preload("res://scripts/space/ship_visual.gd")
const Catalog = preload("res://scripts/core/catalog.gd")
signal radio(message: String)
signal ended(success: bool, hull: float)
var controls_enabled: bool = true
var simulation_paused: bool = false
var phase: String = "survey"
var ship: BHShipVisual
var quarry: BHShipVisual
var position_ship = Vector2(320,610)
var velocity_ship = Vector2.ZERO
var aim = Vector2.RIGHT
var hull: float = 100.0
var armor: float = 45.0
var energy: float = 100.0
var heat: float = 0.0
var condition_bonus: float = 1.0
var engine: float = 100.0
var target_pos = Vector2(1140,425)
var target_velocity = Vector2.ZERO
var cooldowns: Array = [0.0,0.0,0.0,0.0]
var active: Dictionary = {}
var projectiles: Array = []
var enemies: Array = []
var effects: Array = []
var stars: Array = []
var markers: Array = []
var scans: int = 0
var scan_progress: float = 0.0
var clock: float = 0.0
var shot_timer: float = 0.0
var pursuit_timer: float = 0.0
var jump_limit: float = 120.0
var boarding_timer: float = 0.0
var relay_hp: float = 32.0
var relay_pos = Vector2.ZERO
var pod_pos = Vector2.ZERO
var drone_charges: int = 2
var hunter: String = ""
var salvage: bool = false
var finished: bool = false
var font: Font
var latest_radio: String = ""

func _ready() -> void:
	hunter = Game.active_hunter()
	salvage = Game.s.mission.get("id","") == "salvage"
	condition_bonus = 1.12 if int(Game.s.condition)>=85 else 1.0
	if hunter == "rio":
		jump_limit += 25.0
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Noto Sans CJK KR","Malgun Gothic","Apple SD Gothic Neo","NanumGothic"])
	var rng = RandomNumberGenerator.new()
	rng.seed = 823
	for i in range(210):
		stars.append([Vector2(rng.randf_range(0,1600),rng.randf_range(0,900)),rng.randf_range(0.5,1.8),rng.randf_range(0.18,0.65)])
	ship = Ship.new()
	ship.modules = Game.s.equipped.duplicate()
	ship.position = position_ship
	ship.scale = Vector2(1.45,1.45)
	add_child(ship)
	quarry = Ship.new()
	quarry.hull_color = Color("bca98b")
	quarry.hostile = true
	quarry.modules = ["boost","drone"]
	quarry.position = target_pos
	quarry.scale = Vector2(1.5,1.5)
	quarry.hide()
	add_child(quarry)
	markers = [{"pos":Vector2(645,395),"done":false},{"pos":Vector2(1105,600),"done":false}]
	if salvage:
		markers.append({"pos":Vector2(1250,350),"done":false})
		say("구호 물자 3개를 회수합니다. 표식에 접근해 E를 누르십시오. 교전은 없습니다.")
	else:
		if bool(Game.s.mission.get("intel",false)):
			markers[0].done = true
			scans = 1
		say("%s: 연료 흔적을 찾았습니다. 신호에 접근해 E로 분석하십시오." % hunter_name())

func hunter_name() -> String:
	return str(Catalog.HUNTERS[hunter].name) if not hunter.is_empty() else "항법 장치"

func say(message: String) -> void:
	latest_radio = message
	radio.emit(message)

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled or simulation_paused or finished:
		return
	if event.is_action_pressed("interact"):
		interact()
	for i in range(4):
		if event.is_action_pressed("skill_"+str(i+1)):
			use_skill(i)

func _physics_process(delta: float) -> void:
	if finished or simulation_paused:
		return
	clock += delta
	shot_timer = maxf(0.0,shot_timer-delta)
	for i in range(4):
		cooldowns[i] = maxf(0.0,float(cooldowns[i])-delta)
	for key in active.keys():
		active[key] = maxf(0.0,float(active[key])-delta)
	energy = minf(100.0,energy+delta*15.0*condition_bonus)
	heat = maxf(0.0,heat-delta*13.0*condition_bonus)
	armor = minf(45.0,armor+delta*1.8)
	var direction = Vector2.ZERO
	if controls_enabled:
		direction = Input.get_vector("left","right","up","down")
		var mouse: Vector2 = get_global_mouse_position()
		if position_ship.distance_to(mouse)>5.0:
			aim = position_ship.direction_to(mouse)
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and get_viewport().gui_get_hovered_control()==null:
			shoot()
	var speed: float = 670.0 if float(active.get("boost",0.0))>0.0 else 275.0
	velocity_ship = velocity_ship.move_toward(direction*speed,delta*980.0)
	position_ship += velocity_ship*delta
	position_ship.x = clampf(position_ship.x,60,1540)
	position_ship.y = clampf(position_ship.y,212,742)
	ship.position = position_ship
	ship.rotation = aim.angle()+PI*0.5
	ship.thrust = velocity_ship.length()/275.0
	ship.active = active
	if float(active.get("tether",0.0))>0.0 and position_ship.distance_to(target_pos)>520:
		active.tether = 0.0
		say("작살 연결이 끊어졌습니다. 표적과의 거리를 유지하십시오.")
	update_objective(delta)
	update_enemies(delta)
	update_projectiles(delta)
	for i in range(effects.size()-1,-1,-1):
		effects[i].life -= delta
		if float(effects[i].life)<=0:
			effects.remove_at(i)
	queue_redraw()

func update_objective(delta: float) -> void:
	if phase == "survey":
		if controls_enabled and Input.is_action_pressed("interact"):
			for marker in markers:
				if not marker.done and position_ship.distance_to(marker.pos)<90:
					scan_progress += delta*(1.5 if hunter=="rio" else 1.0)
					if scan_progress>=0.9:
						complete_scan(marker)
					return
		scan_progress = 0.0
	elif phase == "pursuit":
		if engine>0:
			var desired = Vector2(1070+sin(clock*0.35)*200,440+cos(clock*0.43)*125)
			target_velocity = target_pos.direction_to(desired)*(35.0 if float(active.get("tether",0.0))>0 else 92.0)
			target_pos += target_velocity*delta
			if float(active.get("tether",0.0))<=0.0:
				pursuit_timer += delta
			if pursuit_timer>jump_limit:
				finish(false)
				return
		else:
			target_velocity = Vector2.ZERO
		quarry.position = target_pos
		if target_velocity.length()>1:
			quarry.rotation = target_velocity.angle()+PI*0.5
		quarry.thrust = target_velocity.length()/100.0
	elif phase == "boarding":
		relay_pos = target_pos+Vector2(-67,-45)
		if relay_hp<=0 and position_ship.distance_to(target_pos)<480:
			boarding_timer += delta
			var duration: float = 12.0 if hunter=="voss" else 15.0
			if boarding_timer>=duration:
				phase = "extraction"
				pod_pos = target_pos+Vector2(-150,95)
				say("%s: 확보했어! 회수 포드로 접근해서 E로 데려가 줘!" % hunter_name())
				Sfx.play("scan")

func interact() -> void:
	if finished:
		return
	if phase == "survey":
		say("E를 누른 채 신호 반경 안에 머무르면 분석·회수할 수 있습니다.")
	elif phase == "pursuit" and engine<=0:
		var reach: float = 195.0 if hunter=="voss" else 150.0
		if position_ship.distance_to(target_pos)>reach:
			say("접현하려면 표적에 더 가까이 접근하십시오.")
			return
		phase = "boarding"
		relay_pos = target_pos+Vector2(-67,-45)
		relay_hp = 20.0 if hunter=="rio" else 32.0
		spawn_enemy(Vector2(1350,310))
		say("%s: 진입했어. 분홍색 보안 중계기를 쏴 줘! 이후 근처에서 회수를 엄호해!" % hunter_name())
	elif phase == "extraction":
		if position_ship.distance_to(pod_pos)<100:
			finish(true)
		else:
			say("회수 포드에 접근한 뒤 E를 누르십시오.")

func complete_scan(marker: Dictionary) -> void:
	if marker.done or phase!="survey":
		return
	marker.done = true
	scans += 1
	scan_progress = 0.0
	Sfx.play("scan")
	pulse(marker.pos,Color("9ac6bc"),65)
	if scans>=markers.size():
		if salvage:
			finish(true)
		else:
			phase = "pursuit"
			quarry.show()
			spawn_enemy(Vector2(1160,285))
			spawn_enemy(Vector2(1320,635))
			say("%s: 표적 발견! 제압포로 엔진을 멈춰 줘. 파괴가 아니라 생포야." % hunter_name())
	else:
		say("단서 %d / %d 확보. 다음 신호로 이동하십시오." % [scans,markers.size()])

func spawn_enemy(pos: Vector2) -> void:
	if enemies.size()>=3:
		return
	var visual = Ship.new()
	visual.hull_color = Color("a27d69")
	visual.hostile = true
	visual.modules = ["rail"]
	visual.position = pos
	visual.scale = Vector2(0.9,0.9)
	add_child(visual)
	enemies.append({"node":visual,"pos":pos,"hp":40.0,"timer":1.7+enemies.size()*0.7,"warning":false,"aim":Vector2.LEFT,"stun":0.0,"age":0.0})

func update_enemies(delta: float) -> void:
	for enemy in enemies:
		enemy.age += delta
		enemy.stun = maxf(0.0,float(enemy.stun)-delta)
		if float(enemy.stun)>0:
			continue
		var toward: Vector2 = enemy.pos.direction_to(position_ship)
		if enemy.pos.distance_to(position_ship)>300:
			enemy.pos += toward*45.0*delta
		enemy.node.position = enemy.pos
		enemy.node.rotation = toward.angle()+PI*0.5
		enemy.node.thrust = 0.4
		enemy.timer -= delta
		if float(enemy.timer)<=0:
			if enemy.warning:
				projectiles.append({"pos":enemy.pos,"vel":enemy.aim*295.0,"life":4.0,"enemy":true,"damage":12.0})
				enemy.warning = false
				enemy.timer = 2.8
			else:
				enemy.warning = true
				enemy.aim = toward
				enemy.timer = 1.15

func shoot() -> void:
	if shot_timer>0 or heat>90 or energy<3:
		return
	shot_timer = 0.17
	energy -= 3.0
	heat += 3.0
	projectiles.append({"pos":position_ship+aim*45,"vel":aim*810.0,"life":1.5,"enemy":false,"damage":8.0})
	Sfx.play("laser")

func hit_segment(point: Vector2, a: Vector2, b: Vector2, radius: float) -> bool:
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point,a,b))<=radius

func update_projectiles(delta: float) -> void:
	for i in range(projectiles.size()-1,-1,-1):
		var shot: Dictionary = projectiles[i]
		var previous: Vector2 = shot.pos
		shot.pos += shot.vel*delta
		shot.life -= delta
		var consumed: bool = false
		if shot.enemy:
			if hit_segment(position_ship,previous,shot.pos,25):
				var protected: bool = float(active.get("shield",0.0))>0.0 and aim.dot((-shot.vel).normalized())>cos(deg_to_rad(70.0))
				if not protected:
					take_damage(float(shot.damage))
				pulse(position_ship,Color("8fc3bf") if protected else Color("cc9276"),32)
				consumed = true
		else:
			# Small boarding objective has precedence over the adjacent target hull.
			if phase=="boarding" and relay_hp>0 and hit_segment(relay_pos,previous,shot.pos,22):
				damage_relay(float(shot.damage))
				consumed = true
			if not consumed:
				for e in range(enemies.size()-1,-1,-1):
					if hit_segment(enemies[e].pos,previous,shot.pos,21):
						damage_enemy(e,float(shot.damage))
						consumed = true
						break
			if not consumed and phase=="pursuit" and engine>0 and hit_segment(target_pos,previous,shot.pos,35):
				damage_engine(float(shot.damage))
				consumed = true
		if consumed or float(shot.life)<=0:
			projectiles.remove_at(i)

func damage_enemy(index: int, amount: float) -> void:
	enemies[index].hp -= amount
	pulse(enemies[index].pos,Color("d5a583"),24)
	if float(enemies[index].hp)<=0:
		pulse(enemies[index].pos,Color("d5a583"),58)
		enemies[index].node.queue_free()
		enemies.remove_at(index)

func damage_engine(amount: float) -> void:
	engine = maxf(0.0,engine-amount)
	pulse(target_pos,Color("a8c9bc"),28)
	if engine<=0:
		quarry.disabled = true
		say("%s: 엔진 정지 확인. 표적 가까이 접근해서 E로 접현해 줘." % hunter_name())

func damage_relay(amount: float) -> void:
	relay_hp = maxf(0.0,relay_hp-amount)
	pulse(relay_pos,Color("c0a2b9"),35)
	if relay_hp<=0:
		say("%s: 문이 열렸어! 표적 근처를 유지하면서 증원군을 막아 줘." % hunter_name())

func take_damage(amount: float) -> void:
	var blocked: float = minf(armor,amount)
	armor -= blocked
	hull = maxf(0.0,hull-(amount-blocked))
	Sfx.play("hit")
	if hull<=0:
		finish(false)

func use_skill(slot: int) -> bool:
	if slot<0 or slot>=4 or finished or simulation_paused:
		return false
	var id: String = str(Game.s.equipped[slot])
	var def: Dictionary = Catalog.MODULES[id]
	if float(cooldowns[slot])>0 or energy<float(def.energy) or heat+float(def.heat)>100:
		say("장비 재사용 대기, 에너지 또는 발열 한도를 확인하십시오.")
		return false
	if id=="tether" and (phase!="pursuit" or position_ship.distance_to(target_pos)>420):
		say("이온 작살은 추격 중 표적과 거리 420 이내에서 사용할 수 있습니다.")
		return false
	if id=="drone" and (drone_charges<=0 or hull>=100):
		say("정비 드론은 선체 손상 시 사용 가능합니다. 남은 출격: %d" % drone_charges)
		return false
	energy -= float(def.energy)
	heat += float(def.heat)
	cooldowns[slot] = float(def.cooldown)
	active[id] = 0.9
	match id:
		"boost":
			active[id] = 0.42
			var direction: Vector2 = Input.get_vector("left","right","up","down")
			velocity_ship = (aim if direction.is_zero_approx() else direction)*670
			pulse(position_ship,Color("9cd6c6"),55)
		"tether": active[id] = 5.0
		"shield": active[id] = 4.0
		"emp":
			pulse(position_ship,Color("bca9d2"),240,0.7)
			for enemy in enemies:
				if enemy.pos.distance_to(position_ship)<240:
					enemy.stun = 3.0
			for i in range(projectiles.size()-1,-1,-1):
				if projectiles[i].enemy and projectiles[i].pos.distance_to(position_ship)<240:
					projectiles.remove_at(i)
			if phase=="pursuit" and target_pos.distance_to(position_ship)<240:
				damage_engine(14)
		"rail":
			var end: Vector2 = position_ship+aim*1200
			effects.append({"kind":"beam","pos":position_ship,"end":end,"life":0.25,"max":0.25,"color":Color("e1cca0")})
			if phase=="boarding" and relay_hp>0 and hit_segment(relay_pos,position_ship,end,22):
				damage_relay(36)
			if phase=="pursuit" and engine>0 and hit_segment(target_pos,position_ship,end,35):
				damage_engine(36)
			for i in range(enemies.size()-1,-1,-1):
				if hit_segment(enemies[i].pos,position_ship,end,22):
					damage_enemy(i,36)
		"drone":
			drone_charges -= 1
			hull = minf(100.0,hull+28.0)
			active[id] = 2.5
			pulse(position_ship,Color("bccea1"),75)
	Sfx.play("skill")
	return true

func pulse(at: Vector2, color: Color, radius: float, duration: float = 0.4) -> void:
	effects.append({"kind":"ring","pos":at,"color":color,"radius":radius,"life":duration,"max":duration})

func finish(success: bool) -> void:
	if finished:
		return
	finished = true
	phase = "completed"
	Sfx.play("win" if success else "hit")
	ended.emit(success,hull)

func objective() -> String:
	match phase:
		"survey": return ("물자 회수" if salvage else "연료 신호 분석")+"  %d / %d  ·  가까이서 E 누르기" % [scans,markers.size()]
		"pursuit": return "엔진 제압 후 가까이서 E로 접현" if engine>0 else "엔진 정지 · 표적에 접근해 E로 접현"
		"boarding":
			if relay_hp>0:
				return "추적자 지원 · 분홍색 보안 중계기 파괴"
			return "표적과 거리 480 이내 유지 · 엄호 %.0f / %d초" % [boarding_timer,12 if hunter=="voss" else 15]
		"extraction": return "회수 포드에 접근 · E로 동료와 표적 회수"
	return "귀환 준비"

func _draw() -> void:
	draw_rect(Rect2(0,0,1600,900),Color("142b38"))
	for star in stars:
		draw_circle(star[0],star[1],Color(0.80,0.86,0.80,star[2]))
	# Original painted-looking nebula washes, not a downloaded background image.
	for i in range(12):
		draw_set_transform(Vector2(800+i*85,430-sin(i*0.4)*160),-0.3,Vector2(1,0.48))
		draw_circle(Vector2.ZERO,210,Color(0.37,0.52,0.56,0.021))
	draw_set_transform(Vector2.ZERO)
	draw_circle(Vector2(1420,123),188,Color("42676d"))
	draw_circle(Vector2(1461,111),176,Color("1e3e4d"))
	draw_arc(Vector2(1420,123),191,0,TAU,96,Color(0.57,0.72,0.70,0.35),1.2,true)
	for x in range(0,1600,100):
		draw_line(Vector2(x,210),Vector2(x,757),Color(0.55,0.67,0.66,0.035),0.7)
	for y in range(230,758,100):
		draw_line(Vector2(40,y),Vector2(1560,y),Color(0.55,0.67,0.66,0.035),0.7)
	if phase=="survey":
		for i in range(markers.size()):
			var marker: Dictionary = markers[i]
			if marker.done:
				continue
			var point: Vector2 = marker.pos
			draw_arc(point,38+sin(clock*2)*3,0,TAU,48,Color("86b8b4"),1.0,true)
			draw_arc(point,90,0,TAU,56,Color(0.6,0.8,0.75,0.16),0.7,true)
			draw_rect(Rect2(point-Vector2(9,12),Vector2(18,24)),Color("b8b79d"),false,1.5)
			draw_string(font,point+Vector2(-40,62),"화물 %d" % (i+1) if salvage else "신호 %d" % (i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("c3d3c7"))
			if position_ship.distance_to(point)<90:
				draw_arc(point,46,-PI*0.5,-PI*0.5+TAU*minf(1.0,scan_progress/0.9),48,Color("e1c58e"),3,true)
	if phase in ["pursuit","boarding","extraction"]:
		draw_arc(target_pos,65,0,TAU,64,Color(0.83,0.71,0.50,0.48),1.0,true)
		draw_rect(Rect2(target_pos+Vector2(-45,63),Vector2(90,4)),Color("38515b"))
		draw_rect(Rect2(target_pos+Vector2(-45,63),Vector2(90*engine/100.0,4)),Color("ccb783"))
		draw_string(font,target_pos+Vector2(-46,86),"엔진 %d%%" % int(engine),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("d8d2b7"))
	if phase=="boarding" and relay_hp>0:
		draw_line(target_pos,relay_pos,Color("b093b4"),1.2,true)
		draw_circle(relay_pos,14,Color("a3809f"))
		draw_arc(relay_pos,23,0,TAU,32,Color("e2bfd3"),1.2,true)
		draw_string(font,relay_pos+Vector2(-30,-30),"중계기",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("e0c7d2"))
	if phase=="extraction":
		draw_circle(pod_pos,14,Color("bfccad"))
		draw_arc(pod_pos,30+sin(clock*3)*5,0,TAU,32,Color("d9ddab"),2,true)
		draw_string(font,pod_pos+Vector2(-40,53),"[E] 회수",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("e7e4c4"))
	for enemy in enemies:
		if enemy.warning and float(enemy.stun)<=0:
			draw_line(enemy.pos,enemy.pos+enemy.aim*800,Color(0.9,0.5,0.37,0.18+float(enemy.timer)*0.1),1.3,true)
			draw_arc(enemy.pos,35,-PI*0.5,-PI*0.5+TAU*clampf(1.0-float(enemy.timer)/1.15,0,1),32,Color("d19375"),2,true)
		if float(enemy.stun)>0:
			draw_arc(enemy.pos,31,0,TAU,32,Color("c2a9d6"),1.2,true)
	for shot in projectiles:
		var color = Color("e2a27c") if shot.enemy else Color("bbdcd2")
		draw_line(shot.pos-shot.vel.normalized()*13,shot.pos,color,2.3,true)
		draw_circle(shot.pos,4,Color(color,0.16))
	if float(active.get("tether",0.0))>0:
		draw_line(position_ship,target_pos,Color("d4c995"),1.8,true)
		draw_arc(target_pos,56,0,TAU,48,Color("d4c995"),1.2,true)
	if float(active.get("shield",0.0))>0:
		draw_arc(position_ship,65,aim.angle()-deg_to_rad(70),aim.angle()+deg_to_rad(70),40,Color("b7e3da"),4,true)
	for effect in effects:
		var progress: float = 1.0-float(effect.life)/float(effect.max)
		var color: Color = Color(effect.color,1.0-progress)
		if effect.kind=="beam":
			draw_line(effect.pos,effect.end,color,3,true)
		else:
			draw_arc(effect.pos,maxf(1.0,float(effect.radius)*progress),0,TAU,64,color,1.7,true)
	# Small crosshair makes the actual aiming direction legible.
	var cursor: Vector2 = get_global_mouse_position()
	if cursor.y>215 and cursor.y<745:
		draw_arc(cursor,10,0,TAU,24,Color(0.7,0.82,0.76,0.65),0.8,true)
		draw_line(cursor+Vector2(-16,0),cursor+Vector2(-8,0),Color("aecdc3"),1,true)
		draw_line(cursor+Vector2(8,0),cursor+Vector2(16,0),Color("aecdc3"),1,true)
