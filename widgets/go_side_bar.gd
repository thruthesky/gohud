## ◧ **A side bar layout** — up to three tiers down the left or right edge: the top tier at the top, the middle tier
## centred on the bar's height, the bottom tier at the bottom; or one tier of items at the top, in the middle, at the
## bottom, or spread with the same gap between every pair. Buttons and panels both go in. It draws nothing; every rule
## is in `GoEdgeBar`. `GoLeftSideBar` and `GoRightSideBar` are this with the side set; use them.
##
## ```gdscript
## var tools := GoRightSideBar.make(3)
## tools.add_start(GoStyle.icon_button(GoIconSet.SETTINGS, open_settings, -1, &"settings"))
## tools.add_center(GoStyle.icon_button(GoIconSet.SEARCH, find, -1, &"search"))
## tools.add_end(GoStyle.icon_button(GoIconSet.USER, open_profile, -1, &"profile"))
## screen.add_child(tools)   # pins itself to the right edge, full height
## ```
##
## 🛑 It stays on the side it names in Arabic and Hebrew too (as the safe area and the joystick do) — turn on
##    `follow_text_direction` for an app screen that should mirror. Its tiers keep top-to-bottom order in every
##    language.
## 🛑 A panel whose text wraps asks for almost no width — give the bar a `thickness` and the panel
##    `size_flags_horizontal = SIZE_EXPAND_FILL`, and mark it `set_meta(GoEdgeBar.KEEP_WRAP, true)`.
@tool
class_name GoSideBar
extends GoEdgeBar

## The number of tiers, 1 to 3 — the same setting as `columns`, under the name a side bar reads by.
var tiers: int:
	get: return columns
	set(value): columns = value


func _init() -> void:
	super()
	name = "SideBar"
	edge = Edge.LEFT
	size_flags_horizontal = Control.SIZE_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
