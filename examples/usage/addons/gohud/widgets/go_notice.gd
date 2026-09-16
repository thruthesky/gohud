## 🍞 **Snackbar / inline notice.** A new message overwrites the previous one, and it disappears on its own.
##
## ## 🛑 It never intercepts input
## A notice is **something you read**, not something you press. It never steals focus, never blocks game input, and
## the buttons underneath still take presses. Need a confirmation? `GoDialogs`. Need a choice? `GoPromptCard`.
##
## ```gdscript
## var notice := GoNotice.new()
## hud.add_child(notice)
## notice.show_text("Saved", GoTheme.SUCCESS)
## ```
##
## Placement — which corner, and how big — is up to the **screen that owns it**; this widget only knows colors, padding and lifetime.
@tool
class_name GoNotice
extends PanelContainer

## The display time ran out.
signal expired

var label: Label
var _remaining := 0.0
var _key := ""
var _arguments := {}
var _content: Control


## 🪟 **Panel background opacity** (0.0~1.0) — for this one panel only. Negative means whatever the theme/config decided.
## 🛑 Only the background thins out — text and icons stay crisp.
## 🔑 A notice sits directly on top of the game screen, so raise the value in a game with busy art —
##    a one-line notice that **is not read might as well not exist.**
var alpha := -1.0:
	set(value):
		alpha = value
		if is_inside_tree(): add_theme_stylebox_override(&"panel", _surface())


func _init() -> void:
	name = "Notice"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 🛑 **Nothing** inside a notice takes input or focus — Godot 4.5+ `*_behavior_recursive` blocks the whole subtree at once,
	#    including content added later (`set_content`). The old approach of setting the filter per node
	#    misses children added after the fact.
	mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label = GoStyle.label("")
	label.name = "Message"
	add_child(label)
	hide()
	set_process(false)


func _ready() -> void:
	theme = GoUi.theme()
	add_theme_stylebox_override(&"panel", _surface())
	set_process(_remaining > 0.0)
	GoUi.watch(_on_ui_changed)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


## 🎨 The whole look changed — `GoUi.use_preset()` and `GoUi.refresh()` call this.
## 🛑 Without it **the widgets already on screen are the only ones left on the old theme** (measured 2026-09-16).
func _on_ui_changed() -> void:
	theme = GoUi.theme()
	# 🔑 The panel of composite content (`set_content`) carries that content's accent color — rebuild it only for text notices.
	if not is_instance_valid(_content): add_theme_stylebox_override(&"panel", _surface())


## Text shown as-is. `tone` is a color token name (`GoTheme.SUCCESS`, …).
func set_message(message: String, tone := GoTheme.TEXT) -> void:
	_drop_content()
	_key = ""
	_arguments.clear()
	label.text = message
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.show()
	GoStyle.typography(label, GoTheme.ROLE_BODY, GoUi.color(tone))
	add_theme_stylebox_override(&"panel", _surface(GoUi.color(tone)))


## Shows text and hides it after `seconds`. Negative means the `notice_duration_ms` token.
func show_text(message: String, tone := GoTheme.TEXT, seconds := -1.0) -> void:
	set_message(message, tone)
	_remaining = float(GoUi.metric(GoTheme.NOTICE_DURATION_MS)) / 1000.0 if seconds < 0.0 else seconds
	show()
	set_process(_remaining > 0.0)


## Shows text by translation key. `arguments` fills placeholders such as `{name}`.
## 🛑 `tr()` alone does not substitute placeholders — the `{name}` in the translated string stays on screen verbatim.
func show_key(key: String, arguments := {}, tone := GoTheme.TEXT, seconds := -1.0) -> void:
	show_text(tr(key).format(arguments), tone, seconds)
	_key = key
	_arguments = arguments.duplicate()


## Holds composite content (an icon plus several rows) instead of text. Its lifetime is managed by the owning screen.
func set_content(content: Control, accent := Color.TRANSPARENT, compact := false) -> void:
	_key = ""
	_arguments.clear()
	_remaining = 0.0
	set_process(false)
	label.hide()
	_drop_content()
	_content = content
	add_child(content)
	# 🛑 Set every `mouse_filter` in the content to IGNORE as well — `mouse_behavior_recursive` blocks the input but leaves the values
	#    alone, which breaks code that checks "nodes inside a notice take no input" by reading those values (host checks, layout logic that reads `mouse_filter`) (2026-09-12, derived game loot-icons).
	_ignore_content_input(content)
	add_theme_stylebox_override(&"panel", GoUi.skin().notice_box(accent, compact, alpha))
	show()


## Changes only the accent color of composite content — no new surface is built (a copy is edited so it does not bleed into other notices).
func set_accent(accent: Color) -> void:
	GoUi.skin().tint_notice(get_theme_stylebox(&"panel"), accent)


## Short text gets its natural width; long text wraps within `limit`.
func preferred_width(limit: float) -> float:
	if is_instance_valid(_content):
		return minf(limit, _content.get_combined_minimum_size().x + get_theme_stylebox(&"panel").get_minimum_size().x)
	var font := label.get_theme_font(&"font")
	if font == null: return limit
	var natural := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		label.get_theme_font_size(&"font_size")).x
	return minf(limit, natural + get_theme_stylebox(&"panel").get_minimum_size().x)


func _surface(accent := Color.TRANSPARENT) -> StyleBox:
	return GoUi.skin().notice_box(accent, true, alpha)


## Keeps the content subtree from eating world input — pressing on the snackbar still reaches the screen underneath.
func _ignore_content_input(node: Node) -> void:
	if node is Control: (node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children(): _ignore_content_input(child)


func _drop_content() -> void:
	if not is_instance_valid(_content): return
	remove_child(_content)
	_content.queue_free()
	_content = null


func _process(delta: float) -> void:
	_remaining -= delta
	if _remaining > 0.0: return
	hide()
	set_process(false)
	expired.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and label != null and not _key.is_empty():
		label.text = tr(_key).format(_arguments)
