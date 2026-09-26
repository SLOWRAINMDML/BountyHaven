# 실제 플레이용 아트 계약

## 기준

가느다란 잉크 선, 옅게 겹치는 안료, 따뜻한 종이, 거대한 건축물과 작은 여행자의 대비. 풍경 안에서 걷고 조사할 수 있어야 하며, 한 장의 정지 삽화나 제목 화면만으로 대체하지 않는다.

항구·선내는 1600×900 기준의 고정 화면 2D 레이어 공간이다. 우주 작전은 절차적 로우폴리 3D 모델과 기울어진 원근 카메라의 쿼터뷰로 렌더링하며, 시뮬레이션 좌표(px)는 `BHVfx3D.to3d`로 20 px = 1 유닛의 비행 평면에 대응한다. 생성형 원화를 사용했다고 표현하지 않는다.

## 레이어

`BHInkArt.texture(port, layer)`는 동일 ID의 텍스처를 캐시한다.

| 레이어 | 책임 | 움직임 |
|---|---|---|
| sky | 하늘, 행성, 먼 도시 | 마우스 시차 약 ±2 px |
| city | 큰 건축물, 상점 입구, 아치, 화분 | 고정 |
| ground | 길, 계단, 부두, 단서 단말 | 고정 |
| water | 수면 폴리곤 | 영역 한정 물결 셰이더 |
| people | 플레이어와 NPC | 분리된 컷아웃 관절, 보행과 대기 |
| furniture | 실제 배치된 생활 소품 | NPC 경로 장애물, 등불의 작은 변화 |
| foreground | 가까운 난간·등불·식물 | 고정 전경 가림 |
| UI | 명료한 한글과 수치 | 종이·번짐 효과를 적용하지 않음 |

캐릭터가 배경 그림에 중복으로 남지 않는다. 유효 보행 폴리곤은 별도로 작성하며 AStarGrid2D가 길을 찾는다. 그림에서 물로 보이는 곳은 이동할 수 없고, 새 가구를 놓으면 길찾기를 갱신한다.

## 최종 아트로 교체할 때

같은 1600×900 원점, 입구/보행 공간, 전경 가림 위치를 유지하는 투명 PNG 레이어로 교체한다. 이동 영역까지 바꾸면 `BHHabitat.walk_polygon`과 hotspots를 함께 수정한다. 배경만 바꾸고 기존 충돌을 그대로 쓰지 않는다.

레이어별 제작 프롬프트의 공통 방향:

> A playable fixed-camera illustrated spaceport, delicate thin ink architectural lines, pale translucent watercolor washes on warm paper, immense orbital architecture contrasted with tiny travelers, quiet weathered harbor, restrained sage and muted terracotta palette. No text, no UI, no baked-in people. Preserve a clear walkable foreground promenade and authored door locations. Separate sky, architecture, ground, water, foreground railings and props.

캐릭터 기준은 같은 머리·외투·스카프·가방 위치를 유지하는 분리 파츠다. 얼굴 반신상과 작은 이동 캐릭터는 이후 별도 원화 제작 대상으로 둔다. 현재 절차적 파츠는 그 구조를 검증하는 임시 자산이다.

## 금지 사항

화면 전체를 왜곡해 석조 선까지 물결치게 만들기, 안개로 상호작용 입구 가리기, UI 본문에 얼룩 적용하기, 가구 수만큼 전투 보너스 무한 중첩하기, 사실과 달리 ‘최종 원화 완성’으로 표기하기.
