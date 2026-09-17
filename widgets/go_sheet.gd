## 📄 **A sheet that rises from the bottom** — a page container with a `CanvasLayer` of its own.
##
## It is a convenient wrapper around `GoSurface`. Put a list or a management page over the game screen
## and swap pages inside it. It holds its own `layer`, so it reliably comes up above the HUD.
##
## ```gdscript
## var sheet := GoSheet.new()
## add_child(sheet)
## sheet.open("Bag")
## sheet.body.add_child(item_list)
## sheet.add_footer(GoStyle.button("Close", sheet.close))
## ```
##
## ## 🔑 When you change page
## `open()` empties the body and the pinned row and **switches off** the back button, the pinned row and the
## footer. A dead button left on a screen with nowhere to go back to reads as a fault to whoever presses it
## and gets nothing. Footer buttons that change per page go in through `add_footer()` — the next `open()`
## detaches and frees them.
@tool
class_name GoSheet
extends CanvasLayer

signal closed
signal page_changed

## The body (scrolls).
var body: VBoxContainer
## The surface being wrapped — reach for it directly when you need fine control.
var surface: GoSurface

## Whether tapping the scrim closes it.
## 🛑 **Turn it off on a sheet that holds irreversible work** — a trade window with goods staked on it
##    loses all of them to a single stray tap outside. The close button, Escape and the back gesture
##    stay as they are, so there is still a way out.
var dismissable := true:
	set(value):
		dismissable = value
		if is_instance_valid(surface): surface.dismiss_on_scrim = value

## 🪟 **Opacity of the panel ground** (0.0~1.0) — for making this one thing differ. Negative uses whatever the theme and settings decide.
## 🛑 Only the ground thins out — text, icons and buttons stay crisp.
##
## ```gdscript
## sheet.alpha = 0.7    # this sheet alone at 70% — a list that has to show the map underneath
## ```
var alpha := -1.0:
	set(value):
		alpha = value
		# 🔑 The surface already exists from `_init` — take the value even before entering the tree and
		#    let the surface's `_ready` apply the panel then (it checks `is_inside_tree()` over there).
		if is_instance_valid(surface): surface.alpha = value

## Fraction of the screen height it takes up.
var height_ratio := 0.6:
	set(value):
		height_ratio = value
		if is_instance_valid(surface): surface.height_ratio = value
	get:
		return surface.height_ratio if is_instance_valid(surface) and surface.height_ratio > 0.0 else height_ratio

## 🔑 **This sheet's ceiling on `height_ratio`** (`GoSurface.max_height_ratio`). 0 means
## `GoConfig.surface_max_height_ratio` (0.72) — a `height_ratio` above that is cut back unless this is raised too.
## It is also how far the player can drag the sheet up.
##
## ```gdscript
## sheet.max_height_ratio = 0.9
## sheet.height_ratio = 0.86    # a bag grid that needs the room
## ```
var max_height_ratio := 0.0:
	set(value):
		max_height_ratio = value
		if is_instance_valid(surface): surface.max_height_ratio = value

var _back_action := Callable()
## This page's footer nodes, added through `add_footer()` — the next `open()` clears them away.
var _page_footer: Array[Node] = []


## 🛑 The surface is built in `_init` — using `sheet.open()` and `sheet.body` before adding this to the
##    tree is the natural way to use it, and building in `_ready` makes `body` still `null` then and crash.
func _init() -> void:
	visible = false
	surface = _make_surface()
	surface.placement = GoSurface.Placement.BOTTOM
	surface.fit_content = true
	surface.resizable = true
	surface.close_requested.connect(close)
	add_child(surface)
	body = surface.body


func _ready() -> void:
	if layer == 1: layer = 10
	# Apply the values that may have been changed after `new()`. 🛑 Do not hard-code `true` — that would
	#    overwrite a sheet set to `dismissable = false` (a trade window that must not close on a stray tap).
	surface.height_ratio = height_ratio
	surface.dismiss_on_scrim = dismissable


## Open the sheet and set the title (already-translated text). Resets the body, the back button, the pinned row and any footer nodes added through `add_footer()`.
func open(title: String) -> void:
	if not visible: GoFeedback.opened()
	surface.set_title(title)
	surface.clear()
	set_back(Callable())
	for child in toolbar().get_children():
		toolbar().remove_child(child)
		child.queue_free()
	# 🛑 Clear **only what `add_footer()` put there**. Merely hiding the row let buttons pile up on screens that
	#    add a close button per page (confirmed 2026-09-15). Emptying it wholesale, on the other hand, would make
	#    a node added once through `footer().add_child()` and kept (a sheet-wide snackbar, say) vanish the moment
	#    the page changes — there are already hosts using it that way.
	for node in _page_footer:
		if is_instance_valid(node) and node.get_parent() == footer():
			footer().remove_child(node)
			node.queue_free()
	_page_footer.clear()
	toolbar().visible = false
	footer().visible = false
	visible = true
	surface.relayout()
	page_changed.emit()


## Open with a translation key.
func open_key(title_key: String) -> void:
	open("")
	surface.set_title_key(title_key)


## Change only the title — unlike `open()` it leaves the body, the back button and the pinned row alone.
## Going into a sub-screen inside the same sheet (list → detail) has to carry the title along.
func set_title(value: String) -> void:
	surface.set_title(value)


## The **pinned row** under the header. Put things that must stay visible as the list scrolls, such as a search field.
## The caller switches `visible = true` on. `open()` empties it and switches it off on every page.
func toolbar() -> VBoxContainer:
	return surface.toolbar


## The **pinned footer row**. 🛑 Confirm and cancel buttons that must always be visible go here — put them in
## `body` and they scroll with the list and leave the screen on a long one. The caller switches `visible = true`
## on. `open()` only switches it off and keeps children added here directly — buttons that change per page go
## in through `add_footer()`.
func footer() -> VBoxContainer:
	return surface.footer


## Add to **this page's** footer row and switch the row on. The next `open()` detaches and frees it.
## 🔑 Screens that add a close or confirm button per page use this — anything added through `footer().add_child()`
##    survives an `open()` (the place for a sheet-wide snackbar or a permanent button).
func add_footer(node: Node) -> Node:
	footer().add_child(node)
	footer().visible = true
	_page_footer.append(node)
	return node


## The back button used by a sub-screen inside the same sheet. An empty `Callable` hides it.
func set_back(action: Callable) -> void:
	_back_action = action
	surface.set_back(action)


func clear() -> void:
	surface.clear()


func close() -> void:
	if not visible: return
	GoFeedback.closed()
	visible = false
	closed.emit()


## Build the surface being wrapped. 🔑 If the host wants a `GoSurface` subclass (for old type-hint compatibility, say), override this in a subclass.
func _make_surface() -> GoSurface:
	return GoSurface.new()
