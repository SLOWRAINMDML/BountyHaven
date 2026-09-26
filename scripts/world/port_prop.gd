class_name BHPortProp
extends Node2D
## Small hand-inked harbor props. Placed just outside the walk polygon and y-sorted
## with the people, so travellers pass in front of or behind them naturally.
var kind: String = "crates"
var clock: float = 0.0
const INK = Color("596766")

func _process(delta: float) -> void:
	clock += delta
	if kind in ["cat","plant","board"]:
		queue_redraw()

func shape(points: PackedVector2Array, fill: Color, width: float = 0.9) -> void:
	draw_colored_polygon(points,fill)
	var edge: PackedVector2Array = points.duplicate()
	edge.append(points[0])
	draw_polyline(edge,INK,width,true)

func box(rect: Rect2, fill: Color) -> void:
	shape(PackedVector2Array([rect.position,rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)]),fill)
	# Top face gives the stack volume in the same oblique projection as the buildings.
	shape(PackedVector2Array([rect.position,rect.position+Vector2(7,-6),rect.position+Vector2(rect.size.x+7,-6),rect.position+Vector2(rect.size.x,0)]),fill.lightened(0.18),0.7)
	shape(PackedVector2Array([rect.position+Vector2(rect.size.x,0),rect.position+Vector2(rect.size.x+7,-6),rect.end+Vector2(7,-6),rect.end]),fill.darkened(0.14),0.7)

func shadow(width: float) -> void:
	draw_set_transform(Vector2(4,0),0,Vector2(1,0.28))
	draw_circle(Vector2.ZERO,width,Color(0.15,0.22,0.23,0.12))
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	match kind:
		"crates":
			shadow(34)
			box(Rect2(-30,-24,30,24),Color("c9b38e"))
			box(Rect2(2,-20,24,20),Color("b9a07c"))
			box(Rect2(-22,-46,26,22),Color("d4c29e"))
			for x in [-24,-12]:
				draw_line(Vector2(x,-22),Vector2(x,-2),Color(INK,0.5),0.7,true)
			draw_line(Vector2(-18,-38),Vector2(-2,-30),Color("a8774e"),1.2,true)
		"barrels":
			shadow(24)
			for data in [[Vector2(-10,0),Color("8fa39c")],[Vector2(10,2),Color("a58f6e")]]:
				var at: Vector2 = data[0]
				shape(PackedVector2Array([at+Vector2(-9,-30),at+Vector2(9,-30),at+Vector2(11,-15),at+Vector2(9,0),at+Vector2(-9,0),at+Vector2(-11,-15)]),data[1])
				draw_set_transform(at+Vector2(0,-30),0,Vector2(1,0.3))
				draw_circle(Vector2.ZERO,9,Color(data[1]).lightened(0.2))
				draw_arc(Vector2.ZERO,9,0,TAU,16,INK,1.8,true)
				draw_set_transform(Vector2.ZERO)
				for y in [-24,-7]:
					draw_line(at+Vector2(-10,y),at+Vector2(10,y),Color(INK,0.7),1.0,true)
		"bollard":
			shadow(10)
			shape(PackedVector2Array([Vector2(-6,-18),Vector2(6,-18),Vector2(7,0),Vector2(-7,0)]),Color("7d8c89"))
			draw_set_transform(Vector2(0,-19),0,Vector2(1,0.4))
			draw_circle(Vector2.ZERO,8,Color("98a7a2"))
			draw_arc(Vector2.ZERO,8,0,TAU,16,INK,1.6,true)
			draw_set_transform(Vector2.ZERO)
			draw_arc(Vector2(0,-8),9,0.2,PI-0.2,12,Color("b39b75"),1.6,true)
		"board":
			# Guild bounty board: pinned wanted posters flutter slightly.
			shadow(30)
			draw_line(Vector2(-24,0),Vector2(-24,-62),INK,2.0,true)
			draw_line(Vector2(24,0),Vector2(24,-62),INK,2.0,true)
			shape(PackedVector2Array([Vector2(-30,-66),Vector2(30,-66),Vector2(30,-24),Vector2(-30,-24)]),Color("a58763"))
			shape(PackedVector2Array([Vector2(-33,-70),Vector2(33,-70),Vector2(30,-66),Vector2(-30,-66)]),Color("7e6a52"))
			var posters: Array = [[Vector2(-24,-62),Color("efe6cf")],[Vector2(-5,-60),Color("e7dcc0")],[Vector2(12,-63),Color("f1ead8")]]
			for i in range(posters.size()):
				var at2: Vector2 = posters[i][0]
				var sway: float = sin(clock*1.7+i*1.3)*1.2
				shape(PackedVector2Array([at2,at2+Vector2(14,0),at2+Vector2(14+sway,18),at2+Vector2(sway,18)]),posters[i][1],0.6)
				draw_circle(at2+Vector2(7,7),3,Color("8b7c68"))
				draw_line(at2+Vector2(3,13),at2+Vector2(11+sway,13),Color("c4956c"),1.0,true)
				draw_circle(at2+Vector2(7,1),1.2,Color("a0513f"))
		"plant":
			shadow(14)
			shape(PackedVector2Array([Vector2(-10,-16),Vector2(10,-16),Vector2(7,0),Vector2(-7,0)]),Color("c58f6c"))
			for i in range(6):
				var a: float = -PI*0.5+(i-2.5)*0.36+sin(clock*1.3+i)*0.05
				var tip: Vector2 = Vector2(0,-16)+Vector2.from_angle(a)*(24+i%2*8)
				shape(PackedVector2Array([Vector2(0,-16),tip+Vector2.from_angle(a+PI*0.5)*5,tip,tip+Vector2.from_angle(a-PI*0.5)*3]),Color("8faf94") if i%2==0 else Color("739c80"),0.6)
		"cat":
			# A harbor cat loafing on the crates; its tail swishes and it blinks.
			var tail: float = sin(clock*2.1)*0.5
			draw_polyline(PackedVector2Array([Vector2(10,-2),Vector2(18,-6),Vector2(22+tail*6,-14),Vector2(20+tail*9,-20)]),Color("4c5456"),2.4,true)
			shape(PackedVector2Array([Vector2(-12,0),Vector2(-10,-9),Vector2(2,-11),Vector2(12,-6),Vector2(12,0)]),Color("5b6466"))
			shape(PackedVector2Array([Vector2(-16,-8),Vector2(-15,-18),Vector2(-12,-14),Vector2(-8,-18),Vector2(-6,-8),Vector2(-10,-4)]),Color("5b6466"))
			var open: bool = fposmod(clock,4.0)>0.18
			if open:
				draw_circle(Vector2(-13,-11),1.1,Color("e9d38e"))
				draw_circle(Vector2(-9,-11),1.1,Color("e9d38e"))
			else:
				draw_line(Vector2(-14,-11),Vector2(-8,-11),Color("e9d38e"),0.8,true)
