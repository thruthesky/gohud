## ⬅️ **Ownership of the Android back gesture**. While even one window is open, back must not quit the app.
##
## ## Why it has to be counted
## `SceneTree.quit_on_go_back` is a single global switch. Window A turns it off, window B turns it on, and back
## quits the app while A is still open. So it **counts how many are open** and restores the original value when
## the last one closes.
##
## ```gdscript
## GoBackPolicy.acquire(get_tree())   # when a window comes up
## GoBackPolicy.release(get_tree())   # when a window closes — from `_exit_tree` too, without fail
## ```
##
## 🛑 A window that called `acquire` has to `release` **no matter what happens**. That includes the path where the
##    node disappears through `queue_free` (which is why `GoSurface` also releases in `_exit_tree`). Miss it and
##    back is dead forever, even once every window is closed.
class_name GoBackPolicy
extends RefCounted

static var _owners := 0
static var _previous := true


## How many windows are holding on to the back gesture right now.
static func owners() -> int:
	return _owners


static func acquire(tree: SceneTree) -> void:
	if tree == null: return
	if _owners == 0: _previous = tree.quit_on_go_back
	_owners += 1
	tree.quit_on_go_back = false


static func release(tree: SceneTree) -> void:
	if tree == null or _owners == 0: return
	_owners -= 1
	if _owners == 0: tree.quit_on_go_back = _previous


## 🛑 For resetting between checks. Never called from production code.
static func reset(tree: SceneTree = null) -> void:
	_owners = 0
	if tree != null: tree.quit_on_go_back = _previous
