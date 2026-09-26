class_name BHHornetVisual
extends Node2D
## Small raider drone: a pale ink stinger with two flickering wing vanes.
## A charging drone glows and its vanes fold back before the dash.
var clock: float = 0.0
var charging: float = 0.0
var dashing: bool = false
var hurt: float = 0.0
const INK = Color("354f5a")

func _process(delta: float) -> void:
	clock += delta
	hurt = maxf(0.0,hurt-delta*4.0)
	queue_redraw()

func _draw() -> void:
	var fold: float = 0.55 if dashing else 1.0-charging*0.35
	var flap: float = sin(clock*38.0)*2.0
	var body: Color = Color("b98e76").lerp(Color("f4e6d0"),hurt)
	for side in [-1.0,1.0]:
		var wing = PackedVector2Array([Vector2(side*4,-2),Vector2(side*(17+flap)*fold,6-flap),Vector2(side*(13*fold),13),Vector2(side*3,8)])
		draw_colored_polygon(wing,Color(0.78,0.84,0.80,0.55))
		wing.append(wing[0])
		draw_polyline(wing,INK,0.8,true)
	var hull = PackedVector2Array([Vector2(0,-17),Vector2(6,-3),Vector2(4,13),Vector2(0,17),Vector2(-4,13),Vector2(-6,-3)])
	draw_colored_polygon(hull,body)
	hull.append(hull[0])
	draw_polyline(hull,INK,1.0,true)
	draw_line(Vector2(0,-12),Vector2(0,8),Color("7a5448"),1.2,true)
	var eye: Color = Color("f3b58c") if charging>0.0 or dashing else Color("d38f6f")
	draw_circle(Vector2(0,-6),2.6+charging*2.0,eye)
	if charging>0.0:
		draw_circle(Vector2(0,-6),9.0+charging*8.0,Color(0.95,0.62,0.44,0.18*charging))
	draw_circle(Vector2(0,16),3.0,Color(0.86,0.6,0.46,0.5))
