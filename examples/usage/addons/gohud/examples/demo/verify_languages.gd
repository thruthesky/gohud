## 🧪 데모의 언어 카드 검증 — 21칸이 각기 다른 언어로 그려지는가, 글리프가 있는가.
##    헤드리스로 돈다. `godot --headless --path . -s res://verify_languages.gd`
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

	# 언어 카드의 칸을 찾는다 — 칸마다 코드 라벨(첫 자식)이 로케일 문자열이다.
	var cells := _find_language_cells(demo)
	_ok(cells.size() == GoUi.LOCALES.size(), "언어 칸 %d개" % GoUi.LOCALES.size(), "찾음 %d" % cells.size())

	# 🛑 폴백 판정은 한 단어로 하지 않는다 — 일본어와 번체는 "確認" 처럼 **같은 표기를 쓰는 단어**가
	#    있어서, 한 칸만 비교하면 정상인 번역을 폴백으로 오판한다(2026-09-13 실측). 칸의 문구를
	#    전부 이어 붙여 비교한다. 그러면 우연한 일치가 사실상 사라진다.
	var seen := {}
	var font: Font = ThemeDB.fallback_font
	for locale: String in GoUi.LOCALES:
		var cell: Control = cells.get(locale)
		if cell == null:
			_ok(false, "%s 칸" % locale, "없다"); continue
		var texts: Array[String] = []
		for child in cell.get_children():
			if child is Label: texts.append((child as Label).text)
		# ① 키가 그대로 보이면 .translation 이 안 붙은 것이다
		var raw := texts.any(func(t: String) -> bool: return t.begins_with("gohud_"))
		var confirm := texts[2] if texts.size() > 2 else ""
		var joined := "|".join(texts.slice(2))
		_ok(not raw and confirm != "", "%s: 문구가 번역돼 있다" % locale, confirm)
		var dup: String = seen.get(joined, "")
		seen[joined] = locale
		if dup != "":
			_ok(false, "%s 와 %s 의 문구가 통째로 같다(폴백)" % [locale, dup], confirm)
		# ② 글리프 — 🛑 `Font.has_char` 로 보지 않는다. 그것은 **시스템 폰트 폴백을 세지 않아서**,
		#    화면에는 멀쩡히 그려지는 태국어·CJK 를 "없다" 고 말한다(2026-09-13 실측).
		#    화면과 같은 판정은 TextServer 의 글리프 인덱스다 — 0 이면 그 글자는 두부(□)로 그려진다.
		var missing := _missing_glyphs(confirm, font)
		_ok(missing == "", "%s: 화면에 그려진다(두부 없음)" % locale,
			"두부가 되는 글자: %s" % missing if missing != "" else "")

	print("")
	if fails == 0:
		print("✅ 데모 언어 카드: %d/%d 통과" % [checks, checks])
		quit(0)
	else:
		printerr("🛑 데모 언어 카드: %d/%d 실패" % [fails, checks])
		quit(1)


## 실제로 그려질 때 글리프가 없는 글자를 돌려준다(빈 문자열 = 전부 그려진다).
## 🔑 `font.get_rids()` 는 폴백 체인을, `allow_system_fallback` 은 OS 폰트를 포함한다 —
##    그래서 이 판정이 `Label` 이 화면에 그리는 것과 같다.
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


## 칸을 찾는다 — 첫 Label 의 text 가 LOCALES 에 있는 Control 이 그 칸이다.
func _find_language_cells(node: Node, out := {}) -> Dictionary:
	if node is VBoxContainer and node.get_child_count() >= 3:
		var first := node.get_child(0)
		if first is Label and GoUi.LOCALES.has((first as Label).text):
			out[(first as Label).text] = node
			return out
	for child in node.get_children():
		_find_language_cells(child, out)
	return out
