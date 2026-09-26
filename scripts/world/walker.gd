class_name BHWalker
extends Node2D
## Original cutout character: independently animated legs, arms, coat, scarf and head.
var tint: Color = Color("607f80")
var is_player: bool = false
var moving: bool = false
var facing: float = 1.0
var phase: float = 0.0
var path: PackedVector2Array = PackedVector2Array()
var role_id: String = "pilot"
var body: Node2D
var head: Node2D
var arm_l: Node2D
var arm_r: Node2D
var leg_l: Node2D
var leg_r: Node2D
var scarf: Node2D
var thought: String = ""

func piece(points: PackedVector2Array, color: Color, at: Vector2 = Vector2.ZERO) -> Node2D:
	var root = Node2D.new()
	root.position = at
	var shape = Polygon2D.new()
	shape.polygon = points
	shape.color = color
	root.add_child(shape)
	var edge = Line2D.new()
	edge.points = points
	edge.closed = true
	edge.width = 0.65
	edge.default_color = Color("596766")
	edge.antialiased = true
	root.add_child(edge)
	return root

func _ready() -> void:
	body = Node2D.new()
	add_child(body)
	leg_l = piece(PackedVector2Array([Vector2(-3,0),Vector2(4,1),Vector2(3,10),Vector2(2,20),Vector2(7,24),Vector2(7,26),Vector2(-5,26),Vector2(-5,20),Vector2(-3,10)]),Color("657475"),Vector2(-5,-27))
	leg_r = piece(PackedVector2Array([Vector2(-3,1),Vector2(4,0),Vector2(4,10),Vector2(2,21),Vector2(7,24),Vector2(7,26),Vector2(-4,26),Vector2(-5,21),Vector2(-4,11)]),Color("485c64"),Vector2(5,-27))
	body.add_child(leg_l)
	body.add_child(leg_r)
	arm_l = piece(PackedVector2Array([Vector2(-3,0),Vector2(3,1),Vector2(5,9),Vector2(3,17),Vector2(4,21),Vector2(-1,23),Vector2(-4,17),Vector2(-5,8)]),tint.darkened(0.1),Vector2(-12,-48))
	body.add_child(arm_l)
	body.add_child(piece(PackedVector2Array([Vector2(-4,-54),Vector2(6,-54),Vector2(13,-49),Vector2(11,-37),Vector2(17,-21),Vector2(21,-13),Vector2(7,-14),Vector2(-3,-12),Vector2(-17,-15),Vector2(-13,-29),Vector2(-14,-42),Vector2(-12,-49)]),tint))
	body.add_child(piece(PackedVector2Array([Vector2(-8,-50),Vector2(-1,-47),Vector2(0,-35),Vector2(-2,-15),Vector2(-10,-15),Vector2(-9,-33)]),tint.lightened(0.13)))
	arm_r = piece(PackedVector2Array([Vector2(-2,0),Vector2(4,2),Vector2(5,9),Vector2(3,18),Vector2(4,22),Vector2(0,24),Vector2(-3,21),Vector2(-4,15),Vector2(-3,9)]),tint.lightened(0.04),Vector2(11,-48))
	body.add_child(arm_r)
	body.add_child(piece(PackedVector2Array([Vector2(-13,-37),Vector2(12,-34),Vector2(12,-31),Vector2(-13,-34)]),Color("997d5e")))
	body.add_child(piece(PackedVector2Array([Vector2(8,-36),Vector2(17,-34),Vector2(18,-27),Vector2(14,-23),Vector2(8,-24)]),Color("b39b75")))
	head = piece(PackedVector2Array([Vector2(-7,-7),Vector2(-4,-11),Vector2(3,-11),Vector2(7,-7),Vector2(7,-2),Vector2(10,1),Vector2(7,2),Vector2(6,7),Vector2(1,10),Vector2(-5,7),Vector2(-7,1)]),Color("e4cdb3"),Vector2(0,-61))
	body.add_child(head)
	head.add_child(piece(PackedVector2Array([Vector2(-9,-4),Vector2(-7,-11),Vector2(3,-13),Vector2(9,-7),Vector2(3,-6),Vector2(-4,-4),Vector2(-6,2)]),Color("515f60")))
	if role_id == "voss":
		head.add_child(piece(PackedVector2Array([Vector2(-10,-7),Vector2(5,-13),Vector2(11,-4),Vector2(-8,-2)]),Color("8c9991")))
	var eye = Line2D.new()
	eye.points = PackedVector2Array([Vector2(4,-1),Vector2(6,-1)])
	eye.width = 1.3
	eye.default_color = Color("596766")
	head.add_child(eye)
	scarf = piece(PackedVector2Array([Vector2(-9,0),Vector2(1,-1),Vector2(9,1),Vector2(8,5),Vector2(-9,6),Vector2(-15,8),Vector2(-27,6),Vector2(-32,10),Vector2(-28,2),Vector2(-18,3)]),Color("c4956c") if is_player else Color("b8b798"),Vector2(0,-54))
	body.add_child(scarf)
	queue_redraw()

func _process(delta: float) -> void:
	phase += delta * (10.0 if moving else 1.8)
	var stride: float = sin(phase) * (0.38 if moving else 0.025)
	leg_l.rotation = stride
	leg_r.rotation = -stride
	arm_l.rotation = -stride * 0.7
	arm_r.rotation = stride * 0.7
	scarf.rotation = sin(phase*0.7)*0.05
	head.rotation = sin(phase*0.35)*0.025
	body.position.y = -absf(sin(phase)) * (1.5 if moving else 0.3)
	body.scale.x = facing

func _draw() -> void:
	draw_set_transform(Vector2(0,-1),0,Vector2(1,0.3))
	draw_circle(Vector2.ZERO,17,Color(0.15,0.22,0.23,0.14))
	if is_player:
		draw_arc(Vector2.ZERO,21,0,TAU,32,Color(0.31,0.55,0.55,0.55),1.5,true)
	draw_set_transform(Vector2.ZERO)
