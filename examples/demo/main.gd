## 🚪 **데모의 문간** — `godot` 한 번으로 이 폴더가 열리게 하는 자리.
##
## 🛑 이 파일만은 gohud 의 이름(`GoUi`·`GoStyle`…)을 **한 글자도 쓰지 않는다.** 애드온 링크나 임포트
##    캐시가 없으면 그 이름들은 파싱 단계에서 터지고, 사람이 보는 것은 빈 창과
##    `Identifier "GoUi" not declared` 한 줄뿐이다 — 이 데모가 실제로 겪던 증상이 그것이다.
##    문간만은 그 상황에서도 떠서, 무엇이 없는지 말하고 스스로 고친다.
##
## ## 하는 일
## 1. `addons/gohud` 링크와 클래스 캐시가 있으면 곧장 홈(`home.tscn`)으로 넘긴다.
## 2. 없으면 애드온을 링크하고 임포트를 한 번 돌린 뒤 **창을 다시 연다**.
##    🔑 임포트는 실행 중인 프로세스에 반영되지 않는다 — 클래스 이름은 시작할 때 한 번 읽힌다.
## 3. 그래도 안 되면 무엇을 해야 하는지 화면에 적는다(빈 화면을 남기지 않는다).
extends Control

const ADDON_MARKER := "res://addons/gohud/plugin.cfg"
const HOME_SCENE := "res://home.tscn"
## 다시 연 창에 붙는 표식. 🛑 이것이 없으면 준비가 끝내 안 될 때 창이 끝없이 다시 열린다.
const RETRY_FLAG := "--gohud-bootstrapped"

# 애드온이 없을 때도 그려야 하므로 테마 토큰을 쓸 수 없다 — 문간 한 장만의 색이다.
const BG := Color("#0b111e")
const INK := Color("#e6edf7")
const DIM := Color("#8fa3bd")
const ACCENT := Color("#71d9e9")

var _title: Label
var _body: Label
var _hint: Label


func _ready() -> void:
	name = "Main"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	if _addon_ready():
		# 🛑 `_ready` 안에서 곧장 바꾸면 트리가 자식을 들이는 중이라 엔진이 거부한다
		#    ("Parent node is busy adding/removing children" — 실측). 한 박자 미룬다.
		get_tree().change_scene_to_file.call_deferred(HOME_SCENE)
		return
	_bootstrap()


# ── 준비 확인 ──────────────────────────────────────────────────────────

## 애드온이 **이 프로세스에서 쓸 수 있는가.** 파일이 제자리에 있는 것만으로는 모자라다 —
## 클래스 이름은 임포트가 남긴 캐시에서 오고, 그 캐시가 없으면 `GoUi` 는 없는 이름이다.
func _addon_ready() -> bool:
	if not FileAccess.file_exists(ADDON_MARKER): return false
	for entry in ProjectSettings.get_global_class_list():
		if String(entry.get("class", "")) == "GoUi": return true
	return false


## 애드온 원본이 있는 폴더. 이 데모는 gohud 저장소의 `examples/demo` 안에 산다.
func _addon_source() -> String:
	var here := _project_dir()
	var root := here.get_base_dir().get_base_dir()   # examples/demo → examples → gohud
	return root if FileAccess.file_exists(root.path_join("plugin.cfg")) else ""


func _project_dir() -> String:
	return ProjectSettings.globalize_path("res://").trim_suffix("/")


# ── 첫 실행 준비 ───────────────────────────────────────────────────────

func _bootstrap() -> void:
	if OS.get_cmdline_user_args().has(RETRY_FLAG):
		_say("gohud is still not linked",
			"The add-on was linked and the project was re-imported, but its classes are still missing.",
			"Run  bash run.sh  in this folder and read the import log.")
		return
	var source := _addon_source()
	if source.is_empty():
		_say("gohud was not found",
			"This demo expects the add-on two folders up, at gohud/plugin.cfg — the layout of the repository it ships in.",
			"Copy the add-on to addons/gohud, or run  bash run.sh  from a full checkout.")
		return
	_say("Setting up gohud",
		"Linking addons/gohud and importing assets. This happens once and takes a moment.",
		"The window reopens by itself when it is done.")
	# 🛑 안내를 **먼저 한 장 그리고** 나서 붙잡는다. 임포트는 프로세스를 통째로 멈추므로,
	#    그리기 전에 부르면 사람은 그동안 빈 창만 본다.
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if not FileAccess.file_exists(ADDON_MARKER) and not _link(source):
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


## 애드온 원본을 가리키는 링크를 만든다 — 복사가 아니라 링크라 원본을 고치면 그대로 보인다.
func _link(source: String) -> bool:
	var project := _project_dir()
	DirAccess.make_dir_recursive_absolute(project.path_join("addons"))
	var link := project.path_join("addons/gohud")
	var output: Array = []
	if OS.get_name() == "Windows":
		# 🔑 접합(junction)은 심볼릭 링크와 달리 관리자 권한 없이도 만들어진다.
		OS.execute("cmd", ["/c", "mklink", "/J", link.replace("/", "\\"), source.replace("/", "\\")],
			output, true)
	else:
		OS.execute("ln", ["-sfn", source, link], output, true)
	return FileAccess.file_exists(ADDON_MARKER)


## 클래스 캐시를 만든다. 🛑 실행 중인 창에는 반영되지 않는다 — 그래서 뒤이어 다시 연다.
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


# ── 문간 화면 ──────────────────────────────────────────────────────────

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
