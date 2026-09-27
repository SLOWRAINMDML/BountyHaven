class_name BHRig
extends RefCounted
## Skeletal cutout rigs ("Spine style"): bones with per-view setup poses, slots that hold
## one attachment image each, skins of attachments per view, and keyframed clips.
## Shared by the game puppet (scripts/world/puppet.gd) and the rig editor
## (scripts/rig/rig_editor.gd). Format reference: docs/art/RIG_FORMAT.md.
## Units are rig pixels (origin = ground between the feet, y down); angles are degrees.

## Drawn views. Diagonal and side views face screen-right; left-facing directions mirror them.
const VIEWS: Array = ["front","front34","side","back34","back"]
const VIEW_NAMES: Dictionary = {"front":"정면","front34":"정면 대각","side":"옆","back34":"뒤 대각","back":"뒤"}
## Eight movement sectors starting east, clockwise on screen (y down): [view, mirrored].
const SECTORS: Array = [["side",false],["front34",false],["front",false],["front34",true],["side",true],["back34",true],["back",false],["back34",false]]
const CURVES: Array = ["smooth","linear","step"]
const TRACK_WIDTH: Dictionary = {"rotate":1,"translate":2,"scale":2}

static var cache: Dictionary = {}
static var textures: Dictionary = {}

static func load_file(path: String, fresh: bool = false) -> Dictionary:
	if fresh or not cache.has(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		cache[path] = parsed if parsed is Dictionary else {}
	return cache[path]

static func save_file(path: String, rig: Dictionary) -> Error:
	var file = FileAccess.open(path,FileAccess.WRITE)
	if file==null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(rig,"\t",false)+"\n")
	file.close()
	cache[path] = rig
	return OK

## Image paths are relative to the rig's part_root. Unimported PNGs (just dropped into the
## folder while the rig editor runs) load straight from disk.
static func texture(rig: Dictionary, image: String) -> Texture2D:
	var path: String = str(rig.get("part_root","res://"))+image
	if not textures.has(path):
		var tex: Texture2D = null
		if ResourceLoader.exists(path):
			tex = load(path)
		elif FileAccess.file_exists(path):
			var img: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
			if img!=null and not img.is_empty():
				img.generate_mipmaps()
				tex = ImageTexture.create_from_image(img)
		textures[path] = tex
	return textures[path]

static func forget_texture(rig: Dictionary, image: String) -> void:
	textures.erase(str(rig.get("part_root","res://"))+image)

## Movement direction on screen -> [view, mirrored].
static func view_for(direction: Vector2) -> Array:
	if direction.length_squared()<0.0001:
		return ["front",false]
	var sector: int = posmod(int(round(direction.angle()/(PI/4.0))),8)
	return SECTORS[sector]

## Sector direction for index 0..7 (east, clockwise).
static func sector_direction(index: int) -> Vector2:
	return Vector2.RIGHT.rotated(posmod(index,8)*PI/4.0)

## Views without art yet borrow the first drawn view, so a partly drawn rig still plays.
static func effective_view(rig: Dictionary, view: String) -> String:
	var drawn: Array = rig.get("views",["front"])
	return view if view in drawn else str(drawn[0])

static func bone_map(rig: Dictionary) -> Dictionary:
	var map: Dictionary = {}
	for bone in rig.get("bones",[]):
		map[bone.name] = bone
	return map

static func slot_map(rig: Dictionary) -> Dictionary:
	var map: Dictionary = {}
	for slot in rig.get("slots",[]):
		map[slot.name] = slot
	return map

static func first_view(rig: Dictionary) -> String:
	return str(rig.get("views",["front"])[0])

static func setup(rig: Dictionary, bone: Dictionary, view: String) -> Dictionary:
	var table: Dictionary = bone.get("setup",{})
	if table.has(view):
		return table[view]
	return table.get(first_view(rig),{"x":0,"y":0,"rotation":0,"scale_x":1,"scale_y":1})

static func slot_z(rig: Dictionary, slot: Dictionary, view: String) -> int:
	var table: Dictionary = slot.get("z",{})
	return int(table.get(view,table.get(first_view(rig),0)))

## Slots sorted back-to-front for a view.
static func draw_order(rig: Dictionary, view: String) -> Array:
	var slots: Array = rig.get("slots",[]).duplicate()
	var index: Dictionary = {}
	for i in slots.size():
		index[slots[i].name] = i
	slots.sort_custom(func(a,b):
		var za: int = slot_z(rig,a,view)
		var zb: int = slot_z(rig,b,view)
		return za<zb if za!=zb else index[a.name]<index[b.name])
	return slots

static func attachment(rig: Dictionary, slot: String, name: String, view: String, skin: String = "default") -> Dictionary:
	var entry: Variant = rig.get("skins",{}).get(skin,{}).get(slot,{}).get(name,{})
	if entry is Dictionary and entry.has(view):
		return entry[view]
	return {}

## Local transform of an attachment image inside its bone.
static func attachment_transform(att: Dictionary) -> Transform2D:
	var scale: Array = att.get("scale",[1,1])
	var pivot: Array = att.get("pivot",[0,0])
	return Transform2D(deg_to_rad(float(att.get("rotation",0.0))),Vector2(float(scale[0]),float(scale[1])),0.0,Vector2.ZERO).translated_local(-Vector2(float(pivot[0]),float(pivot[1])))

## Interpolate one track. Keys are [t, v...(width), curve]; the curve on a key shapes the
## segment that starts there. Looping clips wrap from the last key back to the first.
static func sample(keys: Array, t: float, duration: float, loop: bool, width: int) -> Array:
	if keys.is_empty():
		return []
	var n: int = keys.size()
	if n==1:
		return values(keys[0],width)
	var i: int = -1
	for k in n:
		if float(keys[k][0])<=t:
			i = k
	var a: Array
	var b: Array
	var t0: float
	var t1: float
	var ia: int = i
	if i<0 or i==n-1:
		if not loop or duration<=0.0:
			return values(keys[0] if i<0 else keys[n-1],width)
		a = keys[n-1]
		b = keys[0]
		t0 = float(a[0])-(duration if i<0 else 0.0)
		t1 = float(b[0])+(0.0 if i<0 else duration)
		ia = n-1
	else:
		a = keys[i]
		b = keys[i+1]
		t0 = float(a[0])
		t1 = float(b[0])
	var u: float = 0.0 if t1-t0<=0.00001 else clampf((t-t0)/(t1-t0),0.0,1.0)
	var curve: String = str(a[width+1]) if a.size()>width+1 else "linear"
	var va: Array = values(a,width)
	var vb: Array = values(b,width)
	if curve=="step":
		return va
	var out: Array = []
	if curve=="smooth":
		var prev: Array = values(keys[posmod(ia-1,n)] if (loop or ia>0) else a,width)
		var next_index: int = ia+2
		var after: Array = values(keys[posmod(next_index,n)] if (loop or next_index<n) else b,width)
		for c in width:
			out.append(catmull(float(prev[c]),float(va[c]),float(vb[c]),float(after[c]),u))
		return out
	for c in width:
		out.append(lerpf(float(va[c]),float(vb[c]),u))
	return out

static func values(key: Array, width: int) -> Array:
	var out: Array = []
	for c in width:
		out.append(float(key[c+1]) if key.size()>c+1 else 0.0)
	return out

static func catmull(p0: float, p1: float, p2: float, p3: float, u: float) -> float:
	var u2: float = u*u
	var u3: float = u2*u
	return 0.5*((2.0*p1)+(-p0+p2)*u+(2.0*p0-5.0*p1+4.0*p2-p3)*u2+(-p0+3.0*p1-3.0*p2+p3)*u3)

## The track a bone uses in a view: a view-specific track wins over the shared "*" one.
static func track(clip: Dictionary, view: String, bone: String, property: String) -> Array:
	var tracks: Dictionary = clip.get("tracks",{})
	var own: Variant = tracks.get(view,{}).get(bone,{}).get(property,null)
	if own is Array:
		return own
	var shared: Variant = tracks.get("*",{}).get(bone,{}).get(property,null)
	return shared if shared is Array else []

## Pose offsets per bone at time t: {bone: {rotate, translate, scale}} added to the setup.
static func pose(rig: Dictionary, clip_name: String, view: String, t: float) -> Dictionary:
	var result: Dictionary = {}
	var clip: Dictionary = rig.get("animations",{}).get(clip_name,{})
	if clip.is_empty():
		return result
	var duration: float = float(clip.get("duration",1.0))
	var loop: bool = bool(clip.get("loop",true))
	if loop and duration>0.0:
		t = fposmod(t,duration)
	for bone in rig.get("bones",[]):
		var entry: Dictionary = {}
		for property in TRACK_WIDTH:
			var keys: Array = track(clip,view,bone.name,property)
			if keys.is_empty():
				continue
			var v: Array = sample(keys,t,duration,loop,TRACK_WIDTH[property])
			match property:
				"rotate": entry.rotate = v[0]
				"translate": entry.translate = Vector2(v[0],v[1])
				"scale": entry.scale = Vector2(v[0],v[1])
		if not entry.is_empty():
			result[bone.name] = entry
	return result

## Attachment swaps keyed in a clip: {slot: attachment name or ""}.
static func slot_keys(rig: Dictionary, clip_name: String, view: String, t: float) -> Dictionary:
	var result: Dictionary = {}
	var clip: Dictionary = rig.get("animations",{}).get(clip_name,{})
	var tables: Dictionary = clip.get("slots",{})
	if tables.is_empty():
		return result
	var duration: float = float(clip.get("duration",1.0))
	if bool(clip.get("loop",true)) and duration>0.0:
		t = fposmod(t,duration)
	for scope in ["*",view]:
		for slot in tables.get(scope,{}):
			var chosen: Variant = null
			for key in tables[scope][slot]:
				if float(key[0])<=t:
					chosen = key[1]
			if chosen!=null:
				result[slot] = str(chosen)
	return result

static func blend(a: Dictionary, b: Dictionary, w: float) -> Dictionary:
	if w>=1.0:
		return b
	var out: Dictionary = {}
	for bone in a.keys()+b.keys():
		if out.has(bone):
			continue
		var pa: Dictionary = a.get(bone,{})
		var pb: Dictionary = b.get(bone,{})
		out[bone] = {
			"rotate":lerpf(float(pa.get("rotate",0.0)),float(pb.get("rotate",0.0)),w),
			"translate":(pa.get("translate",Vector2.ZERO) as Vector2).lerp(pb.get("translate",Vector2.ZERO),w),
			"scale":(pa.get("scale",Vector2.ONE) as Vector2).lerp(pb.get("scale",Vector2.ONE),w),
		}
	return out

## Forward kinematics: world transform of every bone in rig space.
static func solve(rig: Dictionary, view: String, offsets: Dictionary) -> Dictionary:
	var world: Dictionary = {}
	for bone in rig.get("bones",[]):
		world[bone.name] = parent_world(world,bone)*local_transform(rig,bone,view,offsets.get(bone.name,{}))
	return world

static func parent_world(world: Dictionary, bone: Dictionary) -> Transform2D:
	var parent: String = str(bone.get("parent",""))
	return world.get(parent,Transform2D.IDENTITY) if not parent.is_empty() else Transform2D.IDENTITY

static func local_transform(rig: Dictionary, bone: Dictionary, view: String, offset: Dictionary) -> Transform2D:
	var s: Dictionary = setup(rig,bone,view)
	var scale := Vector2(float(s.get("scale_x",1.0)),float(s.get("scale_y",1.0)))*(offset.get("scale",Vector2.ONE) as Vector2)
	var position := Vector2(float(s.get("x",0.0)),float(s.get("y",0.0)))+(offset.get("translate",Vector2.ZERO) as Vector2)
	return Transform2D(deg_to_rad(float(s.get("rotation",0.0))+float(offset.get("rotate",0.0))),scale,0.0,position)

## Structural checks used by tests and the editor before saving.
static func problems(rig: Dictionary) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for bone in rig.get("bones",[]):
		var parent: String = str(bone.get("parent",""))
		if not parent.is_empty() and not seen.has(parent):
			out.append("bone %s is listed before its parent %s" % [bone.name,parent])
		seen[bone.name] = true
	for slot in rig.get("slots",[]):
		if not seen.has(slot.bone):
			out.append("slot %s uses missing bone %s" % [slot.name,slot.bone])
	for view in rig.get("views",[]):
		if not view in VIEWS:
			out.append("unknown view "+str(view))
	for clip_name in rig.get("animations",{}):
		var clip: Dictionary = rig.animations[clip_name]
		for scope in clip.get("tracks",{}):
			for bone in clip.tracks[scope]:
				if not seen.has(bone):
					out.append("clip %s animates missing bone %s" % [clip_name,bone])
	return out
