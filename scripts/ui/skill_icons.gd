class_name BHSkillIcons
extends RefCounted
## Module skill icons, authored as layered SVG (gradients, ink outlines, highlights) and
## rasterized once per size. Same frame for every module; the device drawn inside matches
## the 3D hardpoint part, so an icon, its hull part and its effect read as one thing.
static var cache: Dictionary = {}

const FRAME_DEFS = """
<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2d4652"/><stop offset="1" stop-color="#132631"/></linearGradient>
<radialGradient id="vig" cx="0.5" cy="0.42" r="0.62"><stop offset="0.55" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="0.45"/></radialGradient>
<linearGradient id="brass" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#f3e2b8"/><stop offset="0.45" stop-color="#c9a36a"/><stop offset="1" stop-color="#7d5a33"/></linearGradient>
<linearGradient id="cream" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fbf2dd"/><stop offset="1" stop-color="#cdbb97"/></linearGradient>
<linearGradient id="rust" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#d9804f"/><stop offset="1" stop-color="#8c4428"/></linearGradient>
<linearGradient id="steel" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#8fa3ab"/><stop offset="1" stop-color="#3c4d56"/></linearGradient>
<linearGradient id="gloss" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity="0.22"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>
"""

## Accent glow color per module, shared with the HUD slot's ready/active highlight.
const ACCENT = {"boost":Color("7fe3d2"),"tether":Color("f0d58a"),"shield":Color("8fe6e0"),"emp":Color("c8a8f0"),"rail":Color("f5c77e"),"drone":Color("bfe59a")}

static func glow_def(id: String, color: String) -> String:
	return '<radialGradient id="%s" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="%s" stop-opacity="0.95"/><stop offset="0.45" stop-color="%s" stop-opacity="0.35"/><stop offset="1" stop-color="%s" stop-opacity="0"/></radialGradient>' % [id,color,color,color]

static func art(id: String) -> String:
	match id:
		"boost":
			# Side thruster nacelle, vanes flared open, teal exhaust chevrons streaking back.
			return glow_def("g","#7fe3d2")+"""</defs>
<ellipse cx="44" cy="80" rx="40" ry="26" fill="url(#g)"/>
<path d="M14 92 L46 80 M8 76 L44 70 M18 60 L48 62" stroke="#bff6ec" stroke-width="3" stroke-linecap="round" opacity="0.8"/>
<path d="M30 84 l10 -8 l-10 -8" fill="none" stroke="#7fe3d2" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M44 84 l10 -8 l-10 -8" fill="none" stroke="#dffbf5" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>
<ellipse cx="86" cy="112" rx="34" ry="6" fill="#050d12" opacity="0.5"/>
<path d="M58 50 L98 40 Q112 42 114 58 L112 92 Q108 104 94 102 L58 96 Z" fill="url(#cream)" stroke="#1d2b31" stroke-width="3" stroke-linejoin="round"/>
<path d="M62 56 L100 48 L102 62 L62 66 Z" fill="url(#rust)" stroke="#1d2b31" stroke-width="2"/>
<path d="M68 38 L92 22 L100 30 L80 46 Z" fill="url(#steel)" stroke="#1d2b31" stroke-width="2.5" stroke-linejoin="round"/>
<path d="M68 108 L92 122 L100 114 L80 98 Z" fill="url(#steel)" stroke="#1d2b31" stroke-width="2.5" stroke-linejoin="round"/>
<rect x="52" y="64" width="12" height="30" rx="3" fill="#2b3a41" stroke="#1d2b31" stroke-width="2"/>
<rect x="54" y="68" width="8" height="22" rx="2" fill="#7fe3d2"/>
<path d="M72 74 h26 M72 82 h26" stroke="#8d7a5e" stroke-width="1.6"/>
<circle cx="106" cy="66" r="3" fill="#1d2b31"/><circle cx="106" cy="88" r="3" fill="#1d2b31"/>
<path d="M64 52 L96 44" stroke="#fff" stroke-width="2" opacity="0.6" stroke-linecap="round"/>
"""
		"tether":
			# Brass harpoon head on an ion cable that coils back in bright loops.
			return glow_def("g","#f0d58a")+"""</defs>
<circle cx="84" cy="44" r="36" fill="url(#g)"/>
<path d="M18 110 C 30 86, 54 108, 48 86 S 30 62, 56 64 S 74 76, 76 58" fill="none" stroke="#f7e4a6" stroke-width="7" stroke-linecap="round" opacity="0.35"/>
<path d="M18 110 C 30 86, 54 108, 48 86 S 30 62, 56 64 S 74 76, 76 58" fill="none" stroke="#fff3cf" stroke-width="3" stroke-linecap="round"/>
<circle cx="36" cy="98" r="3" fill="#fff8e0"/><circle cx="52" cy="72" r="2.5" fill="#fff8e0"/>
<g transform="translate(-14 4) scale(1.1)">
<path d="M70 62 L96 36" stroke="#1d2b31" stroke-width="12" stroke-linecap="round"/>
<path d="M70 62 L96 36" stroke="url(#steel)" stroke-width="7" stroke-linecap="round"/>
<path d="M90 24 L116 12 L104 38 Z" fill="url(#brass)" stroke="#1d2b31" stroke-width="3" stroke-linejoin="round"/>
<path d="M88 30 L78 22 L92 20 Z M98 40 L106 50 L108 36 Z" fill="url(#rust)" stroke="#1d2b31" stroke-width="2.5" stroke-linejoin="round"/>
<rect x="64" y="58" width="16" height="12" rx="3" transform="rotate(-45 72 64)" fill="url(#rust)" stroke="#1d2b31" stroke-width="2.5"/>
<path d="M100 20 L112 15" stroke="#fff" stroke-width="2" opacity="0.7" stroke-linecap="round"/>
</g>
"""
		"shield":
			# Faceted prism barrier arcing in front of the courier's nose.
			return glow_def("g","#8fe6e0")+"""<linearGradient id="prism" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#bff6f0" stop-opacity="0.9"/><stop offset="0.5" stop-color="#8fe6e0" stop-opacity="0.55"/><stop offset="1" stop-color="#c7b8f5" stop-opacity="0.8"/></linearGradient></defs>
<ellipse cx="64" cy="46" rx="52" ry="34" fill="url(#g)"/>
<path d="M14 58 Q64 4 114 58 L104 66 Q64 22 24 66 Z" fill="url(#prism)" stroke="#e8fffb" stroke-width="2.5" stroke-linejoin="round"/>
<path d="M30 46 L40 58 M50 32 L56 50 M64 28 L64 46 M78 32 L72 50 M98 46 L88 58" stroke="#ffffff" stroke-width="2" opacity="0.75"/>
<ellipse cx="64" cy="116" rx="30" ry="5" fill="#050d12" opacity="0.5"/>
<path d="M64 60 L78 96 L72 112 L56 112 L50 96 Z" fill="url(#cream)" stroke="#1d2b31" stroke-width="3" stroke-linejoin="round"/>
<path d="M56 74 L72 74 L76 90 L52 90 Z" fill="url(#rust)" stroke="#1d2b31" stroke-width="2"/>
<ellipse cx="64" cy="68" rx="5" ry="7" fill="#7fe3d2" stroke="#1d2b31" stroke-width="2"/>
<path d="M50 96 L34 108 L40 114 L54 106 M78 96 L94 108 L88 114 L74 106" fill="url(#steel)" stroke="#1d2b31" stroke-width="2.5" stroke-linejoin="round"/>
<circle cx="64" cy="100" r="5" fill="#2b3a41" stroke="#8fe6e0" stroke-width="2"/>
"""
		"emp":
			# Raised emitter dish throwing violet rings and forked arcs.
			return glow_def("g","#c8a8f0")+"""</defs>
<circle cx="64" cy="56" r="54" fill="url(#g)"/>
<circle cx="64" cy="56" r="44" fill="none" stroke="#d9c4ff" stroke-width="2.5" opacity="0.45"/>
<circle cx="64" cy="56" r="32" fill="none" stroke="#e6d8ff" stroke-width="3" opacity="0.7"/>
<path d="M22 30 L34 40 L28 44 L42 54" fill="none" stroke="#f4ecff" stroke-width="3" stroke-linejoin="round" stroke-linecap="round"/>
<path d="M106 28 L94 40 L100 44 L86 52" fill="none" stroke="#f4ecff" stroke-width="3" stroke-linejoin="round" stroke-linecap="round"/>
<path d="M30 60 Q64 84 98 60 L92 54 Q64 72 36 54 Z" fill="url(#steel)" stroke="#1d2b31" stroke-width="3" stroke-linejoin="round"/>
<path d="M36 54 Q64 72 92 54 Q64 38 36 54 Z" fill="#c8a8f0" stroke="#1d2b31" stroke-width="2.5"/>
<ellipse cx="64" cy="54" rx="9" ry="5" fill="#fbf4ff"/>
<rect x="58" y="70" width="12" height="22" fill="url(#steel)" stroke="#1d2b31" stroke-width="2.5"/>
<ellipse cx="64" cy="112" rx="34" ry="5" fill="#050d12" opacity="0.5"/>
<path d="M40 108 L50 90 L78 90 L88 108 Z" fill="url(#cream)" stroke="#1d2b31" stroke-width="3" stroke-linejoin="round"/>
<rect x="46" y="98" width="36" height="6" fill="url(#rust)" stroke="#1d2b31" stroke-width="1.8"/>
"""
		"rail":
			# Heavy rail cannon: armored breech, twin conductor rails, brass charge coils, hot muzzle.
			return glow_def("g","#f5c77e")+"""</defs>
<ellipse cx="98" cy="30" rx="36" ry="30" fill="url(#g)"/>
<path d="M92 36 L124 4" stroke="#fff1cc" stroke-width="12" stroke-linecap="round" opacity="0.3"/>
<path d="M92 36 L124 4" stroke="#fffaf0" stroke-width="3.5" stroke-linecap="round"/>
<ellipse cx="64" cy="112" rx="44" ry="7" fill="#050d12" opacity="0.5"/>
<g transform="rotate(-45 58 70)">
<rect x="8" y="58" width="112" height="24" rx="4" fill="#1d2b31"/>
<rect x="40" y="60" width="80" height="7" rx="2" fill="url(#steel)" stroke="#1d2b31" stroke-width="1.5"/>
<rect x="40" y="73" width="80" height="7" rx="2" fill="url(#steel)" stroke="#1d2b31" stroke-width="1.5"/>
<rect x="44" y="67" width="74" height="6" fill="#f5c77e" opacity="0.9"/>
<rect x="50" y="54" width="9" height="32" rx="2" fill="url(#brass)" stroke="#1d2b31" stroke-width="2"/>
<rect x="68" y="55" width="9" height="30" rx="2" fill="url(#brass)" stroke="#1d2b31" stroke-width="2"/>
<rect x="86" y="56" width="9" height="28" rx="2" fill="url(#brass)" stroke="#1d2b31" stroke-width="2"/>
<rect x="116" y="57" width="8" height="26" rx="2" fill="url(#steel)" stroke="#1d2b31" stroke-width="2"/>
<path d="M4 52 L42 52 L46 60 L46 80 L42 88 L4 88 Z" fill="url(#cream)" stroke="#1d2b31" stroke-width="3" stroke-linejoin="round"/>
<rect x="10" y="60" width="28" height="8" fill="url(#rust)" stroke="#1d2b31" stroke-width="1.8"/>
<circle cx="14" cy="80" r="2.5" fill="#1d2b31"/><circle cx="34" cy="80" r="2.5" fill="#1d2b31"/>
<path d="M8 55 L40 55" stroke="#fff" stroke-width="2" opacity="0.6"/>
</g>
<circle cx="100" cy="28" r="6" fill="#fff6dc"/>
"""
		"drone":
			# Little repair drone with rotor ring and a green weld spark over a hull plate.
			return glow_def("g","#bfe59a")+"""</defs>
<circle cx="64" cy="54" r="46" fill="url(#g)"/>
<path d="M18 108 L110 108 L104 120 L24 120 Z" fill="url(#cream)" stroke="#1d2b31" stroke-width="3" stroke-linejoin="round"/>
<path d="M40 108 L48 120 M72 108 L80 120" stroke="#8d7a5e" stroke-width="2"/>
<path d="M58 108 L64 94 L70 108" fill="none" stroke="#e9ffd4" stroke-width="3" stroke-linejoin="round"/>
<circle cx="64" cy="98" r="6" fill="#f6ffe6"/>
<path d="M50 96 l-8 -4 M78 96 l8 -4 M64 88 v-6" stroke="#dfffbe" stroke-width="2.5" stroke-linecap="round"/>
<ellipse cx="64" cy="40" rx="42" ry="10" fill="none" stroke="#1d2b31" stroke-width="7"/>
<ellipse cx="64" cy="40" rx="42" ry="10" fill="none" stroke="url(#steel)" stroke-width="4"/>
<path d="M40 44 Q64 80 88 44 Q64 28 40 44 Z" fill="url(#cream)" stroke="#1d2b31" stroke-width="3"/>
<path d="M50 40 Q64 34 78 40" fill="none" stroke="#fff" stroke-width="2" opacity="0.6"/>
<rect x="60" y="24" width="8" height="12" fill="url(#steel)" stroke="#1d2b31" stroke-width="2"/>
<path d="M48 46 Q64 54 80 46" fill="none" stroke="url(#rust)" stroke-width="5"/>
<circle cx="64" cy="52" r="6" fill="#bfe59a" stroke="#1d2b31" stroke-width="2"/>
<path d="M58 62 L54 80 M70 62 L74 80" stroke="#1d2b31" stroke-width="3" stroke-linecap="round"/>
<path d="M22 40 h12 M94 40 h12" stroke="#fff" stroke-width="2" opacity="0.6"/>
"""
	return "</defs>"

static func svg(id: String) -> String:
	var body: String = art(id)
	var split: int = body.find("</defs>")
	return '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><defs>'+FRAME_DEFS+body.substr(0,split)+'</defs>' \
		+'<rect x="3" y="3" width="122" height="122" rx="18" fill="url(#bg)"/>' \
		+'<path d="M3 96 L125 70 L125 125 L3 125 Z" fill="#0c1a22" opacity="0.35"/>' \
		+body.substr(split+7) \
		+'<rect x="3" y="3" width="122" height="122" rx="18" fill="url(#vig)"/><rect x="6" y="6" width="116" height="52" rx="15" fill="url(#gloss)"/>' \
		+'<rect x="3" y="3" width="122" height="122" rx="18" fill="none" stroke="url(#brass)" stroke-width="4"/>' \
		+'<rect x="8" y="8" width="112" height="112" rx="14" fill="none" stroke="#0e1b22" stroke-width="1.5" opacity="0.7"/></svg>'

static func texture(id: String, size: int = 128) -> Texture2D:
	var key: String = "%s@%d" % [id,size]
	if cache.has(key):
		return cache[key]
	var image = Image.new()
	image.load_svg_from_string(svg(id),float(size)/128.0)
	var tex = ImageTexture.create_from_image(image)
	cache[key] = tex
	return tex
