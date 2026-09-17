## 🧱 Widget **factory**. Stamps out buttons, labels, rows, cells and cards to one spec.
##
## ## Why a factory
## Call `Button.new()` directly and every screen ends up with slightly different padding, height
## and wrapping. Code review never catches that difference — only a screenshot does. So **there is
## one place where things are made**.
##
## ```gdscript
## var row := GoStyle.row()
## row.add_child(GoStyle.button("Save", _on_save, true))
## row.add_child(GoStyle.button("Cancel", _on_cancel))
## ```
##
## ## 🛑 Rules
## - Every dimension comes from a **token** (`GoUi.metric`). Never write a raw number.
## - Touch targets keep the `min_touch_size` (48dp) floor — the visible size may be smaller.
## - Long text wraps. Left on one line its minimum width runs off the screen.
@tool
class_name GoStyle
extends RefCounted

# ── Basic skeleton ─────────────────────────────────────────────────────

## A vertical row. Negative `spacing` means the `gap` token.
static func column(spacing := -1) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP) if spacing < 0 else spacing)
	return node


## A horizontal row.
static func row(spacing := -1) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP) if spacing < 0 else spacing)
	return node


## 🔑 A horizontal row that **flows onto the next line when it overflows**. Use it for chips,
## filters and tags — things whose count is not fixed. On a narrow screen `row` squashes its
## children; this one adds a line.
##
## `alignment` gathers the lines to the center or the end. 🛑 Then set the **last line** separately
## (`last_wrap_alignment`) — one or two items floating centered under a centered list looks off.
static func wrap_row(spacing := -1, alignment := FlowContainer.ALIGNMENT_BEGIN,
		last_line := FlowContainer.LAST_WRAP_ALIGNMENT_BEGIN) -> HFlowContainer:
	var node := HFlowContainer.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.alignment = alignment
	node.last_wrap_alignment = last_line
	var value := GoUi.metric(GoTheme.GAP_SMALL) if spacing < 0 else spacing
	node.add_theme_constant_override(&"h_separation", value)
	node.add_theme_constant_override(&"v_separation", value)
	node.child_entered_tree.connect(natural_width)
	return node


## Whatever goes into a flow row must be at its **natural width**.
##
## 🛑 Leave wrapping on and the minimum width drops to nearly 0, and the flow row sizes the cell
##    to that minimum — one button shrinks to a single character wide and its text runs
##    **one character per line, vertically**
##    (measured 2026-09-12 on a portrait phone screenshot: `Primary` read as `Pri m ary`).
##    Leave a mark (`go_no_wrap`) so `form()` does not turn wrapping back on.
static func natural_width(node: Node) -> void:
	if not (node is Control): return
	var control := node as Control
	control.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	control.set_meta(&"go_no_wrap", true)
	if control is Button: (control as Button).autowrap_mode = TextServer.AUTOWRAP_OFF
	elif control is Label: (control as Label).autowrap_mode = TextServer.AUTOWRAP_OFF
	for child in control.get_children(): natural_width(child)


## 📂 **A foldable section** (Godot 4.5+ `FoldableContainer`). For groups that need not stay open,
## like "Advanced" on a settings screen. Pass the same `FoldableGroup` and only one opens at a time
## (an accordion).
##
## 🛑 Do not lay a long settings list out in one scroll — on a phone you scroll a long way to the
##    item you want. The **whole** title row is the tap target, so there is no small arrow to aim at
##    (that is the engine node's own behavior).
static func foldable(title: String, folded := false, group: FoldableGroup = null, translate := true) -> FoldableContainer:
	var node := FoldableContainer.new()
	node.name = "Foldable"
	node.theme = GoUi.theme()
	node.title = title
	node.folded = folded
	node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS if translate else Node.AUTO_TRANSLATE_MODE_DISABLED
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.custom_minimum_size.y = GoUi.metric(GoTheme.TOUCH)
	if group != null: node.foldable_group = group
	return node


## One layer of inner padding. Pass [param vertical] and only the top and bottom take that value
## (left and right take [param amount]) — for one-line list cells that want roomy sides and a tight
## top and bottom. Negative makes all four sides the same.
static func padding(amount := -1, vertical := -1) -> MarginContainer:
	var node := MarginContainer.new()
	insets(node, amount, vertical)
	return node


## Sets all four margins of an existing `MarginContainer` at once. [param vertical] works as in `padding()`.
static func insets(node: MarginContainer, amount := -1, vertical := -1) -> void:
	var value := GoUi.metric(GoTheme.PADDING) if amount < 0 else amount
	for side in [&"margin_left", &"margin_right"]:
		node.add_theme_constant_override(side, value)
	var down := value if vertical < 0 else vertical
	for side in [&"margin_top", &"margin_bottom"]:
		node.add_theme_constant_override(side, down)


## **A card face with a semantic stripe on one edge only** — shows state in a list without stacking
## blocks of color.
##
## 🔑 Paint the whole card background in the state color and the list becomes layer upon layer of
##    color — **you cannot tell what is urgent.** Leave the background as the shared card and stand
##    one stripe at the edge where the text starts.
## 🛑 A face knows nothing about text direction — in RTL (Arabic, Urdu) the stripe must stand on the
##    **right**, so whoever builds the card reads `Control.is_layout_rtl()` and passes it as [param rtl].
## [param width] negative means the small gap token.
## [param alpha] is the opacity of the face background (negative: the card value set by theme and config).
static func edge_card(accent: Color, rtl := false, width := -1.0, alpha := -1.0) -> StyleBoxFlat:
	var style := box(GoTheme.BOX_CARD, Color.TRANSPARENT, alpha)
	var thick := int(width if width >= 0.0 else float(GoUi.metric(GoTheme.GAP_TINY)))
	style.set_border_width_all(0)
	if rtl: style.border_width_right = thick
	else: style.border_width_left = thick
	style.border_color = Color(accent, 0.9)
	return style


## A **container** wearing that stripe card face — the caller fills the content (the stripe counterpart
## of `card()`).
## [param pad] is the inner padding (negative: the compact padding token). 🛑 Do not wrap another
## `padding()` cell around it.
static func edge_card_panel(accent: Color, rtl := false, pad := -1.0, alpha := -1.0) -> PanelContainer:
	var node := PanelContainer.new()
	node.name = "EdgeCard"
	node.theme = GoUi.theme()
	var face := edge_card(accent, rtl, -1.0, alpha)
	face_padding(face, pad if pad >= 0.0 else float(GoUi.metric(GoTheme.PADDING_COMPACT)),
		pad if pad >= 0.0 else float(GoUi.metric(GoTheme.PADDING_COMPACT)))
	node.add_theme_stylebox_override(&"panel", face)
	return node


## Sets a container's child spacing from a token.
static func gap(node: Container, token := GoTheme.GAP) -> void:
	var value := GoUi.metric(token)
	if node is GridContainer or node is FlowContainer:
		node.add_theme_constant_override(&"h_separation", value)
		node.add_theme_constant_override(&"v_separation", value)
	else:
		node.add_theme_constant_override(&"separation", value)


## 🔑 **Spacing given directly as a value** — only for HUD geometry no token expresses.
##
## 🛑 There are two places `gap()` cannot serve. ① **Negative spacing** — a row whose touch boxes
##    overlap on purpose (quick slots 48 wide on a 40 center pitch is −8). ② **0** — a row that must be
##    drawn flush so there is no seam. Tokens hold no such values, and must not (a token is reading
##    rhythm, not finger geometry).
## Omit [param vertical] and it matches the horizontal value. A vertical box uses `separation` alone.
static func spacing(node: Container, horizontal: int, vertical := -9999) -> void:
	var down := horizontal if vertical == -9999 else vertical
	if node is GridContainer or node is FlowContainer:
		node.add_theme_constant_override(&"h_separation", horizontal)
		node.add_theme_constant_override(&"v_separation", down)
	elif node is VBoxContainer:
		node.add_theme_constant_override(&"separation", down)
	else:
		node.add_theme_constant_override(&"separation", horizontal)


## 🔑 **A different margin per side** — `insets()` gives all four the same value, but a HUD pinned to
## the screen edge insets one or two sides only (a potion row given left and bottom). A negative side is
## **left alone** (the same contract as `face_padding`).
static func edge_insets(node: MarginContainer, left := -1, top := -1, right := -1, bottom := -1) -> void:
	if node == null: return
	var sides := {&"margin_left": left, &"margin_top": top, &"margin_right": right, &"margin_bottom": bottom}
	for side: StringName in sides:
		var value: int = sides[side]
		if value >= 0: node.add_theme_constant_override(side, value)


## An empty cell that eats the leftover space — for pushing one side of a row to the end.
static func spacer(minimum := 0.0) -> Control:
	var node := Control.new()
	node.name = "Spacer"
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	node.custom_minimum_size = Vector2(minimum, minimum)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## A 1dp divider. 🛑 Not `HSeparator` — it drags the default theme's margins along and the line turns thick.
static func divider(vertical := false) -> Control:
	var line := ColorRect.new()
	line.name = "Divider"
	line.color = GoUi.skin().divider_color()
	var thick := GoUi.skin().divider_thickness()
	if vertical:
		line.custom_minimum_size = Vector2(thick, 0)
		line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		line.custom_minimum_size = Vector2(0, thick)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


## 🔑 A grid that **keeps a minimum card width and decides its own column count**.
##
## A fixed column count is bound to break on some screen — 3 columns mash the text on a phone, 1 column
## looks empty on a desktop. This grid recounts columns as `floor(width / min card width)` every time the
## width changes.
##
## ```gdscript
## var grid := GoStyle.responsive_grid(160)   # keep cards at least 160dp wide
## ```
static func responsive_grid(min_cell_width := 160.0, spacing := -1) -> GridContainer:
	var node := GridContainer.new()
	node.name = "ResponsiveGrid"
	node.columns = 1
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value := GoUi.metric(GoTheme.GAP) if spacing < 0 else spacing
	node.add_theme_constant_override(&"h_separation", value)
	node.add_theme_constant_override(&"v_separation", value)
	node.set_meta(&"go_min_cell", min_cell_width)
	# 🛑 Cells must be **divided evenly**. `GridContainer` hands the leftover width only to children
	#    flagged `SIZE_EXPAND`, so left at the default `SIZE_FILL` a card shrinks to **its content's minimum
	#    width** — the label inside has wrapping on, so that minimum is nearly 0, the card folds to 25px and
	#    the text runs **one character per line, vertically**
	#    (measured 2026-09-13: card width 25px at every window from 390 to 600 · label 6 lines).
	node.child_entered_tree.connect(func(child: Node) -> void:
		if child is Control: (child as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL)
	var refit := func() -> void:
		if not is_instance_valid(node): return
		var cell: float = node.get_meta(&"go_min_cell", 160.0)
		var separation := float(node.get_theme_constant(&"h_separation"))
		# n columns fit only while n*cell + (n-1)*separation <= width.
		var columns := int(floor((node.size.x + separation) / maxf(1.0, cell + separation)))
		node.columns = maxi(1, columns)
	node.resized.connect(refit)
	refit.call_deferred()
	return node


## A box that keeps its aspect ratio (thumbnails, minimaps, portraits).
static func aspect(ratio := 1.0) -> AspectRatioContainer:
	var node := AspectRatioContainer.new()
	node.ratio = ratio
	node.stretch_mode = AspectRatioContainer.STRETCH_WIDTH_CONTROLS_HEIGHT
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


# ── Text ───────────────────────────────────────────────────────────────

## Applies a text role and color. Also accepts a `RichTextLabel`.
static func typography(node: Control, role := GoTheme.ROLE_BODY, ink := Color.TRANSPARENT) -> void:
	node.theme = GoUi.theme()
	node.set_meta(&"go_text_role", role)
	if node is RichTextLabel:
		# A node with no variation — pin the size directly.
		var size := GoUi.font_size(role)
		for key in [&"normal_font_size", &"bold_font_size", &"italics_font_size", &"bold_italics_font_size"]:
			node.add_theme_font_size_override(key, size)
		if ink.a > 0: node.add_theme_color_override(&"default_color", ink)
		return
	# 🛑 Size comes from the **variation** (`GoCaptionLabel` …, body has none) — pin an override and that
	#    label stops following the theme (mobile shrink, theme swap) (found 2026-09-12 — `set_mobile_type`
	#    did not restyle the label). Override only when a value outside the theme (`base_font_size`) is asked for.
	var type: StringName = GoTheme.ROLE_TYPES.get(role, &"Label")
	if type == &"Label" or type == &"Button": node.theme_type_variation = &""
	else: node.theme_type_variation = type
	if GoUi.config.base_font_size > 0 and role == GoTheme.ROLE_BODY:
		node.add_theme_font_size_override(&"font_size", GoUi.config.base_font_size)
	else:
		node.remove_theme_font_size_override(&"font_size")
	if ink.a > 0: node.add_theme_color_override(&"font_color", ink)


## 🔑 Sets **the font size (and color) only** from a role token — `theme_type_variation` is left alone.
##
## `typography()` swaps the variation too, so it cannot go on **nodes whose variation defines their face**
## (buttons, segment cells) — there it wipes the button face out entirely. Use this to shrink text to a
## small caption inside a cell, or to **restore the original font** on a cell that `glyph_text()` dressed
## in the icon font (it removes the font override).
static func font_role(node: Control, role := GoTheme.ROLE_BODY, ink := Color.TRANSPARENT) -> void:
	if node == null: return
	node.theme = GoUi.theme()
	node.remove_theme_font_override(&"font")
	node.add_theme_font_size_override(&"font_size", GoUi.font_size(role))
	if ink.a > 0: node.add_theme_color_override(&"font_color", ink)


## 🔑 **Text shadow** — lays a shadow one step behind text that sits straight on the world, on art or on
## a photo, so it does not sink into the background (HUD names and levels, text floating with no face).
## Not for text on a face — the face already makes the contrast.
##
## Alpha 0 on [param ink] means the `shadow` token. [param offset_y] and [param offset_x] are dp, and
## **negative leaves that axis alone** (keeps the theme's value) — one step down, vertically, is the default.
static func text_shadow(node: Control, ink := Color.TRANSPARENT, offset_y := 1, offset_x := -1) -> void:
	if node == null: return
	node.add_theme_color_override(&"font_shadow_color", ink if ink.a > 0 else GoUi.color(GoTheme.SHADOW))
	if offset_y >= 0: node.add_theme_constant_override(&"shadow_offset_y", offset_y)
	if offset_x >= 0: node.add_theme_constant_override(&"shadow_offset_x", offset_x)


## 🔑 Makes **the node's own text the icon glyph** — swaps the font for the icon set's and puts the glyph in `text`.
##
## `apply_icon()` adds a child label; this is for places where **one text cell is the icon** (the glyph cell of
## a pill on the map, a disc button — anywhere the caller measures the cell width from the font and lays it
## out). Pass more than one icon and they are joined with a space (list + chevron = "a list that opens").
## [param size] negative means the `icon_size` token. To go back to the original text, call `font_role()`.
## [param set] looks them up in that set — for a screen that swaps sets, like a second set drawing the same
## names in a **filled** style. Leave it empty for the configured default set.
## 🛑 Texture-only icons have no glyph and are skipped — those belong to `apply_icon()` and `icon_button()`.
static func glyph_text(node: Control, icons: Array, size := -1, ink := Color.TRANSPARENT,
		set: GoIconSet = null) -> void:
	if node == null: return
	var marks := set if set != null else GoUi.icons()
	if marks == null: return
	var parts := PackedStringArray()
	var font: Font = null
	for icon in icons:
		var mark := marks.glyph(icon as StringName)
		if mark.is_empty(): continue
		parts.append(mark)
		if font == null: font = marks.glyph_font(icon as StringName)
	node.theme = GoUi.theme()
	node.set(&"text", " ".join(parts))
	if font != null: node.add_theme_font_override(&"font", font)
	node.add_theme_font_size_override(&"font_size", GoUi.metric(GoTheme.ICON_SIZE) if size < 0 else size)
	if ink.a > 0: node.add_theme_color_override(&"font_color", ink)


## The **width** (dp) of the text `glyph_text()` would draw. For measuring ahead of time whether to collapse
## a cell, instead of asking the node back.
##
## 🛑 **Do not ask the button** — its minimum width depends on whether it currently holds text or a glyph,
##    so asking it feeds the decision its own result and it flips between the two shapes. Measure both shapes
##    from the font and compare.
static func glyph_width(icons: Array, size := -1, set: GoIconSet = null) -> float:
	var marks := set if set != null else GoUi.icons()
	if marks == null: return 0.0
	var parts := PackedStringArray()
	var font: Font = null
	for icon in icons:
		var mark := marks.glyph(icon as StringName)
		if mark.is_empty(): continue
		parts.append(mark)
		if font == null: font = marks.glyph_font(icon as StringName)
	if font == null or parts.is_empty(): return 0.0
	return font.get_string_size(" ".join(parts), HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		GoUi.metric(GoTheme.ICON_SIZE) if size < 0 else size).x


## A label holding a **translation key** — the engine redraws it on its own when the language changes.
static func label_key(key: String, role := GoTheme.ROLE_BODY, ink := Color.TRANSPARENT) -> Label:
	var node := Label.new()
	node.theme = GoUi.theme()
	node.text = key
	node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
	if GoUi.config.autowrap_text: node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	typography(node, role, ink)
	return node


## **Text shown as it is** — a person's name, a server value, an already translated phrase.
static func label(text: String, role := GoTheme.ROLE_BODY, ink := Color.TRANSPARENT) -> Label:
	var node := label_key(text, role, ink)
	node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	return node


## One section title line (a small, dim, uppercase-feeling heading).
static func section(text_or_key: String, translate := true) -> Label:
	var node := label_key(text_or_key, GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED)) if translate \
		else label(text_or_key, GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED))
	node.name = "Section"
	# Lets the skin mark the heading. The default skin's is an empty face, so the look is unchanged.
	node.add_theme_stylebox_override(&"normal", GoUi.skin().section_box())
	return node


# ── Buttons ────────────────────────────────────────────────────────────

## 🛑 Add values **at the end only** — insert one in the middle and numbers saved in scenes point at a different tone.
enum Tone { NORMAL, PRIMARY, DANGER, BARE, COMPACT, DANGER_SOLID }

## Applies the gohud spec to an existing button (scene-built buttons too).
static func style_button(node: Button, tone := Tone.NORMAL) -> void:
	node.theme = GoUi.theme()
	match tone:
		Tone.PRIMARY: node.theme_type_variation = GoTheme.VAR_PRIMARY_BUTTON
		Tone.DANGER: node.theme_type_variation = GoTheme.VAR_DANGER_BUTTON
		Tone.DANGER_SOLID: node.theme_type_variation = GoTheme.VAR_DANGER_SOLID_BUTTON
		Tone.BARE: node.theme_type_variation = GoTheme.VAR_BARE_BUTTON
		Tone.COMPACT: node.theme_type_variation = GoTheme.VAR_COMPACT_BUTTON
		_: node.theme_type_variation = GoTheme.VAR_BUTTON
	var compact := tone == Tone.COMPACT or tone == Tone.BARE
	# 🛑 `MOUSE_FILTER_PASS` — a button inside a scroll must hand the finger drag to the `ScrollContainer`.
	#    With STOP, a scroll that starts on the list does nothing.
	node.mouse_filter = Control.MOUSE_FILTER_PASS
	if GoUi.config.autowrap_text: fit_words(node)
	if tone == Tone.BARE:
		# Clears faces (overrides) left on a scene-built button — a bare button is whatever the theme variation draws.
		for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled", &"focus"]:
			node.remove_theme_stylebox_override(state)
		return
	# 🛑 A small button (COMPACT) **leaves the width flag alone** — the caller often places it with
	#    SHRINK_BEGIN/END, and pinning EXPAND_FILL here overwrites what they set already (2026-09-12, 5 call
	#    sites in the game gohud grew out of). The height is the touch floor.
	node.custom_minimum_size.y = GoUi.metric(GoTheme.TOUCH if compact else GoTheme.BUTTON_HEIGHT)
	if not compact: node.size_flags_horizontal = Control.SIZE_EXPAND_FILL


## 🔑 Sets wrapping so **button text is never split character by character**. Call it again after changing the text.
##
## 🛑 A button with wrapping on **drops the text width out of its minimum width** (it assumes it can fold).
##    So a natural-width button, once narrowed, split `Done` into `Don`/`e` (measured 2026-09-13 on a coach
##    mark). Two rules: ① one word never folds — there is nowhere to fold. ② several words fold, but the
##    minimum width guarantees the **longest word** fits on one line.
static func fit_words(node: Button) -> void:
	if node.has_meta(&"go_no_wrap"): return
	# 🛑 Decide from **the text shown on screen, not the translation key**. `button_key()`'s `text` is the key
	#    (`confirm`) and the engine translates it just before drawing — by the key alone it is one word and we
	#    decide not to fold, while the translation may be two (2026-09-13, I-57). `atr()` translates following
	#    that node's own auto-translate setting.
	var shown := node.atr(node.text) if node.is_inside_tree() else node.text
	var words := shown.strip_edges().split(" ", false)
	if words.size() <= 1:
		node.autowrap_mode = TextServer.AUTOWRAP_OFF
		return
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var font := node.get_theme_font(&"font")
	var size := node.get_theme_font_size(&"font_size")
	var longest := 0.0
	for word in words:
		longest = maxf(longest, font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x)
	var frame := node.get_theme_stylebox(&"normal").get_minimum_size().x
	node.custom_minimum_size.x = maxf(node.custom_minimum_size.x, ceilf(longest + frame + 2.0))


## A button holding a translation key.
static func button_key(key: String, action := Callable(), tone := Tone.NORMAL) -> Button:
	var node := Button.new()
	node.text = key
	style_button(node, tone)
	if action.is_valid(): node.pressed.connect(action)
	return node


## A button whose text is shown as it is.
static func button(text: String, action := Callable(), tone := Tone.NORMAL) -> Button:
	var node := button_key(text, action, tone)
	node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	return node


## 🔍 Audits the **face-padding contract of small text buttons**. Returns `"node path:state …"` for every
## state whose face has left/right padding below the `compact_padding_x` token. An empty array passes.
##
## 🔑 **Looks at the face padding itself** — measured by minimum width, a button stretched wide passes even
##    with a zero-padding face, while a sound button narrowed by word wrapping fails.
## 🛑 Buttons with an icon and no text are skipped — a round or square icon face is right to have no padding.
## 🛑 States whose face the caller overrode are skipped by default (some exceptions are deliberate, like a tightened tab). Pass `include_overrides` to include them.
## `variations` — the variation names to treat as small buttons. If the host based its own name on one, pass that too.
static func audit_compact_padding(root: Node, include_overrides := false,
		variations: Array[StringName] = [GoTheme.VAR_COMPACT_BUTTON]) -> Array[String]:
	var problems: Array[String] = []
	_audit_compact(root, float(GoUi.metric(GoTheme.COMPACT_PADDING_X)), include_overrides, variations, problems)
	return problems


static func _audit_compact(node: Node, need: float, include_overrides: bool, variations: Array[StringName],
		out: Array[String]) -> void:
	var button := node as Button
	if button != null and not button.text.strip_edges().is_empty() and _is_variation(button, variations):
		for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
			if not include_overrides and button.has_theme_stylebox_override(state): continue
			var box := button.get_theme_stylebox(state)
			if box == null: continue
			var left := box.get_margin(SIDE_LEFT)
			var right := box.get_margin(SIDE_RIGHT)
			if left < need - 0.01 or right < need - 0.01:
				var where := String(button.get_path()) if button.is_inside_tree() else String(button.name)
				out.append("%s:%s side padding %.0f·%.0f < %.0f" % [where, state, left, right, need])
	for child in node.get_children():
		_audit_compact(child, need, include_overrides, variations, out)


## Is the node's variation in the list, or does following the theme's base chain reach the list?
static func _is_variation(control: Control, variations: Array[StringName]) -> bool:
	var current := control.theme_type_variation
	var theme := GoUi.theme()
	for _depth in 8:
		if current.is_empty(): return false
		if variations.has(current): return true
		current = theme.get_type_variation_base(current) if theme != null else &""
	return false


## 🔑 **An icon-only button**. The visible size is `visual`; the touch area grows past the node out to the
## `touch` token. The same call whether the set is a font or textures.
##
## ♿ **Always pass `tooltip_key`.** On an icon-only button the tooltip is a mouse user's **only** explanation,
## and the accessibility name is a screen reader's. Both come from this one value.
static func icon_button(icon: StringName, action := Callable(), visual := -1,
		tooltip_key: StringName = &"") -> GoIconButton:
	var node := GoIconButton.new()
	node.visual_size = GoUi.metric(GoTheme.TOUCH) - 12 if visual < 0 else visual
	node.set_icon_name(icon)
	if not tooltip_key.is_empty(): node.tooltip_text_name = tooltip_key
	if action.is_valid(): node.pressed.connect(action)
	return node


## Puts an icon on a button — a texture set goes to `Button.icon`, a font set to a child label.
## 🛑 A child label is the only way to use the icon font and the body font on one button (`text` has one font).
##
## [param inset] moves **a font set's glyph** that far in from the button's left edge (so it lands inside the
## face padding) and widens the left and right text padding out to the icon's end + `gap_small` so the text
## does not run over it. Negative keeps it flush to the edge as before and leaves the face alone. A texture
## set does not apply — the button reserves the icon's place itself.
## 🛑 Widen **both** sides — widen one and centered text is pushed toward the icon and overlaps it instead
##    (measured 2026-09-13 on a narrow full-width button: `Log in with email` sat on top of ✉ and read "Lg in with email").
static func apply_icon(node: Button, icon: StringName, size := -1, ink := Color.TRANSPARENT,
		inset := -1.0) -> void:
	var px := GoUi.metric(GoTheme.ICON_SIZE) if size < 0 else size
	var found := GoUi.icons().texture(icon)
	if found != null:
		node.icon = found
		node.expand_icon = true
			# 🛑 Turn on `expand_icon` without `icon_max_width` and the icon grows to the button's height.
		node.add_theme_constant_override(&"icon_max_width", px)
		if ink.a > 0: node.add_theme_color_override(&"icon_normal_color", ink)
		return
	# 🛑 No texture, so this falls through to a **child label**. The button theme's icon color does not reach a
	#    child, so when no color was passed, pick the same one up here — otherwise it draws white.
	var glyph_ink := ink
	if glyph_ink.a <= 0:
		glyph_ink = node.get_theme_color(&"icon_normal_color") if node.has_theme_color(&"icon_normal_color") \
			else GoUi.color(GoTheme.SECONDARY)
	var glyph := GoUi.icons().node(icon, px, glyph_ink)
	glyph.name = "IconGlyph"
	glyph.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE)
	node.add_child(glyph)
	if inset < 0.0: return
	glyph.offset_left += inset
	glyph.offset_right += inset
	var room := glyph.offset_right + float(GoUi.metric(GoTheme.GAP_SMALL))
	for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
		var face := node.get_theme_stylebox(state)
		if face == null: continue
		var plate := face.duplicate() as StyleBox
		plate.content_margin_left = maxf(face.content_margin_left, room)
		plate.content_margin_right = maxf(face.content_margin_right, room)
		node.add_theme_stylebox_override(state, plate)


## 🔑 **A brand button whose spec comes from outside** — a platform provider's sign-in button (Sign in with
## Google, Apple …), where face color, border and mark size are **nailed down by review guidelines**. gohud
## takes the place and the states, the caller gives the values —
## 🛑 no tokens here, because no skin or palette may change these colors. Transcribing the spec is the host's job.
##
## [param fill] face background · [param ink] text color · [param edge] 1dp border color.
## [param mark] is the mark's `icon_max_width` (negative: unchanged) · [param gap] the space between mark and
## text (negative: unchanged) · [param inset] the face's **left and right** inner padding (negative: unchanged ·
## top and bottom are set to 0 — the caller decides the height).
## [param base] duplicates that face to inherit its **shape (rounding)** — so it reads as one set with the other buttons on the screen.
## [param mark_ink] is the mark color, white by default — so a multi-color official mark (Google's four-color G) is not stained by theme colors.
##
## Hover and press lighten a dark face and darken a light one (the same feedback as the providers' own builds),
## disabled pulls toward gray, and the focus face is **hollow**, leaving only the border (the shared focus ring
## draws on top of it).
## 🛑 To stand mark and text together in the middle of the face, call [method center_button_content] once the width is known.
static func style_brand_button(node: Button, fill: Color, ink: Color, edge: Color,
		mark := -1, gap := -1, inset := -1.0, base: StyleBox = null, mark_ink := Color.WHITE) -> void:
	var source := base if base != null else node.get_theme_stylebox(&"normal")
	if source == null: source = surface(GoTheme.BOX_CARD)
	# 🛑 The face must be one the brand color **can be put into**. In a theme whose skin returns a custom face
	#    (an angular one, say), fixing `bg_color` changes nothing because that face draws in its own color, so the
	#    spec color never reaches the screen — move to a flat face with the same padding, border and rounding.
	#    **This is the only place the spec outranks the skin** (every other function keeps the skin's shape).
	if not (source is StyleBoxFlat): source = _flat_like(source)
	# 🔑 How dark the face is decides the feedback direction — a black face (Apple) lightens, a white one (Google) darkens.
	var dark := fill.get_luminance() < 0.5
	for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
		var face := source.duplicate() as StyleBox
		var back := fill
		if state == &"hover" or state == &"pressed" or state == &"hover_pressed":
			back = fill.lightened(0.18) if dark else fill.darkened(0.06)
		elif state == &"disabled":
			back = fill.lerp(Color(0.5, 0.5, 0.5), 0.35)
		if &"bg_color" in face: face.set(&"bg_color", back)
		if state == &"focus" and &"draw_center" in face: face.set(&"draw_center", false)
		if &"border_color" in face: face.set(&"border_color", edge)
		if face is StyleBoxFlat: (face as StyleBoxFlat).set_border_width_all(1)
		elif &"border_width" in face: face.set(&"border_width", 1.0)
		if &"shadow_size" in face: face.set(&"shadow_size", 0)
		if inset >= 0.0:
			face.content_margin_left = inset
			face.content_margin_right = inset
			face.content_margin_top = 0.0
			face.content_margin_bottom = 0.0
		node.add_theme_stylebox_override(state, face)
	for key in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color",
			&"font_focus_color", &"font_disabled_color"]:
		node.add_theme_color_override(key, ink)
	for key in [&"icon_normal_color", &"icon_hover_color", &"icon_pressed_color", &"icon_hover_pressed_color",
			&"icon_focus_color", &"icon_disabled_color"]:
		node.add_theme_color_override(key, mark_ink)
	if mark >= 0: node.add_theme_constant_override(&"icon_max_width", mark)
	if gap >= 0: node.add_theme_constant_override(&"h_separation", gap)
	node.alignment = HORIZONTAL_ALIGNMENT_LEFT
	node.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT


## 🔑 Stands **mark and text together in the middle of the face** — the shape of the providers' own buttons.
## 🛑 Do not use `icon_alignment = CENTER` — the engine draws the mark **on top of** the text (measured
##    2026-09-14: "Sign in w●th Apple"). Instead keep the text on the left and put
##    **left padding = (width − mark − gap − text width) / 2** into the face.
## Call it again when the width changes (`resized`), when the language changes, and when the mark arrives late.
## 🔑 An unchanged value leaves the face alone — changing the padding changes the minimum size, which brings `resized` back around in a loop.
## [param min_inset] negative means the face's own left padding is the floor. Returns the left padding it set (-1 while the width is still 0).
static func center_button_content(node: Button, min_inset := -1.0) -> float:
	if node == null or not is_instance_valid(node) or node.size.x <= 0.0: return -1.0
	var face := node.get_theme_stylebox(&"normal")
	var lower := min_inset
	if lower < 0.0: lower = face.content_margin_left if face != null else 0.0
	var mark := float(node.get_theme_constant(&"icon_max_width") + node.get_theme_constant(&"h_separation"))
	var text := node.get_theme_font(&"font").get_string_size(node.atr(node.text), HORIZONTAL_ALIGNMENT_LEFT, -1,
			node.get_theme_font_size(&"font_size")).x
	var left := maxf(lower, floorf((node.size.x - mark - text) * 0.5))
	for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
		var plate := node.get_theme_stylebox(state)
		if plate != null and not is_equal_approx(plate.content_margin_left, left):
			plate.content_margin_left = left
	return left


## 🎨 Sets **text and icon color only, with no face** — buttons that draw no background and say their state
## in color alone (link rows, quiet menus).
## [param ink] is the resting color, [param active] the hover, pressed and focus color. A transparent one is
## left alone — a button already given its resting color by `typography()` takes [param active] only.
static func tint_button(node: Button, ink := Color.TRANSPARENT, active := Color.TRANSPARENT) -> void:
	if ink.a > 0:
		node.add_theme_color_override(&"font_color", ink)
		node.add_theme_color_override(&"icon_normal_color", ink)
	if active.a > 0:
		for key in [&"font_hover_color", &"font_pressed_color", &"font_focus_color",
				&"icon_hover_color", &"icon_pressed_color", &"icon_focus_color"]:
			node.add_theme_color_override(key, active)


## 🛑 **Pins the font size in pixels** — only where the spec comes from outside (an official sign-in button
##    whose guideline is a text-to-height ratio, say). Normally use a role through `typography()` — a role
##    follows theme swaps and mobile shrink; a value pinned here does not. A `RichTextLabel` gets all four
##    sizes pinned together.
static func pin_font_size(node: Control, size: int) -> void:
	if node is RichTextLabel:
		for key in [&"normal_font_size", &"bold_font_size", &"italics_font_size", &"bold_italics_font_size"]:
			node.add_theme_font_size_override(key, size)
		return
	node.add_theme_font_size_override(&"font_size", size)


## 🧾 **A monospace text box** — for diagnostics codes and logs, where characters must line up and the
## reader must be able to select and copy them.
## [param font] is a monospace font the caller chose — 🛑 gohud ships no fonts (use `SystemFont`, which finds
## one on the device, or have the host pass its own).
## [param selection] is the background of the selected range and [param selected_ink] the text on it (transparent
## leaves them alone) — 🛑 the default selection background is light gray, and light text sinks into it.
static func style_mono_text(node: RichTextLabel, font: Font, selection := Color.TRANSPARENT,
		selected_ink := Color.TRANSPARENT) -> void:
	if font != null:
		for key in [&"normal_font", &"bold_font", &"italics_font", &"bold_italics_font"]:
			node.add_theme_font_override(key, font)
	if selection.a > 0: node.add_theme_color_override(&"selection_color", selection)
	if selected_ink.a > 0: node.add_theme_color_override(&"font_selected_color", selected_ink)


## 🔑 **A list item: one icon + one line of text.** For places that stack vertically, like menus and settings.
##
## The eye travels less than over a two-column grid, and the icon on every row is recognized before the text is
## read. Pass `sub_key` and a one-line summary joins under the title (small and dim).
##
## 🛑 The **whole** row is the tap target — the summary must be inside the button too.
static func list_button(icon: StringName, key: String, action := Callable(),
		ink := Color.TRANSPARENT, sub_key := "", translate := true, trailing: StringName = &"") -> Button:
	return list_row(Button.new(), icon, key, action, ink, sub_key, translate, trailing)


## Dresses an existing button as the same list item — node, name and connections are left as they are.
## `trailing` is the icon at the row's right end (e.g. `GoIconSet.CHEVRON_RIGHT` — the sign that a next screen
## follows). It sits inside the same row as the text so the two center vertically together (never placed by coordinates).
static func list_row(node: Button, icon: StringName, key: String, action := Callable(),
		ink := Color.TRANSPARENT, sub_key := "", translate := true, trailing: StringName = &"") -> Button:
	node.theme = GoUi.theme()
	node.theme_type_variation = GoTheme.VAR_LIST_BUTTON
	node.custom_minimum_size.y = GoUi.metric(GoTheme.TOUCH)
	node.mouse_filter = Control.MOUSE_FILTER_PASS
	node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	node.text = ""            # The label below draws the text — clears the old text of a scene-built button.
	node.clip_text = false
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var inset := padding(GoUi.metric(GoTheme.GAP))
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# On a two-line item the outer padding stays wider than the space between title and summary.
	var vertical_padding := GoUi.metric(GoTheme.GAP_TINY if sub_key.is_empty() else GoTheme.GAP_SMALL)
	inset.add_theme_constant_override(&"margin_top", vertical_padding)
	inset.add_theme_constant_override(&"margin_bottom", vertical_padding)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(inset)

	var line := row(GoUi.metric(GoTheme.GAP_SMALL))
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.alignment = BoxContainer.ALIGNMENT_BEGIN
	inset.add_child(line)

	if not icon.is_empty():
		var glyph := GoUi.icons().node(icon, GoUi.metric(GoTheme.LIST_GLYPH),
			ink if ink.a > 0 else GoUi.color(GoTheme.SECONDARY))
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(glyph)

	var title := label_key(key, GoTheme.ROLE_BODY, ink) if translate else label(key, GoTheme.ROLE_BODY, ink)
	# 🛑 Auto-translate is off on the button (this label draws the text), so pin it on the child instead of
	#    letting it inherit — left at INHERIT the list shows raw translation keys.
	title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS if translate else Node.AUTO_TRANSLATE_MODE_DISABLED
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	if sub_key.is_empty():
		title.size_flags_vertical = Control.SIZE_EXPAND_FILL
		line.add_child(title)
	else:
		# A two-line item — title and summary stacked vertically in one cell. The summary is one step back in color and size.
		var stack := column(GoUi.metric(GoTheme.GAP_TINY))
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# However tall the row grows, the two text lines keep their natural height and center with the icon.
		stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		title.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		title.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		stack.add_child(title)
		var sub := label_key(sub_key, GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED)) if translate \
			else label(sub_key, GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED))
		sub.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS if translate else Node.AUTO_TRANSLATE_MODE_DISABLED
		stack.add_child(sub)
		line.add_child(stack)

	if not trailing.is_empty():
		var tail := GoUi.icons().node(trailing, GoUi.metric(GoTheme.LIST_GLYPH), GoUi.color(GoTheme.MUTED))
		tail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(tail)

	# 🛑 Measure **`inset`**, not `line` — fit the content height alone and the top and bottom padding is left
	#    out, so the text spills below the item by exactly that much. A one-line item stays under the touch floor,
	#    which hides the difference.
	fit_content_height(node, inset)
	if action.is_valid(): node.pressed.connect(action)
	return node


# ── Inputs ─────────────────────────────────────────────────────────────

## 🔑 **A label + its input as one group.** Builds one row (a field) of a form.
##
## ```gdscript
## body.add_child(GoStyle.field("fieldEmail", GoStyle.line_edit("you@example.com")))
## ```
##
## 🛑 **A label must stay attached to its own input.** Stack label, field, label, field at the same
##    spacing (`gap`) and the reader has to work out which label belongs to which field every time, and
##    each field wastes eight pixels of height until the last one is pushed off the screen
##    (measured 2026-09-16 on Laryen's account-linking form).
##    Inside the group is `gap_tiny`; between groups is the form's `gap`.
##
## An empty `key` returns the control alone, with no label. Pass `hint` and a small explanatory line joins under the field.
static func field(key: String, control: Control, hint := "", translate := true) -> Control:
	if key.is_empty() and hint.is_empty(): return control
	var group := column(GoUi.metric(GoTheme.GAP_TINY))
	group.name = "Field"
	# 🛑 The form sets every child box's spacing to `gap` at once, so mark this one group as keeping its own.
	group.set_meta(&"go_own_spacing", true)
	if not key.is_empty():
		var caption := label_key(key, GoTheme.ROLE_CAPTION) if translate else label(key, GoTheme.ROLE_CAPTION)
		caption.name = "FieldLabel"
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		group.add_child(caption)
	group.add_child(control)
	if not hint.is_empty():
		var note := label_key(hint, GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED)) if translate \
			else label(hint, GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED))
		note.name = "FieldHint"
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		group.add_child(note)
	return group


static func line_edit(placeholder := "", translate_placeholder := false) -> LineEdit:
	var node := LineEdit.new()
	node.theme = GoUi.theme()
	node.placeholder_text = placeholder
	# 🛑 Without `translate_placeholder` the translate mode is **left alone** (inherited from the parent).
	#    Pinning DISABLED makes key names show through inside a form the parent is translating
	#    (2026-09-12, 3 search hints in the game gohud grew out of).
	if translate_placeholder: node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
	node.custom_minimum_size.y = GoUi.metric(GoTheme.BUTTON_HEIGHT)
	return node


static func toggle(key := "", translate := true) -> CheckButton:
	var node := CheckButton.new()
	node.theme = GoUi.theme()
	node.text = key
	if translate: node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS   # otherwise inherited from the parent
	# Uses the button height so it lines up with inputs and buttons in a form (taller than the touch floor).
	node.custom_minimum_size.y = GoUi.metric(GoTheme.BUTTON_HEIGHT)
	node.mouse_filter = Control.MOUSE_FILTER_PASS
	if GoUi.config.autowrap_text: fit_words(node)   # the same word rule as buttons
	return node


static func checkbox(key := "", translate := true) -> CheckBox:
	var node := CheckBox.new()
	node.theme = GoUi.theme()
	node.text = key
	node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS if translate \
		else Node.AUTO_TRANSLATE_MODE_DISABLED
	node.custom_minimum_size.y = GoUi.metric(GoTheme.TOUCH)
	node.mouse_filter = Control.MOUSE_FILTER_PASS
	return node


static func slider(minimum := 0.0, maximum := 1.0, step := 0.01) -> HSlider:
	var node := HSlider.new()
	node.theme = GoUi.theme()
	node.min_value = minimum
	node.max_value = maximum
	node.step = step
	node.custom_minimum_size.y = GoUi.metric(GoTheme.TOUCH)
	return node


static func picker() -> OptionButton:
	var node := OptionButton.new()
	node.theme = GoUi.theme()
	node.custom_minimum_size.y = GoUi.metric(GoTheme.TOUCH)
	return node


static func progress(ink := Color.TRANSPARENT) -> ProgressBar:
	var node := ProgressBar.new()
	node.theme = GoUi.theme()
	node.show_percentage = false
	node.custom_minimum_size.y = GoUi.metric(GoTheme.GAP_SMALL)
	if ink.a > 0: tint_progress(node, ink)
	return node


## Changes only the bar's fill color. The skin decides the shape.
static func tint_progress(bar: ProgressBar, ink: Color) -> void:
	bar.add_theme_stylebox_override(&"fill", GoUi.skin().progress_fill_box(ink))


# ── Surface pieces ─────────────────────────────────────────────────────

## 🔑 A **copy** of a card or panel StyleBox — **in exactly the shape the skin decided**. A custom
## StyleBox, an angular face for instance, comes through as it is. Where the theme changes the shape too,
## use this instead of `box()`.
## [param alpha] is the **opacity of the face background** (0.0~1.0) — negative: the value set by theme and config (`GoUi.surface_alpha`).
static func surface(variant := GoTheme.BOX_CARD, accent := Color.TRANSPARENT, alpha := -1.0) -> StyleBox:
	return GoUi.skin().surface_box(variant, accent, alpha)


## A **copy** of a card or panel StyleBox. Pass `accent` and the border takes that color.
##
## 🛑 **Always returns a `StyleBoxFlat`** — many call sites already take it back and fix `bg_color` or
##    `corner_radius`. In a theme whose skin returns a custom StyleBox (sci-fi and the like) that shape
##    does not survive here. To keep the shape, use `surface()`.
## [param alpha] is the opacity of the face background (negative: the theme and config value · as in `surface()`).
static func box(variant := GoTheme.BOX_CARD, accent := Color.TRANSPARENT, alpha := -1.0) -> StyleBoxFlat:
	var shaped := GoUi.skin().surface_box(variant, accent, alpha)
	var style := shaped as StyleBoxFlat
	if style == null:
		style = _flat_like(shaped)
			# 🛑 0.5 — this value is the norm of the game gohud grew out of. Written as 0.55 once, and the delegation cross-check caught it (2026-09-12).
		if accent.a > 0: style.border_color = Color(accent, 0.5)
	return style


## Moves a custom face (angular, forged) onto a flat one with **the same padding, background, border, radius
## and shadow** — only the shape is lost, the geometry is the same.
## 🛑 Return an empty flat face and its padding is 0, which glued the text of cards built by the old `box()` to their borders (2026-09-15, Laryen's look swap).
static func _flat_like(source: StyleBox) -> StyleBoxFlat:
	var flat := StyleBoxFlat.new()
	flat.bg_color = GoUi.color(GoTheme.SURFACE)
	if source == null: return flat
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		flat.set_content_margin(side, source.get_content_margin(side))
	if &"bg_color" in source: flat.bg_color = source.get(&"bg_color")
	if &"draw_center" in source: flat.draw_center = source.get(&"draw_center")
	if &"border_color" in source: flat.border_color = source.get(&"border_color")
	if &"border_width" in source: flat.set_border_width_all(roundi(float(source.get(&"border_width"))))
	if &"radius" in source: flat.set_corner_radius_all(roundi(float(source.get(&"radius"))))
	if &"shadow_color" in source: flat.shadow_color = source.get(&"shadow_color")
	if &"shadow_size" in source: flat.shadow_size = int(source.get(&"shadow_size"))
	if &"shadow_offset" in source: flat.shadow_offset = source.get(&"shadow_offset")
	return flat


## A surface **floating** above the game screen — the same card with a shallow shadow. The same contract as `box()` above.
## [param opaque] **fills the face solid** with the background color — for places where the world shows through and the text cannot be read (a notice row over the HUD).
## [param pad] is the face's inner padding (negative: the skin's value · as in `face_padding`).
## [param alpha] is the opacity of the face background (negative: the theme and config value). 🛑 Turn
## [param opaque] on and this value goes unused — filling solid **on purpose**, for "places where the world
## shows through and the text cannot be read", is what that argument means.
static func floating(variant := GoTheme.BOX_HUD, accent := Color.TRANSPARENT, opaque := false, pad := -1.0,
		alpha := -1.0) -> StyleBoxFlat:
	var style := GoUi.skin().floating_box(variant, accent, alpha) as StyleBoxFlat
	if style == null:
		style = box(variant, accent, alpha)
		style.shadow_color = Color(GoUi.color(GoTheme.SHADOW), 0.35)
		style.shadow_size = GoUi.metric(GoTheme.GAP_SMALL)
		style.shadow_offset = Vector2(0, 2)
	if opaque: style.bg_color = GoUi.color(GoTheme.BACKGROUND)
	face_padding(style, pad, pad)
	return style


## A round badge or avatar border — a faint accent fill with a ring of the same color. The same contract as `box()` above.
static func disc(diameter: float, accent: Color, fill_alpha := 0.14, edge_alpha := 0.38) -> StyleBoxFlat:
	var style := GoUi.skin().disc_box(diameter, accent, fill_alpha, edge_alpha) as StyleBoxFlat
	if style == null:
		style = box(GoTheme.BOX_HUD, accent)
		style.bg_color = Color(accent, fill_alpha)
		style.border_color = Color(accent, edge_alpha)
		style.set_border_width_all(1)
		style.set_corner_radius_all(maxi(1, int(diameter * 0.5) - 1))
		style.corner_detail = 16
		style.set_content_margin_all(0)
		style.shadow_size = 0
	return style


## One card with a border (the caller fills the content).
##
## [param border_alpha] and [param border_width] are the accent border's **depth and thickness** (negative: the
## values the skin face has) — for making one card in a list stand out (the last one chosen, the one in use, a
## notice card asking for attention).
## [param pad] is the face's inner padding (negative: the skin's). 🛑 Do **not** wrap another `padding()` cell
## around it — the padding doubles and the ellipsized text in a narrow cell disappears completely (the same trap as `hud_panel()`).
## 🔑 The face comes from `surface()` — in angular and medieval face themes the shape stays and only color, thickness and padding change.
## [param alpha] is the opacity of the face background (0.0~1.0) — negative: the card value set by theme and config (`GoTheme.CARD_ALPHA`).
## 🔑 Use it when you want **this one card** to differ (an equipment comparison card and other places that must show what is behind).
static func card(accent := Color.TRANSPARENT, border_alpha := -1.0, border_width := -1.0,
		pad := -1.0, alpha := -1.0) -> PanelContainer:
	var node := PanelContainer.new()
	node.name = "Card"
	node.theme = GoUi.theme()
	node.theme_type_variation = GoTheme.VAR_CARD
	# 🛑 A card given nothing **builds no new face** — the look of a project that defined the `GoCard`
	#    variation differently in its own theme would turn into `GoHud/styles/card`. It must still **follow the
	#    face opacity** (80% by default): so read the very face the theme variation draws and **multiply the alpha only.**
	#    🔑 Only this path keeps both — someone else's theme keeps the shape it set, the opacity follows the config.
	#    At 100% opacity `fade_panel()` lifts the override off, so the face is exactly what it used to be.
	if accent.a <= 0 and border_alpha < 0.0 and border_width < 0.0 and pad < 0.0 and alpha < 0.0:
		fade_panel(node, -1.0, &"panel", GoTheme.BOX_CARD)
		return node
	var face := surface(GoTheme.BOX_CARD, accent, alpha)
	_face_border(face, accent if border_alpha >= 0.0 else Color.TRANSPARENT, border_alpha, border_width)
	if pad >= 0.0: face.set_content_margin_all(pad)
	node.add_theme_stylebox_override(&"panel", face)
	return node


## Overrides a face's border color and thickness — assumes nothing about the skin's face type (a flat face has four sides, a custom one a single `border_width`).
## Alpha 0 on [param ink] or a negative [param alpha] sets no color; a negative [param width] sets no thickness.
static func _face_border(face: StyleBox, ink: Color, alpha: float, width: float) -> void:
	if face == null: return
	if ink.a > 0 and alpha >= 0.0 and &"border_color" in face: face.set(&"border_color", Color(ink, alpha))
	if width < 0.0: return
	if face is StyleBoxFlat: (face as StyleBoxFlat).set_border_width_all(roundi(width))
	elif &"border_width" in face: face.set(&"border_width", width)


## 🔑 **One backing cell** — a face that holds no content and is **laid behind** things (the tint cell of a portrait slot, a HUD surface that looks smaller than its touch cell).
## Where `card()` and `hud_panel()` are containers holding children, this is a single `Panel`, so the caller places it with anchors and size.
##
## The face comes from the skin's [param variant] and **only what you pass** is overridden — alpha 0 on
## [param fill] or [param edge] keeps the skin's colors, and negative [param radius] or [param border] keeps the skin's corners and border.
## 🛑 The cell has no content, so face padding and shadow are 0 — the shadow of a face laid under another blurs the text above it.
## 🔑 It takes no input (`MOUSE_FILTER_IGNORE`) — backing must never swallow the press of a button laid on top.
## [param alpha] is the opacity of the face background (negative: the theme and config value). 🛑 **A face given
## [param fill] keeps that exact color** — the face opacity is not multiplied onto a color whose alpha you already
## wrote. To set both, state [param alpha] explicitly.
static func plate(variant := GoTheme.BOX_HUD, fill := Color.TRANSPARENT, edge := Color.TRANSPARENT,
		radius := -1.0, border := -1.0, alpha := -1.0) -> Panel:
	var node := Panel.new()
	node.name = "Plate"
	node.theme = GoUi.theme()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 🛑 The background may be overridden further down, so take the face solid and apply the opacity **last**.
	var face := surface(variant, Color.TRANSPARENT, 1.0)
	var explicit_fill := fill.a > 0
	if explicit_fill and &"bg_color" in face: face.set(&"bg_color", fill)
	_face_border(face, edge, edge.a, border)
	if radius >= 0.0:
		if face is StyleBoxFlat: (face as StyleBoxFlat).set_corner_radius_all(roundi(radius))
		elif &"radius" in face: face.set(&"radius", radius)
	if face is StyleBoxFlat: (face as StyleBoxFlat).shadow_size = 0
	face.set_content_margin_all(0)
	# 🛑 **A face given [param fill] keeps that exact color** — multiply the face opacity again onto a color
	#    whose alpha was written out, like `Color(ink, 0.14)`, and the caller's intent is cut twice
	#    (0.14 → 0.112). Face opacity goes onto "the background the skin gave" only. An explicit
	#    [param alpha] wins.
	if alpha >= 0.0: GoSkin.fade_box(face, alpha)
	elif not explicit_fill: GoSkin.fade_box(face, GoUi.surface_alpha(variant))
	node.add_theme_stylebox_override(&"panel", face)
	return node


## 🔑 **A disc cell** — a container wearing the `disc()` face. Put one icon or one line of text inside and it centers (an entry marker ▶, an avatar slot).
## Its minimum size is the diameter and it takes no input — for a round button you can press, see `style_disc_button()`.
static func disc_panel(diameter: float, accent: Color, fill_alpha := 0.14, edge_alpha := 0.38) -> PanelContainer:
	var node := PanelContainer.new()
	node.name = "Disc"
	node.custom_minimum_size = Vector2(diameter, diameter)
	node.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	style_disc_panel(node, diameter, accent, fill_alpha, edge_alpha)
	return node


## Applies the same disc to **a face you already built** (`Panel`, `PanelContainer`) — for places that must not
## rebuild the node every time the semantic color changes (the preview disc whose border follows the gender you pick). The arguments are those of `disc_panel()`.
static func style_disc_panel(node: Control, diameter: float, accent: Color, fill_alpha := 0.14,
		edge_alpha := 0.38) -> void:
	if node == null: return
	node.theme = GoUi.theme()
	node.add_theme_stylebox_override(&"panel", disc(diameter, accent, fill_alpha, edge_alpha))


## Applies a disc to **a label you already built** — for when the place is pinned with anchors and offsets, like a
## number badge, and `disc_panel()`'s container cannot be used (the round counterpart of `style_chip_label()`).
## The caller gives the text color through `typography()` —
## 🛑 on a deeply filled disc (`fill_alpha` 0.9 and up) white text is washed out. Use `on_accent`.
static func style_disc_label(node: Label, diameter: float, accent: Color, fill_alpha := 0.14,
		edge_alpha := 0.38) -> void:
	if node == null: return
	node.theme = GoUi.theme()
	node.add_theme_stylebox_override(&"normal", disc(diameter, accent, fill_alpha, edge_alpha))


## 🔑 **A press area laid over a face** — the transparent button laid on a card when the whole card is one tap.
## The face draws no shape of its own (border, shadow and padding 0) and lays the semantic color faintly, by
## [param fill_alpha], on hover and press only —
## 🛑 the card's own face already draws the border, so wrapping another one here makes it double.
##
## Its inner padding is 0, so an inner cell like `card_body()` holds the content, and `fit_content_height()` fits the height to it.
## 🛑 `mouse_filter` is left alone — a button over the HUD must be STOP so the press does not leak into the world.
static func style_overlay_button(node: Button, accent: Color, fill_alpha := 0.10) -> void:
	if node == null: return
	node.theme = GoUi.theme()
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
			# 🛑 Not `BOX_EMPTY` — a `StyleBoxEmpty` has no background color, so hover and press are invisible.
			#    Take `box()`, which is always flat, erase the shape and keep the background alone.
		var face := box(GoTheme.BOX_CARD)
		face.set_border_width_all(0)
		face.shadow_size = 0
		face.set_content_margin_all(0)
		var lit: bool = String(state).contains("hover") or state == &"pressed"
		face.bg_color = Color(accent, fill_alpha if lit else 0.0)
		face.draw_center = lit
		node.add_theme_stylebox_override(state, face)


## A container that **draws no face** — place, stacking and spacing stay; only background, border, shadow and padding go.
## 🔑 Never remove a node just to remove one face — removing it breaks node paths and tests with it. The group stays and only the box disappears.
static func bare_panel(node: Control) -> void:
	node.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())


## 🔔 Applies **a notice face to a container you already built** — the error or warning box that settles into the screen (to build a new one, see `alert()`).
## The face is the skin's `notice` surface and the border takes [param accent]. Pass [param tint] and the background
## is pulled that far from the background color toward that one (0 keeps the skin's background) — 🛑 this is where one semantic color stains a face without inventing a new palette.
## [param padding] negative means the `padding_compact` token.
## [param alpha] is the opacity of the face background (negative: the notice value set by theme and config, `GoTheme.NOTICE_ALPHA`).
static func style_notice_panel(node: Control, accent := Color.TRANSPARENT, tint := 0.0, padding := -1,
		alpha := -1.0) -> void:
	# 🛑 The tint overwrites the background, so take the face solid and apply the opacity **last**.
	var face := surface(GoTheme.BOX_NOTICE, accent, 1.0)
	if tint > 0.0:
		# 🛑 To actually stain the background the face must be one a color can be put into — the skin's custom face
		#    draws in its own color, so move to a flat face with the same padding, border and rounding (with no tint given, the skin's shape is left as it is).
		if not (face is StyleBoxFlat): face = _flat_like(face)
		if &"bg_color" in face:
			var back: Color = GoUi.color(GoTheme.BACKGROUND)
			face.set(&"bg_color", back.lerp(accent, tint))
	var pad := float(GoUi.metric(GoTheme.PADDING_COMPACT) if padding < 0 else padding)
	face.content_margin_left = pad
	face.content_margin_right = pad
	face.content_margin_top = pad
	face.content_margin_bottom = pad
	GoSkin.fade_box(face, alpha if alpha >= 0.0 else GoUi.surface_alpha(GoTheme.BOX_NOTICE))
	node.add_theme_stylebox_override(&"panel", face)


## One face **floating** above the game screen — for things laid over the world like a HUD dock or a status bar (the caller fills the content).
## It is the HUD counterpart of `card()`, and the shape is the skin's floating face as it is (an angular face glows instead of casting a shadow).
##
## [param pad_x] and [param pad_y] are the **face's inner padding** (negative: the padding the skin gave). A HUD
## has its finger geometry fixed per screen, so the caller gives the padding — 🛑 and must **not** wrap another
## `padding()` cell around it. It stacks with the face padding, the content width is cut twice over, and the
## ellipsized text in a narrow cell disappears completely
## (2026-09-16: the lead chip in the party dock folded 27 → 11).
## [param variant] is which token face to float — `BOX_HUD` for a HUD dock, `BOX_CARD` for sheets and cards opened
## over the world (the same card shape with only a shadow added).
## [param alpha] is the opacity of the face background (negative: the theme and config value · `GoTheme.HUD_ALPHA` for HUD faces).
## 🔑 A HUD lies straight on the world, so **raise the value the busier the game's art is** — readable text comes first.
static func hud_panel(accent := Color.TRANSPARENT, pad_x := -1.0, pad_y := -1.0,
		variant := GoTheme.BOX_HUD, alpha := -1.0) -> PanelContainer:
	var node := PanelContainer.new()
	node.name = "HudPanel"
	style_hud_panel(node, accent, pad_x, pad_y, variant, alpha)
	return node


## Applies the same floating face to **a `PanelContainer` you already built** — so places whose semantic color changes
## at runtime (an EXP badge turning green, orange or gray by its value) never rebuild the node. The arguments are those of `hud_panel()`.
static func style_hud_panel(node: PanelContainer, accent := Color.TRANSPARENT, pad_x := -1.0, pad_y := -1.0,
		variant := GoTheme.BOX_HUD, alpha := -1.0) -> void:
	if node == null: return
	node.theme = GoUi.theme()
	var face := GoUi.skin().floating_box(variant, accent, alpha)
	face_padding(face, pad_x, pad_y)
	node.add_theme_stylebox_override(&"panel", face)


## 🔑 **Applies one face to any node you already built** — gohud makes the face, the caller decides where it goes.
## Where `style_hud_panel()` above is the counterpart narrowed to "a floating HUD face", this is the primitive.
##
## Where it is used — ① on a node that is not a `PanelContainer` (`Panel`, `Button`, `Label`) ② when a face that
## does **not** float is needed (a chip laid inside a card looks lifted once it has a shadow) ③ when a different
## face goes on each **state**, like `normal`, `hover`, `pressed` ④ when a face the skin made
## (`surface()`, `GoSkin.alert_box()`) goes on as it is.
##
## [param face] is a face returned by `surface()`, `box()`, `edge_card()` or `GoUi.skin().*_box()`.
## [param state] is the theme item name (`panel` for panels; `normal`, `hover`, `pressed`, `disabled` for buttons).
## 🛑 If the face has padding, do not wrap another `padding()` cell around it (the content width is cut twice over · the same reason as `hud_panel()`).
static func style_panel(node: Control, face: StyleBox, state := &"panel") -> void:
	if node == null or face == null: return
	node.theme = GoUi.theme()
	node.add_theme_stylebox_override(state, face)


## 🪟 **Makes one face already in place translucent** — the way to put the same rule on a container gohud did
## not make (a hand-built `PanelContainer`, a face drawn into a scene, the host project's own face).
##
## ```gdscript
## var frame := PanelContainer.new()
## add_child(frame)                       # 🛑 call it **after** adding to the tree — it reads the theme inherited from the parent
## GoStyle.fade_panel(frame)              # the value set by theme and config
## GoStyle.fade_panel(frame, 0.6)         # 60% for this face only
## GoStyle.fade_panel(frame, 1.0)         # back again (lifts the face override off)
## ```
##
## ## 🔑 Called many times, it thins once
## The first call **records the original face in a meta** and every later one recomputes from that. Otherwise
## every redraw through `_notify()` thins the face by another layer until it disappears — the one trap in
## applying alpha by multiplication (`GoSkin.fade_box`), and this is where that trap is blocked.
##
## [param alpha] negative means the theme and config value (`GoUi.surface_alpha(variant)`), [param state] is the
## theme item name (`panel` for panels; `normal`, `hover` … for buttons), and [param variant] is which kind of value to follow.
##
## 🔬 What this function looks like is shown by the third face in `examples/gallery/opacity_lab.gd` — it hangs
##    this on a bare `PanelContainer` over a pattern, and you drag the slider and see it on the spot.
static func fade_panel(node: Control, alpha := -1.0, state := &"panel",
		variant := GoTheme.BOX_PANEL) -> void:
	if node == null: return
	var key := StringName("go_solid_face_" + String(state))
	var base: StyleBox = node.get_meta(key) if node.has_meta(key) else null
	if base == null:
		# 🛑 Lift the override off first — otherwise an already thinned face is recorded as the "original face".
		node.remove_theme_stylebox_override(state)
		base = node.get_theme_stylebox(state)
		if base == null: return
		node.set_meta(key, base)
	var opacity := alpha if alpha >= 0.0 else GoUi.surface_alpha(variant)
	if opacity >= 1.0:
		node.remove_theme_stylebox_override(state)
		return
	node.add_theme_stylebox_override(state, GoSkin.fade_box(base.duplicate(), opacity))


## **Forgets** the "original face" `fade_panel()` recorded — so that after a theme or look swap the next
## `fade_panel()` picks the face up from the theme in force now. 🛑 Leave this out and a window on the new theme wears **the old theme's face**.
static func forget_face(node: Control, state := &"panel") -> void:
	if node == null: return
	var key := StringName("go_solid_face_" + String(state))
	if node.has_meta(key): node.remove_meta(key)


## 🔑 **A visible face smaller than the press area** — lays one face inside a button and has it follow the button's width.
##
## The cell a finger lands on must keep the touch floor (48), but there are places where **the visible face must
## be smaller** (a HUD's thin band, a status bar). Grow the button and the screen feels cramped; grow the face and
## it is hard to press — so the two are split. The face takes no input (IGNORE), so the press area is the button as it is.
##
## [param height] is the visible face's height (dp); pass [param face] to use that face, otherwise a floating HUD face is used.
## You can dress the returned `Panel` with children (the caller lays them out — it is not a `PanelContainer`).
static func touch_face(button: Button, height := 38.0, face: StyleBox = null) -> Panel:
	if button == null: return null
	var node := Panel.new()
	node.name = "Surface"
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	style_panel(node, face if face != null else floating(GoTheme.BOX_HUD))
	button.add_child(node)
	button.resized.connect(func() -> void: node.size = Vector2(button.size.x, height))
	return node


## 🔑 **One pill face laid over a map or over world art** — it lays a dark background and a thin border so the
## text is readable whatever the art behind it is (`GoSkin.overlay_box`). Where `hud_panel()` is the face of a HUD dock, this is **small chrome over the art**.
##
## [param pad_x] and [param pad_y] are the face's inner padding (dp · negative: the small button padding token), and
## [param fill_alpha] the background's opacity (0.0~1.0 · **negative: the HUD value set by theme and config**, `GoTheme.HUD_ALPHA`). 🛑 Do not wrap another `padding()` cell around it (the same reason as `hud_panel()`).
## 🛑 **Never put a pill inside a pill** — buttons placed inside stay bare buttons or `segmented()` cells.
static func overlay_panel(pad_x := -1, pad_y := -1, fill_alpha := -1.0) -> PanelContainer:
	var node := PanelContainer.new()
	node.name = "OverlayPanel"
	style_overlay_panel(node, pad_x, pad_y, fill_alpha)
	return node


## Applies the same pill face to **a `PanelContainer` you already built**. The arguments are those of `overlay_panel()`.
static func style_overlay_panel(node: PanelContainer, pad_x := -1, pad_y := -1, fill_alpha := -1.0) -> void:
	if node == null: return
	node.theme = GoUi.theme()
	node.add_theme_stylebox_override(&"panel", GoUi.skin().overlay_box(pad_x, pad_y, fill_alpha))


## Sets a face's inner padding to the given values — a negative side keeps the value the face has.
## A custom face from a skin has the same `StyleBox` properties, so the shape (border, glow, corners) is untouched.
static func face_padding(face: StyleBox, pad_x := -1.0, pad_y := -1.0) -> void:
	if face == null: return
	if pad_x >= 0.0:
		face.content_margin_left = pad_x
		face.content_margin_right = pad_x
	if pad_y >= 0.0:
		face.content_margin_top = pad_y
		face.content_margin_bottom = pad_y


## Sets a face's **four sides separately** — a negative side is left alone. Where left and right may be equal use
## `face_padding()`; this is for when one side must differ (a pill whose right end is a 48 touch-cell icon button and therefore needs no face padding).
static func face_insets(face: StyleBox, left := -1.0, top := -1.0, right := -1.0, bottom := -1.0) -> void:
	if face == null: return
	if left >= 0.0: face.content_margin_left = left
	if top >= 0.0: face.content_margin_top = top
	if right >= 0.0: face.content_margin_right = right
	if bottom >= 0.0: face.content_margin_bottom = bottom


## 🔑 **The disc face of a HUD round button** — the face of the round icon buttons floating over the game screen (control pads, utility rows).
##
## 🛑 The corner radius comes from **the visible circle's diameter**. Pin a radius as a number in the theme and
##    the circle turns into a pill on buttons of another size (a radius-24 face went into a 104×64 button and did exactly that).
## 🔑 A transparent [param fill] **draws no center** (`draw_center = false`) — on these buttons a child draws the
##    art (a gradient image, a gem), so painting the face too lays one more layer of color over it. The face handles the border and corners only.
## [param edge_width] 0 means no border (a bare face) · [param edge_ink] the border color ·
## [param detail] the corner curve subdivision. The default 1 **builds no triangle fan per corner** — twenty of
## these buttons lie on the screen at once, so that cost is multiplied straight through. For a large circle to look smooth, pass 8 or 16.
## [param accent] is this button's accent color — the angular and medieval skins use it when they draw the face (round skins do not).
##
## 🔑 **The skin decides the shape** (`GoSkin.disc_box`) — the round skin gives a circle, the angular skin cut
##    corners, the medieval skin its own face. This used to call `box()`, whose return type is `StyleBoxFlat`, so
##    **angular faces were ground down to flat ones** and HUD buttons alone stayed round through every look swap
##    (measured 2026-09-16: all three looks returned the same `StyleBoxFlat`).
## 🔑 **The returned face tells you whether the skin is round** — flat means a circle, anything else means the
##    skin has a face with a shape of its own. A host with art it lays on circles only (a gradient disc) switches it on and off by this value.
static func style_hud_disc(node: Control, diameter: float, edge_width := 0.0,
		edge_ink := Color.TRANSPARENT, fill := Color.TRANSPARENT, detail := 1,
		accent := Color.TRANSPARENT) -> StyleBox:
	if node == null: return null
	# 🛑 A button with no accent (a bare face) still needs **a background you can see** — the angular skin builds
	#    its fill from the accent, so passing transparent makes the whole face vanish and only the glyph floats over the world.
	var ink := accent if accent.a > 0.0 else (edge_ink if edge_ink.a > 0.0 else GoUi.color(GoTheme.SURFACE))
	var shaped := GoUi.skin().disc_box(diameter, ink)
	var face := shaped as StyleBoxFlat
	if face == null:
		# A skin face with a shape of its own (angular, medieval) — leave the shape and the fill alone and lay only what the host gave on top.
		if fill.a > 0.0 and &"bg_color" in shaped: shaped.set(&"bg_color", fill)
		# 🛑 For the border **0 is a value too** — leave it unset and the skin's default border stays, drawing a line
		#    on a bare button whose border was removed on purpose (2026-08-07, the user explicitly ruled out the circle-and-border frame).
		if &"border_width" in shaped: shaped.set(&"border_width", maxf(0.0, edge_width))
		if edge_width > 0.0 and edge_ink.a > 0.0 and &"border_color" in shaped:
			shaped.set(&"border_color", edge_ink)
		node.add_theme_stylebox_override(&"panel", shaped)
		return shaped
	face.set_content_margin_all(0)
	face.bg_color = fill
	face.draw_center = fill.a > 0.0
	face.set_corner_radius_all(maxi(0, roundi(diameter * 0.5)))
	face.corner_detail = maxi(1, detail)
	var width := maxi(0, roundi(edge_width))
	face.set_border_width_all(width)
	if width > 0 and edge_ink.a > 0.0: face.border_color = edge_ink
	# 🛑 Draws no shadow — a `StyleBoxFlat`'s shadow draws **a rectangle separate from** the body.
	face.shadow_size = 0
	node.add_theme_stylebox_override(&"panel", face)
	return face


## 🔑 **Applies the quick-slot face to a node** — a host that built its own slots instead of using `GoSlot`
## (a game whose rows inside the cell differ) gets the same face. The skin's `slot_box` decides the shape, so it follows along on a look swap.
## [param lit] means a cooldown or a remaining time is running (the border thickens and the fill deepens).
static func style_slot_face(node: Control, accent: Color, lit := false) -> void:
	if node == null: return
	node.add_theme_stylebox_override(&"panel", GoUi.skin().slot_box(accent, lit))


## 🔑 **A solid badge** — one cell for **a number that must be noticed**, like a count or an alert. It fills the
## face with [param fill] and writes the text in [param ink]. `GoSkin.badge_box` is the **faint** badge laid on a surface, and plays a different part.
##
## 🛑 The font size is not set here — give it a **role** through `typography(node, GoTheme.ROLE_MICRO, ink)`.
##    Pin the size as an override and that badge alone stops following mobile shrink and theme swaps.
## [param edge] is the border color and [param edge_width] 0 means no border. [param radius] negative means the
## `radius_small` token, and [param pad_x] negative keeps the face's own left and right padding. [param detail] works as in `style_hud_disc`.
static func style_count_badge(node: Label, fill: Color, ink := Color.TRANSPARENT,
		edge := Color.TRANSPARENT, edge_width := 0, radius := -1, pad_x := -1.0, detail := 1) -> void:
	if node == null: return
	node.theme = GoUi.theme()
	var face := box(GoTheme.BOX_HUD)
	face.set_content_margin_all(0)
	face.bg_color = fill
	face.draw_center = true
	face.set_corner_radius_all(GoUi.metric(GoTheme.RADIUS_SMALL) if radius < 0 else radius)
	face.corner_detail = maxi(1, detail)
	var width := maxi(0, edge_width)
	face.set_border_width_all(width)
	if width > 0 and edge.a > 0.0: face.border_color = edge
	face.shadow_size = 0
	if pad_x >= 0.0:
		face.content_margin_left = pad_x
		face.content_margin_right = pad_x
	node.add_theme_stylebox_override(&"normal", face)
	if ink.a > 0.0: node.add_theme_color_override(&"font_color", ink)


## 🔑 Restyles **only the size and color of a node that already holds a glyph** — for moving the color of an icon
## drawn once by `glyph_text()` on every state change (pressed, hovered, toggled on) without looking it up again.
##
## [param size] negative leaves the size alone — a HUD's glyph size is geometry proportional to the touch diameter,
## so the caller decides it (it is not a token).
## 🛑 Unless [param states] is turned off, a button's hover, pressed and focus text colors are matched to **the same color**.
##    Miss one state and the glyph color jumps to the theme default the moment it is pressed while hovered.
static func glyph_type(node: Control, size := -1, ink := Color.TRANSPARENT, states := true) -> void:
	if node == null: return
	if size >= 0: node.add_theme_font_size_override(&"font_size", size)
	if ink.a <= 0.0: return
	node.add_theme_color_override(&"font_color", ink)
	if not states or not (node is Button): return
	for key in [&"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color", &"font_focus_color"]:
		node.add_theme_color_override(key, ink)


## An empty container filling **the same pill face** as a chip — for places a one-line chip cannot serve (a roster
## card carrying a name, a level and a gauge together). [param fill_alpha] works as in `style_chip_button` (negative keeps the skin's tint).
static func chip_panel(accent := Color.TRANSPARENT, fill_alpha := -1.0) -> PanelContainer:
	var color := accent if accent.a > 0 else GoUi.color(GoTheme.SECONDARY)
	var node := PanelContainer.new()
	node.name = "ChipPanel"
	node.theme = GoUi.theme()
	var face := _chip_face(color, false)
	if fill_alpha >= 0.0 and &"bg_color" in face: face.set(&"bg_color", Color(color, fill_alpha))
	node.add_theme_stylebox_override(&"panel", face)
	return node


## 🔑 **A choice card.** Puts a face per state on one button — only the chosen card gets the semantic border
## and a faint fill, and hovering stains the border alone.
## The caller fills the content (icon, title, description) through an inner `MarginContainer`.
##
## 🛑 **Face padding is 0 in every state** — differing face padding per state widens the chosen card alone and the row shifts.
## 🔑 The face comes from the skin's `surface()` — in angular and forged face themes the shape stays and only the color changes. The focus face is not overridden.
##
## [param selected] — draws this card as the chosen one on a card with [param toggle] off (screens that rebuild the list on every pick).
## [param toggle] — on, `toggle_mode`'s pressed state is the selection. The caller ties one set together with a single `ButtonGroup`.
## [param dim_disabled] — on, a disabled card goes faint; off, the resting face is kept (so the color does not jump when it turns disabled).
## [param filter] — negative leaves `mouse_filter` alone. 🛑 A card inside a scroll passes `MOUSE_FILTER_PASS` —
##   with STOP a drag that starts on the card never reaches the scroll. The function does not decide on its own
##   because a button floating over the world, a HUD's, must be STOP (with PASS the press event leaks into the world).
static func style_choice_card(node: Button, accent: Color, selected := false, toggle := true,
		dim_disabled := true, filter := -1) -> void:
	node.theme = GoUi.theme()
	node.clip_text = false
	node.text = ""
	if toggle: node.toggle_mode = true
	if filter >= 0: node.mouse_filter = filter as Control.MouseFilter
	var idle := surface(GoTheme.BOX_CARD)
	var hover := surface(GoTheme.BOX_CARD, accent)
	var chosen := _choice_face(accent)
	var picked := selected and not toggle
	var normal := chosen if picked else idle
	var off := normal
	if dim_disabled:
		off = surface(GoTheme.BOX_CARD)
		if &"bg_color" in off:
			var back: Color = off.get(&"bg_color")
			off.set(&"bg_color", Color(back, back.a * 0.6))
	var faces := {&"normal": normal, &"hover": chosen if picked else hover, &"pressed": chosen,
		&"hover_pressed": chosen, &"disabled": off}
	for state: StringName in faces:
		var face: StyleBox = faces[state]
		face.set_content_margin_all(0)
		node.add_theme_stylebox_override(state, face)


## The chosen card's face — stains the resting face color 16% toward the semantic color and sets the border to that color at 0.9, thickness 2. Assumes nothing about the skin's face type.
static func _choice_face(accent: Color) -> StyleBox:
	var face := surface(GoTheme.BOX_CARD, accent)
	if &"bg_color" in face:
		var back: Color = face.get(&"bg_color")
		face.set(&"bg_color", back.lerp(Color(accent, back.a), 0.16))
	if &"border_color" in face: face.set(&"border_color", Color(accent, 0.9))
	if face is StyleBoxFlat: (face as StyleBoxFlat).set_border_width_all(2)
	elif &"border_width" in face: face.set(&"border_width", 2.0)
	return face


## 🔑 **The content cell inside a card** — one layer of inner padding plus a vertical row, filling a card whose
## face padding is 0 (a button dressed by `style_choice_card`, for one).
## The card's height follows the content, wrapped text included (`fit_content_height`).
## 🛑 Used on a `PanelContainer` whose face has padding (`card()`) the padding doubles — put a `column()` straight into that card.
## 🛑 When the card is a button, call `let_input_through(body)` once the content is filled — the card is what gets pressed.
## [param padding] negative means the `padding_compact` token (dp), [param spacing] negative the `gap_tiny` token (dp).
static func card_body(card: Control, padding := -1, spacing := -1) -> VBoxContainer:
	var inset := MarginContainer.new()
	inset.name = "Inset"
	insets(inset, GoUi.metric(GoTheme.PADDING_COMPACT) if padding < 0 else padding)
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inset)
	var body := column(GoUi.metric(GoTheme.GAP_TINY) if spacing < 0 else spacing)
	body.name = "Body"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset.add_child(body)
	fit_content_height(card, inset)
	return body


## Makes this node and every control under it **take no input** — so text and icons on a card button do not swallow press and hover.
## 🔑 A container defaults to PASS and does hand the event to its parent, but it takes the mouse entry first, and the card's hover face never lights.
static func let_input_through(node: Node) -> void:
	if node is Control: (node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children(): let_input_through(child)


## **A one-line label** — never wraps, and cuts the overflow with an ellipsis (…). For name and number rows on narrow cards.
## 🛑 An ellipsized label's minimum width is nearly 0 — in a narrow cell the text looks as if it vanished entirely. The caller secures the cell width.
static func line(text: String, role := GoTheme.ROLE_BODY, ink := Color.TRANSPARENT) -> Label:
	var node := label(text, role, ink)
	node.autowrap_mode = TextServer.AUTOWRAP_OFF
	node.set_meta(&"go_no_wrap", true)
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	node.clip_text = true
	return node


## A small pill-shaped mark (a state, a tag, a quantity).
## Pass [param icon] and the icon set's art goes before the text — with the text empty it is an **icon-only** chip (HUD buff marks and the like).
## [param icon_size] negative means the `list_glyph` token. [param urgent] puts a warning border on what is about to go (a buff with little time left).
static func chip(text: String, ink := Color.TRANSPARENT, translate := false, icon: StringName = &"",
		icon_size := -1, urgent := false) -> PanelContainer:
	var color := ink if ink.a > 0 else GoUi.color(GoTheme.SECONDARY)
	var node := PanelContainer.new()
	node.name = "Chip"
	node.theme = GoUi.theme()
	node.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override(&"panel", _chip_face(color, urgent))
	# 🛑 The text must read **on the chip face** — the background is a tint of the same color, so used as it is it sinks in.
	var ink_on_chip := GoUi.skin().chip_ink(color)
	var text_node: Label = null
	if not text.is_empty():
		text_node = label_key(text, GoTheme.ROLE_COMPACT, ink_on_chip) if translate \
			else label(text, GoTheme.ROLE_COMPACT, ink_on_chip)
		text_node.autowrap_mode = TextServer.AUTOWRAP_OFF
		text_node.set_meta(&"go_no_wrap", true)
		text_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text_node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if icon.is_empty():
		# 🛑 No text and no icon leaves nothing to add — `add_child(null)` is an engine error, not an empty chip
		#    (met 2026-09-17 with a character name that was still empty).
		if text_node != null: node.add_child(text_node)
		return node
	var glyph := GoUi.icons().node(icon, GoUi.metric(GoTheme.LIST_GLYPH) if icon_size < 0 else icon_size, ink_on_chip)
	if text_node == null:
		# 🔑 An icon-only chip stays **close to square** — the left and right padding shrinks to match the top and bottom (for rows of identical cells, like a HUD buff row).
		var face := node.get_theme_stylebox(&"panel")
		var tight := float(GoUi.metric(GoTheme.GAP_TINY))
		face.content_margin_left = tight
		face.content_margin_right = tight
		node.add_child(glyph)
		return node
	var line_row := row(GoUi.metric(GoTheme.GAP_TINY))
	line_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	line_row.add_child(glyph)
	line_row.add_child(text_node)
	node.add_child(line_row)
	return node


## The chip face — the skin decides the shape, and only the urgent ones swap to a warning border (assumes nothing about the skin's face type).
static func _chip_face(color: Color, urgent: bool) -> StyleBox:
	var face := GoUi.skin().chip_box(color)
	if urgent and &"border_color" in face:
		face.set(&"border_color", Color(GoUi.color(GoTheme.DANGER), 0.9))
	return face


## Restyles **the face only** of a chip you already built — so places that refresh often never rebuild the node
## (a roster whose party leader changed, a mark counting a remaining time down). The caller changes the text and icon colors alongside.
static func restyle_chip(node: PanelContainer, ink: Color, urgent := false) -> void:
	if node == null: return
	node.add_theme_stylebox_override(&"panel", _chip_face(ink if ink.a > 0 else GoUi.color(GoTheme.SECONDARY), urgent))


## Applies a chip face to **a label you already built** — for when `chip()`'s container cannot be used, as where the
## caller measures the width itself to place the cell (a badge on the HUD status bar). The text color is matched to read on the face too.
static func style_chip_label(node: Label, accent: Color, urgent := false) -> void:
	node.theme = GoUi.theme()
	var face := _chip_face(accent, urgent)
	node.add_theme_stylebox_override(&"normal", face)
	node.add_theme_color_override(&"font_color", GoUi.skin().chip_ink(accent))


## 🔑 **A button shaped like a chip** — puts the tinted pill face on every state. For "a chip you can press":
## a HUD's state buttons (follow, leave), notification badges, the small action buttons in a list. The caller puts
## the text and icons in (this applies the face only).
##
## A negative [param fill_alpha] keeps the tint of the skin's chip face. Give a value and it fills that far with the
## semantic color — faint, like 0.08, for a quiet state button; large, like 0.85, for an **emphasis** button (the
## caller gives the text color on a filled face through `typography(node, role, ink)`). [param urgent] is the warning border.
## 🔑 The focus face is not overridden — the shared Theme's focus ring appears only under keyboard and gamepad control.
## 🛑 `mouse_filter` is left alone — a button over the HUD must be STOP so the press event does not leak into the world.
static func style_chip_button(node: Button, accent: Color, fill_alpha := -1.0, urgent := false) -> void:
	node.theme = GoUi.theme()
	var face_ink := accent
	for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		var face := _chip_face(accent, urgent)
		if fill_alpha >= 0.0 and &"bg_color" in face: face.set(&"bg_color", Color(accent, fill_alpha))
		if state == &"normal": face_ink = GoUi.skin().readable_on(accent, GoSkin.blend(GoSkin.box_background(face), GoUi.color(GoTheme.SURFACE)))
		node.add_theme_stylebox_override(state, face)
	# 🛑 The text must read **on the chip face** — this is the classic place where text is laid on a tint of its
	#    own color (the same rule as `chip()`). On a filled face this value goes toward the dark side.
	for key in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color", &"font_focus_color"]:
		node.add_theme_color_override(key, face_ink)


## 🔑 **A round control button** — puts the state faces on the round buttons floating over art, like a map's zoom ＋/－ or "my location".
## The caller puts the text and icons in (`glyph_text()`, `font_role()`); this takes the face alone.
##
## Face padding is 0 in every state and the corner radius is half of [param diameter] — the visible size stays the
## diameter the caller set through `custom_minimum_size`, and the width does not shift as the state changes.
## [param fill] is the resting background color (transparent: the `surface` token) and [param fill_alpha] that
## color's resting opacity (1.0 when hovered and when disabled — it stands out more over art). The pressed state fills with the semantic color by [param press_alpha].
## 🛑 `mouse_filter` is left alone — a button over art must be STOP so the press does not leak into the map or the world.
## 🛑 The face comes from `box()`, not `surface()` — **being round is what this button means**, so keeping the
##    shape of an angular or forged skin would turn the circle into a square (the same judgment as `style_hud_disc()`).
##    Color and padding are carried over from the skin's values as they are.
static func style_disc_button(node: Button, diameter: float, accent: Color, fill := Color.TRANSPARENT,
		fill_alpha := 0.92, press_alpha := 0.34) -> void:
	if node == null: return
	node.theme = GoUi.theme()
	var back := fill if fill.a > 0 else GoUi.color(GoTheme.SURFACE)
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled", &"focus"]:
		var face := box(GoTheme.BOX_HUD, accent)
		var pressed: bool = state == &"pressed" or state == &"hover_pressed"
		var focused: bool = state == &"focus"
		face.bg_color = Color(accent, press_alpha) if pressed \
			else Color(back, fill_alpha if state == &"normal" else 1.0)
		face.border_color = Color(accent, 0.7 if focused else 0.42)
		face.set_border_width_all(2 if focused else 1)
		face.set_corner_radius_all(maxi(1, int(diameter * 0.5)))
		face.set_content_margin_all(0)
		node.add_theme_stylebox_override(state, face)


## What is shown when there is nothing — an icon + one line of explanation.
## 🛑 Never leave an empty list **empty**. Users read that as broken.
static func empty_state(icon: StringName, key: String, translate := true) -> Control:
	var wrap := column(GoUi.metric(GoTheme.GAP))
	wrap.name = "EmptyState"
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var glyph := GoUi.icons().node(icon, GoUi.metric(GoTheme.TOUCH), GoUi.color(GoTheme.MUTED))
	glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wrap.add_child(glyph)
	var text := label_key(key, GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED)) if translate \
		else label(key, GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED))
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrap.add_child(text)
	return wrap


# ── Motion ─────────────────────────────────────────────────────────────

## An entrance fade. Kills the previous tween. With `reduce_motion` it shows at once.
static func fade(node: CanvasItem, previous: Tween, shown: bool) -> Tween:
	if previous != null and previous.is_valid(): previous.kill()
	var seconds := GoUi.config.fade_seconds
	if not shown or not node.is_inside_tree() or GoUi.config.reduce_motion or seconds <= 0.0:
		node.modulate.a = 1.0
		return null
	node.modulate.a = 0.0
	var tween := node.create_tween()
	tween.tween_property(node, "modulate:a", 1.0, seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	return tween


## Grows a control that **does not inherit a minimum height from its children**, like `Button`, to fit its content.
## The content stays inside the card through wrapping, translation and font changes.
static func fit_content_height(control: Control, content: Control) -> void:
	var baseline := control.custom_minimum_size.y
	var update := _fit_height.bind(weakref(control), weakref(content), baseline)
	content.minimum_size_changed.connect(update, CONNECT_DEFERRED)
	update.call_deferred()


static func _fit_height(control_ref: WeakRef, content_ref: WeakRef, baseline: float) -> void:
	var control := control_ref.get_ref() as Control
	var content := content_ref.get_ref() as Control
	if control == null or content == null: return
	var height := maxf(baseline, content.get_combined_minimum_size().y)
	if not is_equal_approx(control.custom_minimum_size.y, height):
		control.custom_minimum_size.y = height


## 🔑 **One tooltip to the gohud spec.** Return it from `Control._make_custom_tooltip()`.
##
## 🛑 Leave the engine's default tooltip alone and the text splits **one character per line, vertically** — the
##    label has wrapping on while the maximum width computes as 1dp (measured 2026-09-13: `settings` came out
##    1 wide and 186 tall). Setting the width ourselves takes that computation out of the loop.
static func tooltip_node(text: String, max_width := 260.0) -> Control:
	# 🛑 **Draws no face of its own.** The engine puts this node inside its own `TooltipPanel`, so making one more
	#    face here shows **two** borders (measured 2026-09-13). Return the text alone.
	var label := Label.new()
	label.name = "Text"
	label.text = text
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # what arrives is already translated
	# 🛑 Leave `go_no_wrap` on it — a form forces wrapping onto descendant labels, and a tooltip is not one of them.
	label.set_meta(&"go_no_wrap", true)
	typography(label, GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.TEXT))
	# A short phrase stays on one line. Only a long one folds, and **we give the width it folds at.**
	var wide := label.get_theme_font(&"font").get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, label.get_theme_font_size(&"font_size")).x
	if wide > max_width:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = max_width
	else:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label


## Applies the form spec to a whole tree — so children added later get the same spec.
##
## 🛑🛑 It **guarantees** wrapping on descendant `Label`s. Without it one long sentence runs on a single line
##    and its minimum width runs off the screen, cutting both sides — you cannot even tell which screen you are on.
##    Turning it on by hand per scene **is always forgotten somewhere.** So the container guarantees it itself.
static func form(node: Node) -> void:
	# 🛑 A group that keeps its own spacing (`field()` — its label must stay attached to its field) is left alone.
	if node is BoxContainer and not node.has_meta(&"go_own_spacing"):
		node.add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP))
	if node is Button:
		node.custom_minimum_size.y = maxf(node.custom_minimum_size.y, GoUi.metric(GoTheme.BUTTON_HEIGHT))
		# 🛑 Anything shown at natural width (a cell in a flow row, a single word like "Back") is left alone.
		if GoUi.config.autowrap_text: fit_words(node)
		if node.get_class() == "Button" and node.theme_type_variation == &"":
			style_button(node)
	if node is Label:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if GoUi.config.autowrap_text and not node.has_meta(&"go_no_wrap") and node.autowrap_mode == TextServer.AUTOWRAP_OFF:
			node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if node is LineEdit:
		node.custom_minimum_size.y = GoUi.metric(GoTheme.BUTTON_HEIGHT)
	for child in node.get_children(): form(child)


# ── Selection and menus ────────────────────────────────────────────────

## 🔑 **A dropdown select.** Takes an array of options and builds an `OptionButton`. `placeholder` is the text
## shown while nothing is chosen (it goes once something is). The caller decides the width.
static func select(options: Array, placeholder := "", translate := false) -> OptionButton:
	var node := picker()
	node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS if translate else Node.AUTO_TRANSLATE_MODE_DISABLED
	for option in options: node.add_item(str(option))
	if not placeholder.is_empty():
		# 🛑 `select(-1)` clears the text, so write the placeholder **after** it. Once something is chosen the engine swaps in the item's text.
		node.select(-1)
		node.text = placeholder
	return node


## 🔑 **A dropdown menu.** Press the button and the item list opens downward. An item is a string or a
## `{"text": …, "icon": StringName, "disabled": bool}` dictionary. Choosing one calls `action.call(index)`.
static func dropdown(text: String, items: Array, action := Callable(), translate := false) -> MenuButton:
	var node := MenuButton.new()
	node.theme = GoUi.theme()
	node.theme_type_variation = GoTheme.VAR_BUTTON
	node.text = text
	node.flat = false
	node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS if translate else Node.AUTO_TRANSLATE_MODE_DISABLED
	node.custom_minimum_size.y = GoUi.metric(GoTheme.BUTTON_HEIGHT)
	node.mouse_filter = Control.MOUSE_FILTER_PASS
	# 🛑 **It stands next to `select()` (OptionButton)** — in the demo the two are stacked one above the other, and
	#    their text alignment and arrow size differed enough that they read as different parts (measured 2026-09-13
	#    on a demo capture). The text goes left, and the arrow is matched to the size of the art OptionButton uses.
	node.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var arrow := GoUi.theme().get_icon(&"arrow", &"OptionButton") if GoUi.theme() != null and GoUi.theme().has_icon(&"arrow", &"OptionButton") else null
	apply_icon(node, GoIconSet.CHEVRON_DOWN, arrow.get_width() if arrow != null else GoUi.metric(GoTheme.LIST_GLYPH))
	node.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var popup := node.get_popup()
	popup.theme = GoUi.theme()
	for item in items:
		if item is Dictionary:
			var found := GoUi.icons().texture(item.get("icon", &""))
			if found != null: popup.add_icon_item(found, str(item.get("text", "")))
			else: popup.add_item(str(item.get("text", "")))
			if item.get("disabled", false): popup.set_item_disabled(popup.item_count - 1, true)
		else:
			popup.add_item(str(item))
	if action.is_valid(): popup.index_pressed.connect(action)
	return node


## Spreads the rows of a popup menu so its items keep the **touch floor** — popup text is body size, which makes the rows thinner than a finger.
## [param spacing] negative means the `gap` token. 🔑 Clear the items and refill and this value survives (it is a theme value, not an item).
## [param alpha] is the opacity of the menu face background (0.0~1.0) — negative: `GoTheme.POPUP_ALPHA` (**100** in the default theme).
##
## 🛑 **A popup menu is solid by default.** Unlike other faces a `PopupMenu` may be raised by the engine as a
##    `Window`, and then the OS does not composite it with the game screen, so translucency comes out **black
##    instead of showing what is behind** (projects with `gui_embed_subwindows` off). A project that raises them embedded in the game may lower the value.
static func style_popup(popup: PopupMenu, spacing := -1, alpha := -1.0) -> void:
	if popup == null: return
	popup.theme = GoUi.theme()
	popup.add_theme_constant_override(&"v_separation", GoUi.metric(GoTheme.GAP) if spacing < 0 else spacing)
	var opacity := alpha if alpha >= 0.0 else GoUi.surface_alpha(GoTheme.BOX_POPUP)
	if opacity < 1.0:
		popup.add_theme_stylebox_override(&"panel",
			GoSkin.fade_box(GoUi.box(GoTheme.BOX_POPUP), opacity))


## 🔑 **A radio group.** Only one is chosen. `meta("group")` on the returned vertical row is the `ButtonGroup`,
## and the chosen item is read as `group.get_pressed_button().get_index()`. Every item keeps the touch floor.
static func radio_group(options: Array, selected := 0, translate := false) -> VBoxContainer:
	var column := column(GoUi.metric(GoTheme.GAP_TINY))
	var group := ButtonGroup.new()
	column.set_meta(&"group", group)
	for index in options.size():
		var item := CheckBox.new()
		item.theme = GoUi.theme()
		item.text = str(options[index])
		item.button_group = group   # given a group, a CheckBox draws as a radio
		item.button_pressed = index == selected
		item.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS if translate else Node.AUTO_TRANSLATE_MODE_DISABLED
		item.custom_minimum_size.y = GoUi.metric(GoTheme.TOUCH)
		item.mouse_filter = Control.MOUSE_FILTER_PASS
		column.add_child(item)
	return column


## 🔑 **A segmented / toggle group.** Of the buttons standing side by side, only one stays pressed.
## Choosing one calls `action.call(index)`. `meta("group")` is the `ButtonGroup`.
## Turn `compact` on for **small cells for narrow chrome** — the cell's minimum width is the touch floor and the cell face's padding is the small button padding token.
## 🔑 Use it where width is tight, like a pill over a map or a HUD. The default cell (minimum width touch ×1.5 · card padding) is for forms and settings screens.
static func segmented(options: Array, selected := 0, action := Callable(), translate := false,
		compact := false) -> HBoxContainer:
	var line := row(0)
	line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var group := ButtonGroup.new()
	line.set_meta(&"group", group)
	var count := options.size()
	for index in count:
		var item := Button.new()
		# 🔑 An option is a label, or `{"text", "icon", "tooltip"}` — an icon beside the label (inventory kinds, map
		#    layers), or alone with a tooltip that then doubles as its accessible name.
		var option: Variant = options[index]
		var spec: Dictionary = option if option is Dictionary else {"text": str(option)}
		item.text = str(spec.get("text", ""))
		item.tooltip_text = str(spec.get("tooltip", ""))
		item.toggle_mode = true
		item.button_group = group
		item.button_pressed = index == selected
		item.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS if translate else Node.AUTO_TRANSLATE_MODE_DISABLED
		style_button(item, Tone.COMPACT)
		# 🛑 Natural width — leave wrapping on and the minimum width goes to 0 and the text splits vertically (2026-09-12 demo: only a blue bar was visible).
		natural_width(item)
		item.custom_minimum_size.x = GoUi.metric(GoTheme.TOUCH) * (1.0 if compact else 1.5)
		# Round at the two ends and square in the middle — it reads as one block. The skin decides the actual shape.
		# 🛑 A small cell gets **the same padding in every state** — differing padding per state makes the cell width shift on every press.
		# 🔑 Small cells sit **inside** an outer pill (`GoSkin.overlay_box`) — an unchosen cell draws no face, so no
		#    border reads as double, and only the chosen cell is filled with the accent color.
		for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus"]:
			var face := GoUi.skin().segment_box(index, count, state)
			if compact: face = _compact_segment(face, state)
			item.add_theme_stylebox_override(state, face)
		item.add_theme_color_override(&"font_pressed_color", GoUi.color(GoTheme.ON_ACCENT))
		item.add_theme_color_override(&"font_hover_pressed_color", GoUi.color(GoTheme.ON_ACCENT))
		var mark := StringName(str(spec.get("icon", "")))
		if not mark.is_empty():
			apply_icon(item, mark, GoUi.metric(GoTheme.LIST_GLYPH))
			# 🛑 The icon follows the label's color in every state — left alone it stays light on the chosen
			#    (accent-filled) cell while the label turns dark, and the cell reads as two things.
			for state in [&"icon_pressed_color", &"icon_hover_pressed_color"]:
				item.add_theme_color_override(state, GoUi.color(GoTheme.ON_ACCENT))
			# 🛑 Read from the **theme resource**, not `item.get_theme_color()` — the button is not in the tree yet,
			#    and there a lookup falls through to the engine's default gray instead of the variation's color.
			var look := GoUi.theme()
			var kind := item.theme_type_variation
			for pair in [[&"icon_normal_color", &"font_color"], [&"icon_hover_color", &"font_hover_color"],
					[&"icon_focus_color", &"font_focus_color"]]:
				var tone: Color = look.get_color(pair[1], kind) if look != null and look.has_color(pair[1], kind) \
					else GoUi.color(GoTheme.TEXT)
				item.add_theme_color_override(pair[0], tone)
		if action.is_valid(): item.pressed.connect(action.bind(index))
		line.add_child(item)
	return line


## The small cell face — padding from the small button token, no face on an unchosen cell, a faint ring on focus, and the rest rounded per cell with no border.
## 🔑 The rule holds even when the skin gives a custom face (angular, medieval) — an unchosen cell gets an empty face, and a chosen or hovered cell keeps the skin face with only the padding matched.
static func _compact_segment(face: StyleBox, state: StringName) -> StyleBox:
	var result := face
	if state == &"focus":
		result = GoUi.box(GoTheme.BOX_FOCUS_SOFT)
	elif state == &"normal":
		result = GoUi.box(GoTheme.BOX_EMPTY)
	else:
		var flat := face as StyleBoxFlat
		if flat != null:
			flat.set_border_width_all(0)
			flat.set_corner_radius_all(GoUi.metric(GoTheme.RADIUS_SMALL))
			flat.shadow_size = 0
	_compact_insets(result)
	return result


## Sets a face's inner padding from the small button padding tokens (left/right · top/bottom). A custom face from a skin has the same properties.
static func _compact_insets(face: StyleBox) -> void:
	if face == null: return
	var x := float(GoUi.metric(GoTheme.COMPACT_PADDING_X))
	var y := float(GoUi.metric(GoTheme.COMPACT_PADDING_Y))
	face.content_margin_left = x
	face.content_margin_right = x
	face.content_margin_top = y
	face.content_margin_bottom = y


## 🔑 **A choice grid.** Lays out color swatch, icon and text cards, and only the cell pressed stays selected.
## For places where **you choose by picture**: character customization (skin tone, hair color, clothes), picking an avatar or a difficulty.
##
## An item is a dictionary (a string makes a text card).
##   `color`   the swatch circle — drawn in that exact color (a `Color`, or a string like `"f6cfae"`)
##   `icon`    a `GoIconSet` icon name · `texture` a picture (`Texture2D`)
##   `text`    the caption below. Empty shows the swatch or picture alone
##   `tooltip` the tooltip = the accessibility name. 🛑 **Always give one** on a swatch with no text — color alone says nothing
## Choosing one calls `action.call(index)`. `meta("group")` on the returned flow row is the `ButtonGroup`.
## 🔑 The chosen cell is marked with a **thick accent border** instead of a painted face — the swatch's color
##    stays unmixed, and someone who has trouble telling colors apart still reads the choice from the border thickness.
##
## ```gdscript
## var skins := GoStyle.choice_grid([{"color": "f6cfae", "tooltip": "Peach"}, {"color": "8d5a36", "tooltip": "Cocoa"}],
## 	0, func(i: int) -> void: look.skin = i)
## ```
static func choice_grid(items: Array, selected := 0, action := Callable(), translate := false) -> HFlowContainer:
	var line := wrap_row()
	line.name = "ChoiceGrid"
	var group := ButtonGroup.new()
	line.set_meta(&"group", group)
	for index in items.size():
		var item: Dictionary = items[index] if items[index] is Dictionary else {"text": str(items[index])}
		var cell := _choice_cell(item, translate)
		cell.button_group = group
		cell.button_pressed = index == selected
		if action.is_valid(): cell.pressed.connect(action.bind(index))
		line.add_child(cell)
	return line


## One cell of a choice grid — stacks swatch, picture and caption vertically on the skin face (`choice_box`).
static func _choice_cell(item: Dictionary, translate: bool) -> Button:
	var cell := Button.new()
	cell.name = "Choice"
	cell.theme = GoUi.theme()
	# 🛑 Keep a variation name — left empty, `GoForm` repaints it as an ordinary button and stretches it wide, breaking the grid (`form()`).
	cell.theme_type_variation = GoTheme.VAR_BUTTON
	cell.toggle_mode = true
	cell.focus_mode = Control.FOCUS_ALL
	# 🛑 It sits inside a scroll, so the finger drag is handed to the scroll (the same reason as `style_button`).
	cell.mouse_filter = Control.MOUSE_FILTER_PASS
	cell.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS if translate else Node.AUTO_TRANSLATE_MODE_DISABLED
	cell.tooltip_text = str(item.get("tooltip", item.get("text", "")))
	for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
		cell.add_theme_stylebox_override(state, GoUi.skin().choice_box(state))
	var touch := float(GoUi.metric(GoTheme.TOUCH))
	var inset := float(GoUi.metric(GoTheme.GAP_SMALL))
	var content := column(GoUi.metric(GoTheme.GAP_TINY))
	content.name = "Content"
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = inset
	content.offset_top = inset
	content.offset_right = -inset
	content.offset_bottom = -inset
	cell.add_child(content)
	if item.has("color"):
		var diameter := maxf(touch - inset * 2.0, float(GoUi.metric(GoTheme.ICON_SIZE)))
		var swatch := Panel.new()
		swatch.name = "Swatch"
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		swatch.custom_minimum_size = Vector2(diameter, diameter)
		swatch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var ink: Variant = item["color"]
		swatch.add_theme_stylebox_override(&"panel", GoUi.skin().swatch_box(diameter, ink if ink is Color else Color(str(ink))))
		content.add_child(swatch)
	elif item.get("texture") is Texture2D:
		var picture := TextureRect.new()
		picture.name = "Picture"
		picture.texture = item["texture"]
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size = Vector2.ONE * (touch - inset * 2.0)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(picture)
	elif item.has("icon"):
		var glyph := GoUi.icons().node(StringName(str(item["icon"])), GoUi.metric(GoTheme.ICON_SIZE), GoUi.color(GoTheme.TEXT))
		glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		content.add_child(glyph)
	var text := str(item.get("text", ""))
	if text != "":
		var caption := label_key(text, GoTheme.ROLE_COMPACT) if translate else label(text, GoTheme.ROLE_COMPACT)
		caption.name = "Caption"
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.autowrap_mode = TextServer.AUTOWRAP_OFF
		caption.set_meta(&"go_no_wrap", true)
		content.add_child(caption)
	# Cell size = content + inner padding, at least the touch size both ways. Remeasured when translation or font changes.
	var fit := func() -> void:
		if not is_instance_valid(cell) or not is_instance_valid(content): return
		var need := content.get_combined_minimum_size() + Vector2(inset, inset) * 2.0
		cell.custom_minimum_size = Vector2(maxf(touch, need.x), maxf(touch, need.y))
	content.minimum_size_changed.connect(fit, CONNECT_DEFERRED)
	fit.call()
	return cell


## 🔑 **A tab bar.** Builds a `TabBar` from an array of names. The caller switches the content on `tab_changed`
## (to tie the content in too, give this theme to the engine's `TabContainer`).
static func tabs(names: Array, selected := 0, translate := false) -> TabBar:
	var bar := TabBar.new()
	bar.theme = GoUi.theme()
	bar.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS if translate else Node.AUTO_TRANSLATE_MODE_DISABLED
	for name in names: bar.add_tab(str(name))
	bar.current_tab = clampi(selected, 0, maxi(0, names.size() - 1))
	bar.tab_alignment = TabBar.ALIGNMENT_LEFT
	bar.custom_minimum_size.y = GoUi.metric(GoTheme.TOUCH)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return bar


## 🔑 **A breadcrumb.** Joins the path items with `›`. The last one is where you are, so it cannot be pressed.
## Pressing an earlier one calls `action.call(index)`.
static func breadcrumb(items: Array, action := Callable(), translate := false) -> HBoxContainer:
	var line := row(GoUi.metric(GoTheme.GAP_TINY))
	line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var last := items.size() - 1
	for index in items.size():
		if index > 0:
			line.add_child(GoUi.icons().node(GoIconSet.CHEVRON_RIGHT, GoUi.metric(GoTheme.LIST_GLYPH), GoUi.color(GoTheme.MUTED)))
		if index == last:
			var here := label(str(items[index]), GoTheme.ROLE_BODY) if not translate else label_key(str(items[index]))
			here.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			line.add_child(here)
		else:
			var link := button(str(items[index]), action.bind(index) if action.is_valid() else Callable(), Tone.BARE) \
				if not translate else button_key(str(items[index]), action.bind(index) if action.is_valid() else Callable(), Tone.BARE)
			link.add_theme_color_override(&"font_color", GoUi.color(GoTheme.SECONDARY))
			line.add_child(link)
	natural_width(line)   # 🛑 Natural width per item — otherwise "Weapons" splits vertically into W·e·a·p·o·n·s (2026-09-12 demo)
	return line


# ── Text input ─────────────────────────────────────────────────────────

## 🔑 **A multi-line input (textarea).** It shows `lines` lines' worth of height and scrolls inside when it overflows.
static func textarea(placeholder := "", lines := 4, translate_placeholder := false) -> TextEdit:
	var node := TextEdit.new()
	node.theme = GoUi.theme()
	node.placeholder_text = placeholder
	if translate_placeholder: node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
	node.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	node.scroll_fit_content_height = false
	node.custom_minimum_size.y = GoUi.font_size(GoTheme.ROLE_BODY) * 1.5 * lines + GoUi.metric(GoTheme.PADDING)
	return node


# ── Display ────────────────────────────────────────────────────────────

## How a picture fits its cell. `CONTAIN` fits all of it in, `COVER` fills the cell and crops the overflow, and
## `FILL` drops the aspect ratio and stretches to the cell.
enum Fit { CONTAIN, COVER, FILL }

## 🔑 **A picture cell.** This is what keeps screen code from standing a `TextureRect` up by hand —
##    **how it looks** (stretch, alignment, mouse pass-through) is decided here, and the caller gives only
##    **what to show** (the picture itself) (art belongs to that game, so an addon cannot hold it).
##
## ```gdscript
## var logo := GoStyle.art(texture, Vector2(96, 96))                 # show all of it
## var face := GoStyle.art(portrait, cell, GoStyle.Fit.COVER)        # fill the cell and crop the overflow
## ```
static func art(texture: Texture2D = null, size := Vector2.ZERO, fit := Fit.CONTAIN) -> TextureRect:
	var node := TextureRect.new()
	node.name = "Art"
	if size.x > 0 or size.y > 0: node.custom_minimum_size = size
	node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	style_art(node, texture, fit)
	return node


## **Swaps the picture only** on a picture cell already standing (a portrait that changes every time the gender does).
##
## 🛑 **The caller decides** what happens when `texture` is `null` — the default (`keep_when_null`) is to leave
##    it alone, so the place of a picture still loading is not emptied. But where **missing must look missing**
##    (a portrait in a build without the asset pack — leave it and **the last one picked stays and becomes a lie**),
##    call it with `keep_when_null = false` to empty it.
static func style_art(node: TextureRect, texture: Texture2D = null, fit := Fit.CONTAIN,
		keep_when_null := true) -> void:
	if node == null: return
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	match fit:
		Fit.COVER: node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		Fit.FILL: node.stretch_mode = TextureRect.STRETCH_SCALE
		_: node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if texture != null or not keep_when_null: node.texture = texture


## 🔑 **A scrim.** One layer that veils what is behind so the eye goes to the card or sheet in front.
##    Without `alpha` it uses the scrim color the skin set as it is; with one it lays the background color at that depth.
static func scrim(alpha := -1.0, ink := Color.TRANSPARENT) -> ColorRect:
	var node := ColorRect.new()
	node.name = "Scrim"
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	style_scrim(node, alpha, ink)
	return node


## Resets the depth of a scrim already in place (a login background that veils only once the art has loaded).
static func style_scrim(node: ColorRect, alpha := -1.0, ink := Color.TRANSPARENT) -> void:
	if node == null: return
	if alpha < 0.0 and ink.a <= 0.0:
		node.color = GoUi.color(GoTheme.SCRIM)
		return
	var base := ink if ink.a > 0 else GoUi.color(GoTheme.BACKGROUND)
	node.color = Color(base, alpha if alpha >= 0.0 else base.a)


## 🔑 **A color mark.** A small piece that fills one cell with color alone — for places where **the color itself
##    is the meaning, neither text nor picture**: a legend's short line, the dot saying you are online, the vertical band down a banner's left.
##    🛑 Not the same as a `plate` — a mark paints that one color with no corners and no border.
static func mark(size: Vector2, ink: Color) -> ColorRect:
	var node := ColorRect.new()
	node.name = "Mark"
	node.color = ink
	node.custom_minimum_size = size
	node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## 🔑 **An avatar.** With a picture, the picture cropped to a circle; without one, initials (2 characters at most) on an accent circle.
static func avatar(text := "", size := 40, accent := Color.TRANSPARENT, texture: Texture2D = null) -> Control:
	var ink := accent if accent.a > 0 else GoUi.color(GoTheme.ACCENT)
	var node := PanelContainer.new()
	node.name = "Avatar"
	node.custom_minimum_size = Vector2(size, size)
	node.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override(&"panel", GoUi.skin().disc_box(size, ink, 0.22, 0.6))
	if texture != null:
		var picture := TextureRect.new()
		picture.texture = texture
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(picture)
		return node
	var initials := ""
	for word in text.split(" ", false):
		initials += word.substr(0, 1).to_upper()
		if initials.length() >= 2: break
	var mark := label(initials, GoTheme.ROLE_BUTTON, ink)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.autowrap_mode = TextServer.AUTOWRAP_OFF
	mark.add_theme_font_size_override(&"font_size", maxi(8, roundi(size * 0.4)))
	node.add_child(mark)
	return node


## 🔑 **A skeleton.** A faint face holding the place of content that has not arrived. Once in the tree it breathes
## gently (`reduce_motion` leaves it still). Width 0 fills horizontally.
static func skeleton(width := 0.0, height := 14.0) -> Control:
	var node := Panel.new()
	node.name = "Skeleton"
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.custom_minimum_size = Vector2(width, height)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL if width <= 0.0 else Control.SIZE_SHRINK_BEGIN
	node.add_theme_stylebox_override(&"panel", GoUi.skin().skeleton_box())
	node.tree_entered.connect(func() -> void:
		if GoUi.config.reduce_motion: return
		var pulse := node.create_tween().set_loops()
		pulse.tween_property(node, "modulate:a", 0.45, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(node, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT))
	return node


## 🔑 **An alert box.** A notice fixed into the screen — unlike a snackbar (`GoNotice`) it does not go away.
## `tone` is a color token (`GoTheme.INFO`, `SUCCESS`, `WARNING`, `DANGER`). Leave the icon empty for the default icon of that tone.
static func alert(message: String, tone := GoTheme.INFO, icon: StringName = &"", translate := false,
		alpha := -1.0) -> PanelContainer:
	var ink := GoUi.color(tone)
	var node := PanelContainer.new()
	node.name = "Alert"
	node.theme = GoUi.theme()
	node.add_theme_stylebox_override(&"panel", GoUi.skin().alert_box(ink, alpha))
	var line := row(GoUi.metric(GoTheme.GAP_SMALL))
	line.alignment = BoxContainer.ALIGNMENT_BEGIN
	node.add_child(line)
	var default_icons := {GoTheme.INFO: GoIconSet.INFO, GoTheme.SUCCESS: GoIconSet.SUCCESS,
		GoTheme.WARNING: GoIconSet.WARNING, GoTheme.DANGER: GoIconSet.ERROR}
	var glyph := GoUi.icons().node(icon if not icon.is_empty() else default_icons.get(tone, GoIconSet.INFO),
		GoUi.metric(GoTheme.ICON_SIZE), ink)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	line.add_child(glyph)
	var text := label_key(message) if translate else label(message)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(text)
	return node


## 🔑 **A table.** One header row + the rows. A cell is a string or a `Control`. The header is dim and uppercase-feeling, and the rows are divided by thin lines.
static func table(headers: Array, rows: Array) -> GridContainer:
	var grid := GridContainer.new()
	grid.name = "Table"
	grid.theme = GoUi.theme()
	grid.columns = maxi(1, headers.size())
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override(&"h_separation", GoUi.metric(GoTheme.GAP))
	grid.add_theme_constant_override(&"v_separation", GoUi.metric(GoTheme.GAP_SMALL))
	for header in headers:
		var head := label(str(header), GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED))
		head.uppercase = true
		grid.add_child(head)
	for cells in rows:
		for cell in cells:
			if cell is Control: grid.add_child(cell)
			else:
				var text := label(str(cell))
				grid.add_child(text)
	return grid
