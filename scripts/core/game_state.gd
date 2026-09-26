extends Node
## Domain layer. UI and simulation call these guarded, synchronous transactions.
const Catalog = preload("res://scripts/core/catalog.gd")
const Spiral = preload("res://third_party/space_station_14/ulam_spiral.gd")
const SCHEMA: int = 1
const GRID_SIZE = Vector2i(18, 5)
const MAX_POWER: int = 12
signal changed
var s: Dictionary = {}
var storage_path: String = "user://bountyhaven_v1.json"
var persistence: bool = true
var last_storage_error: String = ""

func reset(write: bool = true) -> void:
	s = {"schema": SCHEMA, "credits": 1600, "port": "rust", "crew": "", "condition": 74,
		"trust": {"voss": 0, "rio": 0}, "owned": ["boost", "tether", "shield", "emp"],
		"equipped": ["boost", "tether", "shield", "emp"], "layout": [
			{"uid": 1, "id": "bed", "x": 2, "y": 0, "rotated": false},
			{"uid": 2, "id": "lamp", "x": 5, "y": 0, "rotated": false}],
		"next_uid": 3, "sequence": 0, "mission": {}, "phase": "dock", "settled": [],
		"completed": 0, "journal": ["작은 배, 커다란 여행."], "look": BHAppearance.defaults()}
	if write:
		commit()

func result(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message}

func commit() -> void:
	if persistence:
		save_game()
	changed.emit()

func active_hunter() -> String:
	return str(s.mission.get("hunter", s.crew))

func journal(message: String) -> void:
	s.journal.append(message)
	if s.journal.size() > 40:
		s.journal.pop_front()

func hire(id: String) -> Dictionary:
	if s.phase != "dock" or not s.mission.is_empty():
		return result(false, "진행 중인 계약을 마친 뒤 동료를 변경할 수 있습니다.")
	if not Catalog.HUNTERS.has(id):
		return result(false, "알 수 없는 추적자입니다.")
	if s.crew == id:
		return result(false, "이미 함께하는 동료입니다.")
	var fee: int = Catalog.HUNTERS[id].fee
	if int(s.credits) < fee:
		return result(false, "고용비가 부족합니다.")
	s.credits -= fee
	s.crew = id
	journal("%s와 동행 계약을 맺었습니다." % Catalog.HUNTERS[id].name)
	commit()
	return result(true, "동료가 선내에 합류했습니다.")

func available_contracts() -> Array:
	var ids: Array = []
	for id in Catalog.CONTRACTS:
		if Catalog.CONTRACTS[id].port in [s.port, "any"]:
			ids.append(id)
	return ids

func accept(id: String, mode: String) -> Dictionary:
	if s.phase != "dock" or not s.mission.is_empty():
		return result(false, "이미 수락한 계약이 있습니다.")
	if not id in available_contracts() or not mode in ["captain", "pilot"]:
		return result(false, "이 항구에서 받을 수 없는 계약입니다.")
	var hunter: String = str(s.crew)
	if id != "salvage" and mode == "captain" and hunter.is_empty():
		return result(false, "먼저 술집에서 추적자를 고용하십시오.")
	if id != "salvage" and mode == "pilot":
		hunter = "voss" if id == "mechanic" else "rio"
	if id == "salvage":
		hunter = ""
	s.sequence += 1
	s.mission = {"id": id, "mode": mode, "hunter": hunter, "nonce": s.sequence, "paid": false,
		"intel": false, "status": "ready", "share": Catalog.HUNTERS[hunter].share if not hunter.is_empty() else 0.0}
	journal("계약 수락: " + Catalog.CONTRACTS[id].title)
	commit()
	return result(true, "계약을 수락했습니다. 항로 기록을 조사하고 선내에서 출항하십시오.")

func cancel() -> Dictionary:
	if s.phase != "dock" or s.mission.is_empty():
		return result(false, "정박 중인 계약만 취소할 수 있습니다.")
	journal("출항 전 계약을 취소했습니다. 위약금 없음.")
	s.mission = {}
	commit()
	return result(true, "계약을 취소했습니다.")

func investigate() -> Dictionary:
	if s.phase != "dock":
		return result(false, "항로 기록은 정박 중에만 조사할 수 있습니다.")
	if s.mission.is_empty():
		return result(false, "먼저 계약을 수락하면 해당 표적의 기록을 조사할 수 있습니다.")
	if s.mission.intel:
		return result(false, "이미 항로 기록을 확보했습니다.")
	s.mission.intel = true
	journal("항로 기록 확보: 첫 단서 위치와 매복 기회를 얻었습니다.")
	commit()
	return result(true, "항로 기록 확보! 우주에서 첫 신호가 미리 분석됩니다.")

func estimated_reward() -> int:
	if s.mission.is_empty():
		return 0
	var contract: Dictionary = Catalog.CONTRACTS[s.mission.id]
	if s.mission.id == "salvage":
		return int(contract.reward)
	if s.mission.mode == "pilot":
		return 800 + int(contract.danger) * 150
	return int(round(float(contract.reward) * (1.0 - float(s.mission.share))))

func launch() -> Dictionary:
	if s.phase != "dock" or s.mission.is_empty():
		return result(false, "길드에서 계약을 수락하십시오.")
	var fee: int = 0 if s.mission.id == "salvage" else 100
	if not s.mission.paid and int(s.credits) < fee:
		return result(false, "출항료 100이 부족합니다. 무료 출항 회수 계약을 이용하십시오.")
	if not s.mission.paid:
		s.credits -= fee
		s.mission.paid = true
	s.phase = "flight"
	s.mission.status = "active"
	commit()
	return result(true, "출항합니다. 선장, 무사히 돌아오십시오.")

func finish(success: bool, hull: float = 100.0) -> Dictionary:
	if s.phase != "flight" or s.mission.is_empty():
		return result(false, "정산할 작전이 없습니다.")
	var nonce: int = int(s.mission.nonce)
	if nonce in s.settled:
		return result(false, "이미 정산한 계약입니다.")
	var gross: int = estimated_reward() if success else 0
	var repairs: int = int(100.0 - clampf(hull, 0.0, 100.0)) if is_finite(hull) else 100
	var paid_repair: int = mini(int(s.credits) + gross, repairs)
	s.credits = maxi(0, int(s.credits) + gross - paid_repair)
	var hunter: String = active_hunter()
	if success and not hunter.is_empty():
		s.trust[hunter] = int(s.trust[hunter]) + 1
	if success and s.mission.id != "salvage":
		s.completed += 1
	s.condition = maxi(25, int(s.condition) - (18 if success else 25))
	s.settled.append(nonce)
	if s.settled.size() > 50:
		s.settled.pop_front()
	var message: String = ("검거·회수 완료" if success else "긴급 귀환") + " · 보수 %d / 수리비 %d" % [gross, paid_repair]
	journal(message)
	s.phase = "dock"
	s.mission = {}
	commit()
	return {"ok": true, "message": message, "gross": gross, "repairs": paid_repair, "success": success}

func travel(port: String) -> Dictionary:
	if s.phase != "dock" or not s.mission.is_empty():
		return result(false, "계약을 마치거나 취소한 뒤 항구를 이동하십시오.")
	if not Catalog.PORTS.has(port):
		return result(false, "알 수 없는 항구입니다.")
	if port == "glass" and int(s.completed) < 1:
		return result(false, "첫 현상금 계약을 완료하면 유리 궤도 항로가 열립니다.")
	s.port = port
	journal("도착: " + Catalog.PORTS[port].name)
	commit()
	return result(true, "항구에 도착했습니다. 행성 간 이동 비용은 프로토타입에서 무료입니다.")

func power_load(equipment: Array = []) -> int:
	var used: int = 0
	var list: Array = s.equipped if equipment.is_empty() else equipment
	for id in list:
		used += int(Catalog.MODULES[id].power)
	return used

func buy_module(id: String) -> Dictionary:
	if s.phase != "dock" or not Catalog.MODULES.has(id):
		return result(false, "정박 중에만 장비를 구입할 수 있습니다.")
	if id in s.owned:
		return result(false, "이미 보유한 장비입니다.")
	var price: int = int(Catalog.MODULES[id].cost)
	if int(s.credits) < price:
		return result(false, "크레딧이 부족합니다.")
	s.credits -= price
	s.owned.append(id)
	commit()
	return result(true, "장비를 구입했습니다. 슬롯을 선택해 장착하십시오.")

func equip(id: String, slot: int) -> Dictionary:
	if s.phase != "dock" or not id in s.owned or slot < 0 or slot >= 4:
		return result(false, "장착할 수 없습니다.")
	var proposed: Array = s.equipped.duplicate()
	var other: int = proposed.find(id)
	if other >= 0:
		proposed[other] = proposed[slot]
	proposed[slot] = id
	if power_load(proposed) > MAX_POWER:
		return result(false, "원자로 용량 12를 초과합니다. 다른 조합을 선택하십시오.")
	s.equipped = proposed
	commit()
	return result(true, "%d번 슬롯에 %s 장착." % [slot + 1, Catalog.MODULES[id].name])

func can_place(id: String, cell: Vector2i, rotated: bool, ignore_uid: int = -1, layout: Array = []) -> bool:
	if not Catalog.FURNITURE.has(id):
		return false
	var dims: Vector2i = Catalog.furniture_size(id, rotated)
	var rect = Rect2i(cell, dims)
	if cell.x < 0 or cell.y < 0 or cell.x + dims.x > GRID_SIZE.x or cell.y + dims.y > GRID_SIZE.y:
		return false
	# The full central aisle and the two end columns stay clear for all furniture sizes.
	if rect.intersects(Rect2i(0, 2, 18, 1)) or cell.x == 0 or cell.x + dims.x >= 18:
		return false
	var items: Array = s.layout if layout.is_empty() else layout
	for item in items:
		if int(item.uid) == ignore_uid:
			continue
		var other = Rect2i(Vector2i(int(item.x), int(item.y)), Catalog.furniture_size(str(item.id), bool(item.rotated)))
		if rect.intersects(other):
			return false
	return true

func nearest_cell(id: String, desired: Vector2i, rotated: bool) -> Vector2i:
	for n in range(1, Spiral.points_for_max_distance(18) + 1):
		var candidate: Vector2i = desired + Spiral.point(n)
		if can_place(id, candidate, rotated):
			return candidate
	return Vector2i(-1, -1)

func place(id: String, cell: Vector2i, rotated: bool = false, move_uid: int = -1) -> Dictionary:
	if s.phase != "dock" or not can_place(id, cell, rotated, move_uid):
		return result(false, "배치 불가: 통로·다른 가구·선체 바깥은 비워 두십시오.")
	if move_uid >= 0:
		for item in s.layout:
			if int(item.uid) == move_uid and item.id == id:
				item.x = cell.x
				item.y = cell.y
				item.rotated = rotated
				commit()
				return result(true, "가구를 이동했습니다.")
		return result(false, "이동할 가구가 없습니다.")
	var price: int = int(Catalog.FURNITURE[id].cost)
	if int(s.credits) < price:
		return result(false, "크레딧이 부족합니다.")
	s.credits -= price
	s.layout.append({"uid": s.next_uid, "id": id, "x": cell.x, "y": cell.y, "rotated": rotated})
	s.next_uid += 1
	commit()
	return result(true, "가구를 배치하고 저장했습니다.")

func remove_furniture(uid: int) -> Dictionary:
	if s.phase != "dock":
		return result(false, "정박 중에만 가능합니다.")
	for index in range(s.layout.size()):
		if int(s.layout[index].uid) == uid:
			var refund: int = int(Catalog.FURNITURE[s.layout[index].id].cost * 0.75)
			s.layout.remove_at(index)
			s.credits += refund
			commit()
			return result(true, "가구를 판매했습니다. 구매가의 75%%, %d 환급." % refund)
	return result(false, "선택된 가구가 없습니다.")

func comfort() -> int:
	var categories: Dictionary = {}
	for item in s.layout:
		var def: Dictionary = Catalog.FURNITURE[item.id]
		categories[def.category] = maxi(int(categories.get(def.category, 0)), int(def.comfort))
	var total: int = 0
	for value in categories.values():
		total += int(value)
	return mini(40, total)

func rest() -> Dictionary:
	if s.phase != "dock":
		return result(false, "안전하게 정박한 뒤 쉴 수 있습니다.")
	var before: int = int(s.condition)
	s.condition = mini(100, maxi(60, before) + 12 + comfort())
	journal("선내에서 휴식했습니다. 컨디션 %d → %d" % [before, s.condition])
	commit()
	return result(true, "휴식 완료 · 컨디션 %d / 쾌적도 %d" % [s.condition, comfort()])

## Change one appearance option; purely cosmetic, allowed at any time.
func set_look(key: String, value: Variant) -> Dictionary:
	if not s.has("look"):
		s.look = BHAppearance.defaults()
	if not s.look.has(key):
		return result(false, "알 수 없는 외형 항목입니다.")
	var candidate: Dictionary = s.look.duplicate()
	candidate[key] = value
	return replace_look(candidate)

## Replace the whole protagonist look at once (random or reset in the creator).
func replace_look(candidate: Dictionary) -> Dictionary:
	if not BHAppearance.valid(candidate):
		return result(false, "선택할 수 없는 외형입니다.")
	s.look = candidate.duplicate()
	commit()
	return result(true, "외형을 바꿨습니다.")

func save_game() -> bool:
	last_storage_error = ""
	var payload: String = JSON.stringify(s)
	var envelope: String = JSON.stringify({"version": SCHEMA, "payload": payload, "sha256": payload.sha256_text()})
	var file = FileAccess.open(storage_path + ".tmp", FileAccess.WRITE)
	if file == null:
		last_storage_error = "저장 파일을 열 수 없습니다. " + error_string(FileAccess.get_open_error())
		return false
	file.store_string(envelope)
	file.flush()
	file.close()
	var absolute: String = ProjectSettings.globalize_path(storage_path)
	if FileAccess.file_exists(storage_path):
		if FileAccess.file_exists(storage_path + ".bak"):
			DirAccess.remove_absolute(absolute + ".bak")
		if DirAccess.rename_absolute(absolute, absolute + ".bak") != OK:
			last_storage_error = "이전 저장 백업 실패. 기존 파일은 유지됩니다."
			return false
	if DirAccess.rename_absolute(absolute + ".tmp", absolute) != OK:
		DirAccess.rename_absolute(absolute + ".bak", absolute)
		last_storage_error = "저장 교체 실패. 이전 파일을 복구했습니다."
		return false
	return true

func decode_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length()>1000000:
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parser = JSON.new()
	if parser.parse(text)!=OK:
		return {}
	var envelope = parser.data
	if not envelope is Dictionary or not envelope.get("payload",null) is String:
		return {}
	if not whole(envelope.get("version",null),SCHEMA,SCHEMA):
		return {}
	var payload: String = envelope.payload
	if payload.sha256_text()!=str(envelope.get("sha256","")):
		return {}
	if parser.parse(payload)!=OK or not parser.data is Dictionary:
		return {}
	var candidate: Dictionary = parser.data
	return candidate if validate_save(candidate) else {}

func whole(value: Variant, low: int = 0, high: int = 100000000) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(float(value)) and float(value)==floor(float(value)) and float(value)>=low and float(value)<=high

func validate_save(data: Dictionary) -> bool:
	for key in ["schema","credits","port","crew","condition","trust","owned","equipped","layout","next_uid","sequence","mission","phase","settled","completed","journal"]:
		if not data.has(key):
			return false
	if not whole(data.schema,SCHEMA,SCHEMA) or not whole(data.credits) or not whole(data.condition,0,100):
		return false
	# Appearance arrived after the first saves: optional, but must be valid when present.
	if data.has("look") and not BHAppearance.valid(data.look):
		return false
	if not whole(data.next_uid,1) or not whole(data.sequence) or not whole(data.completed):
		return false
	if not data.port is String or not Catalog.PORTS.has(data.port) or not data.crew is String or not data.crew in ["","voss","rio"]:
		return false
	if not data.phase is String or not data.phase in ["dock","flight"]:
		return false
	for key in ["owned","equipped","layout","settled","journal"]:
		if not data[key] is Array:
			return false
	if not data.mission is Dictionary or not data.trust is Dictionary:
		return false
	if data.equipped.size()!=4 or data.owned.size()>Catalog.MODULES.size() or data.layout.size()>90 or data.journal.size()>40 or data.settled.size()>50:
		return false
	if not whole(data.trust.get("voss",null)) or not whole(data.trust.get("rio",null)):
		return false
	for line in data.journal:
		if not line is String or line.length()>1500:
			return false
	var seen: Array = []
	for id in data.owned:
		if not id is String or not Catalog.MODULES.has(id) or id in seen:
			return false
		seen.append(id)
	seen.clear()
	for id in data.equipped:
		if not id is String or not id in data.owned or id in seen:
			return false
		seen.append(id)
	if power_load(data.equipped)>MAX_POWER:
		return false
	seen.clear()
	for nonce in data.settled:
		if not whole(nonce,1,int(data.sequence)) or nonce in seen:
			return false
		seen.append(nonce)
	var uids: Array = []
	# Validate every item before any geometric loop dereferences its neighbors.
	for item in data.layout:
		if not item is Dictionary:
			return false
		for key in ["uid","id","x","y","rotated"]:
			if not item.has(key):
				return false
		if not item.id is String or not Catalog.FURNITURE.has(item.id) or not item.rotated is bool:
			return false
		if not whole(item.uid,1,int(data.next_uid)-1) or int(item.uid) in uids or not whole(item.x,0,17) or not whole(item.y,0,4):
			return false
		uids.append(int(item.uid))
	for item in data.layout:
		if not can_place(item.id,Vector2i(int(item.x),int(item.y)),item.rotated,int(item.uid),data.layout):
			return false
	if data.mission.is_empty():
		return data.phase=="dock"
	var m: Dictionary = data.mission
	for key in ["id","mode","hunter","nonce","paid","intel","status","share"]:
		if not m.has(key):
			return false
	if not m.id is String or not Catalog.CONTRACTS.has(m.id) or not m.mode is String or not m.mode in ["captain","pilot"]:
		return false
	if not m.hunter is String or not m.hunter in ["","voss","rio"] or not m.paid is bool or not m.intel is bool:
		return false
	if not whole(m.nonce,1,int(data.sequence)) or m.nonce in data.settled or not m.status is String:
		return false
	if not Catalog.CONTRACTS[m.id].port in [data.port,"any"]:
		return false
	if m.id!="salvage" and m.hunter=="":
		return false
	if m.id!="salvage" and m.mode=="captain" and m.hunter!=data.crew:
		return false
	if m.id=="salvage" and m.hunter!="":
		return false
	if not (m.share is int or m.share is float):
		return false
	var expected_share: float = 0.0 if m.hunter=="" else float(Catalog.HUNTERS[m.hunter].share)
	if not is_equal_approx(float(m.share),expected_share):
		return false
	if data.phase=="flight":
		return m.status=="active" and m.paid
	return m.status=="ready"

func load_game() -> bool:
	var restored: Dictionary = decode_save(storage_path)
	if restored.is_empty():
		restored = decode_save(storage_path + ".bak")
		if not restored.is_empty():
			last_storage_error = "주 저장 파일이 손상되어 이전 백업을 불러왔습니다."
	if restored.is_empty():
		return false
	s = restored
	if not s.has("look"):
		s.look = BHAppearance.defaults()
	if s.phase == "flight":
		s.phase = "dock"
		s.mission.status = "ready"
		journal("중단된 항해를 재개할 준비가 되었습니다. 추가 출항료 없이 처음부터 재도전합니다.")
	changed.emit()
	return true
