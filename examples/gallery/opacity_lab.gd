## 🔬 **The container-opacity lab** — drag the slider and the panels thin out **on the spot**.
##
## ## Why this exists
## `bg_color.a == 0.8` is a number. "Does the back really show through?" and "is the text on top still
## readable?" are answered only **by drawing** — and container opacity is nothing but those two
## questions. So we lay a loud pattern behind the panels and watch both at once while a hand moves the
## value. One drag of the slider is faster than ten lines of documentation.
##
## ## Four routes, side by side
## There are four routes to a translucent panel, and this one screen has all four.
##
## | Panel | Route | Where it is used |
## |---|---|---|
## | ① Card | `GoStyle.card(…, alpha)` | Given as an argument at build time — **one panel** differs |
## | ② HUD dock | `GoStyle.style_hud_panel(node, …, alpha)` | Restyles the panel on **a node already built** |
## | ③ Bare `PanelContainer` | `GoStyle.fade_panel(node, alpha)` | Lays over a panel gohud did **not** build |
## | ④ All of them | `GoUi.config.container_alpha` | The whole project — the button below plants this |
##
## ## How to use it
## ```gdscript
## var lab := preload("res://addons/gohud/examples/gallery/opacity_lab.gd").new()
## page.add_child(lab)
## # To use ④ the host has to rebuild the screen — widgets already born do not change their clothes.
## lab.applied.connect(func(_alpha: float) -> void: rebuild())
## # Optional: a request to lay a pattern behind it — leave it unconnected and that toggle never appears.
## lab.backdrop_wanted.connect(func(on: bool) -> void: my_background.visible = not on)
## ```
##
## 🛑 It adds no global class to the add-on (no `class_name`) — it is used through `preload` only, so the
##    example's names never leak into the host project.
extends VBoxContainer

## ④ "Apply to every panel" was pressed — the host has to rebuild the screen.
signal applied(alpha: float)
## Please lay a pattern behind it / take it away. 🔑 The toggle shows **only in a host that connected this**.
signal backdrop_wanted(on: bool)

## 🔑 **Whether to show the button that applies project-wide.** Turn it off where only one scene is on
## show, as in the sim tour — a project setting is global, so it outlives the scene and thins the panels
## of the next one too.
## 🛑 Decide it **before** `add_child()` (it is read in `_ready`).
var allow_project_wide := true

## The floor the slider can go down to. 🛑 Do not open it as far as 0 — with the panel gone entirely
## nobody can tell what they are touching, and someone who mistakes that state for a "setting" walks on
## to the next screen having lost their panels.
const FLOOR := 0.15

var _slider: HSlider
var _readout: Label
var _card: PanelContainer            ## ① the factory argument
var _hud: PanelContainer             ## ② restyling a node already built
var _plain: PanelContainer           ## ③ a panel gohud did not build
var _backdrop: Control


func _init() -> void:
	name = "OpacityLab"
	add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP_SMALL))


func _ready() -> void:
	add_child(GoStyle.section("Container opacity", false))
	add_child(GoStyle.label(
		"Panels can let the game show through. Only the panel fill thins out — text, icons, borders "
		+ "and buttons stay at full strength, so the screen keeps reading as a screen.",
		GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED)))

	add_child(_dial())
	add_child(_preview())
	add_child(_actions())
	add_child(GoStyle.label(
		"Defaults live in the theme (panel_alpha, card_alpha, hud_alpha, notice_alpha, popup_alpha), "
		+ "a project overrides them in GoConfig, and a single widget can always set its own alpha.",
		GoTheme.ROLE_COMPACT, GoUi.color(GoTheme.MUTED)))
	# 🛑 Styling happens **after it is in the tree** — ③ reads its panel from the theme inherited from the parent.
	_apply(_slider.value)


# ── The dial ───────────────────────────────────────────────────────────

func _dial() -> Control:
	var row := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
	var caption := GoStyle.label("Panel fill", GoTheme.ROLE_COMPACT)
	GoStyle.natural_width(caption)
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(caption)

	_slider = GoStyle.slider(FLOOR, 1.0, 0.01)
	_slider.value = GoUi.surface_alpha(GoTheme.BOX_CARD)
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slider.accessibility_name = "Panel opacity"
	_slider.value_changed.connect(_apply)
	row.add_child(_slider)

	_readout = GoStyle.label("", GoTheme.ROLE_COMPACT)
	# 🛑 If the width wobbles with the value, the slider beside it moves too — and a hand slips mid-drag.
	_readout.custom_minimum_size.x = 48.0
	_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_readout.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_readout)
	return row


# ── The preview ────────────────────────────────────────────────────────

## Three panels laid over the pattern. 🔑 **A flat background will not do** — you cannot tell a panel that
## turned "a slightly different color" from one you can see through.
func _preview() -> Control:
	var frame := Control.new()
	frame.name = "Preview"
	frame.clip_contents = true
	# 🛑 A `Control` does not know its children's size — nail a fixed height on it and a bare band of
	#    pattern is left below the panels (200px was left like that on the first capture). Follow the
	#    content's minimum height instead.
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	_backdrop = Backdrop.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_child(_backdrop)

	var inset := GoStyle.padding(GoUi.metric(GoTheme.PADDING_COMPACT))
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_child(inset)
	var row := GoStyle.wrap_row(GoUi.metric(GoTheme.GAP_SMALL))
	inset.add_child(row)
	var fit := func() -> void: frame.custom_minimum_size.y = inset.get_combined_minimum_size().y
	inset.minimum_size_changed.connect(fit)
	# 🛑 Take the first height **on the next frame** — right now the children do not know their own minimum size.
	fit.call_deferred()

	_card = GoStyle.card()
	_fill(_card, "GoStyle.card()", "alpha argument")
	row.add_child(_card)

	_hud = GoStyle.hud_panel()
	_fill(_hud, "GoStyle.hud_panel()", "restyled in place")
	row.add_child(_hud)

	# ③ 🔑 **A panel the add-on did not build.** This is a `PanelContainer` drawn into a scene, or one the
	#    host made by hand, and it uses the theme's fully opaque `PanelContainer/panel` as it is.
	# 🛑 That panel has **zero padding** (`panel_solid`) — unlike the add-on's panels, its text sits against
	#    the border. Only here do we wrap it in a padding box (do that to the card or the HUD panel and the
	#    padding is doubled).
	_plain = PanelContainer.new()
	_plain.name = "PlainPanel"
	_fill(_plain, "PanelContainer", "GoStyle.fade_panel()", true)
	row.add_child(_plain)
	return frame


## Puts a name and a one-line note on a single panel — the show-through and the readability are seen together.
## Turn [param pad] on **only when the panel has no padding of its own** (the ③ comment above).
func _fill(panel: PanelContainer, title: String, note: String, pad := false) -> void:
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var body := GoStyle.column(GoUi.metric(GoTheme.GAP_TINY))
	# 🛑 gohud's panels already have padding — wrap another `padding()` box around one and it is doubled.
	if pad:
		var inset := GoStyle.padding(GoUi.metric(GoTheme.PADDING_COMPACT))
		panel.add_child(inset)
		inset.add_child(body)
	else:
		panel.add_child(body)
	var name_label := GoStyle.label(title, GoTheme.ROLE_BUTTON)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	body.add_child(name_label)
	var note_label := GoStyle.label(note, GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED))
	note_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	body.add_child(note_label)


# ── The button row ─────────────────────────────────────────────────────

func _actions() -> Control:
	var row := GoStyle.wrap_row(GoUi.metric(GoTheme.GAP_SMALL))
	if allow_project_wide:
		row.add_child(GoStyle.button("Apply to every panel", _apply_to_project, GoStyle.Tone.PRIMARY))
		row.add_child(GoStyle.button("Back to the theme value", _reset_to_theme, GoStyle.Tone.COMPACT))
	# 🔑 Show this toggle only where the host can swap the background — a switch that does nothing has no
	#    place on the screen.
	if backdrop_wanted.get_connections().size() > 0:
		var busy := GoStyle.toggle("Busy background", false)
		GoStyle.font_role(busy, GoTheme.ROLE_COMPACT)
		busy.toggled.connect(func(on: bool) -> void: backdrop_wanted.emit(on))
		row.add_child(busy)
	return row


## ④ The whole project takes this value. 🛑 **Widgets already born do not change their clothes** — the
##    screen has to be rebuilt for it to show, and that is the host's job (hence the signal).
func _apply_to_project() -> void:
	GoUi.config.container_alpha = _slider.value
	GoUi.refresh()
	applied.emit(_slider.value)


func _reset_to_theme() -> void:
	GoUi.config.container_alpha = -1.0
	GoUi.refresh()
	_slider.set_value_no_signal(GoUi.surface_alpha(GoTheme.BOX_CARD))
	_apply(_slider.value)
	applied.emit(-1.0)


# ── Windows to look in from outside ────────────────────────────────────

## The slider the tour and the checks drag.
func dial() -> HSlider:
	return _slider


## 🔑 How opaque the preview card **really is right now**. It reads **the value baked into the panel**,
## not the slider's — only that proves the value reached the panel (the bug where the knob moves and the
## panel does not hides at exactly this point).
func fill_alpha() -> float:
	if _card == null: return -1.0
	var face := _card.get_theme_stylebox(&"panel")
	if face == null or not (&"bg_color" in face): return -1.0
	var fill: Color = face.get(&"bg_color")
	return fill.a


# ── Putting the value onto the panels ──────────────────────────────────

## 🔑 The three panels take the same value by **three different routes**. Every route has to end in the
##    same result — if one differs, that route was missed (which really happened with the angular and
##    the medieval panels).
func _apply(alpha: float) -> void:
	_readout.text = "%d%%" % roundi(alpha * 100.0)
	# ① Restyled with the value you would give at build time (it yields the same panel as `GoStyle.card(…, alpha)`).
	GoStyle.style_panel(_card, GoStyle.surface(GoTheme.BOX_CARD, Color.TRANSPARENT, alpha))
	# ② The floating HUD panel — shadow and border stay exactly as the skin set them; only the fill thins.
	GoStyle.style_hud_panel(_hud, Color.TRANSPARENT, -1.0, -1.0, GoTheme.BOX_HUD, alpha)
	# ③ Laid over someone else's panel. 🔑 Called many times it thins once (the original panel is noted in the metadata).
	GoStyle.fade_panel(_plain, alpha, &"panel", GoTheme.BOX_PANEL)


# ── The pattern laid behind ────────────────────────────────────────────

## Thick diagonal bands. 🛑 One node draws them instead of stacking rotated `ColorRect`s — there is no
## reason to make twenty nodes for one preview box, and nothing has to be placed again when it resizes.
class Backdrop extends Control:
	const BANDS: Array[Color] = [Color("#1f7a4d"), Color("#b8481f"), Color("#2a55a8"), Color("#a89620")]
	const BAND_WIDTH := 30.0

	## 🛑 **There are places where the strength must be turned down.** Inside the preview box 1.0 is right
	## — to see exactly what a panel lets through, the back has to be crisp. But laid across **the whole
	## screen** it fights the body text outside the panels until not one line can be read (which is what
	## the first capture looked like). A real game's background is not loud enough to kill UI text either
	## — so for a whole screen, lay it at about 0.3.
	var intensity := 1.0:
		set(value):
			intensity = clampf(value, 0.0, 1.0)
			queue_redraw()

	func _init() -> void:
		name = "Backdrop"
		# 🛑 It takes no input — the pattern behind the preview must not steal presses from the panels above it.
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var step := BAND_WIDTH * 1.55
		var index := 0
		# 🔑 They are diagonal, so start off the left edge (`-size.y`) or the top-left corner is left bare.
		var offset := -size.y
		while offset < size.x + step:
			draw_line(Vector2(offset, 0.0), Vector2(offset + size.y, size.y),
				Color(BANDS[index % BANDS.size()], intensity), BAND_WIDTH)
			offset += step
			index += 1
