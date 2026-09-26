# 승인된 원본 이미지 보관

원본 20장은 이 대화에서 사용자에게 제시되어 그림체/분위기의 기준이 된 화면 시안입니다. 초기에 작성한 엔진 캡처와는 출처와 역할이 다릅니다.

스타일 기준은 [CANONICAL_STYLE_GUIDE.md](../../docs/art/CANONICAL_STYLE_GUIDE.md), 정확한 파일 목록/해시는 [source_inventory.tsv](../../docs/art/source_inventory.tsv), 장면별 조합은 [style_contract.json](../canonical/style_contract.json)을 봅니다.

공통 master: 01. Primary: 01,04,07,11,17,18,20. Secondary: 02,05,06,09. Support: 03,08,10,12,13,14,15,16,19. Primary 전체를 한번에 섞지 말고 master에 해당 장소의 기준을 더합니다.

원본 경로는 `art/reference/originals/bh_ref_XX_<scene>_v01.png`입니다. 원본은 1672x941 PNG이며 수정하지 않습니다. 모든 파일의 실제 존재와 SHA-256은 `python tools/art_direction.py --scene <recipe>`로 확인합니다. 폴더/목록만 있어서는 준비 완료가 아닙니다.

`prototype_captures/`와 초기 SVG 실행 화면은 구현 비교/회귀검사용입니다. 신규 아트 생성의 스타일 reference로 입력하지 않습니다. `.gdignore`는 참고 원본을 게임 에셋 자동 임포트와 구분하기 위한 것입니다. 제작한 실제 레이어는 별도 런타임 자산 경로에 둡니다.
