# VRoid / VRM 리서치 노트 (protagonist_ww3d 적용용)

조사일 2026-10-02. VRoid Studio(pixiv)는 애니메 캐릭터를 파라미터와 브러시로 만드는 툴이고, 결과물은 VRM(glTF 2.0 확장)으로 나갑니다. 아래는 이 프로젝트에 옮겨 쓸 수 있는 구조만 추렸습니다.

## 1. 모델 구조
- **좌표·단위**: VRM 1.0은 glTF 좌표계(미터, Y up)를 쓰고 모델은 +Z를 바라봅니다. 기준 자세는 T포즈입니다. 팔은 X축과 평행하게 수평, 손바닥은 -Y, 발은 +Z, 발바닥은 Y=0입니다. 모든 노드 스케일은 양수이고 균일해야 합니다. [T-pose]
- **휴머노이드 본**: 필수 본은 hips, spine, head, 양쪽 upperLeg/lowerLeg/foot, upperArm/lowerArm/hand입니다. chest, upperChest, neck, shoulder, eye, jaw, toes, 손가락은 선택입니다. hips가 루트이고, 휴머노이드 본 사이에 다른 노드가 끼어도 됩니다. [humanoid]
- **메시 분리**: VRoid 출력은 몸, 얼굴, 머리카락, 의상이 별도 메시입니다. 얼굴은 다시 피부, 흰자(EyeWhite), 홍채(EyeIris), 하이라이트(EyeHighlight), 눈선·속눈썹(Eyeline, Eyelash), 눈썹(Brow), 입 안(Mouth)이 머티리얼·레이어 단위로 나뉩니다. 홍채와 하이라이트는 얼굴 텍스처 아틀라스의 정해진 칸(1.4.x 기준 오른쪽 아래)에 놓이고, 레이어마다 따로 교체하거나 색 보정(Overlay)할 수 있습니다. [eye-parts]

## 2. 헤어
- **헤어 그룹**: 머리카락은 그룹 단위로 만듭니다. 그룹마다 가이드 곡선이 있고, 파라미터로 다발 수, 길이, 단면(cross-section), 굵기·폭, 끝 가늘어짐, 비틀림, 곱슬, 랜덤을 조절해 다발을 한 번에 생성합니다. 그룹은 복제하거나 브러시 헤어로 바꿀 수 있습니다. [hair-editor]
- **잔머리(stray hair)**: 가이드의 높이·오프셋을 0으로 두고, 곡선·길이·개수를 조절해 바깥으로 튀는 가는 다발을 따로 그룹으로 만듭니다. [stray-hair]
- **흔들림(Hair Bounce)**: 다발 그룹마다 본 체인을 만듭니다. 본 수는 1~16이고, Fixed Point가 첫 본 위치를 정해 값이 클수록 뻣뻣해집니다. [hair-bounce]

## 3. MToon 셰이딩 (VRMC_materials_mtoon 1.0)
- `shading = dot(N, L) + shadingShiftFactor (+ shadingShiftTexture)`
- `shading = linearstep(-1 + shadingToonyFactor, 1 - shadingToonyFactor, shading)`
- `color = lerp(shadeColor, baseColor, shading)`. 기본값은 toony 0.9, shift 0, giEqualization 0.9입니다.
- 림: `parametricRimColor * pow(saturate(1 - dot(N, V) + rimLift), rimFresnelPower)`(power 기본 5)에 matcap을 더하고, rimLightingMix로 조명 영향을 섞습니다.
- 외곽선: outlineWidthMode(none / worldCoordinates[m] / screenCoordinates), outlineWidthFactor, outlineColor, outlineLightingMix. 인버티드 헐 방식입니다.
- UV 스크롤·회전 애니메이션 파라미터가 있습니다. [mtoon]

## 4. 표정 (VRMC_vrm expressions)
- 프리셋은 감정(happy, angry, sad, relaxed, surprised), 립싱크(aa, ih, ou, ee, oh), 눈 깜빡임(blink, blinkLeft, blinkRight), 시선(lookUp/Down/Left/Right), neutral입니다.
- 바인딩은 MorphTargetBind(셰이프 키), MaterialColorBind(색), TextureTransformBind(UV 이동)입니다. 감정 표정은 overrideBlink/overrideMouth/overrideLookAt(none/block/blend)로 깜빡임·립싱크를 막을 수 있습니다. isBinary면 0.5를 기준으로 0 또는 1이 됩니다. [expressions]

## 5. 스프링본 (VRMC_springBone 1.0)
- 조인트 체인마다 stiffness, gravityPower/gravityDir, dragForce(0~1), hitRadius를 둡니다. 충돌체는 sphere/capsule이고 그룹으로 묶습니다.
- 버릿 적분(관성 × (1 - drag) + 강성 복원 + 중력)을 쓰고, 매 스텝 본 길이를 유지하며 충돌체 밖으로 밀어냅니다. [springbone]
- Godot 4.4 이상의 `SpringBoneSimulator3D`가 이 VRM 로직을 이식한 것입니다(체인 = root bone ~ end bone, 조인트별 stiffness/drag/gravity, `SpringBoneCollision3D`). [godot-spring]

## 6. 이 모델에 적용할 것 (우선순위)
1. **헤어**: 가이드 곡선 그룹(앞머리, 옆머리, 정수리, 뒤, 목덜미)마다 다발 N개를 폭 방향으로 분포시킵니다. 단면은 초승달형 리본으로 하고, 끝 가늘어짐·비틀림·곱슬·랜덤을 줍니다. 잔머리 그룹으로 일러스트의 부스스한 실루엣을 만듭니다. 하이라이트 띠는 넣지 않습니다.
2. **눈 레이어**: 흰자, 홍채, 하이라이트, 눈선을 분리합니다. 홍채는 eye 본으로 시선을 따르고, 깜빡임은 눈꺼풀 셰이프 키로 처리합니다.
3. **얼굴 파츠 분리와 표정 셰이프 키**: 눈썹과 입을 분리하고 VRM 프리셋 이름(blink, blinkLeft, blinkRight, aa, ih, ou, ee, oh, happy, angry, sad, relaxed, surprised)으로 셰이프 키를 만듭니다.
4. **MToon 파라미터**: 머티리얼 값을 MToon 이름(shadeColor, shadingShift, shadingToony, rim, outlineWidth[m], outlineColor)으로 정리하고, Godot 셰이더는 위 공식을 그대로 구현합니다.
5. **스프링본**: 머리 다발·망토·스카프 끝에 본 체인을 추가하고, Godot에서 `SpringBoneSimulator3D`로 흔들리게 합니다.
6. **VRM 내보내기**: 이 Mac의 Blender 5.2에는 VRM 애드온이 없습니다(확인함). 본·표정 이름은 VRM 프리셋을 따라 두고, GLB로 내보냅니다.

## 출처
- [mtoon] https://github.com/vrm-c/vrm-specification/blob/master/specification/VRMC_materials_mtoon-1.0/README.md
- [expressions] https://github.com/vrm-c/vrm-specification/blob/master/specification/VRMC_vrm-1.0/expressions.md
- [springbone] https://github.com/vrm-c/vrm-specification/blob/master/specification/VRMC_springBone-1.0/README.md
- [humanoid] https://github.com/vrm-c/vrm-specification/blob/master/specification/VRMC_vrm-1.0/humanoid.md
- [T-pose] https://github.com/vrm-c/vrm-specification/blob/master/specification/VRMC_vrm-1.0/tpose.md
- VRM 1.0 개요: https://github.com/vrm-c/vrm-specification/blob/master/specification/VRMC_vrm-1.0/README.md
- [hair-editor] https://vroid.pixiv.help/hc/en-us/articles/360012339194-Hair-Editor (검색 요약 기준. 직접 열람은 403)
- [stray-hair] https://vroid.pixiv.help/hc/en-us/articles/360013259773-How-to-model-stray-hair-Procedural-Hair-ver
- [hair-bounce] https://vroid.pixiv.help/hc/en-us/articles/900006910023-I-want-to-edit-hair-bounce
- [eye-parts] https://booth.pm/en/items/2513189 , https://www.etsy.com/listing/1195306157 (VRoid 눈 텍스처 레이어 구성: iris, highlight, eyeline, eyelash, sclera)
- [godot-spring] https://docs.godotengine.org/en/stable/classes/class_springbonesimulator3d.html , https://github.com/godotengine/godot/pull/101409
