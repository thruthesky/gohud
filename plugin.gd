## 🔌 The gohud editor plugin.
##
## ## 🛑 Every widget works without turning this on
## All this plugin does is three **conveniences**.
##   ① creates the `gohud/config/resource` (path to the config `.tres`) and
##      `gohud/theme/preset` (look bundle name) fields in Project Settings
##   ② registers the `GoRuntime` autoload (breakpoint·dp scale·virtual keyboard tracking)
##   ③ adds the built-in translation CSV to the project's translation list
##
## Turn it off and only those three go missing; `GoSurface`·`GoSheet`·`GoStyle` and the rest work as they are.
## Shipping as an asset, "it works the moment it is installed" is what matters.
@tool
extends EditorPlugin

const AUTOLOAD_NAME := "GoRuntime"
const AUTOLOAD_PATH := "res://addons/gohud/core/go_runtime.gd"
const CONFIG_SETTING := "gohud/config/resource"
const PRESET_SETTING := "gohud/theme/preset"
const TRANSLATION_CSV := "res://addons/gohud/i18n/gohud.csv"
const TRANSLATION_SETTING := "internationalization/locale/translations"


func _enter_tree() -> void:
	_declare_config_setting()
	_declare_preset_setting()


func _exit_tree() -> void:
	pass


## Called **once, when the plugin is enabled** (unlike `_enter_tree`, which is called on every editor restart).
func _enable_plugin() -> void:
	_declare_config_setting()
	_declare_preset_setting()
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
	_register_translations()


func _disable_plugin() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)
	_unregister_translations()


## Creates the config resource path field — with a file hint so it can be picked from the editor.
func _declare_config_setting() -> void:
	if not ProjectSettings.has_setting(CONFIG_SETTING):
		ProjectSettings.set_setting(CONFIG_SETTING, "")
	ProjectSettings.set_initial_value(CONFIG_SETTING, "")
	ProjectSettings.add_property_info({
		"name": CONFIG_SETTING,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_FILE,
		"hint_string": "*.tres,*.res",
	})
	ProjectSettings.set_as_basic(CONFIG_SETTING, true)
	ProjectSettings.save()


## The **field that picks** the look bundle. Left empty, it is gohud's default look.
## 🔑 The point of this field is to let you switch to sci-fi from the editor without a line of code.
func _declare_preset_setting() -> void:
	if not ProjectSettings.has_setting(PRESET_SETTING):
		ProjectSettings.set_setting(PRESET_SETTING, "")
	ProjectSettings.set_initial_value(PRESET_SETTING, "")
	var names := PackedStringArray()
	# 🔑 The folder's presets too — a theme added with `tools/new_theme.py` shows up here with no code change.
	#    `names()` loads nothing and looks only at names, so it is safe even before the import has finished.
	for id in GoThemePresets.names(): names.append(String(id))
	ProjectSettings.add_property_info({
		"name": PRESET_SETTING,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM_SUGGESTION,
		"hint_string": ",".join(names),
	})
	ProjectSettings.set_as_basic(PRESET_SETTING, true)
	ProjectSettings.save()


## 🛑 Not added if it is already there — the same entry must not pile up every time the plugin is switched off and on.
func _register_translations() -> void:
	if not ResourceLoader.exists(TRANSLATION_CSV): return
	var list := PackedStringArray(ProjectSettings.get_setting(TRANSLATION_SETTING, PackedStringArray()))
	var base := TRANSLATION_CSV.get_basename()
	var added := false
	for locale in GoUi.LOCALES:
		var path := "%s.%s.translation" % [base, locale]
		if not ResourceLoader.exists(path) or list.has(path): continue
		list.append(path)
		added = true
	if added:
		ProjectSettings.set_setting(TRANSLATION_SETTING, list)
		ProjectSettings.save()


func _unregister_translations() -> void:
	var list := PackedStringArray(ProjectSettings.get_setting(TRANSLATION_SETTING, PackedStringArray()))
	var kept := PackedStringArray()
	var base := TRANSLATION_CSV.get_basename()
	for path in list:
		if not path.begins_with(base): kept.append(path)
	if kept.size() != list.size():
		ProjectSettings.set_setting(TRANSLATION_SETTING, kept)
		ProjectSettings.save()
