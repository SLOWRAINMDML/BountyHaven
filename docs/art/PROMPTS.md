# 파생 에셋 제작 프롬프트

아래는 다음 제작용 지시문입니다. 원본의 정확한 생성 프롬프트 복원본은 아닙니다. 항상 해당 원본 이미지를 실제 입력으로 제공합니다.

## 공통 스타일

> BountyHaven, illustrated science-fiction frontier adventure. Preserve the supplied reference composition and design identity. Delicate thin ink architecture lines, translucent watercolor washes, muted cream and oxidized rust metal, cool blue atmospheric depth, warm practical lamps, immense structures and small travelers. No interface text, numeric HUD or readable slogans. Keep gameplay silhouettes and walkable paths legible.

## 깨끗한 배경

> Using [REFERENCE_ID], create an environment-only clean plate. Remove all HUD, captions, menus and interaction markers. Remove characters that will be animated and movable furniture. Reconstruct the architecture and floor behind removed objects. Preserve camera perspective and authored entrances. No substitute characters or baked UI. Output a complete clean background, not a collage.

## 분리 소품

> Recreate [OBJECT] from [REFERENCE_ID] as a separate game asset on a genuinely transparent background. Preserve perspective, line weight, materials, scale relationships and light direction. Show the complete object, including areas hidden by people or UI. Leave a clean transparent margin. No labels or checkerboard background.

## 캐릭터

> Create a consistent animation-ready design for the adult pilot in [REFERENCE_ID]. Fix hair, face, cloak length, boots, bag side and equipment handedness. Separate the portrait design from small gameplay sprites. For cutout animation provide overlapping joint artwork for head, torso, arms, hands, legs, boots and cloak. No scenery or UI. Keep all parts complete and consistently scaled.

## 함선과 파츠

> Preserve the cream-and-rust personal starship in [REFERENCE_ID]. Create the base hull without weapon effects or HUD, then separately create [MODULE] in stowed and deployed states from the same camera angle. Keep attachment positions consistent. Exhaust, harpoon cable, shield and impacts must be independent effects. Do not redesign the entire ship or add unintended weapons.

투명 알파·배경 복원·관절 겹침·일관된 원점은 별도 검사해야 합니다. 한 번의 생성으로 모든 레이어와 애니메이션 파츠가 정확히 완성되었다고 가정하지 않습니다. 글자·수치·버튼은 생성 그림에서 분리하여 실제 Godot UI로 구성합니다.
