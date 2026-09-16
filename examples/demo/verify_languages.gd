## 🧪 Verifies the demo's language card — do all 21 cells draw in a different language, and are the
##    glyphs there? Runs headless: `godot --headless --path . -s res://verify_languages.gd`
extends SceneTree

var checks := 0
var fails := 0

func _ok(cond: bool, label: String, detail := "") -> void:
	checks += 1
	if cond:
		print("   ✅ %s  %s" % [label, detail])
	else:
		fails += 1
		printerr("   ❌ %s  %s" % [label, detail])


func _initialize() -> void:
	var demo: Control = load("res://demo.tscn").instantiate()
	root.add_child(demo)
	await process_frame
	await process_frame

	# Find the cells of the language card — each cell's code label (its first child) is the locale string.
	var cells := _find_language_cells(demo)
	_ok(cells.size() == GoUi.LOCALES.size(), "%d language cells" % GoUi.LOCALES.size(), "found %d" % cells.size())

	# 🛑 Never decide "fallback" from a single word — Japanese and Traditional Chinese share **words
	#    written the same way**, such as "確認", so comparing one cell alone marks a perfectly good
	#    translation as a fallback (measured 2026-09-13). Join all of a cell's text and compare that;
	#    an accidental match then all but disappears.
	var seen := {}
	var font: Font = ThemeDB.fallback_font
	for locale: String in GoUi.LOCALES:
		var cell: Control = cells.get(locale)
		if cell == null:
			_ok(false, "%s cell" % locale, "missing"); continue
		var texts: Array[String] = []
		for child in cell.get_children():
			if child is Label: texts.append((child as Label).text)
		# ① A key showing through means no .translation was attached
		var raw := texts.any(func(t: String) -> bool: return t.begins_with("gohud_"))
		var confirm := texts[2] if texts.size() > 2 else ""
		var joined := "|".join(texts.slice(2))
		_ok(not raw and confirm != "", "%s: the text is translated" % locale, confirm)
		var dup: String = seen.get(joined, "")
		seen[joined] = locale
		if dup != "":
			_ok(false, "%s and %s have exactly the same text (fallback)" % [locale, dup], confirm)
		# ② Glyphs — 🛑 do not look with `Font.has_char`. It **does not count the system font fallback**,
		#    so it reports Thai and CJK that draw perfectly well on screen as "missing"
		#    (measured 2026-09-13). The verdict that matches the screen is TextServer's glyph index —
		#    0 means that character draws as tofu (□).
		var missing := _missing_glyphs(confirm, font)
		_ok(missing == "", "%s: draws on screen (no tofu)" % locale,
			"characters that turn into tofu: %s" % missing if missing != "" else "")

	print("")
	if fails == 0:
		print("✅ Demo language card: %d/%d passed" % [checks, checks])
		quit(0)
	else:
		printerr("🛑 Demo language card: %d/%d failed" % [fails, checks])
		quit(1)


## Returns the characters that have no glyph when actually drawn (empty string = everything draws).
## 🔑 `font.get_rids()` covers the fallback chain and `allow_system_fallback` includes the OS fonts —
##    which is why this verdict matches what `Label` draws on screen.
func _missing_glyphs(text: String, font: Font) -> String:
	if text == "":
		return ""
	var ts := TextServerManager.get_primary_interface()
	var shaped := ts.create_shaped_text()
	ts.shaped_text_add_string(shaped, text, font.get_rids(), 16)
	ts.shaped_text_shape(shaped)
	var out := ""
	for glyph in ts.shaped_text_get_glyphs(shaped):
		if int(glyph["index"]) != 0:
			continue
		var start := int(glyph["start"])
		var end := int(glyph["end"])
		var piece := text.substr(start, maxi(end - start, 1)).strip_edges()
		if piece != "" and not out.contains(piece):
			out += piece
	ts.free_rid(shaped)
	return out


## Finds the cells — a Control whose first Label's text is in LOCALES is one of them.
func _find_language_cells(node: Node, out := {}) -> Dictionary:
	if node is VBoxContainer and node.get_child_count() >= 3:
		var first := node.get_child(0)
		if first is Label and GoUi.LOCALES.has((first as Label).text):
			out[(first as Label).text] = node
			return out
	for child in node.get_children():
		_find_language_cells(child, out)
	return out
