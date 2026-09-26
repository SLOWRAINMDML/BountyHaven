# 아트 전달 상태 · main-art-v2

이 커밋이 반영하는 것은 **공식 스타일 가이드, 에이전트 진입점, 장면별 참조 계약, 원본 복구·검사 도구**입니다.

현재 확인한 기존 main에는 원본 PNG 20장과 전체 갤러리 파일이 없습니다. 이번 지침 정리도 그 바이너리를 원격에 올렸다는 주장이 아닙니다. 원본은 사용자에게 전달한 `BountyHaven_ArtLibrary_20_Images.zip` 및 `BountyHaven_ArtLibrary_MainReset_v1.zip`에 들어 있습니다.

새 에이전트는 `python tools/art_direction.py --archive <ZIP> --scene harbor`로 원본만 검증 복구한 뒤 작업합니다. 옛 지침·프로젝트 파일·게시 스크립트를 통째로 덮어쓰지 않습니다. 이 importer는 미리보기/옛 갤러리 전체가 아니라 PNG 원본만 설치합니다.

실제 가용 상태는 `python tools/art_direction.py --check-config` 출력의 `source_files_present`와 `generation_ready`, 그리고 장면별 파일 검사로 확인합니다. 설정 검사의 성공은 원본 전송이나 신규 게임 화면 완성의 증거가 아닙니다.

## 2026-09-26 원본 복구

사용자가 전달한 `BountyHaven_ArtLibrary_MainReset_v1.zip`에서 `tools/art_direction.py --archive`로 원본 PNG 20장만 설치했습니다. 20장 모두 `docs/art/source_inventory.tsv`의 SHA-256·바이트 수와 일치하며(`all_originals_verified: true`), 이 커밋부터 `art/reference/originals/`에 들어 있습니다. 미리보기·갤러리·프로토타입 캡처는 설치하지 않았습니다.

마스터 01: `bh_ref_01_rust_harbor_v01.png` · 1672×941 · sha256 `7248fae088689e53a71d5130c7abfe8da36ee7df0347e5cc58c11078b6870a17`

이 복구는 원본 설치일 뿐이며, 신규 clean plate·분리 레이어·게임 적용은 아직 없습니다.
