## Main menu built with gohud. Copy to your project (e.g. res://ui/main_menu.gd), attach it to a
## full-screen Control, and connect the signals to your game flow. No scene file is needed.
##
## Layout: title · tagline · a card of list rows (Continue / New game / Settings / Quit) · version line.
## Works on phones (portrait and landscape) and desktop: GoForm caps the width and keeps the safe area.
extends Control

signal continue_requested
signal new_game_requested
signal settings_requested
## Emitted after the player confirms. When nothing is connected the menu quits the game itself.
signal quit_confirmed

@export var game_title := "Ashen Crown"
@export var tagline := "An oath written in iron. A journey kept in ink."
@export var version_text := "v1.0.0"
## Preset to apply before building, e.g. &"medieval_dark". Empty keeps the look chosen at boot.
@export var preset: StringName = &""
@export var has_save := true
@export var save_summary := "Chapter III · 2 h 14 m"

var dialogs: GoDialogs


func _ready() -> void:
	if not preset.is_empty():
		GoUi.use_preset(preset)
	build()


## Builds (or rebuilds after a preset change) the whole screen.
func build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = GoUi.theme()
	layout_direction = Control.LAYOUT_DIRECTION_APPLICATION_LOCALE

	var background := ColorRect.new()
	background.name = "Background"
	background.color = GoUi.color(GoTheme.BACKGROUND)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	# GoForm → GoScroll → column, assembled before the form enters the tree (GoForm finds "Scroll" in _ready).
	var form := GoForm.new()
	var scroll := GoScroll.new()
	var page := GoStyle.column(GoUi.metric(GoTheme.GAP_LARGE))
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	form.add_child(scroll)
	scroll.add_child(page)

	var heading := GoStyle.column(GoUi.metric(GoTheme.GAP_TINY))
	var title := GoStyle.label(game_title, GoTheme.ROLE_TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_child(title)
	var subtitle := GoStyle.label(tagline, GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.SECONDARY))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_child(subtitle)
	page.add_child(heading)

	var card := GoStyle.card()
	var inset := GoStyle.padding(GoUi.metric(GoTheme.GAP_SMALL))
	card.add_child(inset)
	var rows := GoStyle.column(GoUi.metric(GoTheme.GAP_TINY))
	rows.name = "MenuRows"
	inset.add_child(rows)
	if has_save:
		rows.add_child(GoStyle.list_button(GoIconSet.PLAY, "Continue", _on_continue,
			GoUi.color(GoTheme.ACCENT), save_summary, false, GoIconSet.CHEVRON_RIGHT))
	rows.add_child(GoStyle.list_button(GoIconSet.PLUS, "New game", _on_new_game, Color.TRANSPARENT, "", false))
	rows.add_child(GoStyle.list_button(GoIconSet.SETTINGS, "Settings", _on_settings, Color.TRANSPARENT, "", false))
	rows.add_child(GoStyle.divider())
	rows.add_child(GoStyle.list_button(GoIconSet.POWER, "Quit", _on_quit, GoUi.color(GoTheme.DANGER), "", false))
	page.add_child(card)

	var footer := GoStyle.label(version_text, GoTheme.ROLE_MICRO, GoUi.color(GoTheme.MUTED))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(footer)

	add_child(form)
	dialogs = GoDialogs.new()
	add_child(dialogs)


func _on_continue() -> void:
	GoFeedback.confirmed()
	continue_requested.emit()


func _on_new_game() -> void:
	if has_save:
		var yes := await dialogs.confirm("Start a new game?",
			"Your saved progress ({summary}) will be overwritten.", "Start over", "Keep playing", "",
			{"summary": save_summary}, true)
		if not yes:
			return
	new_game_requested.emit()


func _on_settings() -> void:
	GoFeedback.tapped()
	settings_requested.emit()


func _on_quit() -> void:
	if not await dialogs.confirm("Quit", "Leave the game?", "Quit", "Stay"):
		return
	if quit_confirmed.get_connections().is_empty():
		get_tree().quit()
	else:
		quit_confirmed.emit()
