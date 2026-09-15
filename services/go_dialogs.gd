## ❓ **확인·알림 창.** `await` 한 줄로 답을 받는다.
##
## ```gdscript
## var dialogs := GoDialogs.new()
## add_child(dialogs)
##
## if await dialogs.confirm("캐릭터 삭제", "정말 지울까요? 되돌릴 수 없습니다."):
##     delete_character()
##
## await dialogs.alert("오류", "서버에 연결하지 못했습니다.")
## ```
##
## ## 🔑 오토로드로 두면 편하다
## 게임 어디서나 쓰려면 Project Settings > Autoload 에 이 스크립트를 넣는다. 그러면
## `Dialogs.confirm(...)` 처럼 부를 수 있다. 애드온은 **자동으로 등록하지 않는다** —
## 프로젝트의 오토로드 목록은 프로젝트가 정한다.
##
## ## 🔑 버튼 배치 — 세로 · 한 줄 · 자동
## `action_layout` 이 버튼 두 개를 어떻게 놓을지 정한다. 기본 `VERTICAL` 은 긴 번역에도 안전하고,
## `HORIZONTAL` 은 한 줄에 반씩, `AUTO` 는 **두 문구가 반 폭에 한 줄로 들어갈 때만** 한 줄로 두고 아니면 세로로 접는다.
## 버튼이 카드의 절반을 차지하던 짧은 확인창이 한 줄이면 3분의 1 아래로 줄어든다.
## 창 하나만 다르게 하려면 열기 직전에 `set_next_action_layout()` — 그 창이 닫히면 원래 값으로 돌아간다.
##
## ## 🛑 `{name}` 같은 자리는 `args` 로 채운다
## `tr()` 만으로는 치환되지 않는다 — 번역문의 `{name}` 이 화면에 그대로 남는다.
## 되돌릴 수 없는 조작의 확인 문구에서 이 실수는 특히 치명적이다. **제목과 본문을 같은 `args` 로 채운다.**
@tool
class_name GoDialogs
extends Node

## 창이 닫히며 답이 나왔다. 보통은 `await confirm(...)` 을 쓴다.
signal answered(yes: bool)

## 버튼 두 개를 놓는 방식.
enum ActionLayout { VERTICAL, HORIZONTAL, AUTO }

## 이 창이 뜰 층. HUD 보다 위여야 한다.
@export var layer_index := 100

## 카드의 최대 폭(dp).
@export var max_width := 420.0

## 버튼 배치 — `VERTICAL`(기본) · `HORIZONTAL`(한 줄) · `AUTO`(한 줄에 들어갈 때만 한 줄).
@export var action_layout := ActionLayout.VERTICAL

## 버튼 사이 간격(dp). 음수면 `gap_small` 토큰.
## 🛑 컨테이너 기본값에 기대지 않는다 — 테마에 따라 0 이라 두 버튼이 붙는다.
@export var action_gap := -1

## 본문과 버튼 줄 사이 간격(dp). 음수면 표면의 구획 간격 그대로.
## 🔑 버튼끼리보다 넓게 두면 "질문" 과 "고르기" 가 두 덩어리로 읽힌다.
@export var body_gap := -1

var _layer: CanvasLayer
var _surface: GoSurface
var _body: Label
var _ok: Button
var _cancel: Button
## 버튼 줄. 🛑 **처음 열 때** 짓는다(`_ensure_actions`) — 오토로드로 둔 창은 부팅 중 트리에 붙으므로
##    여기서 노드를 더하면 그만큼 입장이 늦어진다.
var _actions: BoxContainer
var _actions_margin: MarginContainer
var _next_layout := -1
var _open := false
var _title_key := ""
var _body_key := ""
var _ok_key := ""
var _cancel_key := ""
var _extra := ""
var _args := {}
var _translate := true


## 🛑 창은 `_init` 에서 만든다 — 트리에 붙기 전에 `confirm()` 을 부를 수 있어야 한다.
func _init() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "DialogLayer"
	_layer.layer = layer_index
	add_child(_layer)

	_surface = _make_surface()
	_surface.visible = false
	_surface.max_width = max_width
	_surface.fit_content = true
	# 닫기(X)는 확인 버튼만 있는 알림에서는 "확인", 취소가 있는 물음에서는 "취소" 로 친다.
	_surface.close_requested.connect(func() -> void: _finish(not _cancel.visible))
	_layer.add_child(_surface)

	_body = GoStyle.label("")
	_body.name = "Body"
	_surface.body.add_child(_body)

	# 버튼 두 개는 우선 `footer` 에 둔다. 배치(세로·한 줄)는 처음 열 때 짓는 버튼 줄이 맡는다.
	_surface.footer.visible = true
	_cancel = GoStyle.button_key(GoUi.text_key(&"cancel"), func() -> void: _finish(false))
	_cancel.name = "Cancel"
	_surface.footer.add_child(_cancel)
	_ok = GoStyle.button_key(GoUi.text_key(&"confirm"), func() -> void: _finish(true), GoStyle.Tone.PRIMARY)
	_ok.name = "Confirm"
	_surface.footer.add_child(_ok)
	_surface.initial_focus = _ok


func _ready() -> void:
	# `new()` 뒤에 바꿨을 수 있는 값을 반영한다.
	_layer.layer = layer_index
	_surface.max_width = max_width
	# 화면을 돌리면 카드 폭이 바뀐다 — 한 줄에 들어가는지 다시 본다.
	if not Engine.is_editor_hint(): get_viewport().size_changed.connect(_on_viewport_resized)


## 예/아니오를 묻는다. `true` 면 사용자가 확인을 눌렀다.
##
## `destructive` 를 켜면 확인 버튼이 **위험색**으로 그려진다. 삭제·탈퇴처럼 되돌릴 수 없는 것에 쓴다.
##
## 🛑 이미 창이 떠 있으면 곧바로 `false` 다 — 확인창 두 개가 겹치지 않게 한다.
func confirm(title: String, body: String, ok_text := "", cancel_text := "", extra := "", args := {},
		destructive := false) -> bool:
	if _open: return false
	_translate = false
	_cancel.visible = true
	_cancel_key = cancel_text if not cancel_text.is_empty() else GoUi.text(&"cancel")
	_tone(destructive)
	_apply(title, body, ok_text if not ok_text.is_empty() else GoUi.text(&"confirm"), extra, args)
	return await answered


## 번역 키로 묻는다. `destructive` 는 `confirm()` 과 같다.
func confirm_key(title_key: String, body_key: String, ok_key := "", cancel_key := "",
		extra := "", args := {}, destructive := false) -> bool:
	if _open: return false
	_translate = true
	_cancel.visible = true
	_cancel_key = cancel_key if not cancel_key.is_empty() else GoUi.text_key(&"cancel")
	_tone(destructive)
	_apply(title_key, body_key, ok_key if not ok_key.is_empty() else GoUi.text_key(&"confirm"), extra, args)
	return await answered


## 알린다(확인 버튼 하나).
func alert(title: String, body: String, ok_text := "", extra := "", args := {}) -> void:
	if _open: return
	_translate = false
	_cancel.visible = false
	_tone(false)
	_apply(title, body, ok_text if not ok_text.is_empty() else GoUi.text(&"confirm"), extra, args)
	await answered


## 번역 키로 알린다.
func alert_key(title_key: String, body_key: String, ok_key := "", extra := "", args := {}) -> void:
	if _open: return
	_translate = true
	_cancel.visible = false
	_tone(false)
	_apply(title_key, body_key, ok_key if not ok_key.is_empty() else GoUi.text_key(&"confirm"), extra, args)
	await answered


func is_open() -> bool:
	return _open


## 다음에 여는 창 **하나만** 버튼 배치를 바꾼다. 그 창이 닫히면 `action_layout` 으로 돌아간다.
## 🔑 되돌릴 수 없는 조작처럼 그 화면에서만 세로로 고정하고 싶을 때 쓴다. 인자를 늘리지 않는 이유 —
##    `confirm()` 을 덮어쓴 자식 클래스가 있으면 인자 개수가 어긋나 컴파일이 깨진다.
func set_next_action_layout(layout: ActionLayout) -> void:
	_next_layout = layout


## 확인 버튼의 색. 🛑 **매번 정한다** — 한 번 위험색으로 칠하면 그 다음 평범한 확인창까지
##    빨갛게 뜬다(창 하나를 돌려 쓰기 때문이다).
func _tone(destructive: bool) -> void:
	GoStyle.style_button(_ok, GoStyle.Tone.DANGER_SOLID if destructive else GoStyle.Tone.PRIMARY)


func _apply(title: String, body: String, ok: String, extra: String, args: Dictionary) -> void:
	_title_key = title
	_body_key = body
	_ok_key = ok
	_extra = extra
	_args = args.duplicate()
	_ensure_actions()
	_retranslate()
	_open = true
	_surface.visible = true
	_surface.relayout()
	_place_actions()
	GoFeedback.opened()


func _retranslate() -> void:
	if _surface == null: return
	# 🛑 **제목도 `args` 로 채운다** — 본문만 채우면 `Drop {item}?` 제목이 글자 그대로 보였다(2026-09-15 확인).
	#    채운 제목은 번역을 마친 글자라 자동 번역을 끈다(`set_title`). 언어가 바뀌면 이 함수가 다시 채운다.
	if _translate:
		if _args.is_empty(): _surface.set_title_key(_title_key)
		else: _surface.set_title(tr(_title_key).format(_args))
		# 🛑 `args` 에 없는 자리는 **번역문에 그대로 남는다**(`{name}` 이 글자로 보인다).
		#    자리표시자를 쓰는 문구는 반드시 그 키를 `args` 로 넘긴다.
		_body.text = tr(_body_key).format(_args)
	else:
		_surface.set_title(_title_key.format(_args) if not _args.is_empty() else _title_key)
		_body.text = _body_key.format(_args) if not _args.is_empty() else _body_key
	if not _extra.is_empty(): _body.text += "\n" + _extra
	_ok.text = _ok_key
	_cancel.text = _cancel_key
	_ok.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS if _translate else Node.AUTO_TRANSLATE_MODE_DISABLED
	_cancel.auto_translate_mode = _ok.auto_translate_mode
	# 🛑 창을 **돌려 쓰므로** 앞 문구가 남긴 최소 폭을 먼저 지운다 — `fit_words` 는 기존 값과 큰 쪽을 취해,
	#    긴 문구 다음의 짧은 한 낱말 문구에서도 버튼이 긴 폭으로 남았다.
	_ok.custom_minimum_size.x = 0.0
	_cancel.custom_minimum_size.x = 0.0
	# 글자·번역 설정을 바꿨으니 낱말 줄바꿈 규칙도 다시 — 안 그러면 `Don`/`e` 로 갈라진다.
	GoStyle.fit_words(_ok)
	GoStyle.fit_words(_cancel)
	# 열린 채 언어가 바뀌면 문구 폭이 달라진다 — 한 줄에 들어가는지 다시 본다.
	if _open: _place_actions.call_deferred()


## 버튼 줄을 처음 열 때 한 번 짓고, 버튼 두 개를 그 안으로 옮긴다.
## 🛑 `footer` 의 타입은 바꾸지 않는다 — 같은 `footer` 에 자기 버튼을 쌓는 화면이 많다.
## 🛑 `MarginContainer` 로 한 번 감싼다 — `footer` 에 자식이 둘이 되면 `footer` 자신의 간격이
##    본문 뒤 간격에 끼어들어 `body_gap` 이 맞지 않는다.
func _ensure_actions() -> void:
	if _actions != null: return
	_actions_margin = MarginContainer.new()
	_actions_margin.name = "ActionsBox"
	_actions_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_surface.footer.add_child(_actions_margin)
	_actions = BoxContainer.new()
	_actions.name = "ActionsRow"
	_actions.vertical = true
	_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_actions_margin.add_child(_actions)
	for button in [_cancel, _ok]:
		(button as Node).reparent(_actions)


## 버튼 줄의 방향·간격과 본문 뒤 간격을 정한다.
## 🛑 **열 때·번역이 바뀔 때·창 크기가 바뀔 때만** 부른다 — 표면은 내용 맞춤이면 매 프레임 `relayout` 하므로
##    거기에 기대면 한 줄 ↔ 세로를 매 프레임 오갈 수 있다.
func _place_actions() -> void:
	if _actions == null or not _open: return
	var layout: int = _next_layout if _next_layout >= 0 else action_layout
	var gap := _action_gap()
	var one_row := false
	# 버튼이 하나(알림)면 한 줄과 세로가 같다 — 폭 전체를 쓴다.
	if _cancel.visible:
		one_row = layout == ActionLayout.HORIZONTAL or (layout == ActionLayout.AUTO and _fits_one_row(gap))
	_actions.vertical = not one_row
	_actions.add_theme_constant_override(&"separation", gap)
	var top := maxi(0, body_gap - _surface.section_gap()) if body_gap >= 0 else 0
	_actions_margin.add_theme_constant_override(&"margin_top", top)
	_surface.relayout()


## 두 문구가 **반 폭에 한 줄로** 들어가는가.
## 🔑 입력은 글자 폭과 카드 안쪽 폭뿐이다 — 지금 어떻게 놓여 있는지에 기대면 판정이 뒤집힌다.
func _fits_one_row(gap: int) -> bool:
	var inner := _surface.card.size.x - float(_surface.content_inset()) * 2.0
	if inner <= 0.0: return false
	var half := (inner - float(gap)) * 0.5
	return _one_line_width(_ok) <= half and _one_line_width(_cancel) <= half


## 버튼 글자를 **한 줄로** 둘 때의 폭 — 글자 폭 + 판 좌우 여백(상태 중 가장 넓은 것).
## 🛑 `get_combined_minimum_size()` 로 재지 않는다 — `fit_words` 가 여러 낱말 버튼의 최소 폭을 가장 긴 낱말로 줄여 둔다.
func _one_line_width(button: Button) -> float:
	var font := button.get_theme_font(&"font")
	if font == null: return INF
	var shown := button.atr(button.text) if button.is_inside_tree() else button.text
	var frame := 0.0
	for state in [&"normal", &"hover", &"pressed", &"hover_pressed"]:
		var face := button.get_theme_stylebox(state)
		if face != null: frame = maxf(frame, face.get_minimum_size().x)
	return font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1.0, button.get_theme_font_size(&"font_size")).x + frame + 2.0


func _action_gap() -> int:
	return action_gap if action_gap >= 0 else GoUi.metric(GoTheme.GAP_SMALL)


func _on_viewport_resized() -> void:
	# 표면이 먼저 새 크기로 카드를 놓은 뒤에 판정한다.
	if _open: _place_actions.call_deferred()


func _finish(yes: bool) -> void:
	if not _open: return
	_open = false
	_next_layout = -1   # 1회용 배치는 이 창으로 끝
	_surface.visible = false
	# 🔔 확인과 취소는 **다른 소리·다른 진동**이다 — 되돌릴 수 없는 조작을 승인했는지 물렀는지를
	#    화면을 안 보고도 알 수 있어야 한다.
	if yes: GoFeedback.confirmed()
	else: GoFeedback.canceled()
	answered.emit(yes)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED: _retranslate()


## 대화상자 표면을 만든다. 🔑 호스트가 `GoSurface` 의 서브클래스를 쓰고 싶으면(옛 타입 힌트 호환 등) 자식에서 덮어쓴다.
func _make_surface() -> GoSurface:
	return GoSurface.new()
