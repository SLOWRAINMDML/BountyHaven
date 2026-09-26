# BountyHaven 아트 라이브러리

이전 10장과 후속 10장, 총 20장의 생성형 목표 화면을 게임 제작 자료로 정리했습니다.

## 현재 저장소 상태

이 준비 커밋에는 **원본 목록·SHA-256·활용 지침·Godot 참고 뷰어·검증 및 업로드 도구**가 포함됩니다. **PNG/JPEG 바이너리와 전체 매니페스트·브라우저 갤러리는 아직 전송되지 않았습니다.** 목록을 실제 이미지 업로드 완료로 취급하지 마십시오. [전송 상태](art/reference/UPLOAD_STATUS.md)를 확인하십시오.

원본 20장과 초기 엔진 캡처 7개를 모두 포함한 완전한 패키지는 대화에서 전달한 `BountyHaven_ArtLibrary_20_Images.zip`입니다. 원본은 1672×941 PNG이며 손대지 않고 보존했습니다.

## 패키지 실행

압축을 푼 폴더에서 `art/reference/index.html`을 열면 브라우저 갤러리를 볼 수 있습니다. ZIP의 루트 `project.godot`는 독립 아트 뷰어용으로, 기존 게임의 `project.godot`에 덮어쓰면 안 됩니다.

전체 패키지를 기존 게임에 반영한 뒤에는 `tools/art_gallery.tscn`을 열고 F6으로 확인합니다. 이 뷰어는 저장 데이터와 게임 시스템을 수정하지 않습니다.

## 원본까지 GitHub에 게시

Python 3.10 이상, Git, 기존 GitHub 로그인이 준비된 로컬 환경에서 완전한 ZIP을 압축 해제하고 실행하십시오.

```sh
python tools/validate_art_library.py
python tools/publish_art_library.py --push
```

업로드 도구는 `https://github.com/SLOWRAINMDML/BountyHaven.git`의 `main`을 임시 작업 폴더로 clone하고 아트 관련 경로만 복사합니다. 기존 게임 코드·세이브·프로젝트 설정을 변경하거나 강제 push하지 않습니다. 성공한 경우 실제 원격 HEAD를 확인한 `publish_receipt.json`이 남습니다. `--push`를 빼면 변경 미리보기만 합니다.

## 활용

[장면 목록](art/reference/README.md) · [제작·조립 기준](docs/art/ASSET_HANDOFF.md) · [제작용 프롬프트](docs/art/PROMPTS.md) · [원본 체크섬](docs/art/source_inventory.tsv)

20장은 완성 화면 형태의 시안입니다. UI·인물·가구가 그림에 포함되어 있으며, 아직 clean plate·투명 소품·캐릭터 파츠로 분리되지 않았습니다. 시안과 현재 엔진의 실제 화면을 혼동하지 않습니다.
