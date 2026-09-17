## 🎨 Theme **token names** and lookups. The names you call colors, metrics and font sizes by are gathered here.
##
## ## Why the names are constants
## A typo in `theme.get_color("acent", "GoHud")` quietly hands back black. Called as a constant, the compiler
## catches it — `GoTheme.ACCENT`.
##
## ## Where the tokens live
## In the **`GoHud`** type inside the theme — `GoHud/colors/accent`, `GoHud/constants/touch`.
## If a project brought its own theme and that type is missing, they are filled from gohud's default theme as
## long as `GoConfig.token_fallback` is on. That is why **plugging in an ordinary Theme does not break the widgets.**
class_name GoTheme
extends RefCounted

## Name of the Theme type the tokens live in.
const TYPE := &"GoHud"

# ── Colors ─────────────────────────────────────────────────────────────
const BACKGROUND := &"background"
const SURFACE := &"surface"
const SURFACE_SOFT := &"surface_soft"
const SURFACE_HIGH := &"surface_high"
const BORDER := &"border"
const TEXT := &"text"
const SECONDARY := &"secondary"
const MUTED := &"muted"
const ACCENT := &"accent"
const ON_ACCENT := &"on_accent"
const SUCCESS := &"success"
const WARNING := &"warning"
const DANGER := &"danger"
const INFO := &"info"
const SCRIM := &"scrim"
const SHADOW := &"shadow"
const TRACK := &"track"

# ── Fill-only colors ───────────────────────────────────────────────────
## 🔑 **The same meaning, the opposite use.** `WARNING` is used as text, so it has to be dark to read on a light
## background; used as the **fill of a health or experience bar** it has to be bright to stand out.
## Making one color carry both turns the light theme's experience bar **brown** (measured 2026-09-13).
##
## 🛑 These are **optional tokens** — when the theme lacks one it falls back to the same name with `_fill` stripped.
##    That is why an old theme, or somebody else's theme, plugs straight in without breaking.
const SUCCESS_FILL := &"success_fill"
const WARNING_FILL := &"warning_fill"
const DANGER_FILL := &"danger_fill"
const INFO_FILL := &"info_fill"
const ACCENT_FILL := &"accent_fill"

# ── Metrics (dp) ───────────────────────────────────────────────────────
const TOUCH := &"touch"
const BUTTON_HEIGHT := &"button_height"
const GAP_TINY := &"gap_tiny"
const GAP_SMALL := &"gap_small"
const GAP := &"gap"
const GAP_LARGE := &"gap_large"
const PADDING := &"padding"
const PADDING_COMPACT := &"padding_compact"
## The **left/right · top/bottom padding** of a compact button (`GoCompactButton`) panel. 🛑 A different value from
##    `padding_compact` (the inner padding of cards and notices) — shared, changing the button padding shakes the
##    surface padding with it. It is also the floor that keeps text off the panel border (`GoStyle.audit_compact_padding`). Default theme 10 · 5.
const COMPACT_PADDING_X := &"compact_padding_x"
const COMPACT_PADDING_Y := &"compact_padding_y"
const RADIUS := &"radius"
const RADIUS_SMALL := &"radius_small"
const RADIUS_LARGE := &"radius_large"
const SCREEN_MARGIN := &"screen_margin"
const SCROLL_DEADZONE := &"scroll_deadzone"
const SCROLL_EDGE := &"scroll_edge"
const SCROLLBAR_WIDTH := &"scrollbar_width"
const LIST_GLYPH := &"list_glyph"
const ICON_SIZE := &"icon_size"
const NOTICE_DURATION_MS := &"notice_duration_ms"

# ── Panel opacity (%) ──────────────────────────────────────────────────
## 🪟 **How solid the background of a panel (container) is.** At 100 nothing behind shows; at 80, 20% of the screen
## behind bleeds through — you see the battle carry on behind a dialog and the map shine through beneath a sheet.
## In a game UI this is not decoration but **the device that keeps you from losing context**.
##
## 🛑 **Text, icons and buttons do not follow this value.** Only the panel turns translucent while the content on it
##    stays crisp — fading the content along with it (`modulate.a`) gives you a UI that cannot be read, and that is
##    not a transparency problem, it is a breakage.
##
## 🛑 It is an **integer percentage** (0~100), because a `Theme` constant can hold nothing but integers. The spot that
##    handles it as a ratio (0.0~1.0) in code is `GoUi.surface_alpha()`, and that is where the division by 100 happens.
##    Write `0.8` into a theme or config field and it truncates to 0, which makes **the panel vanish entirely** — write `80` there.
##
## 🔑 These are **optional tokens** as well — when the theme lacks one it falls back to 100 (a solid color). So an old
##    theme, or somebody else's theme, that never heard of this token leaves the screen exactly as it was.
const PANEL_ALPHA := &"panel_alpha"
const CARD_ALPHA := &"card_alpha"
const HUD_ALPHA := &"hud_alpha"
const NOTICE_ALPHA := &"notice_alpha"
const POPUP_ALPHA := &"popup_alpha"

# ── Surface StyleBoxes ─────────────────────────────────────────────────
const BOX_PANEL := &"panel"
const BOX_CARD := &"card"
const BOX_HUD := &"hud"
const BOX_NOTICE := &"notice"
const BOX_POPUP := &"popup"
const BOX_EMPTY := &"empty"
const BOX_FOCUS := &"focus"
const BOX_FOCUS_SOFT := &"focus_soft"

## Panel variant (`BOX_*`) → **the opacity token of that variant**. The reason each variant has to be settable on its
## own is that the demands differ — a dialog may let a little of the background show, but a HUD panel laid straight
## over the game screen has to be fuller the busier the picture is, or the text stops reading.
## 🛑 There is no `focus`·`empty` — a focus ring is not a panel, and an empty panel has nothing to draw.
const ALPHA_TOKENS := {
	BOX_PANEL: PANEL_ALPHA,
	BOX_CARD: CARD_ALPHA,
	BOX_HUD: HUD_ALPHA,
	BOX_NOTICE: NOTICE_ALPHA,
	BOX_POPUP: POPUP_ALPHA,
}

# ── Type roles ─────────────────────────────────────────────────────────
## Role name → the Theme type that holds that size.
## 🛑 A role is **the name of a size**, not the name of a use — not "title" but "the largest type".
##    That is what keeps the size system steady even when different screens use it to mean different things.
const ROLE_TYPES := {
	&"micro": &"GoMicroLabel",
	&"compact": &"GoCompactLabel",
	&"caption": &"GoCaptionLabel",
	&"body": &"Label",
	&"button": &"Button",
	&"subtitle": &"GoSubtitleLabel",
	&"title": &"GoTitleLabel",
}

const ROLE_MICRO := &"micro"
const ROLE_COMPACT := &"compact"
const ROLE_CAPTION := &"caption"
const ROLE_BODY := &"body"
const ROLE_BUTTON := &"button"
const ROLE_SUBTITLE := &"subtitle"
const ROLE_TITLE := &"title"

# ── Type variations ────────────────────────────────────────────────────
const VAR_PANEL := &"GoPanel"
const VAR_CARD := &"GoCard"
const VAR_BUTTON := &"GoButton"
const VAR_PRIMARY_BUTTON := &"GoPrimaryButton"
const VAR_DANGER_BUTTON := &"GoDangerButton"
## The filled danger button — used only on the **confirm** button of an irreversible action. For a faint danger button use the one above.
const VAR_DANGER_SOLID_BUTTON := &"GoDangerSolidButton"
const VAR_BARE_BUTTON := &"GoBareButton"
const VAR_COMPACT_BUTTON := &"GoCompactButton"
const VAR_ICON_BUTTON := &"GoIconButton"
const VAR_LIST_BUTTON := &"GoListButton"
const VAR_TITLE_LABEL := &"GoTitleLabel"
const VAR_SUBTITLE_LABEL := &"GoSubtitleLabel"
const VAR_CAPTION_LABEL := &"GoCaptionLabel"
const VAR_COMPACT_LABEL := &"GoCompactLabel"
const VAR_MICRO_LABEL := &"GoMicroLabel"


## One color from a theme. Missing, from the `fallback` theme; missing there too, magenta (so it catches the eye).
static func color_of(theme: Theme, key: StringName, fallback: Theme = null) -> Color:
	if theme != null and theme.has_color(key, TYPE): return theme.get_color(key, TYPE)
	if fallback != null and fallback.has_color(key, TYPE): return fallback.get_color(key, TYPE)
	return Color.MAGENTA


## One metric from a theme. [param missing] is what comes back **when no theme has it**.
## 🛑 A metric may default to 0, but **an opacity of 0 means "the panel is invisible"** — so it was pulled out as an
##    argument the caller cannot forget (`GoUi.surface_alpha` passes 100).
static func metric_of(theme: Theme, key: StringName, fallback: Theme = null, missing := 0) -> int:
	if theme != null and theme.has_constant(key, TYPE): return theme.get_constant(key, TYPE)
	if fallback != null and fallback.has_constant(key, TYPE): return fallback.get_constant(key, TYPE)
	return missing


static func box_of(theme: Theme, key: StringName, fallback: Theme = null) -> StyleBox:
	if theme != null and theme.has_stylebox(key, TYPE): return theme.get_stylebox(key, TYPE)
	if fallback != null and fallback.has_stylebox(key, TYPE): return fallback.get_stylebox(key, TYPE)
	return StyleBoxEmpty.new()


## The font size of a role. An unfamiliar role name falls back to the body size.
static func font_size_of(theme: Theme, role: StringName, fallback: Theme = null) -> int:
	var type: StringName = ROLE_TYPES.get(role, &"Label")
	for candidate in [theme, fallback]:
		if candidate == null: continue
		var found := _font_size_in_chain(candidate, type)
		if found > 0: return found
	return 16


## Find the font size defined directly on the type, and failing that **climb the variation's base** (`GoCaptionLabel` → `CaptionLabel` → `Label`).
## 🛑 `Theme.has_font_size()` is unusable — it is true no matter what once `default_font_size` exists; judge by the list of direct definitions instead.
##    This is the road that lets a host project hang its own variation off a base and keep one canonical value. 0 means none.
static func _font_size_in_chain(theme: Theme, type: StringName) -> int:
	var current := type
	for _depth in 8:
		if current.is_empty(): break
		if theme.get_font_size_list(current).has(&"font_size"): return theme.get_font_size(&"font_size", current)
		current = theme.get_type_variation_base(current)
	if theme.has_default_font_size(): return theme.get_default_font_size()
	return 0


## 🔑 **A control's color, read straight from a theme resource** — `name` on `type`, climbing the variation's base
## chain and then the engine's class chain (`GoCompactButton` → `Button` → `BaseButton` → `Control`).
## Returns `missing` when no type on the way defines it.
##
## 🛑 Why not `Theme.has_color()`: it looks at **that one type only**. A variation that defines no colors of its own
##    (most gohud button variations) answers "no" although its base has the color.
## 🛑 Why not `Control.get_theme_color()`: on a control that is **not in the tree yet** it hands back the engine's
##    default (a light gray) — even when the control's own `theme` is set (measured 2026-09-17, Godot 4.7.2). Factories
##    build their nodes before anyone adds them, so they read through here (`GoUi.theme_color`).
static func color_in_chain(theme: Theme, name: StringName, type: StringName, missing := Color.TRANSPARENT) -> Color:
	var defined_on := _color_owner(theme, name, type)
	return missing if defined_on.is_empty() else theme.get_color(name, defined_on)


## Does some type on `type`'s base chain define the color `name`?
static func has_color_in_chain(theme: Theme, name: StringName, type: StringName) -> bool:
	return not _color_owner(theme, name, type).is_empty()


## The first type on the chain that defines the color, or `&""`.
static func _color_owner(theme: Theme, name: StringName, type: StringName) -> StringName:
	if theme == null: return &""
	var current := type
	for _depth in 12:
		if current.is_empty(): break
		if theme.has_color(name, current): return current
		var base := theme.get_type_variation_base(current)
		if base.is_empty() and ClassDB.class_exists(current): base = ClassDB.get_parent_class(current)
		current = base
	return &""


## The **opacity token name** of a panel variant. An unfamiliar variant is read as a card — rather than have an unknown
## panel suddenly turn solid or disappear, following the card's rule keeps the screen reading as one piece.
static func alpha_token(variant: StringName) -> StringName:
	return ALPHA_TOKENS.get(variant, CARD_ALPHA)


## A numeric size → the nearest role. It carries over the spots where older code handed a size in as a number like `14`.
static func role_for_size(size: int) -> StringName:
	if size <= 10: return ROLE_MICRO
	if size <= 12: return ROLE_COMPACT
	if size <= 14: return ROLE_CAPTION
	if size <= 17: return ROLE_BODY
	if size <= 19: return ROLE_BUTTON
	if size <= 24: return ROLE_SUBTITLE
	return ROLE_TITLE
