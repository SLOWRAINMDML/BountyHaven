class_name BHSpace
extends Node2D
const Ship = preload("res://scripts/space/ship_visual.gd")
const Hornet = preload("res://scripts/space/hornet_visual.gd")
const Vfx = preload("res://scripts/fx/vfx.gd")
const Catalog = preload("res://scripts/core/catalog.gd")
signal radio(message: String)
signal ended(success: bool, hull: float)
var controls_enabled: bool = true
var simulation_paused: bool = false
var phase: String = "survey"
var ship: BHShipVisual
var quarry: BHShipVisual
## BHVfx (2D) or BHVfx3D; both share one call surface.
var vfx
## Quarter-view 3D presentation: 2D visuals turn invisible and a BHSpaceView3D renders.
var three_d: bool = false
var mouse_provider: Callable
var next_mine_id: int = 1
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
## Raider drones and proximity mines are separate from the capped gunship escorts.
var hornets: Array = []
var mines: Array = []
var asteroids: Array = []
var effects: Array = []
var stars: Array = []
var dust: Array = []
var far_rocks: Array = []
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
var hornet_timer: float = 10.0
var mine_timer: float = 6.0
var fx_timer: float = 0.0
var ghost_timer: float = 0.0
var shake: float = 0.0
var rng = RandomNumberGenerator.new()

func _ready() -> void:
	hunter = Game.active_hunter()
	salvage = Game.s.mission.get("id","") == "salvage"
	condition_bonus = 1.12 if int(Game.s.condition)>=85 else 1.0
	if hunter == "rio":
		jump_limit += 25.0
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Noto Sans CJK KR","Malgun Gothic","Apple SD Gothic Neo","NanumGothic"])
	rng.seed = 823
	# Three parallax star depths; nearer stars are larger and shift more with the ship.
	for i in range(260):
		var depth: int = i%3
		stars.append({"pos":Vector2(rng.randf_range(0,1600),rng.randf_range(0,900)),"size":rng.randf_range(0.5,1.1)+depth*0.45,"alpha":rng.randf_range(0.18,0.65),"depth":depth,"twinkle":rng.randf_range(0.6,3.2),"seed":rng.randf()*TAU})
	for i in range(55):
		dust.append({"pos":Vector2(rng.randf_range(0,1600),rng.randf_range(90,800)),"alpha":rng.randf_range(0.12,0.35)})
	for i in range(16):
		far_rocks.append({"pos":Vector2(rng.randf_range(0,1600),rng.randf_range(120,790)),"r":rng.randf_range(3,9),"rot":rng.randf()*TAU,"spin":rng.randf_range(-0.3,0.3)})
	# Solid rocks give cover from both sides' fire. Kept clear of every objective route.
	for data in [[Vector2(118,520),44],[Vector2(505,735),34],[Vector2(880,248),30],[Vector2(1480,760),55],[Vector2(1535,372),36],[Vector2(735,690),24],[Vector2(300,330),20]]:
		asteroids.append(make_asteroid(data[0],float(data[1])))
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
	if vfx==null:
		vfx = Vfx.new()
		vfx.z_index = 20
		add_child(vfx)
	if three_d:
		for node in [ship,quarry]:
			node.modulate = Color(1,1,1,0)
	# Warp arrival: a flash and trailing speed lines behind the hull.
	vfx.emit("bloom",position_ship,Vector2.ZERO,0.5,20,Color("bfe8dd"),{"grow":140})
	for i in range(14):
		var y: float = position_ship.y+rng.randf_range(-40,40)
		vfx.emit("spark",Vector2(position_ship.x-rng.randf_range(20,180),y),Vector2(-rng.randf_range(600,1400),0),0.5,1,Color("cdeee6"),{"drag":2.5,"width":1.2})
	markers = [{"pos":Vector2(645,395),"done":false},{"pos":Vector2(1105,600),"done":false}]
	if salvage:
		markers.append({"pos":Vector2(1250,350),"done":false})
		say("구호 물자 3개를 회수합니다. 표식에 접근해 E를 누르십시오. 교전은 없습니다.")
	else:
		if bool(Game.s.mission.get("intel",false)):
			markers[0].done = true
			scans = 1
		say("%s: 연료 흔적을 찾았습니다. 신호에 접근해 E로 분석하십시오." % hunter_name())

func make_asteroid(at: Vector2, radius: float) -> Dictionary:
	var points = PackedVector2Array()
	var count: int = 11
	for i in range(count):
		var a: float = TAU*i/count+rng.randf_range(-0.12,0.12)
		points.append(Vector2.from_angle(a)*radius*rng.randf_range(0.78,1.08))
	var craters: Array = []
	for i in range(int(radius/14)+1):
		craters.append([Vector2.from_angle(rng.randf()*TAU)*radius*rng.randf_range(0.1,0.5),radius*rng.randf_range(0.12,0.24)])
	return {"home":at,"pos":at,"r":radius,"points":points,"craters":craters,"rot":rng.randf()*TAU,"spin":rng.randf_range(-0.25,0.25),"phase":rng.randf()*TAU,"hurt":0.0}

func hunter_name() -> String:
	return str(Catalog.HUNTERS[hunter].name) if not hunter.is_empty() else "항법 장치"

func say(message: String) -> void:
	latest_radio = message
	radio.emit(message)

func add_shake(amount: float) -> void:
	shake = minf(18.0,maxf(shake,amount))

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled or simulation_paused or finished:
		return
	if event.is_action_pressed("interact"):
		interact()
	for i in range(4):
		if event.is_action_pressed("skill_"+str(i+1)):
			use_skill(i)

func _process(_delta: float) -> void:
	vfx.frozen = simulation_paused

func _physics_process(delta: float) -> void:
	if simulation_paused:
		return
	# Camera shake and ambient drift keep running briefly after the operation ends.
	shake = maxf(0.0,shake-delta*28.0)
	if not three_d:
		position = Vector2(rng.randf_range(-1,1),rng.randf_range(-1,1))*shake
	update_backdrop(delta)
	if finished:
		queue_redraw()
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
		var mouse: Vector2 = mouse_provider.call() if three_d and mouse_provider.is_valid() else get_local_mouse_position()
		if position_ship.distance_to(mouse)>5.0:
			aim = position_ship.direction_to(mouse)
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and get_viewport().gui_get_hovered_control()==null:
			shoot()
	var speed: float = 670.0 if float(active.get("boost",0.0))>0.0 else 275.0
	velocity_ship = velocity_ship.move_toward(direction*speed,delta*980.0)
	position_ship += velocity_ship*delta
	position_ship.x = clampf(position_ship.x,60,1540)
	position_ship.y = clampf(position_ship.y,212,742)
	collide_ship_with_rocks()
	ship.position = position_ship
	ship.rotation = aim.angle()+PI*0.5
	ship.thrust = velocity_ship.length()/275.0
	ship.active = active
	if float(active.get("tether",0.0))>0.0 and position_ship.distance_to(target_pos)>520:
		active.tether = 0.0
		say("작살 연결이 끊어졌습니다. 표적과의 거리를 유지하십시오.")
	update_objective(delta)
	update_enemies(delta)
	update_hornets(delta)
	update_mines(delta)
	update_projectiles(delta)
	emit_ambient_fx(delta)
	for i in range(effects.size()-1,-1,-1):
		effects[i].life -= delta
		if float(effects[i].life)<=0:
			effects.remove_at(i)
	queue_redraw()

func update_backdrop(delta: float) -> void:
	for rock in asteroids:
		rock.rot += float(rock.spin)*delta
		rock.pos = rock.home+Vector2(sin(clock*0.21+rock.phase)*9,cos(clock*0.17+rock.phase)*7)
		rock.hurt = maxf(0.0,float(rock.hurt)-delta*3.0)
	for rock in far_rocks:
		rock.rot += float(rock.spin)*delta
	# Near dust streams against the ship's motion to sell speed.
	for mote in dust:
		mote.pos += -velocity_ship*0.45*delta+Vector2(-8,2)*delta
		mote.pos.x = fposmod(mote.pos.x,1600.0)
		mote.pos.y = 90.0+fposmod(mote.pos.y-90.0,715.0)

func collide_ship_with_rocks() -> void:
	for rock in asteroids:
		var reach: float = float(rock.r)+34.0
		var offset: Vector2 = position_ship-rock.pos
		if offset.length()<reach and offset.length()>0.01:
			var normal: Vector2 = offset.normalized()
			position_ship = rock.pos+normal*reach
			var impact: float = -velocity_ship.dot(normal)
			if impact>0:
				velocity_ship += normal*impact*1.5
				if impact>120:
					vfx.sparks(rock.pos+normal*float(rock.r),Color("d9c9a4"),normal.angle(),6,220)
					add_shake(3)
					rock.hurt = 1.0

func emit_ambient_fx(delta: float) -> void:
	fx_timer += delta
	ghost_timer -= delta
	# Twin engine wash from the actual engine positions on the rotated hull.
	var thrust: float = velocity_ship.length()/275.0
	if thrust>0.05:
		for x in [-11.0,11.0]:
			var nozzle: Vector2 = position_ship+Vector2(x,34).rotated(ship.rotation)*ship.scale.x
			vfx.emit("dot",nozzle,-velocity_ship*0.2+Vector2(rng.randf_range(-12,12),rng.randf_range(-12,12)),0.35,2.2+thrust*1.4,Color(0.55,0.85,0.8,0.55),{"drag":3.0})
	if float(active.get("boost",0.0))>0.0 and ghost_timer<=0.0:
		ghost_timer = 0.035
		vfx.afterimage(position_ship,ship.rotation,ship.scale.x,Color(0.66,0.93,0.86,0.8))
	if fx_timer<0.06:
		return
	fx_timer = 0.0
	if hull<45:
		vfx.smoke(position_ship+Vector2(rng.randf_range(-10,10),rng.randf_range(-10,10)),Color("4d5b5f"),7.0,-velocity_ship*0.2)
	if hull<25 and rng.randf()<0.35:
		vfx.sparks(position_ship,Color("f0c48a"),rng.randf()*TAU,3,200)
	vfx.vignette = clampf((45.0-hull)/45.0,0.0,1.0)*(0.75+0.25*sin(clock*6.0))
	for enemy in enemies:
		if float(enemy.hp)<22:
			vfx.smoke(enemy.pos,Color("5d5a55"),5.0)
		if enemy.warning and rng.randf()<0.7:
			var from: Vector2 = enemy.pos+Vector2.from_angle(rng.randf()*TAU)*34
			vfx.emit("dot",from,(enemy.pos-from)*3.2,0.28,1.8,Color("f0b08a"),{"drag":0.0})
	if phase in ["pursuit","boarding","extraction"]:
		if engine<=0:
			vfx.smoke(target_pos+Vector2(12,30),Color("4f5859"),9.0,Vector2(0,-8))
			if rng.randf()<0.2:
				vfx.sparks(target_pos+Vector2(10,28),Color("f2cf92"),rng.randf()*TAU,4,180)
		elif target_velocity.length()>1:
			vfx.emit("dot",target_pos-target_velocity.normalized()*42,-target_velocity*0.6,0.4,2.4,Color(0.86,0.6,0.46,0.5),{"drag":2.0})
	if phase=="survey":
		for marker in markers:
			if not marker.done and position_ship.distance_to(marker.pos)<90 and scan_progress>0:
				for n in range(2):
					var from: Vector2 = marker.pos+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(50,80)
					vfx.emit("dot",from,(marker.pos-from)*2.4,0.4,2.0,Color("e1c58e"),{"drag":0.5})
	if phase=="extraction":
		vfx.emit("dot",pod_pos+Vector2(rng.randf_range(-16,16),6),Vector2(0,-rng.randf_range(40,90)),0.8,2.0,Color("e2e5b8"),{"drag":0.4})

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
				vfx.emit("bloom",target_pos,Vector2.ZERO,0.6,30,Color("e8dfc0"),{"grow":200})
				finish(false)
				return
			# The fleeing quarry sows proximity mines behind it.
			mine_timer -= delta
			if mine_timer<=0.0:
				mine_timer = 7.5
				drop_mine()
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
				vfx.ring(pod_pos,Color("d9ddab"),90,0.8,2.5)
				say("%s: 확보했어! 회수 포드로 접근해서 E로 데려가 줘!" % hunter_name())
				Sfx.play("scan")
	if not salvage and phase in ["pursuit","boarding"]:
		hornet_timer -= delta
		if hornet_timer<=0.0:
			hornet_timer = 12.0
			if hornets.size()<2:
				spawn_hornet(Vector2(1560,rng.randf_range(260,700)))

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
		vfx.ring(target_pos,Color("c0a2b9"),120,0.6,2.0)
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
	vfx.ring(marker.pos,Color("e1c58e"),110,0.7,2.0)
	vfx.burst(marker.pos,Color("cfe3d6"),18,60,200,0.7,2.4,"dot",0.0,TAU,{"drag":2.5})
	if scans>=markers.size():
		if salvage:
			finish(true)
		else:
			phase = "pursuit"
			quarry.show()
			vfx.emit("bloom",target_pos,Vector2.ZERO,0.5,24,Color("efe2c2"),{"grow":150})
			vfx.ring(target_pos,Color("d6b98b"),140,0.8,2.0)
			spawn_enemy(Vector2(1160,285))
			spawn_enemy(Vector2(1320,635))
			say("%s: 표적 발견! 제압포로 엔진을 멈춰 줘. 파괴가 아니라 생포야." % hunter_name())
	else:
		say("단서 %d / %d 확보. 다음 신호로 이동하십시오." % [scans,markers.size()])

func warp_in(pos: Vector2, color: Color) -> void:
	vfx.emit("bloom",pos,Vector2.ZERO,0.35,10,Color(color,0.9),{"grow":90})
	vfx.ring(pos,color,70,0.5,1.8)
	for i in range(4):
		vfx.bolt(pos+Vector2.from_angle(rng.randf()*TAU)*60,pos,Color(color,0.8),0.25)

func spawn_enemy(pos: Vector2) -> void:
	if enemies.size()>=3:
		return
	var visual = Ship.new()
	visual.hull_color = Color("a27d69")
	visual.hostile = true
	visual.modules = ["rail"]
	visual.position = pos
	visual.scale = Vector2(0.9,0.9)
	if three_d:
		visual.modulate = Color(1,1,1,0)
	add_child(visual)
	warp_in(pos,Color("e3a986"))
	enemies.append({"node":visual,"pos":pos,"hp":40.0,"timer":1.7+enemies.size()*0.7,"warning":false,"aim":Vector2.LEFT,"stun":0.0,"age":0.0})

func spawn_hornet(pos: Vector2) -> void:
	var visual = Hornet.new()
	visual.position = pos
	visual.scale = Vector2(1.5,1.5)
	if three_d:
		visual.modulate = Color(1,1,1,0)
	add_child(visual)
	warp_in(pos,Color("f0b28c"))
	hornets.append({"node":visual,"pos":pos,"vel":Vector2(-160,0),"hp":16.0,"state":"orbit","timer":rng.randf_range(1.6,2.6),"angle":rng.randf()*TAU,"turn":1.0 if rng.randf()>0.5 else -1.0,"dir":Vector2.LEFT,"stun":0.0})
	say("%s: 약탈 드론이 붙었어! 돌진 전에 눈이 빛나면 옆으로 피해!" % hunter_name())

func drop_mine() -> void:
	if mines.size()>=4:
		return
	var back: Vector2 = -target_velocity.normalized() if target_velocity.length()>1 else Vector2.LEFT
	next_mine_id += 1
	mines.append({"id":next_mine_id,"pos":target_pos+back*52,"vel":back*55,"arm":1.2,"fuse":-1.0,"hp":8.0,"clock":0.0})
	vfx.ring(target_pos+back*52,Color("d19375"),30,0.4,1.4)

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
				vfx.muzzle(enemy.pos+enemy.aim*26,enemy.aim.angle(),Color("f0a67c"))
				enemy.warning = false
				enemy.timer = 2.8
			else:
				enemy.warning = true
				enemy.aim = toward
				enemy.timer = 1.15

func update_hornets(delta: float) -> void:
	for i in range(hornets.size()-1,-1,-1):
		var h: Dictionary = hornets[i]
		h.stun = maxf(0.0,float(h.stun)-delta)
		var node: BHHornetVisual = h.node
		if float(h.stun)>0:
			h.vel = h.vel*maxf(0.0,1.0-3.0*delta)
			h.pos += h.vel*delta
			node.position = h.pos
			node.rotation += delta*9.0
			continue
		h.timer -= delta
		match h.state:
			"orbit":
				h.angle += float(h.turn)*1.25*delta
				var desired: Vector2 = position_ship+Vector2.from_angle(h.angle)*215.0
				h.vel = h.vel.lerp(((desired-h.pos)*2.5).limit_length(320.0),minf(1.0,delta*3.5))
				if float(h.timer)<=0:
					h.state = "charge"
					h.timer = 0.8
			"charge":
				h.vel = h.vel*maxf(0.0,1.0-5.0*delta)
				if float(h.timer)>0.3:
					h.dir = h.pos.direction_to(position_ship)
				if float(h.timer)<=0:
					h.state = "dash"
					h.timer = 0.55
					h.vel = h.dir*780.0
					vfx.ring(h.pos,Color("f0b28c"),34,0.3,1.6)
			"dash":
				vfx.emit("dot",h.pos,Vector2.ZERO,0.25,3.0,Color(0.94,0.66,0.5,0.6),{"drag":0.0})
				if h.pos.distance_to(position_ship)<32:
					var protected: bool = float(active.get("shield",0.0))>0.0 and aim.dot(-h.dir)>cos(deg_to_rad(70.0))
					if protected:
						shield_ripple(position_ship+aim*50)
					else:
						take_damage(10.0)
					h.state = "recover"
					h.timer = 0.9
					h.vel = -h.dir*260.0
				elif float(h.timer)<=0:
					h.state = "recover"
					h.timer = 0.6
			"recover":
				h.vel = h.vel*maxf(0.0,1.0-2.5*delta)
				if float(h.timer)<=0:
					h.state = "orbit"
					h.timer = rng.randf_range(2.2,3.4)
					h.angle = (h.pos-position_ship).angle()
		h.pos += h.vel*delta
		h.pos.x = clampf(h.pos.x,30,1570)
		h.pos.y = clampf(h.pos.y,180,780)
		node.position = h.pos
		node.charging = clampf(1.0-float(h.timer)/0.8,0.0,1.0) if h.state=="charge" else 0.0
		node.dashing = h.state=="dash"
		var facing: Vector2 = h.dir if h.state in ["charge","dash"] else h.vel
		if facing.length()>1.0 or h.state in ["charge","dash"]:
			node.rotation = facing.angle()+PI*0.5

func update_mines(delta: float) -> void:
	for i in range(mines.size()-1,-1,-1):
		var m: Dictionary = mines[i]
		m.clock += delta
		m.vel = m.vel*maxf(0.0,1.0-1.2*delta)
		m.pos += m.vel*delta
		m.arm -= delta
		if float(m.arm)<=0 and float(m.fuse)<0 and m.pos.distance_to(position_ship)<85:
			m.fuse = 0.55
			vfx.ring(m.pos,Color("e5866a"),95,0.55,1.6)
		if float(m.fuse)>=0:
			m.fuse -= delta
			if float(m.fuse)<=0:
				detonate_mine(i)

func detonate_mine(index: int) -> void:
	if index<0 or index>=mines.size():
		return
	var at: Vector2 = mines[index].pos
	mines.remove_at(index)
	vfx.explosion(at,0.8,Color("e59a70"))
	add_shake(9)
	Sfx.play("boom")
	if at.distance_to(position_ship)<100:
		take_damage(14.0)
	# Chain reactions: blasts hurt nearby raiders and other mines too.
	for e in range(enemies.size()-1,-1,-1):
		if enemies[e].pos.distance_to(at)<100:
			damage_enemy(e,30.0)
	for h in range(hornets.size()-1,-1,-1):
		if hornets[h].pos.distance_to(at)<100:
			damage_hornet(h,30.0)
	for n in range(mines.size()-1,-1,-1):
		if mines[n].pos.distance_to(at)<100 and float(mines[n].fuse)<0:
			mines[n].fuse = 0.15

func shoot() -> void:
	if shot_timer>0 or heat>90 or energy<3:
		return
	shot_timer = 0.17
	energy -= 3.0
	heat += 3.0
	projectiles.append({"pos":position_ship+aim*45,"vel":aim*810.0,"life":1.5,"enemy":false,"damage":8.0})
	vfx.muzzle(position_ship+aim*45,aim.angle(),Color("bfe6db"))
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
		for rock in asteroids:
			if hit_segment(rock.pos,previous,shot.pos,float(rock.r)*0.9):
				var normal: Vector2 = (previous-rock.pos).normalized()
				vfx.sparks(rock.pos+normal*float(rock.r)*0.9,Color("dccaa2"),normal.angle(),5,240)
				vfx.burst(rock.pos+normal*float(rock.r)*0.9,Color("6d6a60"),2,40,110,0.8,2.5,"shard",normal.angle(),1.4)
				rock.hurt = 1.0
				consumed = true
				break
		if consumed:
			pass
		elif shot.enemy:
			if hit_segment(position_ship,previous,shot.pos,25):
				var protected: bool = float(active.get("shield",0.0))>0.0 and aim.dot((-shot.vel).normalized())>cos(deg_to_rad(70.0))
				if not protected:
					take_damage(float(shot.damage))
				else:
					shield_ripple(position_ship+aim*50)
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
			if not consumed:
				for h in range(hornets.size()-1,-1,-1):
					if hit_segment(hornets[h].pos,previous,shot.pos,18):
						damage_hornet(h,float(shot.damage))
						consumed = true
						break
			if not consumed:
				for m in range(mines.size()-1,-1,-1):
					if hit_segment(mines[m].pos,previous,shot.pos,14):
						mines[m].hp -= float(shot.damage)
						vfx.sparks(mines[m].pos,Color("f0c48a"),(-shot.vel).angle(),4,200)
						if float(mines[m].hp)<=0:
							detonate_mine(m)
						consumed = true
						break
			if not consumed and phase=="pursuit" and engine>0 and hit_segment(target_pos,previous,shot.pos,35):
				damage_engine(float(shot.damage))
				consumed = true
		if consumed:
			vfx.emit("bloom",shot.pos,Vector2.ZERO,0.14,4,Color("f3e1bd") if not shot.enemy else Color("f0a67c"),{"grow":40})
		if consumed or float(shot.life)<=0:
			projectiles.remove_at(i)

func shield_ripple(at: Vector2) -> void:
	vfx.emit("bloom",at,Vector2.ZERO,0.3,8,Color("b7e3da"),{"grow":60})
	vfx.sparks(at,Color("d8f4ee"),aim.angle(),6,260)
	ship.hurt = 0.3

func damage_enemy(index: int, amount: float) -> void:
	var enemy: Dictionary = enemies[index]
	enemy.hp -= amount
	pulse(enemy.pos,Color("d5a583"),24)
	vfx.sparks(enemy.pos,Color("f2c796"),(enemy.pos-position_ship).angle(),6,300)
	vfx.floating_text(enemy.pos+Vector2(-30,-44),str(int(amount)),Color("f4d3a8"))
	enemy.node.hurt = 1.0
	if float(enemy.hp)<=0:
		pulse(enemy.pos,Color("d5a583"),58)
		vfx.explosion(enemy.pos,1.0)
		add_shake(8)
		Sfx.play("boom")
		enemy.node.queue_free()
		enemies.remove_at(index)

func damage_hornet(index: int, amount: float) -> void:
	var h: Dictionary = hornets[index]
	h.hp -= amount
	h.node.hurt = 1.0
	vfx.sparks(h.pos,Color("f2c796"),(h.pos-position_ship).angle(),4,260)
	if float(h.hp)<=0:
		vfx.explosion(h.pos,0.55,Color("eeb088"))
		add_shake(5)
		Sfx.play("boom")
		h.node.queue_free()
		hornets.remove_at(index)

func damage_engine(amount: float) -> void:
	var before: float = engine
	engine = maxf(0.0,engine-amount)
	pulse(target_pos,Color("a8c9bc"),28)
	vfx.sparks(target_pos+Vector2(0,24),Color("cfe8dd"),(target_pos-position_ship).angle(),7,300)
	vfx.floating_text(target_pos+Vector2(-30,-70),"엔진 -%d" % int(before-engine),Color("cfe8dd"))
	quarry.hurt = 1.0
	if engine<=0 and before>0:
		quarry.disabled = true
		vfx.explosion(target_pos+Vector2(0,26),0.6,Color("a8d6cb"),Color("3f5557"))
		add_shake(6)
		say("%s: 엔진 정지 확인. 표적 가까이 접근해서 E로 접현해 줘." % hunter_name())

func damage_relay(amount: float) -> void:
	relay_hp = maxf(0.0,relay_hp-amount)
	pulse(relay_pos,Color("c0a2b9"),35)
	vfx.sparks(relay_pos,Color("f1d0e2"),(relay_pos-position_ship).angle(),6,260)
	if relay_hp<=0:
		vfx.explosion(relay_pos,0.7,Color("d7a9c8"),Color("5b4a5a"))
		add_shake(6)
		say("%s: 문이 열렸어! 표적 근처를 유지하면서 증원군을 막아 줘." % hunter_name())

func take_damage(amount: float) -> void:
	var blocked: float = minf(armor,amount)
	armor -= blocked
	hull = maxf(0.0,hull-(amount-blocked))
	Sfx.play("hit")
	add_shake(7)
	ship.hurt = 1.0
	vfx.hit_flash(Color("d2785f"),1.0)
	vfx.sparks(position_ship,Color("f4c38e"),rng.randf()*TAU,8,300)
	vfx.floating_text(position_ship+Vector2(-30,-58),"-%d" % int(amount),Color("f2a488") if amount>blocked else Color("b7e3da"))
	if hull<=0:
		vfx.explosion(position_ship,1.5,Color("9fd3c8"))
		add_shake(16)
		ship.hide()
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
			vfx.ring(position_ship,Color("9cd6c6"),70,0.35,2.4)
			vfx.burst(position_ship,Color("c9f1e6"),10,120,260,0.3,1.0,"spark",(-velocity_ship).angle(),1.2)
		"tether":
			active[id] = 5.0
			vfx.bolt(position_ship,target_pos,Color("e8dcaa"),0.3)
			vfx.ring(target_pos,Color("d4c995"),70,0.45,2.0)
		"shield":
			active[id] = 4.0
			vfx.emit("bloom",position_ship+aim*50,Vector2.ZERO,0.35,12,Color("b7e3da"),{"grow":70})
		"emp":
			pulse(position_ship,Color("bca9d2"),240,0.7)
			vfx.ring(position_ship,Color("d5bce8"),240,0.6,3.0)
			vfx.ring(position_ship,Color("9a86b5"),200,0.9,1.2)
			vfx.emit("bloom",position_ship,Vector2.ZERO,0.3,30,Color("d5bce8"),{"grow":200})
			add_shake(5)
			for enemy in enemies:
				if enemy.pos.distance_to(position_ship)<240:
					enemy.stun = 3.0
					vfx.bolt(position_ship,enemy.pos,Color("dcc8f0"))
			for h in hornets:
				if h.pos.distance_to(position_ship)<240:
					h.stun = 3.0
					h.state = "recover"
					h.timer = 0.2
					vfx.bolt(position_ship,h.pos,Color("dcc8f0"))
			# EMP safely fries mine triggers: they fizzle instead of detonating.
			for i in range(mines.size()-1,-1,-1):
				if mines[i].pos.distance_to(position_ship)<240:
					vfx.bolt(position_ship,mines[i].pos,Color("dcc8f0"))
					vfx.burst(mines[i].pos,Color("c9b6e0"),8,40,140,0.6,2.0,"dot")
					mines.remove_at(i)
			for i in range(projectiles.size()-1,-1,-1):
				if projectiles[i].enemy and projectiles[i].pos.distance_to(position_ship)<240:
					vfx.emit("bloom",projectiles[i].pos,Vector2.ZERO,0.25,3,Color("d5bce8"),{"grow":30})
					projectiles.remove_at(i)
			if phase=="pursuit" and target_pos.distance_to(position_ship)<240:
				damage_engine(14)
		"rail":
			var end: Vector2 = position_ship+aim*1200
			effects.append({"kind":"beam","pos":position_ship,"end":end,"life":0.25,"max":0.25,"color":Color("e1cca0")})
			vfx.beam(position_ship+aim*40,end,Color("e8d4a4"),5.0,0.35)
			vfx.muzzle(position_ship+aim*45,aim.angle(),Color("f1ddb0"))
			velocity_ship -= aim*180.0
			add_shake(6)
			if phase=="boarding" and relay_hp>0 and hit_segment(relay_pos,position_ship,end,22):
				damage_relay(36)
			if phase=="pursuit" and engine>0 and hit_segment(target_pos,position_ship,end,35):
				damage_engine(36)
			for i in range(enemies.size()-1,-1,-1):
				if hit_segment(enemies[i].pos,position_ship,end,22):
					damage_enemy(i,36)
			for i in range(hornets.size()-1,-1,-1):
				if hit_segment(hornets[i].pos,position_ship,end,20):
					damage_hornet(i,36)
			for i in range(mines.size()-1,-1,-1):
				if hit_segment(mines[i].pos,position_ship,end,16):
					detonate_mine(i)
		"drone":
			drone_charges -= 1
			hull = minf(100.0,hull+28.0)
			active[id] = 2.5
			pulse(position_ship,Color("bccea1"),75)
			vfx.burst(position_ship,Color("cfe6b4"),16,30,90,1.0,2.4,"dot",-PI*0.5,PI,{"gravity":Vector2(0,-60),"drag":1.0})
			vfx.floating_text(position_ship+Vector2(-30,-60),"+28",Color("cfe6b4"))
	Sfx.play("skill")
	return true

func pulse(at: Vector2, color: Color, radius: float, duration: float = 0.4) -> void:
	effects.append({"kind":"ring","pos":at,"color":color,"radius":radius,"life":duration,"max":duration})

func finish(success: bool) -> void:
	if finished:
		return
	finished = true
	phase = "completed"
	if success:
		vfx.emit("bloom",position_ship,Vector2.ZERO,0.7,30,Color("e2e5b8"),{"grow":260})
		vfx.ring(position_ship,Color("e2e5b8"),220,0.9,2.5)
		vfx.burst(position_ship,Color("f1efcf"),30,80,320,1.0,2.4,"dot",0.0,TAU,{"drag":2.0})
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

func draw_backdrop() -> void:
	draw_rect(Rect2(-40,-40,1680,980),Color("142b38"))
	var drift: Vector2 = position_ship-Vector2(800,480)
	# Painted nebula washes in three pigments drift very slowly behind everything.
	var washes: Array = [[Vector2(820,430),Color(0.37,0.52,0.56,0.022),12,85.0],[Vector2(420,640),Color(0.55,0.42,0.47,0.018),8,70.0],[Vector2(1150,720),Color(0.60,0.53,0.38,0.016),7,90.0]]
	for w in washes:
		for i in range(int(w[2])):
			var c: Vector2 = w[0]+Vector2(i*float(w[3])-float(w[2])*float(w[3])*0.5,-sin(i*0.4+clock*0.03)*140)-drift*0.02
			draw_set_transform(c,-0.3,Vector2(1,0.48))
			draw_circle(Vector2.ZERO,210,w[1])
	draw_set_transform(Vector2.ZERO)
	for star in stars:
		var factor: float = [0.015,0.04,0.08][int(star.depth)]
		var p: Vector2 = star.pos-drift*factor
		p = Vector2(fposmod(p.x,1600.0),fposmod(p.y,900.0))
		var twinkle: float = 0.65+0.35*sin(clock*float(star.twinkle)+float(star.seed))
		draw_circle(p,float(star.size),Color(0.80,0.86,0.80,float(star.alpha)*twinkle))
		if int(star.depth)==2 and float(star.alpha)>0.55:
			var glint: float = float(star.size)*3.0*twinkle
			draw_line(p-Vector2(glint,0),p+Vector2(glint,0),Color(0.85,0.9,0.85,0.25*twinkle),0.6,true)
			draw_line(p-Vector2(0,glint),p+Vector2(0,glint),Color(0.85,0.9,0.85,0.25*twinkle),0.6,true)
	# Distant gas giant with a faint ring and terminator wash.
	var planet: Vector2 = Vector2(1420,123)-drift*0.01
	draw_circle(planet,188,Color("42676d"))
	draw_circle(planet+Vector2(41,-12),176,Color("1e3e4d"))
	for band in range(5):
		draw_arc(planet,188-band*9,2.3,3.6,32,Color(0.62,0.75,0.72,0.06),5,true)
	draw_arc(planet,191,0,TAU,96,Color(0.57,0.72,0.70,0.35),1.2,true)
	draw_set_transform(planet,-0.35,Vector2(1,0.2))
	draw_arc(Vector2.ZERO,300,0.15,PI-0.15,64,Color(0.7,0.78,0.72,0.22),3,true)
	draw_set_transform(Vector2.ZERO)
	# Derelict ring station: slowly turning spokes, blinking beacons.
	var station: Vector2 = Vector2(960,168)-drift*0.02
	draw_set_transform(station,0,Vector2(1,0.42))
	draw_arc(Vector2.ZERO,92,0,TAU,64,Color(0.58,0.70,0.68,0.28),5,true)
	draw_arc(Vector2.ZERO,84,0,TAU,64,Color(0.58,0.70,0.68,0.16),1,true)
	for s in range(6):
		var a: float = clock*0.08+s*TAU/6.0
		draw_line(Vector2.ZERO,Vector2.from_angle(a)*88,Color(0.58,0.70,0.68,0.16),1.2,true)
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(station-Vector2(9,26),Vector2(18,52)),Color(0.35,0.47,0.50,0.5))
	draw_rect(Rect2(station-Vector2(9,26),Vector2(18,52)),Color(0.58,0.70,0.68,0.35),false,1.0)
	for b in [Vector2(-92,0),Vector2(92,0),Vector2(0,-26)]:
		var on: float = 0.5+0.5*sin(clock*2.4+b.x)
		draw_circle(station+b*Vector2(1,0.42 if b.y==0 else 1.0),2.2,Color(0.94,0.66,0.5,0.25+0.6*on))
	for rock in far_rocks:
		var p2: Vector2 = rock.pos-drift*0.03
		draw_set_transform(p2,rock.rot,Vector2(1,0.7))
		draw_circle(Vector2.ZERO,rock.r,Color(0.30,0.40,0.42,0.55))
		draw_arc(Vector2.ZERO,rock.r,-2.2,0.2,12,Color(0.55,0.65,0.62,0.4),0.8,true)
	draw_set_transform(Vector2.ZERO)
	for x in range(0,1600,100):
		draw_line(Vector2(x,210),Vector2(x,757),Color(0.55,0.67,0.66,0.03),0.7)
	for y in range(230,758,100):
		draw_line(Vector2(40,y),Vector2(1560,y),Color(0.55,0.67,0.66,0.03),0.7)
	var streak: Vector2 = -velocity_ship*0.05
	for mote in dust:
		draw_line(mote.pos,mote.pos+streak,Color(0.78,0.86,0.82,float(mote.alpha)),1.0 if streak.length()>2 else 1.6,true)
	for rock in asteroids:
		draw_asteroid(rock)

func draw_asteroid(rock: Dictionary) -> void:
	var r: float = rock.r
	draw_set_transform(rock.pos+Vector2(6,9),rock.rot)
	draw_colored_polygon(rock.points,Color(0.03,0.08,0.11,0.35))
	draw_set_transform(rock.pos,rock.rot)
	var base: Color = Color("5f6660").lerp(Color("d7cdb3"),float(rock.hurt)*0.5)
	draw_colored_polygon(rock.points,base)
	# Lit side wash and pen outline in the house ink.
	var lit = PackedVector2Array()
	for p in rock.points:
		lit.append(p*0.82+Vector2(-r*0.14,-r*0.14).rotated(-rock.rot))
	draw_colored_polygon(lit,Color(0.62,0.64,0.57,0.55))
	for crater in rock.craters:
		draw_circle(crater[0],crater[1],Color(0.26,0.31,0.31,0.45))
		draw_arc(crater[0],crater[1],-2.6,0.2,10,Color(0.80,0.78,0.68,0.45),0.9,true)
	var outline: PackedVector2Array = rock.points.duplicate()
	outline.append(rock.points[0])
	draw_polyline(outline,Color("2a3c43"),1.4,true)
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	if three_d:
		draw_screen_overlay()
		return
	draw_backdrop()
	if phase=="survey":
		for i in range(markers.size()):
			var marker: Dictionary = markers[i]
			if marker.done:
				continue
			var point: Vector2 = marker.pos
			draw_circle(point,34+sin(clock*2)*3,Color(0.53,0.72,0.70,0.07))
			draw_arc(point,38+sin(clock*2)*3,0,TAU,48,Color("86b8b4"),1.0,true)
			draw_arc(point,90,clock*0.4,clock*0.4+TAU*0.85,56,Color(0.6,0.8,0.75,0.2),0.7,true)
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
		draw_circle(relay_pos,20+sin(clock*5)*2,Color(0.75,0.55,0.70,0.18))
		draw_circle(relay_pos,14,Color("a3809f"))
		draw_arc(relay_pos,23,clock*2,clock*2+TAU*0.75,32,Color("e2bfd3"),1.2,true)
		draw_string(font,relay_pos+Vector2(-30,-30),"중계기",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("e0c7d2"))
	if phase=="extraction":
		draw_circle(pod_pos,40,Color(0.85,0.87,0.67,0.08))
		draw_circle(pod_pos,14,Color("bfccad"))
		draw_arc(pod_pos,30+sin(clock*3)*5,0,TAU,32,Color("d9ddab"),2,true)
		draw_string(font,pod_pos+Vector2(-40,53),"[E] 회수",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("e7e4c4"))
	for m in mines:
		var armed: bool = float(m.arm)<=0
		var blink: float = 0.5+0.5*sin(float(m.clock)*(22.0 if float(m.fuse)>=0 else 5.0))
		if float(m.fuse)>=0:
			draw_circle(m.pos,100,Color(0.9,0.45,0.35,0.05+0.07*blink))
			draw_arc(m.pos,100,0,TAU,48,Color(0.9,0.52,0.4,0.5),1.0,true)
		elif armed:
			draw_arc(m.pos,85,0,TAU,40,Color(0.85,0.55,0.45,0.10),0.8,true)
		for s in range(6):
			var a: float = float(m.clock)*0.8+s*TAU/6.0
			draw_line(m.pos+Vector2.from_angle(a)*10,m.pos+Vector2.from_angle(a)*17,Color("2f3f45"),2.2,true)
		draw_circle(m.pos,11,Color("7d6a5c"))
		draw_circle(m.pos+Vector2(-3,-3),5,Color(0.72,0.62,0.52,0.6))
		draw_arc(m.pos,11,0,TAU,20,Color("2f3f45"),1.2,true)
		draw_circle(m.pos,3.5,Color(0.98,0.55,0.4,0.35+0.65*blink) if armed else Color(0.6,0.6,0.55,0.6))
	for enemy in enemies:
		if enemy.warning and float(enemy.stun)<=0:
			draw_line(enemy.pos,enemy.pos+enemy.aim*800,Color(0.9,0.5,0.37,0.18+float(enemy.timer)*0.1),1.3,true)
			draw_arc(enemy.pos,35,-PI*0.5,-PI*0.5+TAU*clampf(1.0-float(enemy.timer)/1.15,0,1),32,Color("d19375"),2,true)
			draw_circle(enemy.pos+enemy.aim*26,4+6*clampf(1.0-float(enemy.timer)/1.15,0,1),Color(0.95,0.66,0.5,0.35))
		if float(enemy.stun)>0:
			draw_arc(enemy.pos,31,0,TAU,32,Color("c2a9d6"),1.2,true)
			for k in range(3):
				var a2: float = clock*6+k*TAU/3
				draw_line(enemy.pos+Vector2.from_angle(a2)*24,enemy.pos+Vector2.from_angle(a2+0.5)*33,Color("dcc8f0"),1.0,true)
	for h in hornets:
		if h.state=="charge":
			var reach: float = 780.0*0.55
			var charge: float = clampf(1.0-float(h.timer)/0.8,0.0,1.0)
			draw_line(h.pos,h.pos+h.dir*reach,Color(0.98,0.7,0.55,0.05+0.08*charge),12.0*charge+2,true)
			for k in range(10):
				var t4: float = k/10.0
				draw_line(h.pos+h.dir*reach*t4,h.pos+h.dir*reach*(t4+0.05),Color(0.98,0.74,0.58,0.25+0.5*charge),1.2,true)
		if float(h.stun)>0:
			draw_arc(h.pos,22,0,TAU,24,Color("c2a9d6"),1.0,true)
	for shot in projectiles:
		var color = Color("e2a27c") if shot.enemy else Color("bbdcd2")
		var dir: Vector2 = shot.vel.normalized()
		draw_circle(shot.pos,7,Color(color,0.12))
		draw_line(shot.pos-dir*20,shot.pos,Color(color,0.35),4.0,true)
		draw_line(shot.pos-dir*13,shot.pos,color,2.3,true)
		draw_circle(shot.pos,2.0,Color(1,0.97,0.9,0.9))
	if float(active.get("tether",0.0))>0:
		# Ion harpoon: a sagging, humming line with beads travelling toward the target.
		var points = PackedVector2Array()
		var normal: Vector2 = (target_pos-position_ship).orthogonal().normalized()
		for k in range(21):
			var t: float = k/20.0
			points.append(position_ship.lerp(target_pos,t)+normal*sin(t*PI*3+clock*14)*5*sin(t*PI))
		draw_polyline(points,Color(0.83,0.79,0.58,0.3),5,true)
		draw_polyline(points,Color("d4c995"),1.8,true)
		for k in range(3):
			var t2: float = fposmod(clock*1.4+k/3.0,1.0)
			draw_circle(position_ship.lerp(target_pos,t2),3,Color("f2ecc8"))
		draw_arc(target_pos,56,0,TAU,48,Color("d4c995"),1.2,true)
	if float(active.get("shield",0.0))>0:
		var arc_from: float = aim.angle()-deg_to_rad(70)
		var arc_to: float = aim.angle()+deg_to_rad(70)
		draw_arc(position_ship,65,arc_from,arc_to,40,Color(0.72,0.89,0.85,0.18),14,true)
		draw_arc(position_ship,65,arc_from,arc_to,40,Color("b7e3da"),3,true)
		for k in range(5):
			var a3: float = lerpf(arc_from,arc_to,(k+0.5)/5.0)
			draw_arc(position_ship,65,a3-0.08,a3+0.08,6,Color(1,1,1,0.3+0.3*sin(clock*8+k)),5,true)
	for effect in effects:
		var progress: float = 1.0-float(effect.life)/float(effect.max)
		var color: Color = Color(effect.color,1.0-progress)
		if effect.kind=="ring":
			draw_arc(effect.pos,maxf(1.0,float(effect.radius)*progress),0,TAU,64,color,1.7,true)
	# Small crosshair makes the actual aiming direction legible.
	var cursor: Vector2 = get_local_mouse_position()
	if cursor.y>215 and cursor.y<745:
		var spin: float = clock*1.5
		draw_arc(cursor,10,spin,spin+PI*0.6,12,Color(0.7,0.82,0.76,0.75),1.0,true)
		draw_arc(cursor,10,spin+PI,spin+PI*1.6,12,Color(0.7,0.82,0.76,0.75),1.0,true)
		draw_line(cursor+Vector2(-16,0),cursor+Vector2(-8,0),Color("aecdc3"),1,true)
		draw_line(cursor+Vector2(8,0),cursor+Vector2(16,0),Color("aecdc3"),1,true)
		draw_circle(cursor,1.5,Color("d8ece4"))

## 3D mode: the world renders in BHSpaceView3D; only screen-space aim and hit feedback stay 2D.
func draw_screen_overlay() -> void:
	if float(vfx.vignette)>0.01:
		for i in range(6):
			var inset: float = 22.0*i
			draw_rect(Rect2(Vector2(inset,86+inset),Vector2(1600-inset*2,720-inset*2)),Color(vfx.vignette_color,vfx.vignette*0.09*(6-i)/6.0),false,24.0)
	if float(vfx.flash)>0.01:
		draw_rect(Rect2(0,86,1600,720),Color(vfx.flash_color,vfx.flash*0.2))
	var cursor: Vector2 = get_local_mouse_position()
	if cursor.y>95 and cursor.y<800:
		var spin: float = clock*1.5
		draw_arc(cursor,11,spin,spin+PI*0.6,12,Color(0.8,0.95,0.9,0.9),1.4,true)
		draw_arc(cursor,11,spin+PI,spin+PI*1.6,12,Color(0.8,0.95,0.9,0.9),1.4,true)
		draw_line(cursor+Vector2(-18,0),cursor+Vector2(-8,0),Color("cfeee6"),1.2,true)
		draw_line(cursor+Vector2(8,0),cursor+Vector2(18,0),Color("cfeee6"),1.2,true)
		draw_circle(cursor,1.6,Color("e8f6f1"))
