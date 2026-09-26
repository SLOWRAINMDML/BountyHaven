# BountyHaven — 신규 아트 시작점

**정식 시각 기준은 사용자가 승인한 생성 이미지 20장입니다. 초기 SVG 실행 화면은 최종 그림체가 아닙니다.**

[정식 스타일 가이드](docs/art/CANONICAL_STYLE_GUIDE.md) → [기계가 읽는 기준·장면 조합](art/canonical/style_contract.json) → [신규 생성 프롬프트](docs/art/PROMPTS.md) → [다음 에이전트 작업](docs/art/NEXT_AGENT_HANDOFF.md)

루트 `AGENTS.md`와 `CLAUDE.md`도 같은 기준을 가리킵니다. 과거 README의 '아트 구현' 설명은 현재 프로토타입 기술 설명이며 신규 원화의 목표 품질이나 화풍 기준이 아닙니다.

## 무엇이 기준인가

01 녹슨 항구가 공통 그림체의 최상위 기준입니다. 04 실내, 07 함선/전투, 11 항로실, 17 야간, 18 설원, 20 브랜드 장면은 해당 상황의 1차 보조 기준입니다. 모든 화면을 무작정 합성하지 않습니다. 임시 문구·가격·이름은 공식 설정이 아닙니다.

## 실제 파일 확인

```sh
python tools/art_direction.py --check-config
python tools/art_direction.py --scene harbor
```

첫 명령은 문서·설정 연결만 검사합니다. 두 번째 명령은 생성에 필요한 **실제 PNG의 SHA-256·크기·해상도**를 검사하고, 없으면 종료 코드 2로 중단합니다. 파일명이 적혀 있는 것만으로 이미지를 본 것으로 취급하지 않습니다.

이 변경은 스타일 기준/인수인계/검사 도구를 main에 반영하는 작업입니다. 원본 PNG 20장의 원격 전송, 신규 원화 생성, 게임 화면 교체를 완료했다는 뜻이 아닙니다. 정확한 상태는 [전송 상태](art/reference/UPLOAD_STATUS.md)와 실제 파일 검사로 확인합니다.

## 원본이 다른 작업 환경에 없을 때

대화에 전달된 `BountyHaven_ArtLibrary_MainReset_v1.zip` 또는 `BountyHaven_ArtLibrary_20_Images.zip`을 사용합니다.

```sh
python tools/art_direction.py --archive /path/to/BountyHaven_ArtLibrary_MainReset_v1.zip --scene harbor
```

새 importer는 검증된 원본 PNG 20개만 설치합니다. ZIP의 옛 지침이나 `project.godot`는 복사하지 않으므로 새 main 지침/게임 설정을 덮어쓰지 않습니다. 원본 외 미리보기·옛 갤러리의 전체 설치 상태는 별도입니다. 종전 `publish_art_library.py`나 ZIP 전체 덮어쓰기로 이번 지침을 과거 버전으로 되돌리지 마십시오.
