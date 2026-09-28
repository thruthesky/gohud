## 🚪 **The demo's front door** — the place that makes a single `godot` open this folder.
##
## 🛑 This one file uses **not a single** gohud name (`GoUi`, `GoStyle`, …). Without the add-on link or
##    the import cache those names blow up while parsing, and all a person sees is an empty window and
##    one line of `Identifier "GoUi" not declared` — which is exactly what this demo used to suffer.
##    The front door alone must still come up in that state, say what is missing, and fix it itself.
##
## ## What it does
## 1. If the `addons/gohud` link is there and the class cache knows **every** class the project declares,
##    it hands straight over to the home screen (`home.tscn`).
## 2. If not, it links the add-on, runs one import and **reopens the window**.
##    🔑 An import does not reach the running process — class names are read once, at startup.
## 3. If that still does not work, it writes on screen what to do (it never leaves a blank screen).
##
## 🛑 **A cache that has `GoUi` can still be stale.** Only an import (or the editor) writes the class cache —
##    running the game never does. gohud 1.2.0 added `GoIconLibrary`; a demo imported before that still found
##    `GoUi`, came up, and the widget gallery — the one screen using the new name — failed to parse and
##    opened blank (measured 2026-09-24). So every `class_name` is checked, not one.
extends Control

const ADDON_MARKER := "res://addons/gohud/plugin.cfg"
const HOME_SCENE := "res://home.tscn"
## The marker put on the reopened window. 🛑 Without it, a setup that never finishes reopens the window forever.
const RETRY_FLAG := "--gohud-bootstrapped"

# This has to draw even with no add-on, so no theme tokens — these colors belong to the front door alone.
const BG := Color("#0b111e")
const INK := Color("#e6edf7")
const DIM := Color("#8fa3bd")
const ACCENT := Color("#71d9e9")

var _title: Label
var _body: Label
var _hint: Label
## The classes the cache is missing, found by [method _addon_ready]. Shown by name when the import does not fix them.
var _missing := PackedStringArray()


func _ready() -> void:
	name = "Main"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	if _addon_ready():
		# 🛑 Switching straight away inside `_ready` is refused by the engine, because the tree is busy
		#    taking in children ("Parent node is busy adding/removing children" — measured). Wait a beat.
		get_tree().change_scene_to_file.call_deferred(HOME_SCENE)
		return
	_bootstrap()


# ── Readiness check ────────────────────────────────────────────────────

## Is the add-on **usable in this process?** Having the files in place is not enough —
## class names come from the cache the import leaves behind, and a name missing from it does not parse.
func _addon_ready() -> bool:
	if not FileAccess.file_exists(ADDON_MARKER): return false
	_missing = unregistered_classes(ProjectSettings.get_global_class_list())
	return _missing.is_empty()


## The `class_name`s this project declares that `registered` (the class cache) does not know, or knows at
## another path. Empty means every name parses. Static so the demo's test can hand it a stale list.
static func unregistered_classes(registered: Array[Dictionary]) -> PackedStringArray:
	var known := {}
	for entry in registered: known[String(entry.get("class", ""))] = String(entry.get("path", ""))
	var declared := {}
	_declared_classes("res://", RegEx.create_from_string("(?m)^class_name\\s+([A-Za-z_]\\w*)"), declared)
	var missing := PackedStringArray()
	for class_id in declared:
		if known.get(class_id, "") != declared[class_id]: missing.append(class_id)
	missing.sort()
	return missing


## Collects `{class_name: path}` under `dir`, by the editor's own scan rules: hidden folders, folders with a
## `.gdignore` and folders holding another `project.godot` are not part of this project.
## 🔑 Those rules also stop the walk from looping — `addons/gohud` links back to the repository, and the only
##    way back in (`examples/demo`) carries a `.gdignore`.
static func _declared_classes(dir: String, pattern: RegEx, found: Dictionary) -> void:
	var here := DirAccess.open(dir)
	if here == null: return
	# The project root keeps its own `.gdignore` (for the game this folder ships inside) — it does not apply here.
	if dir != "res://" and (here.file_exists(".gdignore") or here.file_exists("project.godot")): return
	for file in here.get_files():
		if file.get_extension() != "gd": continue
		var path := dir.path_join(file)
		var hit := pattern.search(FileAccess.get_file_as_string(path))
		if hit != null: found[hit.get_string(1)] = path
	for sub in here.get_directories():
		_declared_classes(dir.path_join(sub), pattern, found)


## The folder the add-on source lives in. This demo lives inside `examples/demo` of the gohud repository.
func _addon_source() -> String:
	var here := _project_dir()
	var root := here.get_base_dir().get_base_dir()   # examples/demo → examples → gohud
	return root if FileAccess.file_exists(root.path_join("plugin.cfg")) else ""


func _project_dir() -> String:
	return ProjectSettings.globalize_path("res://").trim_suffix("/")


# ── First-run setup ────────────────────────────────────────────────────

func _bootstrap() -> void:
	var linked := FileAccess.file_exists(ADDON_MARKER)
	if OS.get_cmdline_user_args().has(RETRY_FLAG):
		_say("gohud is still not linked" if not linked else "gohud classes are still missing",
			"The add-on was linked and the project was re-imported, but its classes are still missing%s." % (
				": " + ", ".join(_missing) if linked else ""),
			"Run  bash run.sh  in this folder and read the import log.")
		return
	var source := "" if linked else _addon_source()
	if not linked and source.is_empty():
		_say("gohud was not found",
			"This demo expects the add-on two folders up, at gohud/plugin.cfg — the layout of the repository it ships in.",
			"Copy the add-on to addons/gohud, or run  bash run.sh  from a full checkout.")
		return
	if linked:
		# The add-on changed since the last import — a screen using a new name would otherwise open blank.
		_say("Updating gohud",
			"The add-on has classes this project has not registered yet (%s). Importing once more takes a moment." % (
				", ".join(_missing)),
			"The window reopens by itself when it is done.")
	else:
		_say("Setting up gohud",
			"Linking addons/gohud and importing assets. This happens once and takes a moment.",
			"The window reopens by itself when it is done.")
	# 🛑 **Draw the notice first**, then block. An import stops the whole process, so calling it before
	#    drawing leaves the person looking at an empty window the whole time.
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if not linked and not _link(source):
		_say("Could not link gohud",
			"Creating addons/gohud failed. On Windows a junction needs a Developer Mode or an elevated shell.",
			"Run  bash run.sh  in this folder instead — it makes the same link.")
		return
	var code := _reimport()
	if code != 0:
		_say("The import failed",
			"Godot returned %d while importing this project." % code,
			"Run  bash run.sh  in this folder to see the full log.")
		return
	_relaunch()


## Makes a link pointing at the add-on source — a link, not a copy, so edits to the source show through.
func _link(source: String) -> bool:
	var project := _project_dir()
	DirAccess.make_dir_recursive_absolute(project.path_join("addons"))
	var link := project.path_join("addons/gohud")
	var output: Array = []
	if OS.get_name() == "Windows":
		# 🔑 Unlike a symbolic link, a junction can be made without administrator rights.
		OS.execute("cmd", ["/c", "mklink", "/J", link.replace("/", "\\"), source.replace("/", "\\")],
			output, true)
	else:
		OS.execute("ln", ["-sfn", source, link], output, true)
	return FileAccess.file_exists(ADDON_MARKER)


## Builds the class cache. 🛑 It does not reach the running window — which is why we reopen right after.
func _reimport() -> int:
	var output: Array = []
	return OS.execute(OS.get_executable_path(),
		["--headless", "--path", _project_dir(), "--import"], output, true)


func _relaunch() -> void:
	var arguments := PackedStringArray(["--path", _project_dir(), "--"])
	arguments.append_array(OS.get_cmdline_user_args())
	arguments.append(RETRY_FLAG)
	OS.create_process(OS.get_executable_path(), arguments)
	get_tree().quit()


# ── The front-door screen ──────────────────────────────────────────────

func _build() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.color = BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var centre := CenterContainer.new()
	centre.name = "Centre"
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var column := VBoxContainer.new()
	column.name = "Message"
	column.add_theme_constant_override(&"separation", 14)
	column.custom_minimum_size.x = 560
	centre.add_child(column)

	var brand := Label.new()
	brand.text = "gohud"
	brand.add_theme_font_size_override(&"font_size", 44)
	brand.add_theme_color_override(&"font_color", INK)
	column.add_child(brand)

	_title = _text(column, 22, ACCENT)
	_body = _text(column, 15, INK)
	_hint = _text(column, 14, DIM)


func _text(parent: Node, size: int, ink: Color) -> Label:
	var node := Label.new()
	node.add_theme_font_size_override(&"font_size", size)
	node.add_theme_color_override(&"font_color", ink)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.custom_minimum_size.x = 560
	parent.add_child(node)
	return node


func _say(title: String, body: String, hint: String) -> void:
	_title.text = title
	_body.text = body
	_hint.text = hint
