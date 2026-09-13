## Shared family selector for the gallery and simulation. Selection lasts for this process.
extends OptionButton

signal theme_selected(preset: StringName)

const PRESETS := [GoThemePresets.DEFAULT_DARK, GoThemePresets.SCIFI_DARK, GoThemePresets.MEDIEVAL_DARK]
const LIGHT_PRESETS := [GoThemePresets.DEFAULT_LIGHT, GoThemePresets.SCIFI_LIGHT, GoThemePresets.MEDIEVAL_LIGHT]
static var active_preset: StringName = GoThemePresets.DEFAULT_DARK


func _init() -> void:
	name = "ThemePicker"
	for title in ["Default theme", "Sci-fi theme", "Medieval theme"]: add_item(title)
	select(maxi(0, PRESETS.find(active_preset)))
	custom_minimum_size = Vector2(190, 48)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	accessibility_name = "Theme"
	tooltip_text = "Change the theme and rebuild the current example"
	item_selected.connect(func(index: int) -> void: theme_selected.emit(PRESETS[index]))


static func configure(settings: GoConfig, default_colors: Dictionary[StringName, Color]) -> void:
	# Keep the original demo's presentation; other families use their own palette.
	var colors: Dictionary[StringName, Color] = {}
	if active_preset == GoThemePresets.DEFAULT_DARK: colors.assign(default_colors)
	settings.color_overrides = colors
	GoUi.config = settings
	GoUi.use_preset(active_preset)


static func pair() -> Array[Theme]:
	var index := maxi(0, PRESETS.find(active_preset))
	return [GoThemePresets.find(PRESETS[index]).theme, GoThemePresets.find(LIGHT_PRESETS[index]).theme]
