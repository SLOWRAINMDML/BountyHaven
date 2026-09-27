# 주인공 3D (잉크·수채화 NPR) — candidate

상태: **candidate + engine_verified(프리뷰 씬)**. 게임 씬에는 아직 통합하지 않았다.

기준: 마스터 01 Rust Harbor, 07(우주·함선), 17(야간) + `assets/protagonist_customization/` 주인공 시트.
생성 도구: 로컬 ima2 2.0.1 (GPT OAuth, gpt-5.5) — 프롬프트와 참조 목록은 `pipeline/jobs.json`, `pipeline/run_paint.py`.

## 구성
| 경로 | 내용 |
|---|---|
| `exports/bountyhaven_hero.glb` | 리그 + 복장 4 + 액세서리 5 + 헤어 6 + 무기 2 + 애니메이션 10, 페인트 텍스처 내장 |
| `exports/textures/head_<표정>.jpg` | 표정 9종 (머리 텍스처 교체 방식) |
| `godot/hero_customizer.gd` | GLB 루트에 붙이는 커스터마이저 (`set_look`, `play`, `expression`, `weapon`, `accessories`) |
| `godot/watercolor_character.gdshader` | 수채 워시 툰 셰이더 (크림 빛 / 슬레이트 그림자 / 안료 가장자리) |
| `godot/hero_preview.tscn` | 프리뷰·검증 씬 |
| `pipeline/` | Blender 5.2 헤드리스 생성·페인트오버 투영 스크립트 |
| `concepts/`, `previews/` | ima2 컨셉 후보, Blender/Godot 검수 시트 |

## 방식
1. `build_character.py` — 절차적 리그·메시·복장·헤어·애니메이션 생성
2. `paint_project.py -- render` — 각 복장/헤어/맨머리의 정면·후면 정사영 렌더
3. `run_paint.py` — ima2가 렌더를 시트 수준의 잉크·수채화로 덧칠, 실루엣에 정합, 표정은 편집으로 파생
4. `paint_project.py -- apply` — 정면/후면 아틀라스 UV로 투영, GLB 출력

## 검증
```
godot --path . res://art/generated/protagonist_3d/godot/hero_preview.tscn -- --capture /tmp/hero_caps
```
Godot 4.7.1 (Compatibility)에서 복장 4종, 표정 9종, 애니메이션 9종 캡처 성공 → `previews/sheet_godot.png`.

## 한계
- 정면/후면 투영이라 측면 경사면은 번짐이 있다. 옆모습 비중이 큰 카메라면 측면 채색 패스 추가 필요.
- 몸 형태는 절차적 로우폴리 베이스. 손가락·옷 두께 등 조형 디테일은 스컬프트 단계 필요.
