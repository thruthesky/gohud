# gohud — 라리엔 팀 운영 가이드

영문 사용 설명서는 [README.md](README.md) 다(Asset Store 제출용). 이 문서는 **라리엔 저장소 안에서
gohud 를 함께 개발하고, 별도 저장소·서브모듈·Asset Store 로 내보내는 방법**만 다룬다.

## 지금 상태 (2026-09-12)

- `addons/gohud/` 는 라리엔 공용UX 를 **복사해 독립 애드온으로 다시 짠 것**이다. 원본:
  `scripts/ui/ux/*` · `scripts/dialogs.gd` · `scripts/ui/hud_safe_area.gd` · `scripts/ui/hud_sheet.gd` ·
  `scenes/ui/form_container.gd` · `scripts/ui_scale.gd` · `scripts/ui/hud_potion_slot.gd`.
- 🛑 **라리엔의 기존 코드는 한 줄도 바꾸지 않았고, 라리엔은 아직 gohud 를 쓰지 않는다.** 다른 팀이
  HUD/UI 작업 중이다(작업하는 동안에도 `ui_style.gd` 에 `press()` 가 새로 들어왔다). 라리엔을
  gohud 로 옮기는 것은 그 팀과 합의한 뒤의 일이다.
- 아직 라리엔 저장소 안의 **일반 폴더**이고 커밋하지 않았다. 서브모듈 전환은 아래 절차로 한다
  (원격 저장소 주소가 필요하다).
- 에디터 플러그인은 켜지 않았다.

## 라리엔 공용UX ↔ gohud 대응표

| 라리엔 | gohud | 달라진 점 |
|---|---|---|
| `UiStyle` | `GoStyle` + `GoUi` + `GoTheme` | 테마·아이콘 폰트를 상수 preload → `GoConfig` 로 주입. 토큰 타입 `UX` → `GoHud`. 흐르는 줄·반응형 격자·접이식 섹션·칩·빈 상태 추가 |
| `UiSurface` | `GoSurface` | `/root/UiScale`·`HudSafeArea` 의존 제거. 폭·높이 비율·스크림·포커스 링을 설정으로. `toolbar` 높이를 원하는 높이에 포함 |
| `UiScroll` | `GoScroll` | 4.4+ `LAYOUT_DIRECTION_APPLICATION_LOCALE` |
| `UiCloseButton` | `GoIconButton` | 아이콘을 이름으로, `accessibility_name`, 나란히 놓인 버튼끼리 터치 영역 분배 |
| `UiNotice` | `GoNotice` | 4.5+ `mouse/focus_behavior_recursive` 로 서브트리 입력 차단 |
| `UiPromptCard` | `GoPromptCard` | 아이콘을 글리프 문자열 대신 아이콘 이름으로, 위험 버튼 |
| `UiCoachMark` | `GoCoachMark` | 버튼 문구·카드 폭·가운데 띠 비율을 옵션으로, `reduce_motion` |
| `UiBackPolicy` | `GoBackPolicy` | 같음 |
| `UiFeedback` | `GoFeedback` | `/root/Audio` 대신 `sound_handler` Callable, 음원 이름은 `GoConfig.sound_cues` |
| `HudSafeArea` | `GoSafeArea` | `/root/UiScale` 대신 플랫폼 판정, 키보드 영역 계산 포함 |
| `UiScale`(오토로드) | `GoScale` + `GoRuntime`(선택) | **배율 적용은 기본 꺼짐**. 브레이크포인트·보정값을 설정으로 |
| `FormContainer` | `GoForm` | 오토로드 없이도 브레이크포인트 판정 |
| `HudSheet` | `GoSheet` | `open_key()` 추가 |
| `Dialogs`(오토로드) | `GoDialogs` | 오토로드 강제 없음. 원문·번역 키 두 API |
| `HudPotionSlot` | `GoSlot` | 쿨다운 스스로 세기, 단축키 표시(선택), 수량 없는 슬롯 |
| — | `GoBar` · `GoJoystick` · `GoHudAnchor` | HUD 라이브러리로서 새로 만든 것 |
| `UiLootChip` | **이식하지 않음** | 라리엔 인벤토리 카탈로그에 묶인 게임 전용 위젯 |

## 🛑 라리엔 안에 두는 동안 알아둘 것

| 항목 | 사실 | 할 일 |
|---|---|---|
| 전역 클래스 | `Go` 접두사 클래스 20종이 에디터 노드 목록에 뜬다. 라리엔에 `Go*` 클래스는 없다(2026-09-12 확인) | 없음 |
| 로딩·fps | 라리엔 코드가 gohud 를 참조하지 않으므로 실행 중에 로드되지 않는다 | 없음 |
| 내보내기 크기 | A12·macOS·JaeHo16 프리셋이 `export_filter="all_resources"` 이고 `exclude_filter` 에 `addons/gohud/*` 가 없다 → **빌드에 gohud 파일이 함께 들어간다** | 라리엔이 gohud 를 쓰기 전까지 각 프리셋 `exclude_filter` 에 `addons/gohud/*` 추가를 권한다. `export_presets.cfg` 는 다른 세션이 수정 중이라 이번에 건드리지 않았다 |
| 플러그인 | 켜면 `GoRuntime` 오토로드가 등록된다 — 라리엔 `UiScale` 과 역할이 겹친다 | 라리엔에서는 켜지 않는다. 켜더라도 `scale_enabled` 는 끈 채로 둔다(배율 주인이 둘이면 안 된다, SSOT §9) |
| LFS | gohud 는 SVG·텍스트뿐이고 라리엔 `.gitattributes` 의 LFS 패턴에 걸리는 확장자가 없다 | 없음 |

## 별도 저장소 + 서브모듈로 전환

### 1. 저장소 만들기 (한 번)

저장소 **루트가 곧 애드온 폴더**가 되게 한다. 그래야 소비 프로젝트의 `addons/gohud` 자리에 그대로
붙는다 — 루트 안에 `addons/gohud/` 를 또 두면 `addons/gohud/addons/gohud/` 로 중첩된다.

```bash
mkdir -p ~/work/gohud && cd ~/work/gohud
rsync -a --exclude .dist --exclude 'tests/_*' <라리엔>/addons/gohud/ ./
git init -b main
git add . && git commit -m "gohud 1.0.0"
git remote add origin <gohud 저장소 주소>
git push -u origin main
git tag v1.0.0 && git push origin v1.0.0
```

- 🛑 `.import`·`.uid` 파일도 **함께 올린다.** `.import` 에는 DPITexture 임포트 설정이, `.uid` 에는
  리소스 고유 번호가 있다. 빠지면 아이콘이 흐려지거나 참조가 끊긴다.
- 🛑 저장소 공개 범위(Private/Public)는 사람이 정한다.

### 2. 라리엔에서 일반 폴더를 서브모듈로 바꾸기

```bash
cd <라리엔>
git status --short addons/gohud          # 🛑 먼저 본다 — 아래 rm 은 미커밋 수정까지 지운다
git rm -r --cached addons/gohud 2>/dev/null || true   # 이미 커밋된 적이 있을 때만 효과가 있다
rm -rf addons/gohud
git submodule add <gohud 저장소 주소> addons/gohud
git -C addons/gohud checkout v1.0.0
git add .gitmodules addons/gohud
git commit -m "gohud 서브모듈 v1.0.0"
```

다른 사람·CI 는 `git submodule update --init` 한 줄이면 된다.

### 3. 라리엔을 개발하면서 gohud 도 고치기

```bash
cd <라리엔>/addons/gohud
git switch main                  # 🛑 서브모듈은 기본이 detached HEAD — 브랜치에 올라탄 뒤 고친다
# … 고친다 …
bash tools/run_tests.sh          # 라리엔 안에서 검사
bash tools/new_project_check.sh  # 빈 프로젝트에서도 검사
git commit -am "GoSurface: …" && git push
cd ../..
git add addons/gohud && git commit -m "gohud 포인터 갱신"
```

🛑 **커밋은 두 번이다** — gohud 저장소 안에서 한 번, 라리엔에서 포인터를 한 번. gohud 안에서
push 하지 않고 라리엔 포인터만 커밋하면 다른 사람은 존재하지 않는 커밋을 가리키게 된다.

### 4. 버전 올리기

1. `plugin.cfg` 의 `version` 과 `core/go_ui.gd` 의 `VERSION` 을 같이 올린다
2. `CHANGELOG.md` 에 `## [x.y.z] — 날짜` 항목을 쓴다
3. `bash tools/run_tests.sh && bash tools/new_project_check.sh --export`
4. `bash tools/package.sh` → `.dist/gohud-x.y.z.zip` (버전 불일치·문서 누락·애드온 밖 참조가 있으면 거부)
5. `bash tools/new_project_check.sh --zip .dist/gohud-x.y.z.zip` — **제출할 ZIP 자체**를 검사한다
6. 태그 `vx.y.z` 를 push 한다

## 라리엔을 gohud 로 옮길 때 (나중 — 다른 팀과 합의 후)

라리엔의 모습(SSOT §9)은 **설정 한 장**으로 유지한다. 위젯 코드를 고치지 않는다.

```gdscript
# 부팅 어딘가에서 한 번(위젯을 만들기 전)
var settings := GoConfig.new()
settings.theme = preload("res://assets/ui/laryen_gohud_theme.tres")  # 라리엔 팔레트로 만든 GoHud 토큰 테마
var metrics: Dictionary[StringName, int] = {GoTheme.BUTTON_HEIGHT: 56, GoTheme.PADDING_COMPACT: 8, GoTheme.LIST_GLYPH: 16}
settings.metric_overrides = metrics

# 🛑 Font Awesome Pro 는 재배포 권한이 확인되지 않았다 — 라리엔 프로젝트 안에서만 연결한다.
var fa := GoIconSet.new()
fa.font = preload("res://assets/fonts/fa_light.otf")
fa.codepoints = {GoIconSet.CLOSE: 0xf00d, GoIconSet.SETTINGS: 0xf013}   # 나머지는 HudIcons 상수 값을 옮겨 적는다
fa.fallback = GoUi.DEFAULT_ICONS
settings.icons = fa

# 라리엔 번역 키를 그대로 쓴다 — gohud 기본 번역은 끈다.
settings.text_keys = {&"close": "actionClose", &"back": "npc3dBack", &"confirm": "actionConfirm",
	&"cancel": "actionCancel", &"next": "tour3dNext", &"done": "tour3dDone", &"skip": "tour3dSkip"}
settings.load_builtin_translations = false

# 라리엔 음원 이름(audio_manifest.gd)
settings.sound_cues = {&"opened": "uiOpen", &"closed": "uiClose", &"tapped": "uiClick",
	&"confirmed": "uiConfirm", &"canceled": "uiCancel", &"failed": "uiError", &"fanfare": "uiFanfare"}
settings.scale_enabled = false          # 🛑 배율은 라리엔 UiScale 이 계속 소유한다

GoUi.config = settings
GoFeedback.sound_handler = func(cue: String) -> void: get_node("/root/Audio").play(cue)
```

## Asset Store 제출

절차 정본은 [ux-sharing.md](../../.claude/skills/game/references/ux-sharing.md) 의
"현재 공식 Asset Store 와 제출 절차" 다. gohud 에 맞춘 준비물:

| 준비물 | 어디서 |
|---|---|
| 설치 ZIP | `bash tools/package.sh` |
| 16:9 썸네일·스크린샷 | `tests/gallery_shots.gd` — 폰 세로·가로·데스크톱 × 페이지·투어·시트·확인창·오버레이 |
| 영어 이름·요약·설명 | `README.md` 앞부분 — 이름 `gohud`, 태그 ui · hud · mobile · theme · icons |
| 라이선스 | MIT (`LICENSE`, `THIRD_PARTY_NOTICES.md`) |
| 지원 엔진 | 최소 4.5(사용 API 기준) · **검증은 4.7.2 에서만** |
| AI 사용 공개 | 코드·아이콘·문서 작성에 AI(Claude)를 사용했다고 사실대로 적는다 |

🛑 스토어 계정·게시자 생성과 제출은 사람이 한다.

## 검증 명령

```bash
bash addons/gohud/tools/run_tests.sh                         # 라리엔 안에서
bash addons/gohud/tools/new_project_check.sh --export        # 빈 프로젝트 + Web 내보내기
bash addons/gohud/tools/new_project_check.sh --with-runtime  # GoRuntime 오토로드를 켠 상태로
godot --path <빈 프로젝트> -s res://addons/gohud/tests/gallery_shots.gd -- --out=/tmp/gohud_shots
```
