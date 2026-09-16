## 📜 One vertical scroll box. Finger dragging, focus following and edge insets handled in one place.
##
## ## Put exactly one thing inside
## Keep the header and the button row **outside**. When the list grows long they must not leave the screen.
##
## ```gdscript
## var scroll := GoScroll.new()
## scroll.add_child(body_column)      # a single child
## card.add_child(scroll)
## ```
##
## ## 🔑 Keeping the scrollbar off the text
## Call `use_panel_edge()` and the scrollbar moves out into **the card's existing padding**, while the
## content keeps its original indent. When there is no scrollbar the content takes that space back.
@tool
class_name GoScroll
extends ScrollContainer

var _edge_frame: MarginContainer
var _content_inset: MarginContainer
var _edge_gutter := 0
## How far the scroll bounds are pushed outward so a glow has room to spread (dp).
var _bleed := 0


func _init() -> void:
	name = "Scroll"
	horizontal_scroll_mode = SCROLL_MODE_DISABLED
	vertical_scroll_mode = SCROLL_MODE_AUTO
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	follow_focus = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	# 🛑 The scroll **rail is always on the physical right** — in Arabic and Urdu as well.
	#    The children each decide the direction of their own content (`_prepare_branch` puts them back to LOCALE).
	layout_direction = Control.LAYOUT_DIRECTION_LTR


func _ready() -> void:
	theme = GoUi.theme()
	scroll_deadzone = GoUi.metric(GoTheme.SCROLL_DEADZONE)
	child_entered_tree.connect(_prepare_branch)
	for child in get_children(): _prepare_branch(child)


## A scroll that runs horizontally (a row of chips, a row of thumbnails).
static func horizontal() -> GoScroll:
	return as_horizontal(GoScroll.new())


## Just the settings `horizontal()` applies — for a subclass rebuilding the same factory with its own instance
## (`static func horizontal() -> Child: return GoScroll.as_horizontal(Child.new())`). A static function cannot know the subclass type.
static func as_horizontal(node: GoScroll) -> GoScroll:
	node.horizontal_scroll_mode = SCROLL_MODE_AUTO
	node.vertical_scroll_mode = SCROLL_MODE_DISABLED
	node.size_flags_vertical = Control.SIZE_FILL
	node.mouse_filter = Control.MOUSE_FILTER_PASS
	return node


## The `GoScroll` this node sits inside (null if there is none).
static func containing(node: Node) -> GoScroll:
	var ancestor := node.get_parent()
	while ancestor != null:
		if ancestor is GoScroll: return ancestor
		ancestor = ancestor.get_parent()
	return null


## Move the scrollbar out into the parent's existing right padding, keeping the content's original indent.
## `parent_padding` is the padding the parent card uses (dp).
func use_panel_edge(parent_padding: int) -> void:
	if _edge_frame != null: return
	_edge_gutter = maxi(0, parent_padding - GoUi.metric(GoTheme.SCROLL_EDGE))
	var parent := get_parent()
	if parent == null: return
	var index := get_index()
	_edge_frame = MarginContainer.new()
	_edge_frame.name = name + "Edge"
	_edge_frame.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_edge_frame.size_flags_horizontal = size_flags_horizontal
	_edge_frame.size_flags_vertical = size_flags_vertical
	_edge_frame.size_flags_stretch_ratio = size_flags_stretch_ratio
	# 🛑 **Leave breathing room so glows and shadows are not clipped.** A scroll clips at its own bounds,
	#    no exceptions — a full-width accent button had its left glow sheared off in a straight vertical line
	#    (measured 2026-09-13; the right side survived thanks to the rail gutter, so the two sides looked
	#    different). Borrow the parent padding to push the bounds outward, then give the same amount back on
	#    the inside so **the content does not move** — the same trick as the right-hand rail.
	_bleed = mini(GoUi.metric(GoTheme.GAP), parent_padding)
	for side in [&"margin_left", &"margin_top", &"margin_bottom"]:
		_edge_frame.add_theme_constant_override(side, -_bleed)
	_edge_frame.add_theme_constant_override(&"margin_right", -_edge_gutter)
	parent.add_child(_edge_frame)
	parent.move_child(_edge_frame, index)
	_reparent_keeping_owners(self, _edge_frame)
	var content := get_children()
	_content_inset = MarginContainer.new()
	_content_inset.name = "ContentInset"
	_content_inset.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_content_inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_inset.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in [&"margin_left", &"margin_top", &"margin_bottom"]:
		_content_inset.add_theme_constant_override(side, _bleed)
	add_child(_content_inset)
	for child in content: _reparent_keeping_owners(child, _content_inset)
	var bar := get_v_scroll_bar()
	bar.visibility_changed.connect(_sync_edge_inset)
	bar.resized.connect(_sync_edge_inset)
	_sync_edge_inset()


## Move with `reparent()` while preserving the descendants' owners.
## 🛑 The engine's `reparent()` only restores the owner of descendants that share **the same owner** as the node
##    being moved. In a form assembled in code, where only a button is owned (`back.owner = form`) and the scroll
##    has no owner, moving the scroll into the edge frame wiped the button's owner, `%BackButton` was no longer
##    found and the Android back gesture silently stopped working (measured 2026-09-15, 4.7.2). It never shows up
##    in a `.tscn` where the scene root owns everything.
static func _reparent_keeping_owners(node: Node, new_parent: Node) -> void:
	var owners := {}
	if node.owner != null: owners[node] = node.owner
	for each in node.find_children("*", "", true, false):
		if each.owner != null: owners[each] = each.owner
	node.reparent(new_parent)
	for each: Node in owners:
		var keep: Node = owners[each]
		if each.owner != keep and is_instance_valid(keep) and keep.is_ancestor_of(each): each.owner = keep


## For when the card narrowed and the padding changed — fixes only the insets, without rebuilding the scroll and content ownership.
func set_panel_padding(padding: int) -> void:
	if _edge_frame == null: return
	_edge_gutter = maxi(0, padding - GoUi.metric(GoTheme.SCROLL_EDGE))
	_edge_frame.add_theme_constant_override(&"margin_right", -_edge_gutter)
	_bleed = mini(GoUi.metric(GoTheme.GAP), padding)
	for side in [&"margin_left", &"margin_top", &"margin_bottom"]:
		_edge_frame.add_theme_constant_override(side, -_bleed)
		_content_inset.add_theme_constant_override(side, _bleed)
	_sync_edge_inset()


## 🔑 **Bring this descendant into view** — for taking the user to the thing they have to fix, like the field behind 「Passwords do not match」.
##
## 🛑 Calling `ensure_control_visible()` right there misses — the error line has just appeared and the card height
##    is still changing, so the engine scrolls against the **old position** (measured 2026-09-16: only 54% was revealed).
##    Wait the two frames layout takes, then call it.
func reveal(control: Control) -> void:
	if not is_instance_valid(control) or not is_ancestor_of(control): return
	for i in 2:
		await get_tree().process_frame
		if not (is_inside_tree() and is_instance_valid(control) and is_ancestor_of(control)): return
	ensure_control_visible(control)


## Show and hide the whole scroll section together (the edge frame included).
func set_section_visible(value: bool) -> void:
	if _edge_frame != null: _edge_frame.visible = value
	visible = value


func _sync_edge_inset() -> void:
	if _content_inset == null: return
	var bar := get_v_scroll_bar()
	var reserved := 0
	if bar.visible:
		reserved = ceili(bar.get_combined_minimum_size().x) + get_theme_constant(&"scrollbar_h_separation")
	_content_inset.add_theme_constant_override(&"margin_right", maxi(0, _edge_gutter - reserved))


## Ordinary buttons have to let the `ScrollContainer` see finger drags — that is what makes a scroll started on
## top of the list work. Once the drag threshold is crossed the engine cancels the button press for us.
## 🛑 Text editing, sliders and the `OptionButton` popup keep their own gestures, so they are left alone.
func _prepare_branch(node: Node) -> void:
	if node is ScrollBar or node is ScrollContainer: return
	if node is Control and node.get_parent() == self and node.layout_direction == Control.LAYOUT_DIRECTION_INHERITED:
		node.layout_direction = Control.LAYOUT_DIRECTION_APPLICATION_LOCALE  # the 4.4+ name — `LOCALE` is a deprecated alias
	if node is Button and not node is OptionButton:
		node.mouse_filter = Control.MOUSE_FILTER_PASS
	if not node.child_entered_tree.is_connected(_prepare_branch):
		node.child_entered_tree.connect(_prepare_branch)
	for child in node.get_children(): _prepare_branch(child)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _content_inset != null:
		# When the language changes the children flip left-to-right — fit them back inside our physical right inset.
		_content_inset.queue_sort.call_deferred()
