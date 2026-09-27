# 캐릭터 리그 가이드 (스파인 방식 8방향)

주인공은 한 장짜리 그림이 아니라 뼈대(bone)에 파츠 이미지를 붙여 움직이는 컷아웃 리그입니다. 게임은 이동 방향에 맞춰 8방향 중 하나를 고르고, 그 방향의 파츠와 동작을 재생합니다.

- 리그 파일: `assets/characters/captain/captain.rig.json`
- 파츠 이미지: `assets/generated/protagonist/` 아래 (`part_root`)
- 게임 재생기: `scripts/world/puppet.gd` (BHPuppet)
- 공용 계산: `scripts/rig/rig.gd` (BHRig)
- 에디터: `scripts/rig/rig_editor.gd`, `scenes/rig_editor.tscn`

## 에디터 열기

- Godot 4.7.2에서 프로젝트를 열고 `scenes/rig_editor.tscn`을 연 뒤 F6(현재 씬 실행)
- 또는 명령줄: `godot --path . -- --rig-editor`

저장(Ctrl+S)하면 리그 파일에 바로 쓰이고, 다음 실행부터 게임에 반영됩니다.

## 방향

그리는 방향은 5개이고, 왼쪽을 보는 3방향은 좌우 반전으로 만듭니다.

| 이동 방향 | 쓰는 그림 |
|---|---|
| 아래 | 정면 (front) |
| 오른쪽 아래 / 왼쪽 아래 | 정면 대각 (front34) / 반전 |
| 오른쪽 / 왼쪽 | 옆 (side) / 반전 |
| 오른쪽 위 / 왼쪽 위 | 뒤 대각 (back34) / 반전 |
| 위 | 뒤 (back) |

- 옆과 대각 그림은 모두 **화면 오른쪽을 보는 모습**으로 그립니다.
- 이때 캐릭터의 **왼쪽 팔다리(_l)가 카메라 쪽(앞)**, 오른쪽(_r)이 뒤입니다.
- 아직 그리지 않은 방향은 정면 그림으로 대신 보여 줍니다.

## 에디터 모드

| 모드 | 드래그 | Shift+드래그 (또는 오른쪽 버튼) |
|---|---|---|
| 뼈 셋업 | 관절 위치 옮기기 | 뼈 돌리기 |
| 파츠 셋업 | 파츠를 뼈 위에서 옮기기(피벗) | 파츠 돌리기 |
| 애니메이션 | 뼈 돌리기 (지금 시간에 키 생성) | 뼈 옮기기 (키 생성) |

공통 조작:
- 휠: 확대/축소
- 가운데 버튼 드래그 또는 빈 곳 드래그: 화면 이동
- Space: 재생/정지
- ←/→: 한 프레임씩 이동
- K: 키 설정
- Delete: 키 삭제
- Ctrl+Z / Ctrl+Y: 되돌리기 / 다시 실행

기능:
- **8방향 미리보기:** 지금 동작을 8방향으로 동시에 재생합니다.
- **좌우 반전:** 반전된 방향이 어떻게 보이는지 확인합니다.

## 동작과 트랙

- `idle`, `walk`, `run`은 게임이 쓰는 이름입니다.
  - 가만히 있으면 idle, 걸으면 walk, Shift로 달리면 run을 재생합니다.
- **기준 속도(px/초):** 이 속도로 움직일 때 1배속으로 재생합니다. 걸음이 미끄러져 보이면 이 값을 맞추세요 (walk 160, run 265).
- **공유 트랙:** 모든 방향에 쓰입니다. 첫 방향(정면)은 공유 트랙을 편집합니다.
- **방향 전용 트랙:** 다른 방향에서 "트랙: … 전용"으로 바꾸고 편집하면 그 방향만 다르게 움직입니다. 예를 들어 옆모습 걷기는 다리를 앞뒤로 크게 흔듭니다.
  - 전용 트랙은 공유 트랙을 복사한 상태로 시작합니다.
- **키 곡선:** 부드럽게(기본), 직선, 계단 중에서 고릅니다.

## 새 방향 만들기 순서

1. **그림 받기:** 아래 프롬프트와 `art/generated/protagonist/rig_parts_template.png`(파츠 규격표)로 그 방향의 파츠 그림을 만듭니다.
2. **폴더에 넣기:** 파츠를 파일 이름 규칙대로 `assets/generated/protagonist/views/<방향>/`에 넣습니다.
   - 예: `views/side/thigh_l.png`
   - 투명 배경이 어려우면 단색 종이 배경 시트 그대로 스레드에 보내 주세요. `tools/art/extract_parts.py`로 잘라서 넣어 드립니다.
3. **방향 추가:** 에디터 상단에서 그 방향 버튼(이름 옆 +)을 누르면 정면을 복사해 새 방향이 생깁니다.
4. **이미지 가져오기:** 오른쪽 "폴더에서 가져오기"를 누르면 같은 이름의 PNG가 한 번에 바뀝니다.
5. **뼈 맞추기:** 뼈 셋업 모드에서 관절 위치를 그림에 맞춥니다.
6. **파츠 맞추기:** 파츠 셋업 모드에서 각 파츠를 관절에 맞춥니다.
7. **그리기 순서:** 왼쪽 슬롯 목록의 앞으로/뒤로로 이 방향의 겹침 순서를 조정합니다.
   - 옆모습은 먼 쪽 팔다리(_r)를 몸 뒤로 보냅니다.
   - 뒷모습은 망토를 맨 앞으로 보냅니다.
8. **동작 확인:** 애니메이션 모드에서 전용 트랙을 만들어 걷기와 달리기를 다듬고, 8방향 미리보기로 확인한 뒤 저장합니다.

## 파일 이름 규칙 (파츠 = 슬롯 이름)

| 부위 | 파일 이름 |
|---|---|
| 머리(기본 머리카락 포함) | `head` |
| 목도리 | `scarf` |
| 망토 | `cloak` |
| 상체 | `chest` |
| 골반·벨트 | `hips` |
| 위팔 | `arm_l`, `arm_r` |
| 아래팔+장갑 | `fore_l`, `fore_r` |
| 허벅지 | `thigh_l`, `thigh_r` |
| 정강이 | `shin_l`, `shin_r` |
| 부츠 | `boot_l`, `boot_r` |
| 장비 | `goggles`, `cap`, `satchel`, `charm` |
| 헤어스타일 | `hair_01_tousled` … `hair_16_rugged` (헤어 시트와 같은 이름) |

- 헤어스타일을 그 방향에 아직 그리지 않았으면 그 방향의 기본 머리(`head`)가 대신 나옵니다.
- 어떤 방향에서 안 보여야 하는 파츠(예: 뒷모습의 참)는 파츠 셋업에서 "이 방향에서 숨기기"를 누릅니다.

## 그림 규격

- 컷아웃 부품 시트와 같은 픽셀 크기로 그립니다 (발끝부터 머리끝까지 약 660px).
- 파츠 하나당 PNG 하나, 투명 배경, 가장자리 여백 약 8px로 만듭니다.
- 관절 부위는 둥글게 겹치도록 조금 길게 그립니다 (구부러질 때 틈이 생기지 않게).
- 선 굵기, 채색, 빛 방향(왼쪽 위)은 컷아웃 시트와 같게 맞춥니다.
- 글자, 라벨, 배경, 그림자 바닥은 넣지 않습니다.

## 생성 프롬프트

첨부 이미지:
- `assets/protagonist_customization/바운티헤이븐_주인공_컷아웃_부품_시트.png`
- `assets/protagonist_customization/바운티헤이븐_주인공_디자인_시트.png`
- `art/generated/protagonist/rig_parts_template.png`

공통 문장(모든 방향에 먼저 붙입니다):

> Using the attached BountyHaven protagonist cutout-parts sheet and design sheet as the exact character, costume and rendering master, redraw the same young adult bounty-hunter captain as a cutout animation parts sheet. Match the line weight, painterly coloring, palette, material detail and top-left lighting of the attached sheets; same proportions and the same pixel scale (full body about 660 px from boot sole to hair top). Draw every part as a separate, complete piece spaced apart on a plain flat light background (or transparent): head with its hair, scarf, cloak, chest, hips with belt, upper arm and forearm-with-glove for each arm, thigh, shin and boot for each leg, satchel, compass charm, goggles and cap. Complete the hidden edges of each piece and extend limb ends with rounded overlap at every joint so the pieces can rotate without gaps. Follow the attached parts template for the list and names of pieces. No text, labels, frames, scenery, ground shadow or UI.

방향별 문장:

- **정면 대각 (front34):**
  > Three-quarter FRONT view: the character's body is turned 45 degrees toward screen-right, face and chest mostly visible. The character's left arm and left leg are nearest the camera; the right-side limbs are partly hidden behind the body.
- **옆 (side):**
  > Strict SIDE profile facing screen-right. The character's left arm and left leg are nearest the camera; draw the far right arm and right leg as complete separate pieces too (they will be layered behind the body). Face in profile, cloak hanging behind the back.
- **뒤 대각 (back34):**
  > Three-quarter BACK view: the character faces away from the camera, turned 45 degrees toward screen-right, so we see the back of the head and hair, the back of the cloak and the satchel strap. The left-side limbs are nearest the camera. No face visible except a sliver of cheek and ear.
- **뒤 (back):**
  > Straight BACK view: the character faces directly away from the camera. Back of the head and hair, the full back of the cloak, back of the belt and boots. Left and right limbs mirrored from the front view (character's left limbs on screen-left).
- **헤어스타일 추가 (방향마다):**
  > Draw only the head with hair for each of the sixteen hairstyles on the attached hair customization sheet, in the same view and scale as the head above, each as a separate piece with the neck cut at the same line.

생성 결과는 후보입니다. 알파(투명), 관절 겹침, 크기, 방향 일관성은 에디터에서 조립해 본 뒤 확정합니다.

## 파일 형식 요약

리그 JSON(`format: bountyhaven-rig`, `version: 2`)의 구성입니다.

| 키 | 내용 |
|---|---|
| `views` | 그린 방향 목록 |
| `bones` | 이름, 부모, 방향별 기본 자세 `setup{view: {x, y, rotation, scale_x, scale_y}}` (부모가 먼저 나옴) |
| `slots` | 이름, 뼈, 기본 파츠, 염색 여부, 방향별 그리기 순서 `z{view}` |
| `skins.default[slot][파츠][view]` | `{image, pivot, rotation, scale, region?}` (image는 `part_root` 기준 경로) |
| `animations[이름]` | `{duration, loop, ref_speed, tracks{"*" 또는 view: {뼈: {rotate, translate, scale}}}, slots?}` |
| 키 | `[시간, 값…, 곡선]`, 곡선은 `smooth`, `linear`, `step` |
| `customize` | 헤어 슬롯, 기본 머리, 장비 슬롯, 염색 슬롯 |

- 단위는 리그 픽셀입니다 (원점은 두 발 사이 바닥, y는 아래 방향).
- 각도는 도(degree)입니다.
- 애니메이션 값은 기본 자세에 더해지는 양입니다.

처음 파일은 `tools/art/migrate_rig_v2.py`가 v01 종이인형 리그에서 만들었습니다. 이후에는 에디터가 원본이므로 이 스크립트를 다시 돌리지 마세요(`--force` 없이는 거부합니다).
