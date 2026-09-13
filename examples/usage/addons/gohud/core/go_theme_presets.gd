## 📚 **프리셋 이름표.** 이름 하나로 테마·스킨·아이콘 묶음을 찾는다.
##
## ```gdscript
## GoUi.use_preset(GoThemePresets.SCIFI_DARK)          # 고르기
## for id in GoThemePresets.ids(): print(id)             # 목록
## GoThemePresets.register(my_preset)                    # 내 것 더하기
## ```
##
## ## 🛑 `preload` 하지 않는다
## 프리셋은 테마를 참조하고, 테마는 SVG 를 참조한다. 애드온을 막 설치해 **아직 임포트하지 않은**
## 프로젝트에서 상수로 preload 하면 그 파일 하나 때문에 `GoUi` 가 통째로 로드에 실패한다.
## 그래서 경로만 들고 있다가 **부를 때** 읽고, 없으면 조용히 `null` 을 돌려준다(위젯은 기본값으로 돈다).
@tool
class_name GoThemePresets
extends RefCounted

## gohud 가 담아 보내는 여섯 가지.
const DEFAULT_DARK := &"default_dark"
const DEFAULT_LIGHT := &"default_light"
const SCIFI_DARK := &"scifi_dark"
const SCIFI_LIGHT := &"scifi_light"
const MEDIEVAL_DARK := &"medieval_dark"
const MEDIEVAL_LIGHT := &"medieval_light"

const FOLDER := "res://addons/gohud/themes/presets/"

## 이름 → 경로. 순서가 곧 고르개에 보이는 순서다.
const BUILTIN := {
	DEFAULT_DARK: FOLDER + "default_dark.tres",
	DEFAULT_LIGHT: FOLDER + "default_light.tres",
	SCIFI_DARK: FOLDER + "scifi_dark.tres",
	SCIFI_LIGHT: FOLDER + "scifi_light.tres",
	MEDIEVAL_DARK: FOLDER + "medieval_dark.tres",
	MEDIEVAL_LIGHT: FOLDER + "medieval_light.tres",
}

static var _loaded: Dictionary[StringName, GoThemePreset] = {}
static var _extra: Dictionary[StringName, GoThemePreset] = {}


## 🔑 **폴더에 있는 프리셋 파일 이름 전부** — 로드하지 않고 이름만 본다.
##
## `themes/presets/` 에 `.tres` 를 하나 떨어뜨리면 코드를 고치지 않아도 고르개에 뜬다. 그래서 새 테마는
## `tools/new_theme.py` 가 파일만 만들면 끝난다(2026-09-13 — 테마를 더 들일 예정이라는 요청).
## 🛑 내보낸 게임에서는 텍스트 리소스가 `.remap` 을 달고 있을 수 있다 — 그 꼬리도 벗긴다.
static func scan_folder(folder := FOLDER) -> Array[StringName]:
	var out: Array[StringName] = []
	var dir := DirAccess.open(folder)
	if dir == null: return out
	for file in dir.get_files():
		var name := file
		if name.ends_with(".remap"): name = name.get_basename()
		if name.ends_with(".tres") or name.ends_with(".res"):
			var id := StringName(name.get_basename())
			if not out.has(id): out.append(id)
	out.sort()
	return out


## 고를 수 있는 **이름**만 — 기본 순서 → 폴더의 나머지 → 등록한 것. 로드하지 않으므로 에디터 시작
## 시점처럼 임포트가 끝나기 전에도 안전하다(설정 힌트가 이것을 쓴다).
static func names() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in BUILTIN: out.append(id)
	for id in scan_folder():
		if not out.has(id): out.append(id)
	for id in _extra:
		if not out.has(id): out.append(id)
	return out


## 이름으로 찾는다. 없거나 아직 임포트되지 않았으면 `null`.
## 기본 여섯이 아니어도 `themes/presets/<id>.tres` 가 있으면 읽는다.
static func find(id: StringName) -> GoThemePreset:
	if id.is_empty(): return null
	if _extra.has(id): return _extra[id]
	if _loaded.has(id): return _loaded[id]
	var path: String = BUILTIN[id] if BUILTIN.has(id) else FOLDER + String(id) + ".tres"
	if not ResourceLoader.exists(path): return null
	var found := ResourceLoader.load(path) as GoThemePreset
	if found == null: return null
	_loaded[id] = found
	return found


## 호스트 프로젝트의 프리셋을 더한다. 같은 이름이면 기본 것을 덮는다.
## 🛑 `id` 가 비어 있으면 찾을 수 없으므로 넣지 않는다.
static func register(preset: GoThemePreset) -> void:
	if preset == null or preset.id.is_empty(): return
	_extra[preset.id] = preset


## 등록한 프리셋을 뺀다.
static func unregister(id: StringName) -> void:
	_extra.erase(id)


## 고를 수 있는 이름 전부(기본 여섯 + 등록한 것). 실제로 읽히는 것만 센다.
static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in names():
		if find(id) != null and not out.has(id): out.append(id)
	return out


## 위 이름들의 프리셋 자체.
static func all() -> Array[GoThemePreset]:
	var out: Array[GoThemePreset] = []
	for id in ids():
		var found := find(id)
		if found != null: out.append(found)
	return out


## 🛑 검사·에디터 재시작용. 읽어 둔 프리셋을 버린다(등록한 것은 남긴다).
static func reset() -> void:
	_loaded.clear()
