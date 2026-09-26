class_name BHNavOverlay
extends Control
## Flight instruments for the wide operation area: a north-up radar, an edge arrow with
## distance for the current objective when it is off screen, a heading chevron around the
## ship, and a speed/throttle readout. Reads BHSpace and the 3D camera; owns no state.
const Fx = preload("res://scripts/space3d/fx3d.gd")
const RADAR_CENTER = Vector2(1478,318)
const RADAR_RADIUS: float = 92.0
const RADAR_RANGE: float = 2600.0
## Keeps edge arrows clear of the radar column on the right.
const PLAY_RECT = Rect2(24,96,1340,700)
var world: BHSpace
var view: BHSpaceView3D
var font: Font
var clock: float = 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Noto Sans CJK KR","Malgun Gothic","Apple SD Gothic Neo","NanumGothic"])
	font.font_weight = 600

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

## The point the pilot should fly to next, with its label and colour.
func objective_point() -> Dictionary:
	match world.phase:
		"survey":
			for i in range(world.markers.size()):
				if not world.markers[i].done:
					return {"pos":world.markers[i].pos,"text":("화물 %d" if world.salvage else "신호 %d") % (i+1),"color":Color("8fe0d4")}
		"pursuit":
			return {"pos":world.target_pos,"text":"표적","color":Color("f0c48a")}
		"boarding":
			return {"pos":world.relay_pos if world.relay_hp>0 else world.target_pos,"text":"중계기" if world.relay_hp>0 else "엄호","color":Color("f1a6cf")}
		"extraction":
			return {"pos":world.pod_pos,"text":"회수 포드","color":Color("eeeec6")}
	return {}

func distance_text(d: float) -> String:
	return ("%.1f km" % (d/1000.0)) if d>=1000.0 else ("%d m" % int(d))

func screen_of(p: Vector2) -> Vector2:
	return view.camera.unproject_position(Fx.to3d(p))

func _draw() -> void:
	if not is_instance_valid(world) or not is_instance_valid(view) or world.finished:
		return
	draw_radar()
	draw_speed()
	var goal: Dictionary = objective_point()
	if goal.is_empty():
		return
	var target: Vector2 = goal.pos
	var gap: float = world.position_ship.distance_to(target)
	var ship_screen: Vector2 = screen_of(world.position_ship)
	var target_screen: Vector2 = screen_of(target)
	var inner: Rect2 = PLAY_RECT.grow(-40)
	var color: Color = goal.color
	if inner.has_point(target_screen) and not view.camera.is_position_behind(Fx.to3d(target)):
		# On screen: the 3D labels already name ships; signals and pods get a distance tag.
		if world.phase in ["pursuit","boarding"] or gap<260.0:
			return
		var b: Vector2 = target_screen+Vector2(0,-74)
		draw_string_outline(font,b+Vector2(-80,0),"%s · %s" % [goal.text,distance_text(gap)],HORIZONTAL_ALIGNMENT_CENTER,160,15,5,Color(0.03,0.07,0.1,0.8))
		draw_string(font,b+Vector2(-80,0),"%s · %s" % [goal.text,distance_text(gap)],HORIZONTAL_ALIGNMENT_CENTER,160,15,color)
	else:
		# Off screen: clamp the direction to the play area edge and point at it.
		var dir: Vector2 = (target_screen-ship_screen).normalized()
		if dir.is_zero_approx():
			dir = Vector2.RIGHT
		var edge: Vector2 = ship_screen
		var reach: float = 4000.0
		for bound in [[inner.position.x,0],[inner.end.x,0],[inner.position.y,1],[inner.end.y,1]]:
			var axis: int = bound[1]
			var comp: float = dir.x if axis==0 else dir.y
			if absf(comp)<0.0001:
				continue
			var t: float = (float(bound[0])-(ship_screen.x if axis==0 else ship_screen.y))/comp
			if t>0.0:
				reach = minf(reach,t)
		edge = ship_screen+dir*reach
		var pulse: float = 0.5+0.5*sin(clock*5.0)
		var tip: Vector2 = edge
		var base: Vector2 = edge-dir*26.0
		var side: Vector2 = dir.orthogonal()*13.0
		draw_colored_polygon(PackedVector2Array([tip,base+side,base-side]),Color(color,0.75+0.25*pulse))
		draw_polyline(PackedVector2Array([tip,base+side,base-side,tip]),Color(0.03,0.07,0.1,0.8),1.5,true)
		var label_at: Vector2 = edge-dir*54.0
		var text: String = "%s  %s" % [goal.text,distance_text(gap)]
		draw_string_outline(font,label_at+Vector2(-90,6),text,HORIZONTAL_ALIGNMENT_CENTER,180,16,5,Color(0.03,0.07,0.1,0.85))
		draw_string(font,label_at+Vector2(-90,6),text,HORIZONTAL_ALIGNMENT_CENTER,180,16,color)
	# Heading chevrons orbiting the ship toward the objective when it is far away.
	if gap>520.0:
		var dir2: Vector2 = (target_screen-ship_screen).normalized()
		for k in range(3):
			var at: Vector2 = ship_screen+dir2*(78.0+k*13.0)
			var fade: float = fposmod(clock*1.6-k*0.25,1.0)
			var side2: Vector2 = dir2.orthogonal()*8.0
			draw_polyline(PackedVector2Array([at-dir2*5.0+side2,at+dir2*4.0,at-dir2*5.0-side2]),Color(color,0.25+0.6*(1.0-fade)),2.4,true)

func radar_point(p: Vector2) -> Vector2:
	var rel: Vector2 = (p-world.position_ship)/RADAR_RANGE*RADAR_RADIUS
	if rel.length()>RADAR_RADIUS-5.0:
		rel = rel.normalized()*(RADAR_RADIUS-5.0)
	return RADAR_CENTER+rel

func draw_radar() -> void:
	var c: Vector2 = RADAR_CENTER
	draw_circle(c,RADAR_RADIUS+6,Color(0.03,0.08,0.11,0.72))
	draw_arc(c,RADAR_RADIUS+6,0,TAU,64,Color("d9b77c"),2.0,true)
	for r in [0.33,0.66,1.0]:
		draw_arc(c,RADAR_RADIUS*r,0,TAU,48,Color(0.55,0.85,0.8,0.18),1.0,true)
	draw_line(c-Vector2(RADAR_RADIUS,0),c+Vector2(RADAR_RADIUS,0),Color(0.55,0.85,0.8,0.1),1.0)
	draw_line(c-Vector2(0,RADAR_RADIUS),c+Vector2(0,RADAR_RADIUS),Color(0.55,0.85,0.8,0.1),1.0)
	# Sweep wedge.
	var sweep: float = clock*1.8
	for k in range(10):
		var a: float = sweep-k*0.06
		draw_line(c,c+Vector2.from_angle(a)*RADAR_RADIUS,Color(0.55,0.95,0.85,0.16*(1.0-k/10.0)),2.0,true)
	# Operation-area boundary, clipped to the scope.
	var bounds: Rect2 = BHSpace.WORLD
	var corners: Array = [bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)]
	for i in range(4):
		var a2: Vector2 = (corners[i]-world.position_ship)/RADAR_RANGE*RADAR_RADIUS
		var b2: Vector2 = (corners[(i+1)%4]-world.position_ship)/RADAR_RANGE*RADAR_RADIUS
		var pts = PackedVector2Array()
		for n in range(17):
			var q: Vector2 = a2.lerp(b2,n/16.0)
			if q.length()<=RADAR_RADIUS:
				pts.append(c+q)
			elif pts.size()>1:
				draw_polyline(pts,Color(0.95,0.6,0.45,0.35),1.2)
				pts = PackedVector2Array()
			else:
				pts = PackedVector2Array()
		if pts.size()>1:
			draw_polyline(pts,Color(0.95,0.6,0.45,0.35),1.2)
	for rock in world.asteroids:
		if rock.pos.distance_to(world.position_ship)<RADAR_RANGE:
			draw_circle(radar_point(rock.pos),maxf(1.2,float(rock.r)/RADAR_RANGE*RADAR_RADIUS),Color(0.7,0.68,0.6,0.35))
	if world.phase=="survey":
		for marker in world.markers:
			if not marker.done:
				var m: Vector2 = radar_point(marker.pos)
				draw_colored_polygon(PackedVector2Array([m+Vector2(0,-6),m+Vector2(5,0),m+Vector2(0,6),m+Vector2(-5,0)]),Color("8fe0d4"))
	if world.quarry.visible and world.phase!="survey":
		var q2: Vector2 = radar_point(world.target_pos)
		draw_circle(q2,5.0,Color("f0c48a"))
		draw_arc(q2,8.0+2.0*sin(clock*5.0),0,TAU,16,Color(0.95,0.77,0.54,0.6),1.2,true)
	for enemy in world.enemies:
		draw_circle(radar_point(enemy.pos),3.2,Color("ef8a6a"))
	for h in world.hornets:
		draw_circle(radar_point(h.pos),2.4,Color("f0b28c"))
	for mine in world.mines:
		draw_circle(radar_point(mine.pos),1.8,Color("e5866a"))
	if world.phase=="extraction":
		draw_circle(radar_point(world.pod_pos),4.0,Color("eeeec6"))
	# Own ship: velocity whisker plus a heading arrow along the aim.
	if world.velocity_ship.length()>5.0:
		draw_line(c,c+world.velocity_ship/BHSpace.BOOST*28.0,Color(0.8,1.0,0.95,0.7),1.5,true)
	var f: Vector2 = world.aim
	draw_colored_polygon(PackedVector2Array([c+f*8.0,c-f*5.0+f.orthogonal()*5.0,c-f*5.0-f.orthogonal()*5.0]),Color("f5ead0"))
	draw_string(font,c+Vector2(-RADAR_RADIUS,RADAR_RADIUS+26),"레이더 · %s" % distance_text(RADAR_RANGE),HORIZONTAL_ALIGNMENT_CENTER,RADAR_RADIUS*2,12,Color(0.8,0.9,0.86,0.75))

func draw_speed() -> void:
	var speed: float = world.velocity_ship.length()
	var at: Vector2 = Vector2(40,306)
	var mode: String = "순항"
	var tone: Color = Color("9fe0d4")
	if float(world.active.get("boost",0.0))>0.0:
		mode = "벡터 부스트"
		tone = Color("f5c77e")
	elif world.afterburner:
		mode = "애프터버너"
		tone = Color("f0a67c")
	elif speed<20.0:
		mode = "정지"
		tone = Color(0.75,0.82,0.8)
	elif Input.get_vector("left","right","up","down").is_zero_approx():
		mode = "관성 비행"
	draw_string_outline(font,at,"%d" % int(speed),HORIZONTAL_ALIGNMENT_LEFT,-1,30,6,Color(0.03,0.07,0.1,0.8))
	draw_string(font,at,"%d" % int(speed),HORIZONTAL_ALIGNMENT_LEFT,-1,30,Color("f5ead0"))
	var w: float = font.get_string_size("%d" % int(speed),HORIZONTAL_ALIGNMENT_LEFT,-1,30).x
	draw_string(font,at+Vector2(w+8,-2),"m/s  ·  %s" % mode,HORIZONTAL_ALIGNMENT_LEFT,-1,15,tone)
	var bar: Rect2 = Rect2(at+Vector2(0,10),Vector2(250,6))
	draw_rect(bar,Color(0.1,0.18,0.22,0.8))
	draw_rect(Rect2(bar.position,Vector2(bar.size.x*clampf(speed/BHSpace.BOOST,0,1),bar.size.y)),tone)
	var cruise_x: float = bar.position.x+bar.size.x*BHSpace.CRUISE/BHSpace.BOOST
	var burn_x: float = bar.position.x+bar.size.x*BHSpace.AFTERBURN/BHSpace.BOOST
	draw_line(Vector2(cruise_x,bar.position.y-3),Vector2(cruise_x,bar.end.y+3),Color("d9e3dc"),1.2)
	draw_line(Vector2(burn_x,bar.position.y-3),Vector2(burn_x,bar.end.y+3),Color("f0a67c"),1.2)
	draw_string(font,at+Vector2(0,36),"Shift 애프터버너  ·  키를 놓으면 관성으로 미끄러집니다",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(0.75,0.84,0.8,0.7))
