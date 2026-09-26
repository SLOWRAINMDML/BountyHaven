# BountyHaven 신규 아트 프롬프트

공식 기준은 `CANONICAL_STYLE_GUIDE.md`입니다. 아래는 앞으로의 제작용 프롬프트이며 과거 생성 요청의 정확한 복원본이 아닙니다. `python tools/art_direction.py --scene <recipe>`가 성공한 뒤 출력된 실제 PNG를 열고 이미지 입력으로 첨부합니다. 도구/모델 이름은 실제 사용한 것을 기록하며 Google Imagen 사용을 추정해서 표기하지 않습니다.

## 공통 스타일 블록

> Match the attached approved BountyHaven references, with Rust Harbor 01 as the master for visual language. Create richly detailed illustrated industrial science-fiction frontier art. Use fine structural ink drawing, translucent painterly watercolor and pigment washes, weathered cream and rust-orange machinery, worn fabric and practical travel equipment. Preserve readable dark foreground contours, warm amber practical lamps, cool blue atmospheric distance, monumental port structures, and the scale of small adult travelers. Do not reduce this to pale flat SVG geometry or a minimal pastel illustration. Preserve the reference's actual detail density, material separation, contrast and composition. Do not turn it into photorealism, glossy CGI, neon cyberpunk, voxel art or an unrelated anime style. Baked UI, slogans, temporary names and numbers are not visual canon.

## 다음 작업: 녹슨 항구 clean plate

> Using the attached Rust Harbor 01 original as the composition and style master, produce a complete environment-only clean plate for a playable fixed-camera exploration scene. Preserve the harbor's recognizable architecture, dock, workshop/guild/tavern entrances, personal ship identity and walkable promenade. Remove every HUD panel, numeric display, compass, action prompt and readable slogan. Remove the protagonist and all people that will be animated separately; reconstruct the ground and structures behind them with no silhouettes or empty cutout holes. Do not replace them with new baked characters. Keep foreground occluders, water and emissive lights separable for subsequent passes. No frames, labels, interface, collage or exploded diagram. This is a candidate background, not a final assembled game screenshot.

## 선내 생활실 clean plate

> Use master 01 for drawing language and attached Living Deck 04 for this room. Preserve the lived-in industrial starship interior, warm lights, cream/rust surfaces, textiles and personal belongings. Remove UI, all animated people and the furniture designated as movable in the task brief. Reconstruct the floor and wall behind them. Retain doorways and circulation space. The window must show the outside environment or a physically plausible nearby hull section, not another full copy of the player's own ship. Do not invent a new ship interior style. Output the complete clean room, not an image of a decorated UI menu.

## 함선·파츠

> Use master 01 for visual language, attached Pursuit 07 for ship identity and Engineering 06 for mechanical details. Produce the same cream-and-rust personal ship in the explicitly specified gameplay projection, without HUD, typography, thruster exhaust, shield or harpoon cable baked in. Preserve hull silhouette, panel layout and attachment positions. Produce the requested module's stowed/deployed states as separate assets in the identical projection and scale. No new camera system or extra weapons. Effects will be assembled separately by the engine.

## 실제 분리 소품/캐릭터

> Recreate the explicitly requested object or character part from the attached approved design on a genuine transparent background. Preserve perspective, stroke weight, palette, scale and light direction. Include complete hidden edges and the overlap required at joints. No checkerboard painted into the texture, no scenery, text, UI, built-in action effects or labels. Keep all parts aligned to the specified common canvas and pivots.

한 요청에 완성 레이어/애니메이션이 모두 정확하게 생긴다고 가정하지 않습니다. 투명 알파·관절 겹침·원점·방향 일관성·보행 공간을 실제 출력에서 검사합니다. 프롬프트의 'separable'만으로 분리 완료라고 보고하지 않습니다.
