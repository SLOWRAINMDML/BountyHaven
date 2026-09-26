class_name BHAppearance
extends RefCounted
## Protagonist customization options. Every option maps to art cut from the supplied
## customization sheets (assets/protagonist_customization/) by tools/art/extract_parts.py.
const HAIR: Array = [
	["base","기본 · 컷아웃 시트"],
	["hair_01_tousled","01 헝클어진 기본"],["hair_02_tidy_crop","02 단정한 크롭"],
	["hair_03_windswept","03 바람머리"],["hair_04_layered_shag","04 레이어드 섀그"],
	["hair_05_side_part","05 옆가르마"],["hair_06_undercut","06 언더컷"],
	["hair_07_tied_low","07 낮게 묶음"],["hair_08_tied_high","08 높게 묶음"],
	["hair_09_travel_braid","09 여행자 땋기"],["hair_10_braided_tail","10 땋은 꽁지"],
	["hair_11_half_up","11 반묶음"],["hair_12_messy_long","12 부스스한 장발"],
	["hair_13_rough_wild","13 거친 머리"],["hair_14_scruffy","14 덥수룩한 길이"],
	["hair_15_rebellious","15 반항적인 머리"],["hair_16_rugged","16 생존자 머리"],
]
## Accent colours from the customization catalog (C1–C12), applied to scarf and cloak.
const CLOTH: Array = [
	["C1 녹빛 빨강","a8483a"],["C2 모래 베이지","cdb893"],["C3 흙갈색","6e5236"],
	["C4 슬레이트 회색","5d6664"],["C5 남색","2f3b58"],["C6 올리브","5e6340"],
	["C7 검정","2e2c2b"],["C8 뼈 흰색","e4dccb"],["C9 머스터드","c99a3a"],
	["C10 청록","2f6d6e"],["C11 버건디","6e2630"],["C12 하늘색","7fa2c4"],
]
const GEAR: Array = [["scarf","스카프"],["cloak","망토"],["goggles","고글"],["cap","모자"],["satchel","가방"],["charm","나침반 참"]]

static func defaults() -> Dictionary:
	return {"hair":"base","cloth":0,"scarf":true,"cloak":true,"goggles":false,"cap":false,"satchel":false,"charm":true}

static func hair_ids() -> Array:
	return HAIR.map(func(entry): return entry[0])

static func valid(look: Variant) -> bool:
	if not look is Dictionary or look.size()!=defaults().size():
		return false
	if not look.get("hair",null) is String or not look.hair in hair_ids():
		return false
	var cloth: Variant = look.get("cloth",null)
	if not (cloth is int or cloth is float) or float(cloth)!=floor(float(cloth)) or int(cloth)<0 or int(cloth)>=CLOTH.size():
		return false
	for entry in GEAR:
		if not look.get(entry[0],null) is bool:
			return false
	return true

static func random(rng: RandomNumberGenerator) -> Dictionary:
	var look: Dictionary = defaults()
	look.hair = HAIR[rng.randi_range(0,HAIR.size()-1)][0]
	look.cloth = rng.randi_range(0,CLOTH.size()-1)
	for entry in GEAR:
		look[entry[0]] = rng.randf()<0.5
	return look
