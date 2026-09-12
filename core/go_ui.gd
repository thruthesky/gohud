## 🚪 gohud 의 **단 하나의 관문**. 설정·테마·아이콘·문구를 여기서 꺼낸다.
##
## ## 오토로드가 필요 없다
## 전부 `static` 이다. 플러그인을 켜지 않아도, 오토로드를 등록하지 않아도
## `GoUi.color(GoTheme.ACCENT)` 가 바로 동작한다 — 애셋으로 배포할 때 가장 중요한 성질이다.
##
## 플러그인을 켜면 `GoRuntime` 오토로드가 붙어 **창 크기 추적·dp 배율·가상 키보드 높이**가
## 추가로 동작한다. 없어도 위젯은 전부 동작하고, 그 기능만 빠진다.
##
## ## 설정 넣기
## ```gdscript
## GoUi.config = preload("res://ui/my_gohud.tres")   # 코드에서
## # 또는 Project Settings > Gohud > Config 에 경로를 넣는다(플러그인이 그 칸을 만든다).
## ```
##
## ## 🛑 이 파일은 위젯을 참조하지 않는다
## `GoStyle`·`GoSurface` 등 모든 위젯이 이것을 참조한다. 반대 방향을 하나라도 만들면
## 순환 의존이 되어 `.new()` 가 통째로 실패한다.
@tool
class_name GoUi
extends RefCounted

## 이 애드온의 버전. `CHANGELOG.md` 와 같이 움직인다.
const VERSION := "1.0.0"

## 설정 리소스의 경로를 담는 프로젝트 설정 키. 플러그인이 이 칸을 만든다.
const CONFIG_SETTING := "gohud/config/resource"

const DEFAULT_THEME: Theme = preload("res://addons/gohud/themes/gohud_dark.tres")
const LIGHT_THEME: Theme = preload("res://addons/gohud/themes/gohud_light.tres")
const DEFAULT_ICONS: GoIconSet = preload("res://addons/gohud/icons/gohud_icons.tres")
const BUILTIN_TRANSLATIONS := "res://addons/gohud/i18n/gohud.csv"

## 기본 번역이 담고 있는 언어. 🛑 CSV 에 열을 더했으면 **여기도 더한다** — 없는 언어는
##    조각 파일이 만들어져도 등록되지 않아 조용히 영어로 나온다.
const LOCALES := ["en", "ko", "ja", "zh", "es", "pt", "de", "fr", "ru", "hi", "ar"]

## 설정이 바뀌었다 — 이미 떠 있는 위젯이 다시 그려야 한다.
## 🛑 `static signal` 은 Godot 4.x 에 없다. 그래서 콜백 목록을 직접 들고 있는다.
static var _watchers: Array[Callable] = []
static var _config: GoConfig
static var _resolved := false
static var _translations_loaded := false
static var _mobile_type := false
static var _base_font_sizes := {}


## 지금 설정. 처음 읽을 때 프로젝트 설정에 적힌 경로를 자동으로 불러온다.
static var config: GoConfig:
	get:
		if not _resolved:
			_resolved = true
			if _config == null: _config = _load_project_config()
			if _config == null: _config = GoConfig.new()
			_apply_config(_config)
		return _config
	set(value):
		if _config == value: return
		if _config != null and _config.changed_settings.is_connected(_notify):
			_config.changed_settings.disconnect(_notify)
		_config = value
		_resolved = true
		if _config == null: _config = GoConfig.new()
		_apply_config(_config)
		_notify()


static func _apply_config(value: GoConfig) -> void:
	if not value.changed_settings.is_connected(_notify):
		value.changed_settings.connect(_notify)
	if value.load_builtin_translations: _load_translations()


static func _load_project_config() -> GoConfig:
	if not ProjectSettings.has_setting(CONFIG_SETTING): return null
	var path := str(ProjectSettings.get_setting(CONFIG_SETTING, ""))
	if path.is_empty() or not ResourceLoader.exists(path): return null
	return ResourceLoader.load(path) as GoConfig


## 설정이 바뀔 때 불릴 콜백을 등록한다. 노드는 `_exit_tree` 에서 `unwatch` 한다.
static func watch(callback: Callable) -> void:
	if not _watchers.has(callback): _watchers.append(callback)


static func unwatch(callback: Callable) -> void:
	_watchers.erase(callback)


## 설정의 평범한 칸을 코드에서 바꾼 뒤 부른다 — 떠 있는 위젯이 다시 배치된다.
## (`theme`·`icons` 를 바꾸면 자동으로 불린다.)
static func refresh() -> void:
	_notify()


static func _notify() -> void:
	var alive: Array[Callable] = []
	for callback in _watchers:
		if callback.is_valid():
			alive.append(callback)
			callback.call()
	_watchers = alive


# ── 테마·아이콘 ────────────────────────────────────────────────────────

## 지금 쓰는 Theme. 설정이 비어 있으면 gohud 기본(어두운) 테마.
static func theme() -> Theme:
	var value := config.theme
	return value if value != null else DEFAULT_THEME


## 토큰을 채워 줄 예비 테마. `token_fallback` 이 꺼져 있으면 `null`.
static func _fallback_theme() -> Theme:
	return DEFAULT_THEME if config.token_fallback else null


## 지금 쓰는 아이콘 세트. 설정이 비어 있으면 gohud 기본 세트.
static func icons() -> GoIconSet:
	var value := config.icons
	return value if value != null else DEFAULT_ICONS


## 색 하나. `GoConfig.color_overrides` 가 테마보다 우선한다.
static func color(key: StringName) -> Color:
	var overrides := config.color_overrides
	if overrides.has(key): return overrides[key]
	return GoTheme.color_of(theme(), key, _fallback_theme())


## 치수 하나(dp). `GoConfig.metric_overrides` 가 테마보다 우선한다.
static func metric(key: StringName) -> int:
	var overrides := config.metric_overrides
	if overrides.has(key): return overrides[key]
	if key == GoTheme.TOUCH: return config.min_touch_size
	return GoTheme.metric_of(theme(), key, _fallback_theme())


## 표면 StyleBox 한 장의 **사본**. 🛑 사본이 아니면 한 카드의 색 변경이 모든 카드에 번진다.
static func box(key: StringName) -> StyleBox:
	return GoTheme.box_of(theme(), key, _fallback_theme()).duplicate()


## 역할의 글자 크기(dp). 모바일 축소가 켜져 있으면 이미 반영된 값이다.
static func font_size(role: StringName = GoTheme.ROLE_BODY) -> int:
	if config.base_font_size > 0 and role == GoTheme.ROLE_BODY: return config.base_font_size
	return GoTheme.font_size_of(theme(), role, _fallback_theme())


# ── 문구 ───────────────────────────────────────────────────────────────

## gohud 문구 하나를 **번역해서** 돌려준다.
##
## 순서: `text_overrides`(원문 그대로) → `text_keys` 의 키를 `tr()` → 이름 그대로.
## 🛑 번역 테이블에 키가 없으면 `tr()` 은 키를 그대로 돌려준다 — 화면에 `gohud_close` 가
##    보인다면 번역이 안 붙은 것이지 코드가 틀린 것이 아니다.
static func text(name: StringName) -> String:
	var overrides := config.text_overrides
	if overrides.has(name): return overrides[name]
	var key: String = config.text_keys.get(name, "")
	if key.is_empty(): return String(name)
	return TranslationServer.translate(key)


## 위 문구의 **번역 키**. 자동 번역 라벨(`auto_translate_mode`)에 그대로 넣을 때 쓴다.
static func text_key(name: StringName) -> String:
	if config.text_overrides.has(name): return config.text_overrides[name]
	return config.text_keys.get(name, String(name))


static func _load_translations() -> void:
	if _translations_loaded: return
	_translations_loaded = true
	if not ResourceLoader.exists(BUILTIN_TRANSLATIONS): return
	# 🛑 CSV 는 임포트 때 **언어마다 하나씩** `.translation` 으로 쪼개진다 — 원본 CSV 를
	#    로드하는 것이 아니라 그 조각들을 등록해야 한다. 조각이 아직 없으면(에디터를 한 번도
	#    돌리지 않은 사본) 조용히 지나간다: 문구는 키 그대로 나오고 위젯은 그대로 동작한다.
	var base := BUILTIN_TRANSLATIONS.get_basename()
	for suffix in LOCALES:
		var path := "%s.%s.translation" % [base, suffix]
		if not ResourceLoader.exists(path): continue
		var loaded := ResourceLoader.load(path) as Translation
		if loaded != null: TranslationServer.add_translation(loaded)


# ── 트리 접근(오토로드 없이) ────────────────────────────────────────────

## 지금 `SceneTree`. 🛑 `-s` 로 도는 검사·에디터에서는 `null` 일 수 있다 — 반드시 확인한다.
static func tree() -> SceneTree:
	var loop := Engine.get_main_loop()
	return loop as SceneTree if loop is SceneTree else null


## 선택 오토로드 `GoRuntime`. 플러그인을 켜지 않았으면 `null` 이고, 그래도 위젯은 동작한다.
static func runtime() -> Node:
	var scene := tree()
	return scene.root.get_node_or_null(^"GoRuntime") if scene != null else null


## 이 기기가 손에 드는 기기인가 — 진동·가상 키보드·안전영역의 판정 기준이다.
## 🛑 "창이 좁은가" 와 다르다. 작은 창으로 띄운 데스크톱에서 진동하면 안 된다.
static func is_handheld_platform() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios")


# ── 모바일 글자 축소 ───────────────────────────────────────────────────

## 좁은 화면에서 **글자만** 한 단계 줄인다. 터치 영역은 건드리지 않는다.
## `GoRuntime` 이 브레이크포인트가 바뀔 때 부른다. 오토로드가 없으면 아무도 부르지 않고,
## 그때는 테마 값 그대로 나온다(그것도 올바른 동작이다).
static func set_mobile_type(enabled: bool) -> void:
	if not config.shrink_type_on_mobile or _mobile_type == enabled: return
	var current := theme()
	if _base_font_sizes.is_empty():
		for type in current.get_font_size_type_list():
			for key in current.get_font_size_list(type):
				_base_font_sizes[[type, key]] = current.get_font_size(key, type)
		_base_font_sizes[[&"", &"default"]] = current.default_font_size
	_mobile_type = enabled
	for pair in _base_font_sizes:
		var base: int = _base_font_sizes[pair]
		var small := maxi(10, base - (4 if base >= 28 else (2 if base >= 14 else 1)))
		var value := small if enabled else base
		if pair[0] == &"": current.default_font_size = value
		else: current.set_font_size(pair[1], pair[0], value)
	_notify()


static func is_mobile_type() -> bool:
	return _mobile_type


## 🛑 검사·에디터 재시작용. 캐시를 비워 설정을 처음부터 다시 읽게 한다.
static func reset() -> void:
	if _config != null and _config.changed_settings.is_connected(_notify):
		_config.changed_settings.disconnect(_notify)
	_config = null
	_resolved = false
	_mobile_type = false
	_base_font_sizes.clear()
	_watchers.clear()
