class_name BHShipVisual
extends Node2D
## One persistent hull; hardpoints visibly change with the actual equipped modules.
var modules: Array = ["boost","tether","shield","emp"]
var hull_color: Color = Color("c8d2c7")
var hostile: bool = false
var thrust: float = 0.0
var active: Dictionary = {}
var clock: float = 0.0
var disabled: bool = false
## Brief pale flash when struck; decays on its own.
var hurt: float = 0.0
const INK = Color("354f5a")

func poly(points: PackedVector2Array, color: Color, width: float = 1.0) -> void:
	draw_colored_polygon(points,color)
	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	draw_polyline(outline,INK,width,true)

func _process(delta: float) -> void:
	clock += delta
	hurt = maxf(0.0,hurt-delta*5.0)
	queue_redraw()

func _draw() -> void:
	var flame: Color = Color("d59e78") if hostile else Color("79bfba")
	var base_color: Color = hull_color
	hull_color = base_color.lerp(Color("fbf3df"),hurt*0.8)
	draw_hull(flame)
	hull_color = base_color

func draw_hull(flame: Color) -> void:
	if thrust>0.05 and not disabled:
		draw_circle(Vector2(0,34),14+thrust*6,Color(flame,0.10))
		for x in [-11,11]:
			var tail: float = 12+thrust*23+sin(clock*25)*3
			draw_line(Vector2(x,30),Vector2(x,tail+20),Color(1,0.98,0.9,0.55),1.6,true)
			poly(PackedVector2Array([Vector2(x-4,29),Vector2(x,tail+27),Vector2(x+4,29)]),Color(flame,0.6),0.6)
			draw_circle(Vector2(x,30),6,Color(flame,0.16))
	# Broad split cargo hull and small central cockpit preserve a recognizable silhouette.
	poly(PackedVector2Array([Vector2(-14,-17),Vector2(-24,-4),Vector2(-24,26),Vector2(-8,31),Vector2(-6,-15)]),hull_color.darkened(0.12))
	poly(PackedVector2Array([Vector2(14,-17),Vector2(24,-4),Vector2(24,26),Vector2(8,31),Vector2(6,-15)]),hull_color.darkened(0.08))
	poly(PackedVector2Array([Vector2(0,-39),Vector2(15,-17),Vector2(12,26),Vector2(-12,26),Vector2(-15,-17)]),hull_color)
	poly(PackedVector2Array([Vector2(0,-31),Vector2(8,-16),Vector2(6,-6),Vector2(-6,-6),Vector2(-8,-16)]),Color("648f91"))
	draw_line(Vector2(0,-28),Vector2(0,-8),Color("bedbd0"),1.2,true)
	poly(PackedVector2Array([Vector2(-7,0),Vector2(7,0),Vector2(7,19),Vector2(-7,19)]),hull_color.darkened(0.12))
	for y in [1,7,13]:
		draw_line(Vector2(-21,y),Vector2(-12,y),INK,1,true)
		draw_line(Vector2(12,y),Vector2(21,y),INK,1,true)
	draw_line(Vector2(-4,22),Vector2(4,22),flame,2,true)
	var mounts: Array = [Vector2(-28,15),Vector2(28,15),Vector2(-20,-12),Vector2(20,-12)]
	for i in range(mini(modules.size(),4)):
		var id: String = str(modules[i])
		var deployed: bool = float(active.get(id,0.0))>0.0
		draw_set_transform(mounts[i])
		match id:
			"boost":
				poly(PackedVector2Array([Vector2(-6,-6),Vector2(5,-10),Vector2(7,12),Vector2(-6,14)]),Color("8faba5"))
				if deployed:
					draw_line(Vector2(0,11),Vector2(0,44),Color("b6eee0"),4,true)
			"tether":
				poly(PackedVector2Array([Vector2(-5,-9),Vector2(5,-9),Vector2(4,12),Vector2(-4,12)]),Color("baac87"))
				draw_line(Vector2.ZERO,Vector2(0,-18 if deployed else -10),Color("dcd5b4"),3,true)
			"shield":
				draw_arc(Vector2.ZERO,12 if deployed else 7,0,TAU,16,Color("8ed0c9"),2,true)
			"emp":
				draw_circle(Vector2.ZERO,7,Color("999eb0"))
				draw_arc(Vector2.ZERO,15 if deployed else 9,PI,TAU,16,Color("d5bce8"),2,true)
			"rail":
				draw_line(Vector2(0,11),Vector2(0,-29 if deployed else -19),Color("c2b28c"),7,true)
				draw_line(Vector2(0,4),Vector2(0,-24 if deployed else -17),Color("f0dfb5"),1.5,true)
			"drone":
				poly(PackedVector2Array([Vector2(-7,-8),Vector2(7,-8),Vector2(7,10),Vector2(-7,10)]),Color("9cae8c"))
				if deployed:
					for n in range(2):
						draw_circle(Vector2(cos(clock*3+n*PI)*19,sin(clock*3+n*PI)*25),3,Color("c7e0b0"))
		draw_set_transform(Vector2.ZERO)
	if disabled:
		draw_circle(Vector2(10,25),9,Color(0.58,0.45,0.32,0.22))
