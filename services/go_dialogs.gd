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
## ## 🛑 `{name}` 같은 자리는 `args` 로 채운다
## `tr()` 만으로는 치환되지 않는다 — 번역문의 `{name}` 이 화면에 그대로 남는다.
## 되돌릴 수 없는 조작의 확인 문구에서 이 실수는 특히 치명적이다.
@tool
class_name GoDialogs
extends Node

## 창이 닫히며 답이 나왔다. 보통은 `await confirm(...)` 을 쓴다.
signal answered(yes: bool)

## 이 창이 뜰 층. HUD 보다 위여야 한다.
@export var layer_index := 100

## 카드의 최대 폭(dp).
@export var max_width := 420.0

var _layer: CanvasLayer
var _surface: GoSurface
var _body: Label
var _ok: Button
var _cancel: Button
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

	_surface = GoSurface.new()
	_surface.visible = false
	_surface.max_width = max_width
	_surface.fit_content = true
	# 닫기(X)는 확인 버튼만 있는 알림에서는 "확인", 취소가 있는 물음에서는 "취소" 로 친다.
	_surface.close_requested.connect(func() -> void: _finish(not _cancel.visible))
	_layer.add_child(_surface)

	_body = GoStyle.label("")
	_body.name = "Body"
	_surface.body.add_child(_body)

	# 🛑 동작을 **세로로** 쌓는다 — 긴 번역문이 가로로 들어가면 글자가 잘리거나 닫기가 밀린다.
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


## 예/아니오를 묻는다. `true` 면 사용자가 확인을 눌렀다.
## 🛑 이미 창이 떠 있으면 곧바로 `false` 다 — 확인창 두 개가 겹치지 않게 한다.
func confirm(title: String, body: String, ok_text := "", cancel_text := "", extra := "", args := {}) -> bool:
	if _open: return false
	_translate = false
	_cancel.visible = true
	_cancel_key = cancel_text if not cancel_text.is_empty() else GoUi.text(&"cancel")
	_apply(title, body, ok_text if not ok_text.is_empty() else GoUi.text(&"confirm"), extra, args)
	return await answered


## 번역 키로 묻는다.
func confirm_key(title_key: String, body_key: String, ok_key := "", cancel_key := "",
		extra := "", args := {}) -> bool:
	if _open: return false
	_translate = true
	_cancel.visible = true
	_cancel_key = cancel_key if not cancel_key.is_empty() else GoUi.text_key(&"cancel")
	_apply(title_key, body_key, ok_key if not ok_key.is_empty() else GoUi.text_key(&"confirm"), extra, args)
	return await answered


## 알린다(확인 버튼 하나).
func alert(title: String, body: String, ok_text := "", extra := "", args := {}) -> void:
	if _open: return
	_translate = false
	_cancel.visible = false
	_apply(title, body, ok_text if not ok_text.is_empty() else GoUi.text(&"confirm"), extra, args)
	await answered


## 번역 키로 알린다.
func alert_key(title_key: String, body_key: String, ok_key := "", extra := "", args := {}) -> void:
	if _open: return
	_translate = true
	_cancel.visible = false
	_apply(title_key, body_key, ok_key if not ok_key.is_empty() else GoUi.text_key(&"confirm"), extra, args)
	await answered


func is_open() -> bool:
	return _open


func _apply(title: String, body: String, ok: String, extra: String, args: Dictionary) -> void:
	_title_key = title
	_body_key = body
	_ok_key = ok
	_extra = extra
	_args = args.duplicate()
	_retranslate()
	_open = true
	_surface.visible = true
	_surface.relayout()
	GoFeedback.opened()


func _retranslate() -> void:
	if _surface == null: return
	if _translate:
		_surface.set_title_key(_title_key)
		# 🛑 `args` 에 없는 자리는 **번역문에 그대로 남는다**(`{name}` 이 글자로 보인다).
		#    자리표시자를 쓰는 문구는 반드시 그 키를 `args` 로 넘긴다.
		_body.text = tr(_body_key).format(_args)
	else:
		_surface.set_title(_title_key)
		_body.text = _body_key.format(_args) if not _args.is_empty() else _body_key
	if not _extra.is_empty(): _body.text += "\n" + _extra
	_ok.text = _ok_key
	_cancel.text = _cancel_key
	_ok.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS if _translate else Node.AUTO_TRANSLATE_MODE_DISABLED
	_cancel.auto_translate_mode = _ok.auto_translate_mode


func _finish(yes: bool) -> void:
	if not _open: return
	_open = false
	_surface.visible = false
	# 🔔 확인과 취소는 **다른 소리·다른 진동**이다 — 되돌릴 수 없는 조작을 승인했는지 물렀는지를
	#    화면을 안 보고도 알 수 있어야 한다.
	if yes: GoFeedback.confirmed()
	else: GoFeedback.canceled()
	answered.emit(yes)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED: _retranslate()
