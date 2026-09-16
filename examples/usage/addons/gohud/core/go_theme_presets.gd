## 📚 **The preset nameplate.** One name finds a theme·skin·icon bundle.
##
## ```gdscript
## GoUi.use_preset(GoThemePresets.SCIFI_DARK)          # pick one
## for id in GoThemePresets.ids(): print(id)             # list them
## GoThemePresets.register(my_preset)                    # add your own
## ```
##
## ## 🛑 It does not `preload`
## A preset references a theme, and a theme references SVGs. In a project that has just installed the addon and
## has **not imported yet**, a constant `preload` makes `GoUi` fail to load outright over that one file.
## So it holds nothing but paths, reads them **when called**, and quietly returns `null` when there is none (the widgets run on the defaults).
@tool
class_name GoThemePresets
extends RefCounted

## The six gohud packs and ships.
const DEFAULT_DARK := &"default_dark"
const DEFAULT_LIGHT := &"default_light"
const SCIFI_DARK := &"scifi_dark"
const SCIFI_LIGHT := &"scifi_light"
const MEDIEVAL_DARK := &"medieval_dark"
const MEDIEVAL_LIGHT := &"medieval_light"

const FOLDER := "res://addons/gohud/themes/presets/"

## Name → path. The order here is the order the pickers show.
const BUILTIN := {
	DEFAULT_DARK: FOLDER + "default_dark.tres",
	DEFAULT_LIGHT: FOLDER + "default_light.tres",
	SCIFI_DARK: FOLDER + "scifi_dark.tres",
	SCIFI_LIGHT: FOLDER + "scifi_light.tres",
	MEDIEVAL_DARK: FOLDER + "medieval_dark.tres",
	MEDIEVAL_LIGHT: FOLDER + "medieval_light.tres",
}

static var _loaded: Dictionary[StringName, GoThemePreset] = {}
static var _extra: Dictionary[StringName, GoThemePreset] = {}


## 🔑 **Every preset file name in the folder** — the names alone, nothing loaded.
##
## Drop a `.tres` into `themes/presets/` and it shows up in the pickers with no code change. So a new theme is done
## the moment `tools/new_theme.py` creates the file (2026-09-13 — a request, since more themes are planned).
## 🛑 In an exported game a text resource may be carrying a `.remap` — that tail is stripped too.
static func scan_folder(folder := FOLDER) -> Array[StringName]:
	var out: Array[StringName] = []
	var dir := DirAccess.open(folder)
	if dir == null: return out
	for file in dir.get_files():
		var name := file
		if name.ends_with(".remap"): name = name.get_basename()
		if name.ends_with(".tres") or name.ends_with(".res"):
			var id := StringName(name.get_basename())
			if not out.has(id): out.append(id)
	out.sort()
	return out


## The **names** you can pick and nothing more — the built-in order → the rest of the folder → whatever was registered.
## Nothing is loaded, so it is safe even before the import has finished, as at editor startup (the settings hint uses it).
static func names() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in BUILTIN: out.append(id)
	for id in scan_folder():
		if not out.has(id): out.append(id)
	for id in _extra:
		if not out.has(id): out.append(id)
	return out


## Find one by name. `null` if it does not exist or has not been imported yet.
## Even outside the built-in six, `themes/presets/<id>.tres` is read if it is there.
static func find(id: StringName) -> GoThemePreset:
	if id.is_empty(): return null
	if _extra.has(id): return _extra[id]
	if _loaded.has(id): return _loaded[id]
	var path: String = BUILTIN[id] if BUILTIN.has(id) else FOLDER + String(id) + ".tres"
	if not ResourceLoader.exists(path): return null
	var found := ResourceLoader.load(path) as GoThemePreset
	if found == null: return null
	_loaded[id] = found
	return found


## Add a host project's preset. The same name overrides the built-in one.
## 🛑 An empty `id` could never be found again, so it is not taken.
static func register(preset: GoThemePreset) -> void:
	if preset == null or preset.id.is_empty(): return
	_extra[preset.id] = preset


## Remove a registered preset.
static func unregister(id: StringName) -> void:
	_extra.erase(id)


## Every name you can pick (the built-in six + whatever was registered). Only the ones that actually read are counted.
static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in names():
		if find(id) != null and not out.has(id): out.append(id)
	return out


## The presets themselves, for the names above.
static func all() -> Array[GoThemePreset]:
	var out: Array[GoThemePreset] = []
	for id in ids():
		var found := find(id)
		if found != null: out.append(found)
	return out


## 🛑 For checks and editor restarts. Throws away the presets read so far (registered ones stay).
static func reset() -> void:
	_loaded.clear()
