## 🚪 gohud's **single gateway**. Settings, theme, icons and strings all come out of here.
##
## ## No autoload needed
## Everything is `static`. Without enabling the plugin and without registering an autoload,
## `GoUi.color(GoTheme.ACCENT)` works right away — the most important property when this ships as an asset.
##
## Enable the plugin and the `GoRuntime` autoload joins in, adding **window size tracking, the dp scale and
## the virtual keyboard height**. Without it every widget still works; only those features are missing.
##
## ## Putting the config in
## ```gdscript
## GoUi.config = preload("res://ui/my_gohud.tres")   # from code
## # or put the path in Project Settings > Gohud > Config (the plugin creates that field).
## ```
##
## ## 🛑 This file never references a widget
## Every widget — `GoStyle`·`GoSurface` and the rest — references this. Make even one reference in the
## other direction and it becomes a circular dependency, and `.new()` fails outright.
@tool
class_name GoUi
extends RefCounted

## The version of this addon. It moves together with `CHANGELOG.md`.
const VERSION := "1.2.0"

## The **lowest engine version** this addon requires. `[major, minor]`.
##
## 🛑 On an engine below this it does not turn on — and not merely "does not turn on": it **dies at the parsing stage**,
##    because it uses names that version does not have, such as `FoldableContainer`·`DPITexture`·`mouse_behavior_recursive`.
##    So checking at runtime is pointless; this constant is here to **give the checks and the docs one place to look**.
const MIN_ENGINE := [4, 6]


## Can the engine we are on run this addon.
static func engine_supported() -> bool:
	var info := Engine.get_version_info()
	if int(info.major) != int(MIN_ENGINE[0]): return int(info.major) > int(MIN_ENGINE[0])
	return int(info.minor) >= int(MIN_ENGINE[1])


## The minimum version as readable text, like `"4.6"`.
static func min_engine_string() -> String:
	return "%d.%d" % [MIN_ENGINE[0], MIN_ENGINE[1]]

## Project setting key holding the path to the config resource. The plugin creates that field.
const CONFIG_SETTING := "gohud/config/resource"

## Project setting key holding the look bundle name. The plugin creates that field.
const PRESET_SETTING := "gohud/theme/preset"

const DEFAULT_THEME: Theme = preload("res://addons/gohud/themes/gohud_dark.tres")
const LIGHT_THEME: Theme = preload("res://addons/gohud/themes/gohud_light.tres")
const DEFAULT_ICONS: GoIconSet = preload("res://addons/gohud/icons/gohud_icons.tres")
const BUILTIN_TRANSLATIONS := "res://addons/gohud/i18n/gohud.csv"

## The languages the built-in translations carry. 🛑 If you added a column to the CSV, **add it here too** —
##    a language that is missing never gets registered even once its piece file is built, and it quietly comes out in English.
const LOCALES := [
	"en", "ko", "ja", "zh", "es", "pt", "de", "fr", "ru", "hi", "ar",
	"tr", "vi", "id", "th", "it", "pl", "uk", "nl", "zh_TW", "he",
]

## The settings changed — widgets already on screen have to redraw.
## 🛑 There is no `static signal` in Godot 4.x. So it holds the callback list itself.
static var _watchers: Array[Callable] = []
static var _config: GoConfig
static var _resolved := false
static var _translations_loaded := false
static var _mobile_type := false
static var _base_font_sizes := {}
static var _default_skin: GoSkin
# The set `icons()` builds when `GoConfig.extra_icons` is filled, and what it was built from.
static var _stacked: GoIconSet
static var _stacked_main: GoIconSet
static var _stacked_extra: Array[GoIconSet] = []


## The config in use. On the first read it automatically loads the path written in the project settings.
static var config: GoConfig:
	get:
		if not _resolved:
			_resolved = true
			if _config == null: _config = _load_project_config()
			if _config == null: _config = GoConfig.new()
			_apply_config(_config)
		return _config
	set(value):
		if _config == value: return
		if _config != null and _config.changed_settings.is_connected(_notify):
			_config.changed_settings.disconnect(_notify)
		_config = value
		_resolved = true
		if _config == null: _config = GoConfig.new()
		_apply_config(_config)
		_notify()


static func _apply_config(value: GoConfig) -> void:
	if not value.changed_settings.is_connected(_notify):
		value.changed_settings.connect(_notify)
	if value.load_builtin_translations: _load_translations()


static func _load_project_config() -> GoConfig:
	if not ProjectSettings.has_setting(CONFIG_SETTING): return null
	var path := str(ProjectSettings.get_setting(CONFIG_SETTING, ""))
	if path.is_empty() or not ResourceLoader.exists(path): return null
	return ResourceLoader.load(path) as GoConfig


## Register a callback to be called when the settings change. A node `unwatch`es in `_exit_tree`.
static func watch(callback: Callable) -> void:
	if not _watchers.has(callback): _watchers.append(callback)


static func unwatch(callback: Callable) -> void:
	_watchers.erase(callback)


## Call this after changing a plain field of the config from code — the widgets on screen lay out again.
## (Changing `theme`·`icons` calls it automatically.)
static func refresh() -> void:
	_notify()


static func _notify() -> void:
	var alive: Array[Callable] = []
	for callback in _watchers:
		if callback.is_valid():
			alive.append(callback)
			callback.call()
	_watchers = alive


# ── Theme·icons ────────────────────────────────────────────────────────

## The look bundle currently picked. `null` if the name is empty or it has not been imported yet.
## When the config resource is empty it looks at the **project settings** (`gohud/theme/preset`) — pickable from the editor without code.
static func preset() -> GoThemePreset:
	var id := config.preset
	if id.is_empty() and ProjectSettings.has_setting(PRESET_SETTING):
		id = StringName(str(ProjectSettings.get_setting(PRESET_SETTING, "")))
	return GoThemePresets.find(id)


## 🎁 Change the look **wholesale** — theme, skin and icons move together.
##
## ```gdscript
## GoUi.use_preset(GoThemePresets.SCIFI_DARK)
## GoUi.use_preset(my_preset)                    # handing over a GoThemePreset works too
## ```
##
## 🛑 It **clears** any `config.theme`·`skin`·`icons` you plugged in by hand — that is what lets the chosen bundle show as it is.
##    To keep one of those fields as your own, fill that field back in after this call.
##    `config.extra_icons` is **kept** — extra icon sets sit under whichever preset comes next.
static func use_preset(value: Variant) -> void:
	var chosen: GoThemePreset = null
	var id: StringName = &""
	if value is GoThemePreset:
		chosen = value
		id = chosen.id
		GoThemePresets.register(chosen)
	elif value is StringName or value is String:
		id = StringName(value)
	var settings := config
	settings.theme = null
	settings.skin = null
	settings.icons = null
	settings.preset = id
	# 🛑 Throw the font size baseline away — once the theme changes there is no putting the old theme's sizes back.
	_base_font_sizes.clear()
	_mobile_type = false
	_notify()


## The Theme in use. If the config is empty, the chosen bundle's theme; failing that, gohud's default (dark) theme.
static func theme() -> Theme:
	var value := config.theme
	if value != null: return value
	var chosen := preset()
	if chosen != null and chosen.theme != null: return chosen.theme
	return DEFAULT_THEME


## The backup theme that fills tokens in. `null` when `token_fallback` is off.
static func _fallback_theme() -> Theme:
	return DEFAULT_THEME if config.token_fallback else null


## The **skin** in use — the look of the spots the code draws itself (joystick·quick slot·coach mark·chip).
## If the config is empty, the chosen bundle's skin; failing that, gohud's default look.
static func skin() -> GoSkin:
	var value := config.skin
	if value != null: return value
	var chosen := preset()
	if chosen != null and chosen.skin != null: return chosen.skin
	# 🛑 Not kept as a constant — `GoSkin` calls `GoUi` and `GoConfig` holds a `GoSkin`.
	#    Built at constant-initialization time, that cycle drags the load order down with it. It is built on first use.
	if _default_skin == null: _default_skin = GoSkin.new()
	return _default_skin


## The icon set in use. If the config is empty, the chosen bundle's set; failing that, gohud's default set.
## With `GoConfig.extra_icons` filled, a set that looks in that one first and then in the extra sets — built once and
## kept, so two calls hand back the same object (and with no extra sets, exactly the set above).
static func icons() -> GoIconSet:
	var main := _main_icons()
	var extra := config.extra_icons
	if extra.is_empty(): return main
	if _stacked == null or _stacked_main != main or _stacked_extra != extra:
		_stacked = GoIconSet.new()
		_stacked.set_name = "%s + %d more" % [main.set_name, extra.size()]
		var layers: Array[GoIconSet] = [main]
		layers.append_array(extra)
		_stacked.layers = layers
		_stacked_main = main
		_stacked_extra = extra.duplicate()
	return _stacked


static func _main_icons() -> GoIconSet:
	var value := config.icons
	if value != null: return value
	var chosen := preset()
	if chosen != null and chosen.icons != null: return chosen.icons
	return DEFAULT_ICONS


## 🧩 Adds an icon set to `GoConfig.extra_icons` (once — adding it again does nothing) and redraws what is open.
## Its names become drawable by every widget, under whatever preset is in use — the preset's drawings still win.
##
## ```gdscript
## GoUi.use_preset(GoThemePresets.MEDIEVAL_DARK)
## GoUi.add_icons(GoIconLibrary.icon_set())   # engraved sword, and 1,187 names the medieval set does not draw
## ```
static func add_icons(extra: GoIconSet) -> void:
	if extra == null or config.extra_icons.has(extra): return
	var list := config.extra_icons.duplicate()
	list.append(extra)
	config.extra_icons = list


## A single color. `GoConfig.color_overrides` takes precedence over the theme.
##
## 🔑 `*_fill` (a color used over a **wide area**, such as a bar fill) is an **optional token** — when the theme
##    lacks it, it falls back to the same name with `_fill` stripped. That is why plugging in a theme that never heard of this token does not raise magenta.
static func color(key: StringName) -> Color:
	var overrides := config.color_overrides
	if overrides.has(key): return overrides[key]
	var name := String(key)
	if name.ends_with("_fill") and not _has_color(key):
		return color(StringName(name.trim_suffix("_fill")))
	return GoTheme.color_of(theme(), key, _fallback_theme())


## 🔑 **A control color from the theme, safe before the node is in the tree** — `name` on a theme type
## (`&"font_color"` on `GoTheme.VAR_COMPACT_BUTTON`), climbing the variation's base chain.
##
## ```gdscript
## var ink := GoUi.theme_color(&"font_color", GoTheme.VAR_LIST_BUTTON)
## ```
##
## Looks in the current theme, then the backup theme. When neither defines it: `missing` if one was passed, otherwise
## the engine's default theme (what a control in the tree would get).
## 🛑 `node.get_theme_color()` on a node not added yet returns the engine default instead of gohud's color — see
##    `GoTheme.color_in_chain`. For a node you already hold, `theme_color_of(node, name)` picks the right road.
static func theme_color(name: StringName, type: StringName, missing := Color.TRANSPARENT) -> Color:
	for look: Theme in [theme(), _fallback_theme()]:
		if GoTheme.has_color_in_chain(look, name, type): return GoTheme.color_in_chain(look, name, type)
	if missing.a > 0: return missing
	return GoTheme.color_in_chain(ThemeDB.get_default_theme(), name, type, Color.WHITE)


## `theme_color` for a control you hold — its own override first, then the engine lookup once it is in the tree,
## and before that the theme resource (the node's own `theme` if set, else gohud's) along its variation or class.
static func theme_color_of(node: Control, name: StringName, missing := Color.TRANSPARENT) -> Color:
	if node.has_theme_color_override(name): return node.get_theme_color(name)
	if node.is_inside_tree(): return node.get_theme_color(name)
	var type := node.theme_type_variation if not node.theme_type_variation.is_empty() else StringName(node.get_class())
	if node.theme != null and node.theme != theme() and GoTheme.has_color_in_chain(node.theme, name, type):
		return GoTheme.color_in_chain(node.theme, name, type)
	return theme_color(name, type, missing)


## Is this color token **actually defined** in the current theme (or the backup theme).
static func _has_color(key: StringName) -> bool:
	var current := theme()
	if current != null and current.has_color(key, GoTheme.TYPE): return true
	var backup := _fallback_theme()
	return backup != null and backup.has_color(key, GoTheme.TYPE)


## A single metric (dp). `GoConfig.metric_overrides` takes precedence over the theme.
static func metric(key: StringName) -> int:
	var overrides := config.metric_overrides
	if overrides.has(key): return overrides[key]
	if key == GoTheme.TOUCH: return config.min_touch_size
	return GoTheme.metric_of(theme(), key, _fallback_theme())


## A **copy** of one surface StyleBox. 🛑 Without the copy, a color change on one card bleeds into every card.
static func box(key: StringName) -> StyleBox:
	return GoTheme.box_of(theme(), key, _fallback_theme()).duplicate()


## 🪟 The **opacity (0.0~1.0)** of one panel variant. 1.0 is a solid color; at 0.8, 20% of what is behind bleeds through.
##
## ## The more specific wins — four layers
## | Order | Where | Unit | When it is used |
## |---|---|---|---|
## | ① | `GoConfig.container_alpha_overrides[variant]` | ratio | to make **only this variant** different in this project |
## | ② | `GoConfig.metric_overrides[<variant>_alpha]` | **%** | to follow the habit of a project that keeps its metrics in one place |
## | ③ | `GoConfig.container_alpha` | ratio | **every panel** in the project at once |
## | ④ | the theme's `GoHud/constants/<variant>_alpha` | **%** | the value the look bundle decided — **the canonical one** |
##
## With none of the four it is 1.0 (a solid color) — meaning plugging in a theme that never heard of this token leaves the screen as it was.
##
## 🔑 To make **one widget alone** different, do not go through this function — give 0.0~1.0 to the argument
##    at that spot, as in `GoSurface.alpha` or `GoStyle.card(..., alpha)` (a negative falls through to this function).
##
## ## 🛑 Percentages live **in the theme constant layer alone**
## Every spot that handles opacity works in ratios (0.0~1.0) — a widget's `alpha` field, `GoStyle` arguments,
## the two fields of `GoConfig`, and the return value of this function. **Because a `Theme` constant can hold
## nothing but integers**, only the theme's `<variant>_alpha` and the channel that overrides it
## (`metric_overrides` — same name and type as a theme metric) are percentages. Those two spots are the only place it divides by 100.
##
## ## 🔬 Drag it before you pick a number
## How large this value should be is something you only learn by looking at the screen — does the background show, does the text on it still read?
## So the examples carry a lab where a single slider thins the panels right where you are looking
## (`examples/gallery/opacity_lab.gd` · widget gallery · guide tour chapter 16 · demo home · medieval example).
static func surface_alpha(variant := GoTheme.BOX_CARD) -> float:
	var settings := config
	var chosen: float = settings.container_alpha_overrides.get(variant, -1.0)
	if chosen >= 0.0: return clampf(chosen, 0.0, 1.0)
	var token := GoTheme.alpha_token(variant)
	# 🛑 This channel alone is a percentage — it is the general window over theme metrics, so it uses the theme's unit.
	if settings.metric_overrides.has(token):
		return _alpha_ratio(settings.metric_overrides[token])
	if settings.container_alpha >= 0.0: return clampf(settings.container_alpha, 0.0, 1.0)
	# 🛑 With nothing there it falls back to **100** — taking `metric_of`'s default of 0 as is would make the panel vanish entirely.
	return _alpha_ratio(GoTheme.metric_of(theme(), token, _fallback_theme(), 100))


## Theme constant percentage (0~100) → ratio (0.0~1.0). Values out of range are clamped — one typo in a theme
## must not be enough to make a panel disappear or get painted twice over.
static func _alpha_ratio(percent: int) -> float:
	return clampf(float(percent) / 100.0, 0.0, 1.0)


## The font size of a role (dp). With mobile shrinking on, it is already reflected in the value.
static func font_size(role: StringName = GoTheme.ROLE_BODY) -> int:
	if config.base_font_size > 0 and role == GoTheme.ROLE_BODY: return config.base_font_size
	return GoTheme.font_size_of(theme(), role, _fallback_theme())


# ── Strings ────────────────────────────────────────────────────────────

## Return one gohud string, **translated**.
##
## Order: `text_overrides` (the literal text) → the key from `text_keys` through `tr()` → **the name itself** through `tr()`.
## 🔑 The last step is what lets a widget take **your own translation key** (`icon_button(…, &"HUD_BAG")`) without
##    registering it in `text_keys` first. A name with no translation comes back as written, so plain words still work.
## 🛑 If the key is not in the translation table, `tr()` hands the key straight back — `gohud_close` showing
##    on screen means the translations are not attached, not that the code is wrong.
static func text(name: StringName) -> String:
	var overrides := config.text_overrides
	if overrides.has(name): return overrides[name]
	var key: String = config.text_keys.get(name, "")
	if key.is_empty(): return TranslationServer.translate(String(name))
	return TranslationServer.translate(key)


## ♿ **Join the pieces** so a screen reader can read them as one phrase. Empty pieces drop out.
##
## ```gdscript
## node.accessibility_name = GoUi.spoken([label.text, error.text])
## ```
##
## 🛑 **Do not join with `"%s %s"` in every widget.** That way the joining differs from widget to widget, and
##    the rule "never hard-code text that goes on screen" (which a check enforces) leaks out all over the place.
##    The day the joining rule has to differ per language, **this one spot** is all there is to fix.
## 🔑 The separator is a space, not a string — it is not translatable, so it is not pulled out as a key.
static func spoken(parts: Array) -> String:
	var kept: Array[String] = []
	for part in parts:
		var word := str(part).strip_edges()
		if not word.is_empty(): kept.append(word)
	return " ".join(kept)


## The **translation key** of the string above. Used when feeding it straight to an auto-translated label (`auto_translate_mode`).
static func text_key(name: StringName) -> String:
	if config.text_overrides.has(name): return config.text_overrides[name]
	return config.text_keys.get(name, String(name))


static func _load_translations() -> void:
	if _translations_loaded: return
	_translations_loaded = true
	if not ResourceLoader.exists(BUILTIN_TRANSLATIONS): return
	# 🛑 On import the CSV is split into **one `.translation` per language** — what you register is those
	#    pieces, not the original CSV. If the pieces are not there yet (a copy where the editor has never
	#    been run once) it passes quietly: the strings come out as their keys and the widgets work all the same.
	var base := BUILTIN_TRANSLATIONS.get_basename()
	for suffix in LOCALES:
		var path := "%s.%s.translation" % [base, suffix]
		if not ResourceLoader.exists(path): continue
		var loaded := ResourceLoader.load(path) as Translation
		if loaded != null: TranslationServer.add_translation(loaded)


# ── Tree access (without an autoload) ──────────────────────────────────

## The current `SceneTree`. 🛑 It can be `null` in checks run with `-s` and in the editor — always check.
static func tree() -> SceneTree:
	var loop := Engine.get_main_loop()
	return loop as SceneTree if loop is SceneTree else null


## The optional `GoRuntime` autoload. `null` when the plugin is not enabled, and the widgets work regardless.
static func runtime() -> Node:
	var scene := tree()
	return scene.root.get_node_or_null(^"GoRuntime") if scene != null else null


## Is this a handheld device — the basis for judging haptics, the virtual keyboard and the safe area.
## 🛑 Not the same as "is the window narrow". A desktop opened in a small window must not vibrate.
static func is_handheld_platform() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios")


# ── Mobile type shrinking ──────────────────────────────────────────────

## On a narrow screen, shrink **the type alone** by one step. Touch areas are left untouched.
## `GoRuntime` calls it when the breakpoint changes. With no autoload nobody calls it, and
## then the theme values come out as they are (which is correct behavior too).
static func set_mobile_type(enabled: bool) -> void:
	if not config.shrink_type_on_mobile or _mobile_type == enabled: return
	var current := theme()
	if _base_font_sizes.is_empty():
		for type in current.get_font_size_type_list():
			for key in current.get_font_size_list(type):
				_base_font_sizes[[type, key]] = current.get_font_size(key, type)
		_base_font_sizes[[&"", &"default"]] = current.default_font_size
	_mobile_type = enabled
	for pair in _base_font_sizes:
		var base: int = _base_font_sizes[pair]
		var small := maxi(10, base - (4 if base >= 28 else (2 if base >= 14 else 1)))
		var value := small if enabled else base
		if pair[0] == &"": current.default_font_size = value
		else: current.set_font_size(pair[1], pair[0], value)
	_notify()


static func is_mobile_type() -> bool:
	return _mobile_type


## 🛑 For checks and editor restarts. Clears the cache so the config is read again from scratch.
static func reset() -> void:
	if _config != null and _config.changed_settings.is_connected(_notify):
		_config.changed_settings.disconnect(_notify)
	_config = null
	_resolved = false
	_mobile_type = false
	_base_font_sizes.clear()
	_default_skin = null
	_stacked = null
	_stacked_main = null
	_stacked_extra = []
	GoThemePresets.reset()
	_watchers.clear()
