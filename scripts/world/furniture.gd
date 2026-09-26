class_name BHDecor
extends Node2D
const Catalog = preload("res://scripts/core/catalog.gd")
var item_id: String = "bed"
var rotated: bool = false
var uid: int = -1
var ghost: bool = false
var valid_ghost: bool = true
const INK = Color("53636a")
var clock: float = 0.0

func polygon(points: PackedVector2Array, fill: Color) -> void:
	draw_colored_polygon(points,fill)
	var closed: PackedVector2Array = points.duplicate()
	closed.append(points[0])
	draw_polyline(closed,INK,1.2,true)

func box(rect: Rect2, fill: Color, height: float = 10.0) -> void:
	var a: Vector2 = rect.position
	var b: Vector2 = rect.end
	polygon(PackedVector2Array([Vector2(a.x,a.y-height),Vector2(b.x,a.y-height),Vector2(b.x,b.y-height),Vector2(a.x,b.y-height)]),fill)
	polygon(PackedVector2Array([Vector2(a.x,b.y-height),Vector2(b.x,b.y-height),b,Vector2(a.x,b.y)]),fill.darkened(0.13))

func _process(delta: float) -> void:
	if item_id == "lamp":
		clock += delta
		queue_redraw()

func _draw() -> void:
	var dims: Vector2 = Vector2(Catalog.furniture_size(item_id,rotated)) * 60.0
	if ghost:
		draw_rect(Rect2(Vector2.ZERO,dims),Color(0.3,0.68,0.63,0.24) if valid_ghost else Color(0.84,0.33,0.23,0.3))
		draw_rect(Rect2(Vector2.ZERO,dims),Color("498e81") if valid_ghost else Color("ba634a"),false,2)
	draw_rect(Rect2(Vector2(7,dims.y-13),Vector2(dims.x-8,14)),Color(0.15,0.2,0.2,0.12))
	match item_id:
		"bed":
			box(Rect2(6,8,dims.x-12,dims.y-13),Color("b0aea0"),12)
			box(Rect2(8,5,dims.x-16,dims.y-20),Color("eae1cf"),14)
			box(Rect2(9,8,25,dims.y-24),Color("f0ecdf"),15)
			box(Rect2(41,7,dims.x-51,dims.y-22),Color("89a7a0"),14)
			for x in range(49,int(dims.x)-12,13):
				draw_line(Vector2(x,-5),Vector2(x,dims.y-24),Color(0.9,0.9,0.78,0.6),1,true)
		"sofa":
			box(Rect2(4,9,dims.x-8,dims.y-17),Color("ac9d87"),15)
			box(Rect2(4,4,dims.x-8,12),Color("a5b1a1"),26)
			box(Rect2(9,18,dims.x-18,dims.y-32),Color("c8c3a9"),17)
			box(Rect2(0,6,10,dims.y-15),Color("a5b1a1"),24)
			box(Rect2(dims.x-10,6,10,dims.y-15),Color("a5b1a1"),24)
			draw_line(Vector2(dims.x*0.5,3),Vector2(dims.x*0.5,dims.y-27),INK,1,true)
		"desk", "table":
			draw_line(Vector2(12,27),Vector2(12,dims.y-6),INK,4,true)
			draw_line(Vector2(dims.x-12,27),Vector2(dims.x-12,dims.y-6),INK,4,true)
			box(Rect2(4,10,dims.x-8,dims.y-20),Color("c6b292"),24)
			if item_id == "desk":
				box(Rect2(13,2,35,18),Color("6b8885"),25)
				draw_line(Vector2(19,-13),Vector2(42,-12),Color("d3ddc7"),2,true)
				box(Rect2(dims.x-38,17,22,15),Color("e9e0c8"),26)
			else:
				draw_circle(Vector2(26,8),9,Color("f2e5cb"))
				draw_circle(Vector2(dims.x-26,8),9,Color("f2e5cb"))
				draw_circle(Vector2(dims.x*0.5,7),5,Color("a77b5e"))
		"plant":
			polygon(PackedVector2Array([Vector2(16,24),Vector2(44,24),Vector2(40,48),Vector2(20,48)]),Color("c6a385"))
			draw_line(Vector2(30,27),Vector2(30,-22),INK,1.5,true)
			for i in range(6):
				var y: float = 14-i*7
				var side: float = -1.0 if i%2==0 else 1.0
				polygon(PackedVector2Array([Vector2(30,y),Vector2(30+side*18,y-5),Vector2(30+side*20,y-17),Vector2(30+side*3,y-13)]),Color("96ad94"))
		"lamp":
			draw_set_transform(Vector2(30,25),0,Vector2(1,0.5))
			draw_circle(Vector2.ZERO,46,Color(0.90,0.74,0.38,0.07+sin(clock)*0.012))
			draw_set_transform(Vector2.ZERO)
			draw_circle(Vector2(30,44),11,Color("939d91"))
			draw_line(Vector2(30,41),Vector2(30,-23),INK,3,true)
			polygon(PackedVector2Array([Vector2(18,-29),Vector2(41,-29),Vector2(49,-5),Vector2(11,-5)]),Color("e2c891"))
			draw_line(Vector2(14,-3),Vector2(46,-3),Color("f8e5b2"),3,true)
