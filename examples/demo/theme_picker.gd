## Shared family selector for the gallery and simulation. Selection lasts for this process.
##
## 🔑 The families are read from `themes/presets/`, not listed here: every `<family>_dark` preset is one entry,
## paired with `<family>_light` for the dark/light comparison. A theme `tools/new_theme.py` adds shows up in the
## demo with no code change — a hand-kept list had already left Material out of the showreel and Kids out of all of it.
extends OptionButton

signal theme_selected(preset: StringName)

## Families whose name `capitalize()` would spell wrong.
const TITLES := {&"scifi": "Sci-fi theme"}
static var active_preset: StringName = GoThemePresets.DEFAULT_DARK


func _init() -> void:
	name = "ThemePicker"
	var presets := darks()
	for preset in presets: add_item(title(preset))
	select(maxi(0, presets.find(active_preset)))
	custom_minimum_size = Vector2(190, 48)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	accessibility_name = "Theme"
	tooltip_text = "Change the theme and rebuild the current example"
	item_selected.connect(func(index: int) -> void: theme_selected.emit(presets[index]))


## The dark preset of every family, in the order `GoThemePresets.names()` gives — the built-ins first, then the
## folder. Names only: nothing is loaded until one is picked.
static func darks() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in GoThemePresets.names():
		if String(id).ends_with("_dark"): out.append(id)
	return out


## "Sci-fi theme" for `scifi_dark`, "Kids theme" for `kids_dark`.
static func title(preset: StringName) -> String:
	var family := StringName(String(preset).trim_suffix("_dark"))
	return TITLES.get(family, String(family).capitalize() + " theme")


static func configure(settings: GoConfig, default_colors: Dictionary[StringName, Color]) -> void:
	# Keep the original demo's presentation; other families use their own palette.
	var colors: Dictionary[StringName, Color] = {}
	if active_preset == GoThemePresets.DEFAULT_DARK: colors.assign(default_colors)
	settings.color_overrides = colors
	GoUi.config = settings
	GoUi.use_preset(active_preset)


## The active family's dark and light themes. A family without a light preset shows its dark one twice.
static func pair() -> Array[Theme]:
	var dark := GoThemePresets.find(active_preset)
	if dark == null: dark = GoThemePresets.find(GoThemePresets.DEFAULT_DARK)
	var light := GoThemePresets.find(StringName(String(dark.id).trim_suffix("_dark") + "_light"))
	return [dark.theme, light.theme if light != null else dark.theme]
