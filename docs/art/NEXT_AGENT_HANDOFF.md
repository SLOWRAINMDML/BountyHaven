# 다음 에이전트 작업 지시

## 바로 시작

`AGENTS.md` → `CANONICAL_STYLE_GUIDE.md` → `art/canonical/style_contract.json` → `PROMPTS.md`를 읽습니다.

```sh
python tools/art_direction.py --check-config
python tools/art_direction.py --scene harbor
# 원본이 없고 사용자 전달 ZIP이 있는 경우
python tools/art_direction.py --archive /path/to/BountyHaven_ArtLibrary_MainReset_v1.zip --scene harbor
```

두 번째/세 번째 명령이 성공해야 출력된 실제 이미지를 열어 보고 생성 입력으로 첨부합니다. source ID만 프롬프트에 적는 것은 참조 이미지를 첨부한 것이 아닙니다. 파일이 없으면 현재 대화/프로젝트 첨부 ZIP을 먼저 확인하고, 없을 때만 사용자에게 원본을 요청합니다. 다른 화풍으로 대체 생성하지 않습니다.

## 다음 산출물

01 녹슨 항구의 원본 구도를 기준으로 HUD와 고정 인물을 제거한 clean plate 1장, 이 배경에서 파생된 원경·건축/바닥·전경·물 마스크, 독립 플레이어/NPC를 제작하고 한 장소를 조립합니다. 원본을 그대로 깔고 새 플레이어를 겹치지 않습니다. 별도의 무관한 신규 키아트 10장 생성은 이번 우선순위가 아닙니다.

`art/generated/rust_harbor/v02/`에 후보/작업 기록, 실제 게임 자산은 검토 후 `assets/generated/rust_harbor/v02/`에 둡니다. 레이어 기준 캔버스와 원점, 입구 좌표, 발 위치, 가림, UI 안전 영역을 먼저 정합니다. 기존 1600x900 구현과 다른 구도를 쓰면 보행 폴리곤/핫스폿까지 함께 맞춥니다.

## 보존할 것

다른 에이전트가 추가한 전투·VFX·효과·적·세이브·조작 로직은 아트 복귀를 이유로 삭제하지 않습니다. 기존 SVG는 fallback/prototype으로 남길 수 있지만 최종 화풍의 학습/참조 자료로 사용하지 않습니다. 현재 ID·가격·정원은 실제 데이터가 우선합니다.

## 완료 보고

사용한 원본 파일/해시, 생성 파일, 분리된 레이어, 변경한 Godot 씬/스크립트, 실제 실행 캡처, 이동/가림/상호작용/저장 검사, main 커밋과 원격 확인을 구분해 보고합니다. 아직 만들지 않은 원화·레이어·게임 적용은 완료라고 말하지 않습니다.
