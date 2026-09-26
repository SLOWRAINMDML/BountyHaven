class_name BHInkArt
extends RefCounted
## Original, deterministic layered vector paintings. No baked-in people or UI.
## Rasterized once at scene creation; independent layers remain independently animated.
static var cache: Dictionary = {}
const INK = "#697574"
const LIGHT = "#dce0d1"
const PAPER = "#f3ecdc"

static func path(d: String, fill: String = "none", stroke: String = INK, width: float = 1.2, opacity: float = 1.0) -> String:
	return '<path d="%s" fill="%s" stroke="%s" stroke-width="%.2f" opacity="%.3f" stroke-linecap="round" stroke-linejoin="round"/>' % [d, fill, stroke, width, opacity]

static func rect(x: float, y: float, w: float, h: float, fill: String, opacity: float = 1.0, stroke: String = INK) -> String:
	return '<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="2" fill="%s" stroke="%s" stroke-width="0.8" opacity="%.3f"/>' % [x,y,w,h,fill,stroke,opacity]

static func ellipse(x: float, y: float, rx: float, ry: float, fill: String, opacity: float = 1.0, stroke: String = "none") -> String:
	return '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s" opacity="%.3f" stroke="%s" stroke-width="1.1"/>' % [x,y,rx,ry,fill,opacity,stroke]

static func line(x: float, y: float, ex: float, ey: float, color: String = INK, opacity: float = 1.0, width: float = 1.0) -> String:
	return path("M%.1f %.1fL%.1f %.1f" % [x,y,ex,ey], "none", color, width, opacity)

static func arch(x: float, y: float, w: float, h: float, fill: String, opacity: float = 1.0) -> String:
	return path("M%.1f %.1fv-%.1fq%.1f -%.1f %.1f 0v%.1fZ" % [x,y,h-w*0.5,w*0.5,w,w,h-w*0.5], fill, INK, 1.1, opacity)

static func building(x: float, y: float, w: float, h: float, wash: String, seed_value: int, detail: bool = true) -> String:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: String = rect(x, y, w, h, wash, 0.86)
	out += line(x+1,y-2,x+w-1,y-1,INK,0.30,0.45)
	out += path("M%.1f %.1fl%.1f -20v%.1fl-%.1f 20Z" % [x+w,y,w*0.18,h,w*0.18], "#b1b9ab", INK, 1.0, 0.65)
	out += path("M%.1f %.1fl%.1f -20h%.1fl-%.1f 20Z" % [x,y,w*0.18,w,w*0.18], "#e7deca")
	# Transparent overlapping pigment pools; quiet double pen strokes.
	for i in range(8):
		var by: float = rng.randf_range(y+8,y+h-8)
		out += ellipse(rng.randf_range(x+8,x+w-8),by,rng.randf_range(10,w*0.30),rng.randf_range(10,35),"#97b2ad",0.055)
	out += line(x+2,y+1,x+1,y+h,"#6c7471",0.42,0.65)
	if detail:
		var rows: int = maxi(1,int((h-90)/36))
		var cols: int = maxi(1,int((w-22)/28))
		for r in range(rows):
			for c in range(cols):
				var wx: float = x+14+c*(w-24)/cols
				var wy: float = y+28+r*36
				out += arch(wx,wy+19,10,19,"#9fb1ab",0.72)
				out += line(wx-2,wy+21,wx+13,wy+21,INK,0.65,0.55)
				if (r+c)%4==1:
					out += rect(wx-3,wy+2,2,18,"#bcb6a0",0.70)
				out += line(wx+4,wy+6,wx+4,wy+18,"#e3ded0",0.85,0.7)
			out += line(x+7,y+52+r*36,x+w-6,y+51+r*36,INK,0.25,0.65)
		for r in range(int(h/17)):
			for c in range(int(w/37)):
				if rng.randf() > 0.48:
					var sx: float = x+8+c*37+(r%2)*11
					out += line(sx,y+10+r*17,sx+12,y+10+r*17,INK,0.18,0.7)
	return out

static func sky(glass: bool) -> String:
	var rng = RandomNumberGenerator.new()
	rng.seed = 52
	var out: String = rect(0,0,1600,900,PAPER,1.0,"none")
	for i in range(50):
		out += ellipse(rng.randf_range(-100,1700),rng.randf_range(110,470),rng.randf_range(85,350),rng.randf_range(15,95),"#bed1cc" if glass else "#c6cec1",rng.randf_range(0.025,0.11))
	out += ellipse(1130,140,158,158,"#e0d9c3",0.3)
	out += '<ellipse cx="1080" cy="170" rx="395" ry="54" transform="rotate(-24 1080 170)" fill="none" stroke="#99ada8" stroke-width="1.1" opacity="0.55"/>'
	out += '<ellipse cx="1080" cy="170" rx="401" ry="58" transform="rotate(-24 1080 170)" fill="none" stroke="#99ada8" stroke-width="0.7" opacity="0.30"/>'
	for i in range(28):
		var x: float = i*63-60
		var h: float = rng.randf_range(100,250)
		out += '<g opacity="0.30">' + building(x,510-h,45+rng.randf()*30,h,"#b7c7bc",i+40,false) + '</g>'
		out += line(x+21,510-h,x+21,470-h,INK,0.2)
	return out

static func city(glass: bool) -> String:
	var out: String = ""
	var wash: String = "#d6e0d8" if glass else "#e3d9bd"
	# Immense orbital harbor tower, with radial landing decks and a weathered shaft.
	out += building(315,192,123,405,wash,31)
	out += building(338,122,70,80,wash,32,false)
	out += path("M328 122L375 74L419 121Z", "#b6c3b8")
	out += line(375,74,375,25,INK,0.7)
	for y in [235,326,427]:
		out += ellipse(377,float(y),164,28,"#d6d9c8",0.96,INK)
		out += ellipse(377,float(y)-9,165,21,"#e8e2ce",0.96,INK)
		out += path("M214 %dl8 12q150 53 309 -1l12 -12" % y,"none",INK,1.25)
		for x in range(228,530,22):
			out += line(x,y-6,x,y+10,INK,0.4,0.7)
	for y in range(164,555,23):
		out += line(347,y,408,y+2,INK,0.27,0.65)
	# Long viaduct: very thin outlines, muted washed stone, deep repeating archways.
	out += path("M-30 464Q710 386 1640 453L1640 487Q750 422 -30 500Z", "#c8cebe", INK,1.5)
	for x in range(-20,1630,127):
		out += arch(x,596,103,135,"#e5e6d8",0.9)
		out += line(x+11,590,x+11,512,INK,0.28)
	out += line(0,454,1600,445,INK,0.4,0.7)
	# Guild hall; small human entrances below a monumental facade.
	out += building(581,362,185,275,wash,58)
	out += path("M573 364L662 311L782 349L766 362Z","#a7bbb3")
	out += arch(643,640,49,82,"#647a79")
	out += arch(650,640,34,66,"#c8b89b",0.9)
	out += line(667,586,667,637,INK,0.8)
	out += rect(595,526,152,18,"#e5ddc4")
	out += ellipse(670,400,19,19,"#e9e4d3",0.95,INK)
	out += path("M664 389L675 404L664 415L667 402Z","#9baead")
	# Narrow residential stack behind the tavern.
	out += building(845,216,103,394,"#ccd5ca",87)
	out += building(886,158,36,65,"#cad0c1",88,false)
	out += path("M881 157L904 135L928 157Z","#809a96")
	# Lantern tavern with balconies, shade awning, cables and hanging plants.
	out += building(1013,318,191,338,"#e2d6bf",91)
	out += path("M1001 320L1087 276L1224 295L1204 320Z","#b4bfb0")
	out += arch(1080,657,48,78,"#576c6a")
	out += path("M1003 553L1225 559L1250 588L980 583Z","#bf9275",INK,1.3,0.92)
	for x in range(1000,1221,27):
		out += line(x,555,x-12,581,"#e6ccb1",0.7,2)
	for y in [428,495]:
		out += rect(997,y,226,13,"#adb8aa")
		for x in range(1001,1222,12):
			out += line(x,y,x,y-18,INK,0.7,0.8)
		out += line(998,y-19,1223,y-19)
	out += line(990,329,1259,367,INK,0.65,0.8)
	out += path("M965 528Q1100 487 1271 529","none",INK,0.75)
	for x in [1000,1070,1175,1240]:
		out += line(x,519,x,543,INK,0.7)
		out += ellipse(x,547,5,8,"#ccaa77",0.9,INK)
	# Outfitter's lower dome and workshop.
	out += building(1330,457,168,251,"#d7dbc9",105)
	out += path("M1320 457Q1407 348 1516 457Z","#a5bcb7",INK,1.2)
	out += path("M1360 456Q1399 363 1409 405Q1439 416 1470 456","none",INK,0.7,0.5)
	out += arch(1393,710,54,75,"#586c6b")
	out += rect(1336,610,67,20,"#e9dfc6")
	out += path("M1457 620h56l24 34h-87Z","#bcae91")
	# Architectural rigging, pipes and small futuristic service markings.
	for x in [622,733,1045,1188,1366,1480]:
		out += path("M%d 499v85h8v24" % x,"none",INK,1.4,0.5)
	out += path("M437 300Q610 359 847 260M942 310Q1010 337 1034 334","none",INK,0.8,0.6)
	# Tiny organic roof gardens and weathering, kept out of the authored pedestrian lane.
	var rng = RandomNumberGenerator.new()
	rng.seed = 417
	for box in [Vector2(1012,422),Vector2(1114,489),Vector2(1338,601),Vector2(702,522)]:
		out += rect(box.x,box.y,29,8,"#b4ac90",0.85)
		for j in range(10):
			var gx: float = box.x+rng.randf_range(-3,32)
			var gy: float = box.y-rng.randf_range(0,14)
			out += ellipse(gx,gy,rng.randf_range(3,8),rng.randf_range(2,5),"#9aae99",0.30)
			out += line(gx,gy,box.x+15,box.y+3,INK,0.20,0.5)
	for i in range(24):
		var px: float = rng.randf_range(585,756)
		var py: float = rng.randf_range(372,520)
		out += line(px,py,px+3,py-4,INK,0.20,0.45)
	out += path("M638 638L638 598Q662 542 692 596V637","none",INK,0.70,0.60)
	out += path("M632 638L632 596Q662 532 698 594V637","none",INK,0.50,0.45)
	out += line(774,610,818,602,INK,0.40,0.65)
	return out

static func ground(glass: bool) -> String:
	var out: String = path("M0 610L400 608L510 647L170 850H0Z", "#acc2bc", "none")
	out += path("M164 825L491 639L650 594L1210 615L1500 713L1550 833Z", "#e5ddc9",INK,1.5)
	out += path("M164 825L491 639L650 594L647 609L499 653L193 825Z", "#bcbca9",INK,0.9)
	var rng = RandomNumberGenerator.new()
	rng.seed = 30
	for y in range(659,832,24):
		out += line(535-(y-659)*1.65,y,1350+(y-659)*0.85,y-5,INK,0.22,0.7)
	for x in range(335,1540,62):
		out += line(x,823,800+(x-800)*0.45,642,INK,0.17,0.6)
	for i in range(80):
		out += ellipse(rng.randf_range(500,1400),rng.randf_range(680,805),rng.randf_range(4,25),rng.randf_range(1,6),"#aebaa9",0.05)
	# Dock landing and steps; these areas have explicitly authored walkability.
	out += path("M195 768L394 671L462 690L289 802Z","#c4bda8",INK,1.0)
	for i in range(7):
		out += line(263+i*18,775-i*10,312+i*18,790-i*10,INK,0.55,0.8)
	out += path("M625 642L719 645L739 663L600 661Z","#d3cbb5")
	out += path("M1074 655H1141L1163 675H1053Z","#d2c6af")
	# Baggage and a readable route-record terminal, not part of the background people.
	out += building(793,634,41,40,"#a9bcb3",900,false)
	out += rect(800,639,24,14,"#668887")
	for x in [915,943]:
		out += building(x,655,23,25,"#c3ab86",120,false)
	return out

static func foreground() -> String:
	var out: String = ""
	out += path("M0 859L156 819L163 850L0 898Z","#b8beaa",INK,1.5)
	out += path("M118 838L157 815L452 641","none",INK,2.0)
	for i in range(8):
		var x: float = 154+i*42
		var y: float = 817-i*24
		out += line(x,y,x,y-29,INK,0.9,1.6)
	out += line(155,788,448,620,INK,0.85,1.4)
	# A close inked lantern and ivy frame the scene without obscuring the street.
	out += path("M1518 840V504Q1520 476 1550 481h26","none",INK,3.0)
	out += path("M1568 479v35m-12 0h25l-3 33h-19Z","#dccda9",INK,1.5)
	for i in range(12):
		out += ellipse(1560+(i%3)*10,745-i*9,8,4,"#81998b",0.5)
	return out

static func cabin() -> String:
	var out: String = rect(0,0,1600,900,"#e8e7db",1.0,"none")
	out += ellipse(815,550,700,263,"#bcc6bf",0.20)
	out += path("M150 444L312 310H1263L1452 440V788H148Z","#d7d3c0",INK,1.8)
	out += path("M151 446L313 330H1257L1450 446H151Z","#efeadb",INK,1.4)
	out += path("M170 473H1420V784H170Z","#ded4bd",INK,1.4)
	out += path("M170 473H1420L1367 500H225Z","#bfbda9",INK,0.8,0.6)
	for y in range(498,783,22):
		out += line(174,y,1416,y,"#8e9384",0.23,0.7)
	for x in range(190,1420,62):
		out += line(x,474,x,785,"#8e9384",0.20,0.6)
	# Three real windows: deep blue outside, pale pen-drawn mullions.
	for x in [460,725,990]:
		out += arch(x,433,159,89,"#648384")
		out += arch(x+8,426,143,74,"#93b2ad")
		out += ellipse(x+91,384,23,23,"#e0d6b9",0.8)
		out += line(x+81,351,x+81,428,"#e5e0cd",0.95,3)
		out += line(x+8,403,x+151,403,"#e5e0cd",0.95,2)
	# Exposed overhead ribs, ducts, storage and galley.
	for x in [370,662,931,1198]:
		out += path("M%d 464v-52q0 -63 24 -75" % x,"none",INK,2,0.7)
		out += path("M%d 463v-49q0 -62 21 -75" % (x+6),"none","#f7f2e5",2,0.95)
	out += rect(232,352,116,93,"#c1b79f")
	out += rect(241,360,45,75,"#d4c8ad")
	out += rect(291,360,45,75,"#d4c8ad")
	out += line(280,389,280,408,INK,0.8,2)
	out += line(297,389,297,408,INK,0.8,2)
	out += rect(1265,371,111,77,"#b2bbb0")
	out += rect(1276,379,43,42,"#e4dccc")
	out += ellipse(1347,398,14,14,"#707f7b",0.9,INK)
	out += line(1268,432,1375,432,INK,0.5)
	# Cockpit and airlock stay reachable via the permanently reserved aisle.
	out += path("M162 560L108 582V650L162 680Z","#8fa8a2",INK,1.4)
	out += path("M115 591L153 574V609L115 618Z","#3e6266")
	out += rect(1405,579,49,91,"#889e98")
	out += rect(1413,588,29,34,"#bfd0c5")
	out += line(1428,579,1428,670,INK,0.8)
	# Warm cloth, suspended light, handwritten-looking frame shapes and pipework.
	out += path("M441 347Q452 355 456 430L444 435Q449 385 434 353Z","#cbb69f",INK,0.7,0.7)
	out += path("M1153 348L1170 350Q1157 388 1168 433L1152 430Q1162 388 1153 348Z","#cbb69f",INK,0.7,0.7)
	for cx in [625,887]:
		out += path("M%d 334v28m-18 0h37l9 18h-55Z" % cx,"#d7c4a0",INK,0.8)
		out += ellipse(cx,393,72,31,"#e1cd9d",0.06)
	out += rect(375,366,39,47,"#d6c7ac",0.9)
	out += rect(379,370,31,37,"#ede6d3",0.9)
	out += path("M383 394l8 -13l7 9l7 -4M382 400h24","none",INK,0.7,0.8)
	out += path("M246 443v13h148m810 0h151v-13","none",INK,0.8,0.7)
	for px in range(260,1290,106):
		out += ellipse(px,461,1.5,1.5,"#8b9287",0.50)
	# Paper flecks, pigment pools and panel fasteners: deterministic, very subtle.
	var rng = RandomNumberGenerator.new()
	rng.seed = 71
	for i in range(90):
		out += ellipse(rng.randf_range(180,1400),rng.randf_range(483,781),rng.randf_range(4,25),rng.randf_range(1,9),"#a6ab90",0.035)
	return out

static func texture(kind: String, layer: String = "sky") -> Texture2D:
	var key: String = kind + layer
	if cache.has(key):
		return cache[key]
	var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="900" viewBox="0 0 1600 900">'
	match layer:
		"sky": svg += sky(kind == "glass")
		"city": svg += city(kind == "glass")
		"ground": svg += ground(kind == "glass")
		"foreground": svg += foreground()
		"cabin": svg += cabin()
	svg += '</svg>'
	var image = Image.new()
	var err: Error = image.load_svg_from_string(svg)
	if err != OK:
		push_error("Ink art could not be rasterized: " + key)
		image = Image.create(1600,900,false,Image.FORMAT_RGBA8)
	var tex = ImageTexture.create_from_image(image)
	cache[key] = tex
	return tex
