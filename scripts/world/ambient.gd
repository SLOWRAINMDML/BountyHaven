class_name BHAmbient
extends Node2D
## Living-world layer for the harbor and cabin: gulls, drifting pollen, water glints,
## steam, fluttering bunting, footstep dust, click ripples and starlight past the windows.
## Cosmetic only; never touches navigation or saved state.
var place_kind: String = "port"
var clock: float = 0.0
var rng = RandomNumberGenerator.new()
var birds: Array = []
var motes: Array = []
var puffs: Array = []
var ripples: Array = []
var window_stars: Array = []
var steam_timer: float = 0.0
var water: PackedVector2Array = PackedVector2Array([Vector2(0,622),Vector2(380,611),Vector2(475,644),Vector2(154,831),Vector2(0,889)])
const WINDOWS = [Vector2(540,430),Vector2(805,430),Vector2(1070,430)]

func _ready() -> void:
	rng.seed = 1907
	if place_kind == "port":
		for i in range(7):
			birds.append({"pos":Vector2(rng.randf_range(-200,1600),rng.randf_range(150,330)),"speed":rng.randf_range(34,62),"flap":rng.randf_range(5,8),"phase":rng.randf()*TAU,"size":rng.randf_range(0.7,1.2)})
		for i in range(46):
			motes.append({"pos":Vector2(rng.randf_range(0,1600),rng.randf_range(90,800)),"vel":Vector2(rng.randf_range(6,18),rng.randf_range(-4,5)),"size":rng.randf_range(1.0,2.4),"phase":rng.randf()*TAU,"color":[Color(0.98,0.93,0.78,0.55),Color(0.92,0.80,0.74,0.45),Color(0.85,0.93,0.88,0.5)][i%3]})
	else:
		for i in range(40):
			motes.append({"pos":Vector2(rng.randf_range(300,1350),rng.randf_range(360,760)),"vel":Vector2(rng.randf_range(-4,4),rng.randf_range(-6,-1)),"size":rng.randf_range(0.8,1.8),"phase":rng.randf()*TAU,"color":Color(1.0,0.95,0.8,0.55)})
		for i in range(45):
			window_stars.append({"pos":Vector2(rng.randf_range(0,300),rng.randf_range(0,90)),"speed":rng.randf_range(10,40),"size":rng.randf_range(0.6,1.6)})

func footstep(at: Vector2, tint: Color = Color(0.72,0.66,0.55)) -> void:
	for i in range(2):
		puffs.append({"pos":at+Vector2(rng.randf_range(-6,6),rng.randf_range(-2,2)),"vel":Vector2(rng.randf_range(-14,14),rng.randf_range(-8,-2)),"life":0.55,"max":0.55,"size":rng.randf_range(3,5),"color":tint})

func ripple(at: Vector2, color: Color = Color("5c8b88")) -> void:
	ripples.append({"pos":at,"life":0.6,"max":0.6,"radius":22.0,"color":color})

func steam(at: Vector2) -> void:
	puffs.append({"pos":at,"vel":Vector2(rng.randf_range(-5,5),rng.randf_range(-26,-16)),"life":2.4,"max":2.4,"size":rng.randf_range(6,9),"color":Color(0.97,0.96,0.92),"grow":9.0})

func _process(delta: float) -> void:
	clock += delta
	for bird in birds:
		bird.pos.x += bird.speed*delta
		bird.pos.y += sin(clock*0.6+bird.phase)*6.0*delta
		if bird.pos.x>1680:
			bird.pos = Vector2(-80,rng.randf_range(150,330))
	for mote in motes:
		mote.pos += (mote.vel+Vector2(0,sin(clock*0.9+mote.phase)*6.0))*delta
		if place_kind == "port":
			mote.pos.x = fposmod(mote.pos.x,1600.0)
			mote.pos.y = 90.0+fposmod(mote.pos.y-90.0,710.0)
		elif mote.pos.y<360:
			mote.pos = Vector2(rng.randf_range(300,1350),760)
	for star in window_stars:
		star.pos.x = fposmod(star.pos.x-star.speed*delta,300.0)
	steam_timer -= delta
	if steam_timer<=0.0:
		steam_timer = 0.45
		if place_kind == "port":
			steam(Vector2(452,540))
			steam(Vector2(1238,420))
			if rng.randf()<0.5:
				ripple(Vector2(rng.randf_range(40,300),rng.randf_range(660,800)),Color(0.93,0.96,0.92,0.8))
	for i in range(puffs.size()-1,-1,-1):
		var p: Dictionary = puffs[i]
		p.life -= delta
		p.pos += p.vel*delta
		p.size += float(p.get("grow",4.0))*delta
		if p.life<=0:
			puffs.remove_at(i)
	for i in range(ripples.size()-1,-1,-1):
		ripples[i].life -= delta
		if ripples[i].life<=0:
			ripples.remove_at(i)
	queue_redraw()

func draw_bunting(a: Vector2, b: Vector2, sag: float, count: int) -> void:
	var points = PackedVector2Array()
	for i in range(count+1):
		var t: float = float(i)/count
		points.append(a.lerp(b,t)+Vector2(0,sin(t*PI)*sag+sin(clock*1.1)*2.0*sin(t*PI)))
	draw_polyline(points,Color(0.35,0.40,0.40,0.7),0.9,true)
	var colors: Array = [Color("c4956c"),Color("8fb3ab"),Color("d8c28c"),Color("b77d6f"),Color("9fb59a")]
	for i in range(count):
		var top: Vector2 = points[i].lerp(points[i+1],0.2)
		var top2: Vector2 = points[i].lerp(points[i+1],0.8)
		var flutter: float = sin(clock*3.2+i*0.9)*2.5
		var tip: Vector2 = (top+top2)*0.5+Vector2(flutter,13)
		draw_colored_polygon(PackedVector2Array([top,top2,tip]),Color(colors[i%colors.size()],0.9))
		draw_polyline(PackedVector2Array([top,tip,top2]),Color(0.35,0.40,0.40,0.5),0.6,true)

func _draw() -> void:
	if place_kind == "port":
		# Water glints and a bobbing channel buoy.
		for i in range(18):
			var p: Vector2 = Vector2(20+fposmod(i*97.0,420.0),650+fposmod(i*53.0,200.0))
			if Geometry2D.is_point_in_polygon(p,water):
				var glint: float = maxf(0.0,sin(clock*1.7+i*2.3))
				draw_line(p-Vector2(6*glint,0),p+Vector2(6*glint,0),Color(1,1,0.96,0.55*glint),1.2,true)
		var buoy: Vector2 = Vector2(92,742)+Vector2(0,sin(clock*1.4)*2.5)
		draw_set_transform(Vector2(92,748),0,Vector2(1,0.3))
		draw_arc(Vector2.ZERO,14+sin(clock*1.4)*2,0,TAU,24,Color(0.95,0.97,0.93,0.6),1.0,true)
		draw_set_transform(Vector2.ZERO)
		draw_colored_polygon(PackedVector2Array([buoy+Vector2(-7,0),buoy+Vector2(7,0),buoy+Vector2(4,-16),buoy+Vector2(-4,-16)]),Color("c77e68"))
		draw_rect(Rect2(buoy+Vector2(-5,-10),Vector2(10,4)),Color("efe6cf"))
		draw_line(buoy+Vector2(0,-16),buoy+Vector2(0,-24),Color("596766"),1.0,true)
		draw_circle(buoy+Vector2(0,-25),2.5,Color(0.98,0.8,0.5,0.5+0.5*maxf(0.0,sin(clock*3.0))))
		draw_bunting(Vector2(782,540),Vector2(998,522),26,9)
		draw_bunting(Vector2(1222,512),Vector2(1330,470),14,5)
		for bird in birds:
			var wing: float = sin(clock*bird.flap+bird.phase)*6.0*bird.size
			var s: float = 9.0*bird.size
			var at: Vector2 = bird.pos
			draw_polyline(PackedVector2Array([at+Vector2(-s,-wing),at+Vector2(-s*0.4,-wing*0.3-1),at,at+Vector2(s*0.4,-wing*0.3-1),at+Vector2(s,-wing)]),Color(0.30,0.36,0.37,0.75),1.2,true)
	else:
		# Stars slide past the three cabin windows; light pools on the floor below them.
		for w in WINDOWS:
			for star in window_stars:
				var local: Vector2 = Vector2(star.pos.x-150.0,-star.pos.y)
				if pow(local.x/70.0,2)+pow(local.y/78.0,2)<0.85:
					draw_circle(w+local,star.size,Color(0.95,0.97,0.9,0.75))
			draw_colored_polygon(PackedVector2Array([w+Vector2(-70,5),w+Vector2(70,5),w+Vector2(130,230),w+Vector2(-40,230)]),Color(1.0,0.97,0.86,0.10))
		var blink: float = 0.5+0.5*sin(clock*3.0)
		draw_circle(Vector2(1300,436),3,Color(0.62,0.85,0.72,0.3+0.7*blink))
		draw_circle(Vector2(1312,436),3,Color(0.95,0.72,0.5,0.3+0.7*(1.0-blink)))
		for glow in [Vector2(625,380),Vector2(888,380)]:
			draw_circle(glow+Vector2(0,20),26+sin(clock*1.3)*2,Color(1.0,0.9,0.66,0.10))
	for mote in motes:
		var twinkle: float = 0.55+0.45*sin(clock*1.8+mote.phase)
		draw_circle(mote.pos,mote.size,Color(mote.color,mote.color.a*twinkle))
	for p in puffs:
		var fade: float = p.life/p.max
		draw_circle(p.pos,p.size,Color(p.color,0.35*fade if p.has("grow") else 0.45*fade))
	for r in ripples:
		var t: float = 1.0-r.life/r.max
		draw_set_transform(r.pos,0,Vector2(1,0.38))
		draw_arc(Vector2.ZERO,r.radius*(0.3+t),0,TAU,32,Color(r.color,r.color.a*(1.0-t)),1.4,true)
		draw_arc(Vector2.ZERO,r.radius*(0.1+t*0.6),0,TAU,32,Color(r.color,r.color.a*(1.0-t)*0.6),1.0,true)
		draw_set_transform(Vector2.ZERO)
