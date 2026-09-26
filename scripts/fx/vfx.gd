class_name BHVfx
extends Node2D
## Pooled 2D particle layer drawn in a single pass. Original ink-and-pigment look:
## soft washes bloom and fade, thin pen sparks streak, torn paper-like shards tumble.
## Purely cosmetic: gameplay never reads particle state, so tests stay deterministic.
const LIMIT: int = 1400
var parts: Array = []
var texts: Array = []
var rng = RandomNumberGenerator.new()
var font: Font
## Full-screen overlays (hit flash, low-hull vignette) live on the same top layer.
var flash: float = 0.0
var flash_color: Color = Color.WHITE
var vignette: float = 0.0
var vignette_color: Color = Color("a0513f")
var overlay_rect: Rect2 = Rect2(-60,-60,1720,1020)
## Frozen particles still draw (pause menu, staged captures) but stop advancing.
var frozen: bool = false

func _ready() -> void:
	rng.seed = 4401
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Noto Sans CJK KR","Malgun Gothic","Apple SD Gothic Neo","NanumGothic"])

func emit(kind: String, pos: Vector2, vel: Vector2, life: float, size: float, color: Color, extra: Dictionary = {}) -> void:
	if parts.size()>=LIMIT:
		parts.remove_at(0)
	var p: Dictionary = {"kind":kind,"pos":pos,"vel":vel,"life":life,"max":life,"size":size,"color":color,
		"drag":float(extra.get("drag",1.6)),"grow":float(extra.get("grow",0.0)),"gravity":extra.get("gravity",Vector2.ZERO),
		"rot":rng.randf()*TAU,"spin":float(extra.get("spin",rng.randf_range(-6.0,6.0))),"width":float(extra.get("width",1.4))}
	if extra.has("points"):
		p.points = extra.points
	if extra.has("end"):
		p.end = extra.end
	parts.append(p)

func burst(pos: Vector2, color: Color, count: int, speed_min: float, speed_max: float, life: float, size: float, kind: String = "spark", direction: float = 0.0, spread: float = TAU, extra: Dictionary = {}) -> void:
	for i in range(count):
		var angle: float = direction+rng.randf_range(-spread*0.5,spread*0.5)
		var speed: float = rng.randf_range(speed_min,speed_max)
		emit(kind,pos,Vector2.from_angle(angle)*speed,life*rng.randf_range(0.6,1.15),size*rng.randf_range(0.7,1.25),color,extra)

func ring(pos: Vector2, color: Color, radius: float, life: float = 0.45, width: float = 2.0) -> void:
	emit("ring",pos,Vector2.ZERO,life,radius,color,{"width":width})

func smoke(pos: Vector2, color: Color = Color("5d6f73"), size: float = 11.0, drift: Vector2 = Vector2.ZERO) -> void:
	emit("puff",pos+Vector2(rng.randf_range(-4,4),rng.randf_range(-4,4)),drift+Vector2(rng.randf_range(-14,14),rng.randf_range(-22,-6)),rng.randf_range(0.9,1.6),size,Color(color,0.35),{"grow":size*1.6,"drag":1.2})

func sparks(pos: Vector2, color: Color, direction: float, count: int = 7, speed: float = 320.0) -> void:
	burst(pos,color,count,speed*0.45,speed,0.32,1.0,"spark",direction,1.6,{"drag":4.0})

func muzzle(pos: Vector2, direction: float, color: Color) -> void:
	emit("bloom",pos,Vector2.ZERO,0.09,9.0,Color(color,0.9),{"grow":30.0})
	burst(pos,color.lightened(0.3),4,160,340,0.14,1.0,"spark",direction,0.7,{"drag":6.0})

func floating_text(pos: Vector2, value: String, color: Color) -> void:
	texts.append({"pos":pos+Vector2(rng.randf_range(-8,8),0),"text":value,"life":0.9,"max":0.9,"color":color})
	if texts.size()>40:
		texts.remove_at(0)

## Watercolor explosion: white flash, hot pigment blooms, ink shards, sparks, lingering smoke and a ring.
func explosion(pos: Vector2, scale_value: float = 1.0, hot: Color = Color("e0a36f"), ink: Color = Color("4b5a5c")) -> void:
	emit("bloom",pos,Vector2.ZERO,0.16,22.0*scale_value,Color(1,0.97,0.88,0.95),{"grow":90.0*scale_value})
	for i in range(int(9*scale_value)+4):
		var dir: Vector2 = Vector2.from_angle(rng.randf()*TAU)
		emit("bloom",pos+dir*rng.randf_range(0,14)*scale_value,dir*rng.randf_range(30,120)*scale_value,rng.randf_range(0.35,0.7),rng.randf_range(8,17)*scale_value,
			[hot,hot.lightened(0.25),Color("c9765a"),Color("e8cf92")][i%4],{"grow":rng.randf_range(14,34)*scale_value,"drag":3.2})
	burst(pos,Color("f6e2b5"),int(16*scale_value)+6,180,520*scale_value,0.5,1.0,"spark",0.0,TAU,{"drag":3.0})
	burst(pos,ink,int(10*scale_value)+3,90,300*scale_value,1.1,5.0*scale_value,"shard",0.0,TAU,{"drag":1.4})
	for i in range(int(6*scale_value)+2):
		smoke(pos,ink.lightened(0.15),13.0*scale_value,Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(10,60))
	ring(pos,Color(hot,0.8),85*scale_value,0.5,2.4)
	ring(pos,Color(ink,0.45),130*scale_value,0.75,1.0)

## Branching pen-line lightning between two points.
func bolt(a: Vector2, b: Vector2, color: Color, life: float = 0.22) -> void:
	var points = PackedVector2Array([a])
	var steps: int = maxi(3,int(a.distance_to(b)/26.0))
	var normal: Vector2 = (b-a).orthogonal().normalized()
	for i in range(1,steps):
		points.append(a.lerp(b,float(i)/steps)+normal*rng.randf_range(-13,13))
	points.append(b)
	emit("bolt",a,Vector2.ZERO,life,1.0,color,{"points":points,"width":2.0})

func beam(a: Vector2, b: Vector2, color: Color, width: float, life: float) -> void:
	emit("beam",a,Vector2.ZERO,life,width,color,{"end":b})

func hit_flash(color: Color, amount: float) -> void:
	flash_color = color
	flash = maxf(flash,amount)

func _process(delta: float) -> void:
	if frozen:
		return
	flash = maxf(0.0,flash-delta*2.6)
	for i in range(parts.size()-1,-1,-1):
		var p: Dictionary = parts[i]
		p.life -= delta
		if p.life<=0.0:
			parts.remove_at(i)
			continue
		p.vel = p.vel*maxf(0.0,1.0-p.drag*delta)+p.gravity*delta
		p.pos += p.vel*delta
		p.size += p.grow*delta
		p.rot += p.spin*delta
	for i in range(texts.size()-1,-1,-1):
		texts[i].life -= delta
		texts[i].pos.y -= 38.0*delta
		if texts[i].life<=0.0:
			texts.remove_at(i)
	queue_redraw()

func _draw() -> void:
	for p in parts:
		var t: float = 1.0-p.life/p.max
		var fade: float = 1.0-t
		var color: Color = p.color
		match p.kind:
			"spark":
				var tail: Vector2 = p.vel*0.035
				if tail.length()<2.0:
					tail = tail.normalized()*2.0
				draw_line(p.pos-tail,p.pos,Color(color,color.a*fade),p.width,true)
			"bloom":
				# Two stacked washes give a soft pigment edge; a faint ink rim reads as watercolor.
				draw_circle(p.pos,p.size,Color(color,color.a*fade*0.35))
				draw_circle(p.pos,p.size*0.62,Color(color,color.a*fade*0.55))
				if p.size>10.0:
					draw_arc(p.pos,p.size,0,TAU,24,Color(0.29,0.34,0.35,0.16*fade),0.8,true)
			"puff":
				draw_circle(p.pos,p.size,Color(color,color.a*fade*0.6))
				draw_circle(p.pos+Vector2(p.size*0.3,-p.size*0.2),p.size*0.6,Color(color,color.a*fade*0.4))
			"dot":
				draw_circle(p.pos,p.size*(0.4+0.6*fade),Color(color,color.a*fade))
			"mote":
				# Twinkling ambient particle; fades in and out.
				draw_circle(p.pos,p.size,Color(color,color.a*sin(t*PI)))
			"shard":
				var s: float = p.size
				var a: Vector2 = Vector2.from_angle(p.rot)*s
				var b: Vector2 = Vector2.from_angle(p.rot+2.3)*s*0.7
				var c: Vector2 = Vector2.from_angle(p.rot+4.1)*s*0.85
				var tri = PackedVector2Array([p.pos+a,p.pos+b,p.pos+c])
				draw_colored_polygon(tri,Color(color,fade*0.9))
			"ring":
				var eased: float = 1.0-pow(1.0-t,3.0)
				draw_arc(p.pos,maxf(1.0,p.size*eased),0,TAU,64,Color(color,color.a*fade),p.width*(0.4+fade),true)
			"bolt":
				draw_polyline(p.points,Color(color,fade),p.width,true)
				draw_polyline(p.points,Color(1,1,1,fade*0.7),p.width*0.4,true)
			"beam":
				draw_line(p.pos,p.end,Color(color,0.25*fade),p.size*2.4*fade+1.0,true)
				draw_line(p.pos,p.end,Color(color,0.8*fade),p.size*fade+0.8,true)
				draw_line(p.pos,p.end,Color(1,0.98,0.9,fade),maxf(0.8,p.size*0.3*fade),true)
			"ghost":
				# Boost afterimage: a fading ink outline of the hull.
				var pts: PackedVector2Array = PackedVector2Array()
				for v in [Vector2(0,-39),Vector2(24,-4),Vector2(24,26),Vector2(-24,26),Vector2(-24,-4),Vector2(0,-39)]:
					pts.append(p.pos+v.rotated(p.rot)*p.size)
				draw_polyline(pts,Color(color,color.a*fade),1.4,true)
	for label in texts:
		var fade2: float = label.life/label.max
		draw_string(font,label.pos+Vector2(1,1),label.text,HORIZONTAL_ALIGNMENT_CENTER,60,15,Color(0.08,0.14,0.17,0.6*fade2))
		draw_string(font,label.pos,label.text,HORIZONTAL_ALIGNMENT_CENTER,60,15,Color(label.color,fade2))
	if vignette>0.01:
		# Stacked frame bands approximate a soft edge vignette without a texture.
		for i in range(6):
			var inset: float = 22.0*i
			var r: Rect2 = Rect2(overlay_rect.position+Vector2(inset,inset)+Vector2(60,146),overlay_rect.size-Vector2(inset,inset)*2-Vector2(120,292))
			draw_rect(r,Color(vignette_color,vignette*0.09*(6-i)/6.0),false,24.0)
	if flash>0.01:
		draw_rect(overlay_rect,Color(flash_color,flash*0.22))
