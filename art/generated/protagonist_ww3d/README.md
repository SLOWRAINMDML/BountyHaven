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


## 얼굴 10회 (face_iter00 → face_iter10)
기준은 표정 시트 NEUTRAL(정면)·PROFILE(측면) 타일과 얼굴 시트 NEUTRAL PORTRAIT(3/4)입니다. 랜드마크는 `measure/face/face_landmarks.json`에, 얼굴 파라미터는 `measure/face/face_spec.json`에 있습니다. 몸 형태는 바꾸지 않았습니다. 다만 피부색 변경은 목·귀·팔뚝에도 같이 적용됩니다.

- 실행: `pipeline/run_face.sh <NN> "note" [--glb ...]` → `iterations/face_iterNN/` (`ww_face.py`: 얼굴 렌더와 3D 랜드마크 투영, `ww_face_score.py`: 채점과 시트)
- 채점: 두 눈(측면은 눈과 턱)으로 렌더를 일러스트에 정렬한 뒤, 나머지 랜드마크 오차(눈 간격 대비 %), 피부 윤곽 IoU, 밝은 피부색 오차를 잽니다. 카메라 각도는 뷰별 허용 범위(정면 ±6°, 3/4 30–66°, 측면 80–100°) 안에서 일러스트 랜드마크에 맞췄습니다.
- 점수: 랜드마크 오차 22.9% → 12.6% (정면 15.1 → 3.0, 3/4 19.4 → 15.9, 측면 34.1 → 18.9), 윤곽 IoU 0.570 → 0.613, 피부색 오차 65 → 4.
- 주요 변경: 측정 비율, 측면 윤곽, Codex 데칼 v2(`concepts/08_ww_face_parts_v2.png`), 일러스트 피부색, 머리 메시에 조각한 코, 매끈한 얼굴 그림자, 칠한 형태 그림자.
- 한계: 일러스트 타일끼리 비율이 다릅니다(코 높이가 눈~턱 대비 0.41/0.64/0.31). 3/4 입 위치, 붓 질감, 머리카락·스카프(범위 밖)는 아직 차이가 납니다.

## VRoid 연구 적용 (vroid_v00 → vroid_v03)
리서치 노트: `docs/vroid_research.md` (VRM 1.0 사양과 VRoid 도움말, 출처 포함). 몸 측정값과 얼굴 랜드마크 맞춤은 유지했습니다.

- 헤어 (`pipeline/ww_hair.py`, `face_spec.hair_mode = "vroid"`): 가이드 그룹(정수리 2층, 앞머리 좌·중·우, 옆, 뒤, 목덜미, 삐침)마다 초승달 단면 다발을 만들고, 끝 가늘어짐·비틀림·끝 말림·랜덤을 줬습니다. 잔머리 그룹과 측정 머리 폭에 맞춘 실루엣 가이드도 넣었습니다. 하이라이트 띠는 없습니다.
- 얼굴 파츠 (`pipeline/ww_face_layers.py`, `ww_face_parts.py`, `eye_mode = "layered"`): 흰자, 홍채(데칼의 보이는 부분에서 복원, `eye.L/R` 본으로 시선), 하이라이트, 눈꺼풀을 얼굴 눈 구멍(알파 컷) 뒤에 두었습니다. 눈선·눈썹·입·입 안은 얼굴 앞의 데칼 메시입니다.
- 표정: VRM 프리셋 이름의 셰이프 키 13개(blink, blinkLeft, blinkRight, aa, ih, ou, ee, oh, happy, angry, sad, relaxed, surprised). `exports/expressions.json`에 정리했고, Godot에서는 `hero_ww.gd`의 `set_expression()`으로 씁니다.
- MToon 1.0: 모든 머티리얼에 shadingShift/Toony, parametric rim, world outline 값을 두고 `exports/palette.json`의 `mtoon`에 기록했습니다. `godot/ww_toon.gdshader`와 `ww_toon_cut.gdshader`가 같은 공식을 씁니다.
- 스프링본: 헤어 그룹 6개와 망토 3줄의 체인, 머리 충돌 구(`exports/springbones.json`). Godot `SpringBoneSimulator3D`에서 Slash 중 뒷머리 끝이 머리 대비 최대 4.8cm 움직이는 것을 측정했습니다.
- 점수(V00 → V03): 몸 실루엣 IoU 0.794 → 0.793, 얼굴 랜드마크 12.6% → 12.6%, 얼굴 윤곽 IoU 0.613 → 0.641, 피부색 오차 3.9 → 3.4.
- 한계: VRM(.vrm) 내보내기는 Blender VRM 애드온이 없어 하지 못했습니다. 일러스트의 가는 곱슬 다발 질감과 볼·입 주변 형태가 바뀌는 표정은 아직 없습니다.
- 실행: `pipeline/run_vroid.sh <NN> "note" [--vfx --final --glb ...]`, 그다음 `pipeline/godot_verify.sh ../iterations/vroid_vNN`.
