## Pause menu built with gohud: a centred GoSurface over the dimmed game that pauses the SceneTree.
## Copy to your project (e.g. res://ui/pause_menu.gd) and add it to the game scene:
##     var pause := preload("res://ui/pause_menu.gd").new()
##     add_child(pause)
##     hud.menu_requested.connect(pause.open)          # the HUD menu button (templates/game_hud.gd)
## Escape / gamepad Start (`ui_cancel`) opens it; Escape, Android Back, the X or a scrim tap resumes.
extends CanvasLayer

signal resumed
signal settings_requested
signal quit_to_title_requested

@export var title_text := "Paused"
## Pause the whole SceneTree while open. This layer keeps processing (PROCESS_MODE_ALWAYS).
@export var pause_tree := true

var surface: GoSurface
var dialogs: GoDialogs


func _ready() -> void:
	if layer == 1:
		layer = 50                                    # above the HUD (5) and sheets (10), below dialogs (100)
	process_mode = Node.PROCESS_MODE_ALWAYS
	dialogs = GoDialogs.new()
	add_child(dialogs)


func is_open() -> bool:
	return is_instance_valid(surface)


func toggle() -> void:
	if is_open(): resume()
	else: open()


func open() -> void:
	if is_open():
		return
	surface = GoSurface.new()
	surface.set_title(title_text)
	surface.dismiss_on_scrim = true
	surface.max_width = 380
	surface.close_requested.connect(resume)
	surface.body.add_child(GoStyle.list_button(GoIconSet.PLAY, "Resume", resume, GoUi.color(GoTheme.ACCENT), "", false))
	surface.body.add_child(GoStyle.list_button(GoIconSet.SETTINGS, "Settings", _on_settings, Color.TRANSPARENT, "", false))
	surface.body.add_child(GoStyle.list_button(GoIconSet.HELP, "How to play", _on_help, Color.TRANSPARENT, "", false))
	surface.body.add_child(GoStyle.divider())
	surface.body.add_child(GoStyle.list_button(GoIconSet.LOGOUT, "Quit to title", _on_quit,
		GoUi.color(GoTheme.DANGER), "", false))
	add_child(surface)
	if pause_tree:
		get_tree().paused = true
	GoFeedback.opened()


func resume() -> void:
	if not is_open() or dialogs.is_open():
		return
	surface.queue_free()
	surface = null
	if pause_tree:
		get_tree().paused = false
	GoFeedback.closed()
	resumed.emit()


func _unhandled_input(event: InputEvent) -> void:
	# Closing is handled by GoSurface itself (it consumes ui_cancel while it is the top window).
	if is_open() or GoSurface.is_any_open():
		return
	if event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		open()
		get_viewport().set_input_as_handled()


func _on_settings() -> void:
	GoFeedback.tapped()
	settings_requested.emit()


func _on_help() -> void:
	await dialogs.alert("How to play", "Move with the left stick or WASD. Tap a quick slot to use an item.")


func _on_quit() -> void:
	var yes := await dialogs.confirm("Quit to title?", "Progress since your last save will be lost.",
		"Quit", "Keep playing", "", {}, true)
	if not yes:
		return
	resume()
	quit_to_title_requested.emit()
