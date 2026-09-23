## 🎨 A swappable **icon set**. Every gohud widget calls an icon by *name* alone,
## and this one resource decides what that name gets drawn with.
##
## ## Why a resource
## `preload` an icon into the code and the user has no way to change it. So it is pulled out into **a single
## `.tres`**: a project builds its own set, plugs it into `GoConfig.icons`, and every icon changes without a
## single line of widget code being touched.
##
## ## It takes either approach
## | Approach | Fields to fill | Where it is used |
## |---|---|---|
## | **Textures** (SVG·PNG) | `textures` | gohud's default set. Color goes on through `modulate` |
## | **An icon font** (Font Awesome·Material Symbols and the like) | `font` + `codepoints` | projects already using a font |
##
## Mixing the two is fine — it looks at `textures` first, then `codepoints`, and failing that drops to the
## `fallback` set. That is what makes **partial replacement** possible: keep the default set as the fallback
## and override only the few you want changed.
##
## ## How to use it
## ```gdscript
## # ① One node by name — the same call whether it is a texture or a font.
## var mark := icons.node(GoIconSet.CLOSE, 20, Color.WHITE)
##
## # ② Attaching it to a button (a texture goes to Button.icon, a font to a child Label, on its own)
## GoStyle.apply_icon(button, GoIconSet.SETTINGS)
##
## # ③ Building a partial-replacement set
## var mine := GoIconSet.new()
## mine.fallback = GoUi.icons()            # everything else stays the default set
## mine.textures = {GoIconSet.CLOSE: preload("res://my_close.svg")}
## ```
##
## 🛑 This resource **never references a widget** — `GoStyle`·`GoSurface` reference it, so a reference in the
##    other direction becomes a circular dependency and it collapses as early as `.new()`
##    (close the cycle style → icon → icon button → style and it really does die that way).
@tool
class_name GoIconSet
extends Resource

# ── Semantic name constants ────────────────────────────────────────────
# Widget and game code use nothing but these names. Swap the set and the names stay.
# 🛑 Names not listed here are fine too — put them in `textures`/`codepoints` and they are found all the same.
#    The constants are here to stop typos and get editor completion, not to be an allowlist.

const CLOSE := &"close"
const BACK := &"back"
const FORWARD := &"forward"
const UP := &"up"
const DOWN := &"down"
const CHEVRON_LEFT := &"chevron_left"
const CHEVRON_RIGHT := &"chevron_right"
const CHEVRON_UP := &"chevron_up"
const CHEVRON_DOWN := &"chevron_down"
const MENU := &"menu"
const MORE := &"more"
const EXTERNAL := &"external"
const EXPAND := &"expand"
const COLLAPSE := &"collapse"

const CHECK := &"check"
const INFO := &"info"
const WARNING := &"warning"
const ERROR := &"error"
const SUCCESS := &"success"
const HELP := &"help"
const BELL := &"bell"
const CLOCK := &"clock"
const HOURGLASS := &"hourglass"

const USER := &"user"
const USERS := &"users"
const USER_PLUS := &"user_plus"
const CHAT := &"chat"
const HEART := &"heart"
const STAR := &"star"
const CROWN := &"crown"

const SETTINGS := &"settings"
const SLIDERS := &"sliders"
const DISPLAY := &"display"
const MOBILE := &"mobile"
const VOLUME_HIGH := &"volume_high"
const VOLUME_LOW := &"volume_low"
const VOLUME_OFF := &"volume_off"
const EYE := &"eye"
const EYE_OFF := &"eye_off"
const SUN := &"sun"
const MOON := &"moon"
const GLOBE := &"globe"

const PLUS := &"plus"
const MINUS := &"minus"
const TRASH := &"trash"
const EDIT := &"edit"
const SAVE := &"save"
const REFRESH := &"refresh"
const SEARCH := &"search"
const FILTER := &"filter"
const SORT := &"sort"
const COPY := &"copy"
const DOWNLOAD := &"download"
const UPLOAD := &"upload"
const PLAY := &"play"
const PAUSE := &"pause"
const STOP := &"stop"
const POWER := &"power"
const LOGOUT := &"logout"
const LOGIN := &"login"

const LOCK := &"lock"
const UNLOCK := &"unlock"
const SHIELD := &"shield"
const SHIELD_CHECK := &"shield_check"
const KEY := &"key"

const HOME := &"home"
const MAP := &"map"
const LOCATION := &"location"
const BAG := &"bag"
const BOX := &"box"
const COIN := &"coin"
const GIFT := &"gift"
const BOOK := &"book"

const LIST := &"list"
const GRID := &"grid"
const COLUMNS := &"columns"
const CHART := &"chart"

const SWORD := &"sword"
const BOLT := &"bolt"
const TARGET := &"target"
const FLAG := &"flag"
const POTION := &"potion"
const SKULL := &"skull"
const RUN := &"run"

# ── What the set holds ─────────────────────────────────────────────────

## The human-readable set name — shown by the editor inspector and the gallery example.
@export var set_name := ""

## One line of source·license. 🛑 If you put somebody else's icons in, **write it here without fail** — the
##    release's `THIRD_PARTY_NOTICES.md` is written from this field.
@export_multiline var attribution := ""

## Name → `Texture2D`. The approach gohud's default set uses.
@export var textures: Dictionary[StringName, Texture2D] = {}

## The icon font. It pairs with `codepoints`.
@export var font: Font

## Name → Unicode codepoint (integer). Put a value like Font Awesome's `0xf00d` straight in.
@export var codepoints: Dictionary[StringName, int] = {}

## Glyphs in an icon font are usually drawn smaller than their box — the requested size is multiplied by this
## to match the visible size of a texture icon. 1.0 means no correction.
@export_range(0.5, 2.0, 0.01) var font_size_ratio := 1.0

## The next set to look in for a name this set lacks. Put the default set here and you get **partial replacement**,
## overriding only a few. 🛑 Do not wire it into a cycle (A→B→A) — the `_seen` guard stops it, but it is waste.
@export var fallback: GoIconSet

## The default color multiplied into texture icons. Transparent means the color the caller gave is used as is.
@export var tint := Color.TRANSPARENT


# ── Lookups ────────────────────────────────────────────────────────────

## Can this name be drawn (fallback included).
func has_icon(icon: StringName) -> bool:
	return not _resolve(icon, {}).is_empty()


## The texture icon. `null` for a font-only name — the caller is safer using `node()`.
func texture(icon: StringName) -> Texture2D:
	return _resolve(icon, {}).get("texture")


## A single character of the icon font. An empty string for a texture-only name.
func glyph(icon: StringName) -> String:
	var found := _resolve(icon, {})
	return String.chr(found.codepoint) if found.has("codepoint") else ""


## The font that draws this name (it may be the fallback set's font).
func glyph_font(icon: StringName) -> Font:
	return _resolve(icon, {}).get("font")


## 🎯 **The unified API** — one name gets you a `Control` ready to draw.
## A texture set yields a `TextureRect`, an icon font a `Label`. The caller has no need to tell them apart.
##
## `size` is in dp (= the same coordinate space as the Theme constants), and the node takes exactly that square as
## its minimum size — which keeps the text start position from wobbling line to line as icon widths differ.
func node(icon: StringName, size: int, ink := Color.TRANSPARENT) -> Control:
	var found := _resolve(icon, {})
	var color := ink if ink.a > 0 else (tint if tint.a > 0 else Color.WHITE)
	if found.has("texture"):
		var rect := TextureRect.new()
		rect.name = "Icon"
		rect.texture = found.texture
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.custom_minimum_size = Vector2(size, size)
		rect.modulate = color
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 🛑 An icon must never flip left-right with the language (the close ×, a cog). The only ones that have to
		#    flip direction are `back`/`forward`, and the caller picks those by changing the name.
		rect.layout_direction = Control.LAYOUT_DIRECTION_LTR
		rect.set_meta(&"go_icon", true)
		return rect
	var label := Label.new()
	label.name = "Icon"
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(size, size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.layout_direction = Control.LAYOUT_DIRECTION_LTR
	label.clip_text = false
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	# 🛑 A glyph is a picture, not text — `GoStyle.form()` turns wrapping on for every label under a form unless told not to,
	#    and a wrapping glyph grew from 24 to 51dp tall: the crown made its reward cell a size larger than the others (2026-09-23).
	label.set_meta(&"go_no_wrap", true)
	label.set_meta(&"go_icon", true)
	label.add_theme_color_override(&"font_color", color)
	if found.has("codepoint"):
		label.text = String.chr(found.codepoint)
		if found.has("font"): label.add_theme_font_override(&"font", found.font)
		label.add_theme_font_size_override(&"font_size", maxi(1, roundi(size * float(found.get("ratio", 1.0)))))
	else:
		# 🛑 The name was not found — **hand back an empty box that still takes up the space.** If a whole row shifts
		#    because one icon is missing, the cause is hard to track down. During development the warning below tells you.
		label.text = ""
		if OS.is_debug_build() and not icon.is_empty():
			push_warning("[gohud] icon set has no '%s' (set: %s)" % [icon, set_name if not set_name.is_empty() else resource_path])
	return label


## Every name this set holds (fallback included, sorted). The gallery example and the checks use it.
func icon_names() -> PackedStringArray:
	var names := {}
	_collect(names, {})
	var list := PackedStringArray(names.keys())
	list.sort()
	return list


func _collect(into: Dictionary, seen: Dictionary) -> void:
	if seen.has(get_instance_id()): return
	seen[get_instance_id()] = true
	for key in textures: into[String(key)] = true
	for key in codepoints: into[String(key)] = true
	if fallback != null: fallback._collect(into, seen)


## Decides where and how one name gets drawn. Texture → codepoint → fallback, in that order.
## **An empty Dictionary means "cannot be drawn"** (a `-> Dictionary` cannot hold null).
func _resolve(icon: StringName, seen: Dictionary) -> Dictionary:
	if seen.has(get_instance_id()): return {}   # the sets are wired into a cycle — treat it as missing
	seen[get_instance_id()] = true
	var found: Texture2D = textures.get(icon)
	if found != null: return {"texture": found}
	if codepoints.has(icon):
		var entry := {"codepoint": int(codepoints[icon]), "ratio": font_size_ratio}
		if font != null: entry["font"] = font
		return entry
	if fallback != null: return fallback._resolve(icon, seen)
	return {}
