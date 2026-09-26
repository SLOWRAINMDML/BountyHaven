class_name BHCatalog
extends RefCounted
## Authored game data. IDs, not translated labels, are persisted.

const HUNTERS = {
	"voss": {"name": "바스", "role": "생포 · 돌입 전문가", "fee": 180, "share": 0.25,
		"color": "8d9997", "intro": "범인을 잡는 건 내 일이야. 돌아올 길은 선장에게 맡기지.",
		"perk": "접현 가능 거리 +45 / 회수 준비 시간 -3초", "pref": "plant"},
	"rio": {"name": "리오", "role": "신호 · 전자전 전문가", "fee": 120, "share": 0.20,
		"color": "ad8166", "intro": "신호는 거짓말을 하지 않아. 신호를 보내는 사람은 다르지만.",
		"perk": "단서 스캔 속도 +50% / 표적 점프 제한 시간 +25초", "pref": "desk"}
}
const MODULES = {
	"boost": {"name": "벡터 부스터", "key": "VEC", "cost": 0, "power": 2, "energy": 15.0, "heat": 12.0, "cooldown": 4.5, "text": "이동 방향으로 순간 가속. 측면 추진기가 펼쳐집니다."},
	"tether": {"name": "이온 작살", "key": "ION", "cost": 0, "power": 3, "energy": 22.0, "heat": 10.0, "cooldown": 8.0, "text": "420 이내 표적을 5초간 견인. 거리 520 초과 시 연결 해제."},
	"shield": {"name": "프리즘 실드", "key": "AEG", "cost": 0, "power": 2, "energy": 20.0, "heat": 5.0, "cooldown": 10.0, "text": "4초간 전방 140도 방어막. 마우스로 방어 방향을 조절합니다."},
	"emp": {"name": "전자기 펄스", "key": "EMP", "cost": 0, "power": 3, "energy": 30.0, "heat": 24.0, "cooldown": 9.0, "text": "반경 240의 적을 3초 정지시키고 투사체를 제거합니다."},
	"rail": {"name": "정밀 레일포", "key": "RAIL", "cost": 680, "power": 5, "energy": 32.0, "heat": 32.0, "cooldown": 6.0, "text": "마우스 방향으로 정밀 관통 사격. 엔진 또는 호위함 피해 36."},
	"drone": {"name": "정비 드론", "key": "FIX", "cost": 480, "power": 2, "energy": 20.0, "heat": 4.0, "cooldown": 12.0, "text": "선체 28 회복. 출항당 2회. 격납고에서 드론이 출격합니다."}
}
const FURNITURE = {
	"bed": {"name": "항해자의 침대", "cost": 180, "size": [2, 1], "category": "rest", "comfort": 12, "text": "수면 공간 · 회복 +12"},
	"sofa": {"name": "빛바랜 소파", "cost": 160, "size": [2, 1], "category": "social", "comfort": 9, "text": "함께 쉬는 자리 · 회복 +9"},
	"plant": {"name": "항구의 작은 나무", "cost": 70, "size": [1, 1], "category": "nature", "comfort": 6, "text": "작은 초록 · 회복 +6 / 바스 선호"},
	"desk": {"name": "신호 분석 책상", "cost": 220, "size": [2, 1], "category": "work", "comfort": 7, "text": "개인 작업 공간 · 회복 +7 / 리오 선호"},
	"lamp": {"name": "호박빛 독서등", "cost": 65, "size": [1, 1], "category": "light", "comfort": 5, "text": "따뜻한 조명 · 회복 +5"},
	"table": {"name": "둘을 위한 식탁", "cost": 130, "size": [2, 1], "category": "social", "comfort": 8, "text": "함께하는 식사 · 같은 종류 효과는 중복되지 않음"}
}
const CONTRACTS = {
	"mechanic": {"title": "도망치는 정비공", "target": "케일 / 정비선 MAGPIE", "port": "rust", "reward": 1450, "danger": 1, "brief": "폐함선 지대에 숨은 정비공을 생포하십시오. 훔친 항로 기록도 회수해야 합니다.", "hint": "두 개의 연료 신호를 분석하면 진짜 항로가 드러납니다."},
	"courier": {"title": "유리 도시의 유령", "target": "이리스 / 위장선 MOTH", "port": "glass", "reward": 1900, "danger": 2, "brief": "가짜 신분 신호를 뿌리는 밀수 운반책. 생포와 데이터 회수가 필요합니다.", "hint": "리오와 함께하면 가짜 신호를 더 빠르게 분리할 수 있습니다."},
	"salvage": {"title": "잃어버린 구호 물자", "target": "표류 화물 3개", "port": "any", "reward": 420, "danger": 0, "brief": "전투가 없는 회수 계약입니다. 동료 없이도 지원할 수 있으며 출항료가 없습니다.", "hint": "표시된 화물에 접근하여 E를 누르십시오."}
}
const PORTS = {
	"rust": {"name": "녹슨 항구", "subtitle": "RUST HARBOR / OUTER REACH", "text": "고철과 안개 사이, 떠나는 이들의 도시"},
	"glass": {"name": "유리 궤도", "subtitle": "GLASS ORBIT / CORPORATE RING", "text": "빛나는 수로 아래, 지워진 신호들의 도시"}
}

static func furniture_size(id: String, rotated: bool) -> Vector2i:
	var dims: Array = FURNITURE[id].size
	return Vector2i(int(dims[1]), int(dims[0])) if rotated else Vector2i(int(dims[0]), int(dims[1]))
