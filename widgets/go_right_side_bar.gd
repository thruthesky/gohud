## A **right side bar** — `GoSideBar` held to the right edge. Every rule is in `GoEdgeBar`.
##
## ```gdscript
## var tools := GoRightSideBar.make(3)
## tools.add_start(GoStyle.icon_button(GoIconSet.MENU, open_menu, -1, &"menu"))
## tools.add_end(GoStyle.icon_button(GoIconSet.USER, open_profile, -1, &"profile"))
## screen.add_child(tools)   # pins itself to the right edge, full height
## ```
@tool
class_name GoRightSideBar
extends GoSideBar


func _init() -> void:
	super()
	name = "RightSideBar"
	edge = Edge.RIGHT


## A right side bar with [param count] tiers (1, 2 or 3); [param placing] places the tier of a one-tier bar —
## `START` at the top, `CENTER` in the middle, `END` at the bottom, `SPACE_BETWEEN` spread.
static func make(count := 3, placing := Justify.START) -> GoRightSideBar:
	var bar := GoRightSideBar.new()
	bar.tiers = count
	bar.justify = placing
	return bar
