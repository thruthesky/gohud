extends SceneTree

## The podium leaderboard's controls: GoCategoryButton, GoGlyphButton's check badge and glow, GoPageStepper,
## GoStatePanel and GoBoardTitle.

var passed := 0
var failed: Array[String] = []
var previous_count := 0
var next_count := 0
var state_presses := 0


func _initialize() -> void:
	GoUi.use_preset(GoThemePresets.ARCADE_LIGHT)
	var theme: Theme = GoUi.theme()
	for variation in [&"GoCategoryButton", &"GoCategoryButtonSelected", &"GoPagePlate", &"GoPageLabel",
			&"GoStatePanel", &"GoStateHeader", &"GoStateHeading", &"GoStateBody", &"GoBoardTitle", &"GoBoardPill",
			&"GoBoardPillLabel", &"GoPillGreen", &"GoPillBlue", &"GoPillRed"]:
		check(not theme.get_type_variation_base(variation).is_empty(), "%s is a variation of arcade_light" % variation)
	var host := Control.new()
	host.size = Vector2(1672, 941)
	host.theme = theme
	root.add_child(host)
	await _category_button(host)
	await _glyph_badge(host)
	await _stepper(host)
	await _state_panel(host)
	await _board_title(host)
	host.queue_free()
	await process_frame
	print("gohud leaderboard controls tests: %d/%d passed" % [passed, passed + failed.size()])
	for line in failed: print("FAIL %s" % line)
	quit(0 if failed.is_empty() else 1)


func _category_button(host: Control) -> void:
	var art := _square(Color.RED)
	var button := GoCategoryButton.make("FASTEST CLEARS", art)
	button.size = Vector2(320, 100)
	host.add_child(button)
	button.size = Vector2(320, 100)
	await process_frame
	await process_frame
	check(button.theme_type_variation == GoCategoryButton.VAR_CATEGORY, "an unselected category is blue")
	check(button.chevron_rect() == Rect2(), "an unselected category has no chevron")
	check(button.icon_rect().size.x > 0.0, "the icon has its room")
	var icon := button.icon_rect()
	check(icon.position.y >= 100 * 0.18 and icon.end.y <= 100 * 0.82 and icon.position.x >= 100 * 0.14,
			"the icon stays inside the plate's rim")
	button.selected = true
	await process_frame
	check(button.theme_type_variation == GoCategoryButton.VAR_SELECTED, "selecting turns it gold")
	check(button.chevron_rect().size.x > 0.0, "a selected category shows its chevron")
	check(button.text == "FASTEST CLEARS", "fitting never changes the caller's text")
	button.selected = false
	await process_frame
	check(button.theme_type_variation == GoCategoryButton.VAR_CATEGORY, "unselecting turns it blue again")
	button.text = "AN EXTREMELY LONG CATEGORY NAME FOR TESTING"
	await process_frame
	await process_frame
	var base := GoUi.theme().get_font_size(&"font_size", GoCategoryButton.VAR_CATEGORY)
	var floor_size := int(base * GoUi.config.fit_min_scale)
	check(button.get_theme_font_size(&"font_size") >= floor_size, "a long name never shrinks under the floor")
	check(button.is_wrapped(), "a long name breaks into two lines")
	button.queue_free()


func _glyph_badge(host: Control) -> void:
	var pill := GoGlyphButton.make("EASY", &"", &"GoPrimaryButton")
	pill.size = Vector2(150, 65)
	host.add_child(pill)
	check(pill.badge_rect() == Rect2(), "no badge: no badge rect")
	pill.check_badge = _square(Color.GREEN)
	check(pill.badge_rect().size.x > 0.0, "a badge has a rect")
	check(pill.badge_rect().end.x > pill.size.x and pill.badge_rect().position.y < 0.0,
			"the badge overlaps the top-right corner")
	pill.glow = true
	await process_frame
	check(pill.glow, "the glow turns on")
	pill.glow = false
	pill.check_badge = null
	check(pill.badge_rect() == Rect2(), "clearing the badge removes it")
	pill.queue_free()


func _stepper(host: Control) -> void:
	var stepper := GoPageStepper.new()
	stepper.text = "STAGE 4"
	stepper.page_count = 5
	stepper.page_index = 3
	stepper.size = Vector2(420, 90)
	host.add_child(stepper)
	stepper.previous_pressed.connect(func() -> void: previous_count += 1)
	stepper.next_pressed.connect(func() -> void: next_count += 1)
	await process_frame
	check(stepper.label.text == "STAGE 4", "the stepper shows its name")
	check(stepper.dots.visible, "five pages show dots")
	stepper.previous_button.pressed.emit()
	stepper.next_button.pressed.emit()
	check(previous_count == 1 and next_count == 1, "the keys emit previous and next")
	stepper.previous_disabled = true
	stepper.next_disabled = true
	check(stepper.previous_button.disabled and stepper.next_button.disabled, "the ends disable their keys")
	stepper.previous_button.pressed.emit()
	stepper.next_button.pressed.emit()
	check(previous_count == 1 and next_count == 1, "a disabled key emits nothing")
	check(stepper.dot_center(3).x > stepper.dot_center(2).x, "the dots run left to right")
	stepper.page_count = 1
	check(not stepper.dots.visible, "one page shows no dots")
	check(stepper.previous_button.glyph_flip_h and not stepper.next_button.glyph_flip_h, "the keys point outwards")
	stepper.queue_free()


func _state_panel(host: Control) -> void:
	var panel := GoStatePanel.new()
	panel.size = Vector2(1100, 600)
	host.add_child(panel)
	panel.illustration = _square(Color.BLUE)
	panel.heading = "NO TIMES YET"
	panel.body = "Be the first!"
	panel.button_text = "PLAY"
	panel.button_pressed.connect(func() -> void: state_presses += 1)
	await process_frame
	check(not panel.header.visible, "the header is hidden by default")
	panel.heading = "COULD NOT LOAD THE RANKINGS OF THIS VERY LONG LEADERBOARD NAME"
	panel.fit_now()
	await process_frame
	check(panel.get_combined_minimum_size().x <= 1100.5, "a long heading wraps instead of widening the card")
	panel.heading = "NO TIMES YET"
	check(panel.picture.visible and not panel.ring.visible, "the illustration shows when not loading")
	check(panel.button.visible, "a button with words shows")
	check(panel.button.theme_type_variation == &"GoPillGreen", "the button is a green pill by default")
	panel.button.pressed.emit()
	check(state_presses == 1, "the button emits button_pressed")
	panel.loading = true
	await process_frame
	check(not panel.picture.visible and panel.ring.visible, "loading shows the ring instead of the illustration")
	check(not panel.button.visible, "loading hides the button")
	panel.loading = false
	panel.button_text = ""
	check(not panel.button.visible, "no words: no button")
	panel.button_variation = &"GoInfoButton"
	check(panel.button.theme_type_variation == &"GoInfoButton", "the button's look follows button_variation")
	panel.set_header(_square(Color.WHITE), "WEEKLY CHALLENGE", "3d 4h")
	check(panel.header.visible and panel.header_title.text == "WEEKLY CHALLENGE", "set_header shows the strip")
	check(panel.header_pill.visible, "a pill text shows the pill")
	panel.set_header(null, "WEEKLY", "")
	check(not panel.header_pill.visible and not panel.header_icon.visible, "no pill text, no icon: both hidden")
	panel.clear_header()
	check(not panel.header.visible, "clear_header hides the strip")
	panel.queue_free()


func _board_title(host: Control) -> void:
	var title := GoBoardTitle.new()
	title.size = Vector2(700, 160)
	host.add_child(title)
	title.text = "WEEKLY CHALLENGE"
	check(not title.pill.visible, "no pill text: no pill")
	check(not title.icon_rect.visible, "no icon: no icon")
	title.pill_text = "Resets in 3d 4h"
	title.icon = _square(Color.WHITE)
	await process_frame
	check(title.pill.visible and title.pill_label.text == "Resets in 3d 4h", "the pill shows its words")
	check(title.icon_rect.visible, "the icon shows")
	title.text = "A VERY VERY LONG TITLE THAT CANNOT FIT IN SEVEN HUNDRED PIXELS AT ALL"
	title.fit_now()
	check(title.title_label.get_theme_font_size(&"font_size") < 72, "a long title shrinks")
	title.pill_text = ""
	check(not title.pill.visible, "clearing the pill hides it")
	title.queue_free()


func _square(colour: Color) -> Texture2D:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(colour)
	return ImageTexture.create_from_image(image)


func check(condition: bool, label: String) -> void:
	if condition: passed += 1
	else: failed.append(label)
