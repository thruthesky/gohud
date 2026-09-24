extends Control

var dialogs := GoDialogs.new()

func _ready() -> void:
	GoUi.use_preset(GoThemePresets.SCIFI_DARK)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = GoUi.theme()
	RenderingServer.set_default_clear_color(GoUi.color(GoTheme.BACKGROUND))
	
	var center := CenterContainer.new()
	cneter.set_anchor_and_offsets_preset(Control.PRESET_FULL_RECT)
	cneter.add_child(GoStyle.button("Click Me!", _show_popup, GoStyle.Tone.PRIMARY))
	add_child(center);
	add_child(dialogs);

func _show_popup() -> void:
	dialogs.alert("This is a Popup!", "Good bye.")
