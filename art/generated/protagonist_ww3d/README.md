# 주인공 3D, 애니메 액션 RPG 툰 스타일 (명조풍 참고, 독자 디자인): candidate

상태: **candidate + engine_verified(프리뷰 씬)**. 게임 씬에는 아직 통합하지 않았습니다. 기존 `art/generated/protagonist_3d/`(수채 투영 방식)와는 별개의 새 파이프라인이며, 기존 폴더는 건드리지 않았습니다.

- 기준: `assets/protagonist_customization/바운티헤이븐_주인공_디자인_시트.png`(비율 측정), 얼굴·의상 시트.
- 이미지 생성: 로컬 ima2 2.0.1 (Codex / GPT OAuth, gpt-5.5). 프롬프트와 참조 목록은 `pipeline/jobs.json`에 있습니다. 명조 캐릭터를 복제하지 않도록 프롬프트에 명시했습니다.
- 모델링·렌더: Blender 5.2 헤드리스, EEVEE. 모든 형상을 스크립트로 처음부터 만들며, 외부 모델이나 샘플 모델은 쓰지 않았습니다.

## 구성
| 경로 | 내용 |
|---|---|
| `measure/landmarks.json` | 디자인 시트 정면·측면 크롭에서 격자로 읽은 랜드마크(머리·눈·턱·어깨·허리·가랑이·무릎·발목 높이, 얼굴·머리·어깨 폭) |
| `concepts/` | ima2 생성물: 01 스타일 턴어라운드, 02 얼굴 시트, 03 눈·눈썹·입 데칼(투명 배경), 04 나침반 문양, 05 스킬 시질, 06 VFX 키아트, 07 천 스와치 |
| `pipeline/ww_build.py` | 측정값 → 로프트 바디, 얼굴(데칼 UV + 타원체 노멀 전사), 헤어 락, 의상, 툰 머티리얼 + 인버티드 헐 외곽선 |
| `pipeline/ww_rig.py` | 측정 관절 기반 16본 리그, 근접 스킨 웨이트, 단검, 망토 바람 셰이프 키, 2본 IK 포즈 |
| `pipeline/ww_render.py` | 비교 뷰(정면·3/4·측면·후면 직교), 얼굴 클로즈업, VFX 샷(슬래시 아크, 시질, 불꽃, 충격파), 뷰티 샷 |
| `pipeline/ww_export.py` | Idle/Slash 애니메이션, `exports/palette.json`, GLB |
| `pipeline/ww_textures.py` | 얼굴 텍스처(측정 위치에 데칼 배치), 망토 색·찢어진 밑단 알파, 천 디테일, 어깨 패치 |
| `pipeline/ww_compare.py` | 일러스트 대비 채점(실루엣 IoU, 랜드마크 높이·폭 오차)과 비교 시트 |
| `pipeline/run_iter.sh`, `godot_verify.sh` | 반복 1회 실행, Godot 임포트·캡처 |
| `exports/bountyhaven_hero_ww.glb` | 리그 + Idle/Slash + 망토 모프 |
| `godot/` | `ww_toon.gdshader`, `ww_outline.gdshader`, `ww_sigil.gdshader`, `ww_slash.gdshader`, `hero_ww.gd`, `hero_ww_preview.tscn` |
| `iterations/iter00..iter10/` | 반복별 비교 시트, VFX 샷, `score.json`, 메모, 스크립트 스냅샷(`src/`) |
| `previews/final_*.jpg` | 최종 시트, VFX 샷 2장, 뷰티 샷, Godot 캡처 |

## 실행
```
cd art/generated/protagonist_ww3d/pipeline
python3 run_ima2.py                      # (선택) ima2 서버 127.0.0.1:3333 필요
./run_iter.sh 10 "note" --vfx --final --glb $PWD/../exports/bountyhaven_hero_ww.glb
./godot_verify.sh ../iterations/iter10   # Godot 4.7.1: GODOT=<바이너리 경로>로 변경 가능
```

## 점수 (iter00 → iter10)
실루엣 IoU 4뷰 평균 0.741 → 0.794 (front 0.787 / 3/4 0.799 / side 0.765 / back 0.827).
랜드마크 높이 오차는 전신 대비 평균 0.56%에서 0.09%로, 폭 오차는 6.8%에서 1.2%로 줄었습니다. 모두 Blender의 평가된 메시에서 측정했습니다.

## 한계
- 헤어가 일러스트보다 덜 부스스합니다. 스카프도 천 주름 없이 튜브처럼 보입니다.
- 리벳, 스티치, 버클 같은 작은 장비 디테일이 부족합니다.
- 표정은 중립 한 종류뿐입니다. 표정 시트 기반 데칼 교체가 다음 단계입니다.
- Godot 쪽은 GLB의 머티리얼 이름으로 툰 셰이더를 다시 거는 방식입니다. 망토 바람 모프는 Godot에서 애니메이션하지 않습니다.
