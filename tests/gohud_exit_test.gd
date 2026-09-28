## 🧪 **gohud leaves nothing in memory at exit** — the verdict comes from the runner, not from this file:
##
##   GOHUD_EXIT_CLEAN=1 GOHUD_TEST_SCRIPT=res://addons/gohud/tests/gohud_exit_test.gd bash addons/gohud/tools/run_tests.sh
##
## ## 🛑 Why this is needed (2026-09-28)
## 1.2.0 declared `GoIconSet.layers` as an exported `Array[GoIconSet]`. From then on, merely loading
## `go_icon_set.gd` made every run of the editor build — `godot --headless` included — end with
## "ERROR: 1 resources still in use at exit": Godot caches each export's default value, that default was an empty
## array typed to the script itself, and nothing clears the cache. Harmless in a game, but a game team's headless
## pipeline that stops on any `ERROR:` line stopped on it. No check saw it — the unit tests leave their own test
## nodes behind anyway, and the runner never read what Godot prints after `quit()`.
##
## ## What is checked
## The leak report is printed after `quit()`, where no script can read it, so this file only **uses** gohud the way
## a game does and quits; `run_tests.sh` with `GOHUD_EXIT_CLEAN=1` fails when anything under the add-on is still in
## use. ① every script under `core/`, `widgets/`, `services/` and `themes/` loads ② icon sets stacked through
## `GoConfig.extra_icons` (which fills `layers`) look a name up and draw it ③ everything made here is freed.
extends SceneTree

const ROOT := "res://addons/gohud"
const FOLDERS := ["core", "widgets", "services", "themes"]

var passed := 0
var failed: Array[String] = []


func _initialize() -> void:
	var scripts := PackedStringArray()
	for folder in FOLDERS: scripts.append_array(_scripts(ROOT.path_join(folder)))
	var broken := PackedStringArray()
	for file in scripts:
		var script: GDScript = load(file)
		if script == null or not script.can_instantiate(): broken.append(file)
	check(scripts.size() > 40 and broken.is_empty(), "every gohud script loads (%d, broken: %s)" % [scripts.size(), ", ".join(broken)])

	GoUi.reset()
	GoUi.config.extra_icons = [GoIconLibrary.icon_set()] as Array[GoIconSet]
	var icons := GoUi.icons()
	check(icons.layers.size() == 2 and icons.texture(GoIconSet.CLOSE) != null, "stacked icon sets resolve a name (layers: %d)" % icons.layers.size())
	var mark := icons.node(GoIconSet.CLOSE, 24)
	check(mark is TextureRect, "a stacked set draws a node")
	mark.free()
	var loose := GoIconSet.new()
	loose.layers = [null, "not a set", icons]
	check(loose.has_icon(GoIconSet.CLOSE), "entries of layers that are not icon sets are skipped")
	var hint := ""
	for property in loose.get_property_list():
		if property.name == "layers" and property.hint == PROPERTY_HINT_TYPE_STRING: hint = property.hint_string
	check(hint == "%d/%d:GoIconSet" % [TYPE_OBJECT, PROPERTY_HINT_RESOURCE_TYPE], "the inspector still offers only icon sets for layers (%s)" % hint)
	GoUi.reset()

	print("gohud exit tests: %d/%d passed" % [passed, passed + failed.size()])
	for line in failed: print("FAIL %s" % line)
	quit(0 if failed.is_empty() else 1)


func check(condition: bool, label: String) -> void:
	if condition: passed += 1
	else: failed.append(label)


## Every `.gd` under `folder`, sub-folders included.
func _scripts(folder: String) -> PackedStringArray:
	var found := PackedStringArray()
	for entry in ResourceLoader.list_directory(folder):
		if entry.ends_with("/"): found.append_array(_scripts(folder.path_join(entry.trim_suffix("/"))))
		elif entry.get_extension() == "gd": found.append(folder.path_join(entry))
	return found
