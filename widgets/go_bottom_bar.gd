## 🔻 **A bottom bar layout** — up to three slots along the bottom edge, or one run of items placed at the start, in
## the centre, at the end, or spread with the same gap between every pair (`Justify.SPACE_BETWEEN`). It draws nothing;
## every rule is in `GoEdgeBar`.
##
## ```gdscript
## var actions := GoBottomBar.make(1, GoBottomBar.Justify.SPACE_BETWEEN)
## for name in ["Attack", "Guard", "Item", "Run"]: actions.add_start(GoStyle.button(name, act.bind(name)))
## screen.add_child(actions)   # pins itself to the bottom edge, padded clear of the gesture bar
## ```
@tool
class_name GoBottomBar
extends GoEdgeBar


func _init() -> void:
	super()
	name = "BottomBar"
	edge = Edge.BOTTOM


## A bottom bar with [param count] slots (1, 2 or 3); [param placing] places the run of a one-column bar.
static func make(count := 1, placing := Justify.START) -> GoBottomBar:
	var bar := GoBottomBar.new()
	bar.columns = count
	bar.justify = placing
	return bar
