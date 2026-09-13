## 🎁 **고르는 단위 한 장.** 테마(색·엔진 컨트롤)와 스킨(코드가 그리는 모양)과 아이콘을 묶는다.
##
## ## 왜 묶는가
## sci-fi 처럼 생김새를 통째로 바꾸려면 셋이 함께 움직여야 한다 — 청록 팔레트만 바꾸고 조이스틱이
## 그대로 둥글면 어정쩡하다. 셋을 따로 꽂게 두면 **한두 개를 빠뜨린 조합**이 반드시 생긴다.
##
## ```gdscript
## GoUi.use_preset(GoThemePresets.SCIFI_DARK)     # 셋이 한꺼번에 바뀐다
## ```
##
## ## 자기 프리셋 만들기
## 1. `themes/presets/` 의 `.tres` 하나를 복제한다.
## 2. `theme` 에 자기 `Theme`, `skin` 에 자기 `GoSkin`(비우면 gohud 기본 모양)을 넣는다.
## 3. `GoThemePresets.register(preload("res://ui/my_preset.tres"))` — 이제 이름으로 고를 수 있다.
##
## 🛑 비워 둔 칸은 **기본값으로 떨어진다** — `skin` 을 비우면 gohud 원래 모양, `icons` 를 비우면
##    기본 아이콘 세트다. 색만 바꾸는 프리셋은 `theme` 한 칸만 채우면 된다.
@tool
class_name GoThemePreset
extends Resource

## 코드에서 고를 때 쓰는 이름(`&"scifi_dark"`). 🛑 비어 있으면 레지스트리가 찾지 못한다.
@export var id: StringName = &""

## 화면에 보여 줄 이름. 비우면 `id` 를 그대로 쓴다.
@export var title := ""

## 어두운 계열인가 — 고르개를 묶어 보여 줄 때 쓴다. 동작에는 영향이 없다.
@export var dark := true

## 색·치수·글자·엔진 컨트롤의 모양. 비우면 gohud 기본(어두운) 테마.
@export var theme: Theme

## 코드가 직접 그리는 자리의 모양. 비우면 gohud 기본 모양.
@export var skin: GoSkin

## 아이콘 세트. 비우면 gohud 기본 세트.
@export var icons: GoIconSet


## 화면에 보여 줄 이름.
func label() -> String:
	return title if not title.is_empty() else String(id)
