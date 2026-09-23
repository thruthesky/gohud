## 📐 **Layout checks — does everything fit, in every look, at every width?** Runs alongside `gohud_test.gd`.
##
##   GOHUD_TEST_SCRIPT=res://addons/gohud/tests/gohud_layout_test.gd bash addons/gohud/tools/run_tests.sh
##
## ## 🔑 Why a file of its own
## Every widget had passed its own checks while the gallery was broken on a phone: a carousel sliced its banner in half,
## a pager dragged the whole page 121dp off the screen, a count badge ballooned to 65×65 inside a form (2026-09-23 user
## report and audit). Those only show on a **laid-out screen**, so this file lays screens out and measures them with
## `GoStyle.audit_layout()` — the real gallery in all six looks, narrow and wide, left-to-right and right-to-left.
##
## ## 🛑 Every rule is proven to bite first
## A check that cannot fail proves nothing (the first probe printed "passed" over 30 faults). Each kind of fault is built
## on purpose and must be caught before the gallery's clean result means anything.
extends SceneTree

const ADDON := "res://addons/gohud"
const GALLERY := "res://addons/gohud/examples/gallery/gallery.tscn"

var passed := 0
var failed: Array[String] = []


func _initialize() -> void:
	GoUi.reset()
	GoUi.use_preset(GoThemePresets.DEFAULT_DARK)
	GoUi.config.reduce_motion = true
	GoUi.config.surface_fade_in = false
	create_timer(420.0).timeout.connect(func() -> void:
		print("FAIL watchdog — did not finish within 420 seconds")
		quit(2))

	await _audit_bites()
	_one_line_in_source()
	await _form_keeps_widgets()
	await _carousel_fits()
	await _pagination_fits()
	await _code_input_fits()
	await _badge_reads()
	await _slot_shortcut()
	await _section_rhythm()
	await _drawer_width()
	await _gallery()

	print("gohud layout tests: %d/%d passed" % [passed, passed + failed.size()])
	for line in failed: print("FAIL %s" % line)
	quit(0 if failed.is_empty() else 1)


func check(condition: bool, label: String) -> void:
	if condition: passed += 1
	else: failed.append(label)


func section(name: String) -> void:
	print("  %s %s" % ["ok  " if failed.is_empty() else "....", name])


func frames(count: int) -> void:
	for _i in count: await process_frame


## Sets the screen to [param width] dp wide. The host project may scale the UI by breakpoint, so the stretch size is
## corrected until the laid-out width lands (it converges in a step or two). Returns the width it reached.
func _screen(width: float, height := 844.0) -> float:
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	var ask := Vector2(width, height)
	var got := Vector2.ZERO
	for _attempt in 6:
		root.content_scale_size = Vector2i(ask.round())
		await frames(2)
		got = root.get_visible_rect().size
		if absf(got.x - width) < 1.0: break
		ask *= Vector2(width, height) / got
	return got.x


func _has(problems: Array[String], words: String) -> bool:
	for line in problems:
		if line.contains(words): return true
	return false


# ── The audit catches each fault ───────────────────────────────────────

func _audit_bites() -> void:
	var stage := Control.new()
	stage.size = Vector2(300, 600)
	root.add_child(stage)
	await frames(1)

	# cut — a clipping box shorter than its content (the carousel before the fix).
	var window := Control.new()
	window.clip_contents = true
	window.position = Vector2(0, 0)
	window.size = Vector2(200, 40)
	stage.add_child(window)
	var tall := ColorRect.new()
	tall.size = Vector2(200, 80)
	window.add_child(tall)
	# outside — a child hanging off a button that does not lay it out.
	var button := Button.new()
	button.position = Vector2(0, 60)
	button.size = Vector2(120, 48)
	stage.add_child(button)
	var hanging := ColorRect.new()
	hanging.position = Vector2(100, 0)
	hanging.size = Vector2(60, 20)
	button.add_child(hanging)
	# small to press — a 30dp button. A 36dp icon button is not: its reach is the touch size.
	var tiny := Button.new()
	tiny.position = Vector2(0, 120)
	tiny.size = Vector2(30, 30)
	stage.add_child(tiny)
	var icon := GoIconButton.new()
	icon.icon_name = GoIconSet.CLOSE
	icon.position = Vector2(60, 120)
	stage.add_child(icon)
	# folds inside a word — a wrapping label narrower than its word (the drawer's "Poti/on").
	var narrow := Label.new()
	narrow.text = "Restores"
	narrow.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	narrow.position = Vector2(0, 170)
	narrow.size = Vector2(20, 60)
	stage.add_child(narrow)
	# touches the edge — text on the border of the face behind it.
	var card := PanelContainer.new()
	card.position = Vector2(0, 240)
	card.add_theme_stylebox_override(&"panel", GoStyle.box(GoTheme.BOX_CARD))
	stage.add_child(card)
	var flush := Label.new()
	flush.text = "Flush"
	card.add_child(flush)
	var flat := card.get_theme_stylebox(&"panel") as StyleBoxFlat
	if flat != null: flat.set_content_margin_all(0)
	# past the screen — wider than the window.
	var wide := ColorRect.new()
	wide.position = Vector2(0, 300)
	wide.custom_minimum_size = Vector2(root.get_visible_rect().size.x + 80.0, 10)
	stage.add_child(wide)
	# go_overlay — hangs over an edge on purpose and is left alone.
	var corner := ColorRect.new()
	corner.position = Vector2(110, -8)
	corner.size = Vector2(20, 20)
	corner.set_meta(&"go_overlay", true)
	button.add_child(corner)
	await frames(3)

	var found := GoStyle.audit_layout(stage)
	check(_has(found, "cut 40dp by"), "audit: a box cut by its clipping parent is caught")
	check(_has(found, "outside @Button") or _has(found, "outside Button") or _has(found, "reaches 40dp outside"),
		"audit: a child hanging off a non-container is caught (%s)" % str(found.filter(func(l: String) -> bool: return l.contains("outside"))))
	check(_has(found, "x30 is small to press"), "audit: a 30dp button is caught (%s)" % str(found))
	check(not _has(found, "%s: 36" % icon.get_path()), "audit: a 36dp icon button is not — its reach is the touch size")
	check(_has(found, "folds inside a word"), "audit: a word broken in two is caught")
	check(_has(found, "sits 0/"), "audit: text on the face's border is caught")
	check(_has(found, "past the side of the screen"), "audit: a control wider than the screen is caught")
	check(not _has(found, String(corner.get_path())), "audit: a go_overlay node is left out")
	stage.queue_free()
	await frames(1)
	section("the audit catches each fault")


# ── One-line labels say so ─────────────────────────────────────────────

## 🛑 A label set to `AUTOWRAP_OFF` without `go_no_wrap` is turned back on by `GoForm` — a count badge ballooned and a
##    key hint's `+` went 1dp wide that way. Every one inside the add-on must carry the mark (`GoStyle.one_line()`).
func _one_line_in_source() -> void:
	var misses: Array[String] = []
	for folder in ["widgets", "core"]:
		var dir := DirAccess.open("%s/%s" % [ADDON, folder])
		if dir == null: continue
		for file in dir.get_files():
			if not file.ends_with(".gd"): continue
			var lines := FileAccess.get_file_as_string("%s/%s/%s" % [ADDON, folder, file]).split("\n")
			for index in lines.size():
				var text := lines[index].strip_edges()
				if text.begins_with("#") or not text.contains("autowrap_mode = TextServer.AUTOWRAP_OFF"): continue
				# The function around it must mark the node.
				var first := index
				while first > 0 and not lines[first].begins_with("func ") and not lines[first].begins_with("static func "): first -= 1
				var last := index
				while last < lines.size() - 1 and not lines[last + 1].begins_with("func ") and not lines[last + 1].begins_with("static func "): last += 1
				var body := "\n".join(lines.slice(first, last + 1))
				if not body.contains("go_no_wrap") and not body.contains("one_line("):
					misses.append("%s/%s:%d" % [folder, file, index + 1])
	check(misses.is_empty(), "every AUTOWRAP_OFF in the add-on carries go_no_wrap — use GoStyle.one_line() (%s)" % ", ".join(misses))
	section("one-line labels say so")


# ── A form keeps what a widget chose ───────────────────────────────────

func _build_samples(host: Control) -> Dictionary:
	var parts := {}
	parts.group = GoInputGroup.make(GoStyle.line_edit("Message"), {"suffix": GoStyle.button("Send")})
	host.add_child(parts.group)
	parts.field = GoField.make("Guild name", GoStyle.line_edit("2-16 characters"), "Everyone sees this")
	host.add_child(parts.field)
	parts.row = GoStyle.list_button(GoIconSet.USER, "Profile", Callable(), Color.TRANSPARENT, "Name and title", false)
	host.add_child(parts.row)
	var holder := GoStyle.row()
	parts.icon = GoIconButton.new()
	parts.icon.icon_name = GoIconSet.BELL
	holder.add_child(parts.icon)
	host.add_child(holder)
	parts.badge = GoBadge.attach(parts.icon, 0, "NEW")
	parts.keys = GoKbd.make("Ctrl", "S")
	parts.keys.hide_on_handheld = false
	host.add_child(parts.keys)
	parts.plain = VBoxContainer.new()
	host.add_child(parts.plain)
	parts.raw = Button.new()
	parts.raw.text = "Raw"
	host.add_child(parts.raw)
	parts.sentence = Label.new()
	parts.sentence.text = "A long sentence a person wrote straight into the form, with no wrapping set at all."
	host.add_child(parts.sentence)
	return parts


func _form_keeps_widgets() -> void:
	var outside := GoStyle.column()
	outside.size = Vector2(360, 800)
	root.add_child(outside)
	var loose := _build_samples(outside)
	var form := GoForm.new()
	var scroll := GoScroll.new()
	scroll.name = "Scroll"
	form.add_child(scroll)
	var page := GoStyle.column()
	scroll.add_child(page)
	root.add_child(form)
	var held := _build_samples(page)
	await frames(6)
	check(held.group.get_theme_constant(&"separation") == loose.group.get_theme_constant(&"separation"),
		"form: an input group stays joined (%d in a form, %d outside)" % [held.group.get_theme_constant(&"separation"),
		loose.group.get_theme_constant(&"separation")])
	check(held.field.get_theme_constant(&"separation") == GoUi.metric(GoTheme.GAP_TINY),
		"form: a field's label stays on its field (%d)" % held.field.get_theme_constant(&"separation"))
	var held_line: Array[Node] = (held.row as Node).find_children("*", "HBoxContainer", true, false)
	var loose_line: Array[Node] = (loose.row as Node).find_children("*", "HBoxContainer", true, false)
	if not held_line.is_empty() and not loose_line.is_empty():
		check(held_line[0].get_theme_constant(&"separation") == loose_line[0].get_theme_constant(&"separation"),
			"form: a list row keeps its inner spacing (%d / %d)" % [held_line[0].get_theme_constant(&"separation"),
			loose_line[0].get_theme_constant(&"separation")])
	check(held.icon.size.is_equal_approx(loose.icon.size), "form: an icon button keeps its square (%s / %s)" % [held.icon.size, loose.icon.size])
	check(held.badge.size.is_equal_approx(loose.badge.size),
		"form: a count badge is the same size in and out of a form (%s / %s)" % [held.badge.size, loose.badge.size])
	var plus: Label = null
	for node in held.keys.get_children():
		if node is Label: plus = node
	check(plus != null and plus.size.x > 2.0, "form: the + between keys keeps its width (%.0f)" % (plus.size.x if plus else -1.0))
	check(held.plain.get_theme_constant(&"separation") == GoUi.metric(GoTheme.GAP), "form: a box with no spacing of its own gets the form's gap")
	check(held.raw.custom_minimum_size.y >= float(GoUi.metric(GoTheme.BUTTON_HEIGHT)) - 0.5,
		"form: a bare scene button gets the button height (%.0f)" % held.raw.custom_minimum_size.y)
	check(held.sentence.autowrap_mode != TextServer.AUTOWRAP_OFF, "form: a sentence written straight into a form still wraps")
	outside.queue_free()
	form.queue_free()
	await frames(1)
	section("a form keeps what a widget chose")


# ── Carousel ───────────────────────────────────────────────────────────

func _banner(words: String) -> Control:
	var card := GoStyle.card(GoUi.color(GoTheme.ACCENT))
	var title := GoStyle.label(words, GoTheme.ROLE_SUBTITLE, GoUi.color(GoTheme.ACCENT))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(title)
	return card


func _carousel_fits() -> void:
	var holder := GoStyle.column()
	holder.size = Vector2(350, 600)
	root.add_child(holder)
	var carousel := GoCarousel.new()
	# 🛑 The gallery's 120 — too short for a banner and the dots, as it was on the user's screen.
	carousel.custom_minimum_size.y = 120
	holder.add_child(carousel)
	carousel.set_pages([_banner("Spring event"), _banner("Double XP"), _banner("New skins")])
	await frames(6)
	var viewport := carousel._viewport
	var page := carousel.pages()[0]
	check(viewport.size.y + 0.5 >= page.get_combined_minimum_size().y,
		"carousel: it is as tall as its tallest page (viewport %.0f, page needs %.0f)" % [viewport.size.y, page.get_combined_minimum_size().y])
	check(GoStyle.audit_layout(carousel).is_empty(), "carousel: nothing is cut (%s)" % str(GoStyle.audit_layout(carousel)))
	var dots := carousel.dot_rects()
	check(dots.size() == 3, "carousel: three dots")
	var side := float(GoUi.metric(GoTheme.GAP_SMALL))
	check(dots[1].position.x - dots[0].end.x <= side + 0.5, "carousel: the dots sit close (%.0fdp apart)" % (dots[1].position.x - dots[0].end.x))
	check(dots[0].size.x > dots[1].size.x, "carousel: the lit dot is a longer pill — not colour alone")
	# A press on a dot goes to that page; on the open bar either side, one page that way.
	carousel.press_dots_at(dots[2].get_center())
	await frames(1)
	check(carousel.index() == 2, "carousel: a press on the third dot goes to page 3 (%d)" % carousel.index())
	carousel.press_dots_at(Vector2(4, 24))
	await frames(1)
	check(carousel.index() == 1, "carousel: a press on the bar left of the dots goes back one (%d)" % carousel.index())
	carousel.press_dots_at(Vector2(carousel._dots.size.x - 4, 24))
	await frames(1)
	check(carousel.index() == 2, "carousel: a press on the bar right of the dots goes on one (%d)" % carousel.index())
	var left_room := carousel.dot_rects()[0].position.x
	check(left_room >= float(GoUi.metric(GoTheme.TOUCH)), "carousel: the open bar either side is wider than a finger (%.0f)" % left_room)
	# The dots read on the page in every look — a graphic needs 3:1.
	for preset in GoThemePresets.all():
		GoUi.use_preset(preset.id)
		await frames(1)
		var back := GoUi.color(GoTheme.BACKGROUND)
		var idle := GoSkin.contrast_ratio(carousel._idle_ink(), back)
		var lit := GoSkin.contrast_ratio(GoUi.color(GoTheme.ACCENT), back)
		check(idle >= 3.0 and lit >= 3.0, "carousel: the dots read in %s (idle %.2f, lit %.2f)" % [preset.id, idle, lit])
	GoUi.use_preset(GoThemePresets.DEFAULT_DARK)
	holder.queue_free()
	await frames(1)
	section("carousel")


# ── Pagination ─────────────────────────────────────────────────────────

func _pagination_fits() -> void:
	for width in [280.0, 350.0, 700.0]:
		var strip := GoStyle.column(0)
		strip.size = Vector2(width, 100)
		root.add_child(strip)
		var pager := GoPagination.make(5, 12)
		strip.add_child(pager)
		await frames(4)
		check(pager.get_combined_minimum_size().x <= width + 0.5,
			"pagination: it never asks for more than the %.0fdp it is given (%.0f)" % [width, pager.get_combined_minimum_size().x])
		check(GoStyle.audit_layout(strip).is_empty(), "pagination: nothing spills at %.0fdp (%s)" % [width, str(GoStyle.audit_layout(strip))])
		var numbers := pager._numbers()
		if width >= 700.0:
			check(numbers.has(1) and numbers.has(5) and numbers.has(12), "pagination: wide, it folds to 1 … 5 … 12 (%s)" % str(numbers))
		elif width <= 280.0:
			check(numbers.is_empty() and pager.find_child("Where", true, false) != null,
				"pagination: too narrow for three numbers, it reads 5 / 12 (%s)" % str(numbers))
		strip.queue_free()
		await frames(1)
	section("pagination")


# ── Coupon code ────────────────────────────────────────────────────────

func _code_input_fits() -> void:
	var strip := GoStyle.column(0)
	strip.size = Vector2(280, 300)
	root.add_child(strip)
	var coupon := GoCodeInput.make(12, 4)
	strip.add_child(coupon)
	await frames(6)
	var inside := Rect2(coupon.cells_row.global_position, coupon.cells_row.size).grow(0.5)
	var outside := 0
	var rows := {}
	for cell in coupon._cells:
		if not inside.encloses(cell.get_global_rect()): outside += 1
		rows[roundi(cell.global_position.y)] = true
	check(outside == 0, "coupon: on a 280dp body every cell stays inside (%d outside)" % outside)
	check(rows.size() > 1, "coupon: it folds onto more lines instead (%d lines)" % rows.size())
	var side := float(GoUi.font_size(GoTheme.ROLE_SUBTITLE)) * 1.7
	check(coupon._cells[0].size.x + 0.5 >= side, "coupon: the cells were not squeezed to fit (%.0f)" % coupon._cells[0].size.x)
	# A fold never splits a group — ABCD stays together.
	check(is_equal_approx(coupon._cells[0].global_position.y, coupon._cells[3].global_position.y), "coupon: a group stays on one line")
	check(Rect2(coupon.edit.global_position, coupon.edit.size).encloses(coupon._cells[11].get_global_rect()),
		"coupon: the hidden field still covers the last cell — a tap there opens the keyboard")
	check(GoStyle.audit_layout(strip).is_empty(), "coupon: nothing spills (%s)" % str(GoStyle.audit_layout(strip)))
	strip.queue_free()
	await frames(1)
	section("code input")


# ── Badge ──────────────────────────────────────────────────────────────

func _badge_reads() -> void:
	for preset in GoThemePresets.all():
		GoUi.use_preset(preset.id)
		var badge := GoBadge.make(3)
		root.add_child(badge)
		await frames(2)
		var face := badge.get_theme_stylebox(&"panel")
		var back := GoSkin.blend(GoSkin.box_background(face), GoUi.color(GoTheme.SURFACE))
		var ink := badge._label.get_theme_color(&"font_color")
		check(GoSkin.contrast_ratio(ink, back) >= 4.5,
			"badge: the count reads on the face it is painted on in %s (%.2f)" % [preset.id, GoSkin.contrast_ratio(ink, back)])
		badge.queue_free()
	GoUi.use_preset(GoThemePresets.DEFAULT_DARK)
	var host := Button.new()
	host.position = Vector2(100, 100)
	host.size = Vector2(48, 48)
	root.add_child(host)
	var pinned := GoBadge.attach(host, 3)
	await frames(2)
	pinned.set_count(128)
	await frames(3)
	var center := pinned.get_global_rect().get_center()
	var corner := host.global_position + Vector2(host.size.x, 0)
	check(center.distance_to(corner) <= 1.0, "badge: it stays centred on the corner when the count grows (%.1fdp off)" % center.distance_to(corner))
	host.queue_free()
	await frames(1)
	section("badge")


# ── Slot ───────────────────────────────────────────────────────────────

func _slot_shortcut() -> void:
	var slot := GoSlot.new()
	slot.shortcut_label = "1"
	root.add_child(slot)
	await frames(4)
	var shortcut := slot._shortcut
	var face := slot._face
	var need := float(GoStyle.face_clearance(face))
	check(shortcut.position.x + 0.5 >= need and shortcut.position.y + 0.5 >= need,
		"slot: the shortcut keeps clear of the face's border and corner (%s, needs %.0f)" % [shortcut.position, need])
	slot.queue_free()
	await frames(1)
	section("slot")


# ── Section rhythm ─────────────────────────────────────────────────────

func _section_rhythm() -> void:
	for preset in GoThemePresets.all():
		GoUi.use_preset(preset.id)
		var column := GoStyle.column()
		column.size = Vector2(360, 400)
		root.add_child(column)
		var above := GoStyle.label("The group before")
		column.add_child(above)
		var heading := GoStyle.section("Next group", false)
		column.add_child(heading)
		var below := GoStyle.label("Its first line")
		column.add_child(below)
		await frames(3)
		var face := heading.get_theme_stylebox(&"normal")
		var text_top := heading.global_position.y + maxf(0.0, face.content_margin_top)
		var text_end := heading.get_global_rect().end.y - maxf(0.0, face.content_margin_bottom)
		var gap_above := text_top - above.get_global_rect().end.y
		var gap_below := below.global_position.y - text_end
		check(gap_above > gap_below + 0.5, "section: a heading sits closer to its own group in %s (above %.0f, below %.0f)" % [
			preset.id, gap_above, gap_below])
		column.queue_free()
		await frames(1)
	GoUi.use_preset(GoThemePresets.DEFAULT_DARK)
	section("section rhythm")


# ── Drawer ─────────────────────────────────────────────────────────────

func _drawer_width() -> void:
	var width := await _screen(390.0)
	var drawer := GoDrawer.new()
	root.add_child(drawer)
	drawer.body.add_child(GoStyle.label("Potion 1"))
	drawer.open()
	await frames(6)
	var want := minf(drawer.min_width, width - float(GoUi.metric(GoTheme.TOUCH) + GoUi.metric(GoTheme.GAP_SMALL)))
	check(drawer.panel.size.x + 0.5 >= want, "drawer: on a %.0fdp phone it is %.0fdp — readable, not 42%%" % [width, drawer.panel.size.x])
	check(drawer.panel.size.x <= width - 48.0, "drawer: a strip of screen is left to tap it shut")
	drawer.queue_free()
	await frames(2)
	section("drawer")


# ── The real gallery ───────────────────────────────────────────────────

## Opens the gallery in every look, narrow and wide, both directions, and measures the whole page.
func _gallery() -> void:
	var scene: PackedScene = load(GALLERY)
	var widths := [320.0, 390.0, 1280.0]
	var seen := 0
	for preset in GoThemePresets.all():
		GoUi.use_preset(preset.id)
		for width in widths:
			for rtl in [false, true]:
				var reached := await _screen(width)
				var gallery: Control = scene.instantiate()
				gallery.layout_direction = Control.LAYOUT_DIRECTION_RTL if rtl else Control.LAYOUT_DIRECTION_LTR
				root.add_child(gallery)
				await frames(12)
				var problems := GoStyle.audit_layout(gallery)
				seen += 1
				check(problems.is_empty(), "gallery %s @%.0f%s: %d faults — %s" % [preset.id, reached, " rtl" if rtl else "",
					problems.size(), " | ".join(problems.slice(0, 4))])
				gallery.queue_free()
				await frames(2)
	# Longer words — German and Russian through the add-on's own strings, on the narrowest screen.
	GoUi.use_preset(GoThemePresets.DEFAULT_DARK)
	for locale in ["de", "ru"]:
		TranslationServer.set_locale(locale)
		var reached := await _screen(320.0)
		var gallery: Control = scene.instantiate()
		root.add_child(gallery)
		await frames(12)
		var problems := GoStyle.audit_layout(gallery)
		check(problems.is_empty(), "gallery %s @%.0f: %d faults — %s" % [locale, reached, problems.size(), " | ".join(problems.slice(0, 4))])
		gallery.queue_free()
		await frames(2)
	TranslationServer.set_locale("en")
	check(seen == GoThemePresets.all().size() * widths.size() * 2, "gallery: every look × width × direction was laid out (%d)" % seen)
	section("the gallery fits")
