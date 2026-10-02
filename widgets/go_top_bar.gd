## 🔝 **A top bar layout** — up to three slots along the top edge: the start slot at the start, the centre slot in the
## middle of the bar, the end slot at the far end. It draws nothing; every rule is in `GoEdgeBar`.
##
## ```gdscript
## var bar := GoTopBar.make(3)
## bar.add_start(GoStyle.icon_button(GoIconSet.BACK, go_back, -1, &"back"))
## bar.add_center(GoStyle.label("Stage 3"))
## bar.add_end(GoStyle.chip("1,250"))
## screen.add_child(bar)   # pins itself to the top edge, padded clear of the notch
## ```
@tool
class_name GoTopBar
extends GoEdgeBar


func _init() -> void:
	super()
	name = "TopBar"
	edge = Edge.TOP


## A top bar with [param count] slots (1, 2 or 3).
static func make(count := 3) -> GoTopBar:
	var bar := GoTopBar.new()
	bar.columns = count
	return bar
