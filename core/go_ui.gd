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
const VERSION := "1.0.3"

## 이 애드온이 요구하는 **가장 낮은 엔진 버전**. `[major, minor]`.
##
## 🛑 이보다 낮은 엔진에서는 켜지지 않는다 — 켜지지 않는 정도가 아니라 **파싱 단계에서 죽는다.**
##    `FoldableContainer`·`DPITexture`·`mouse_behavior_recursive` 처럼 그 버전에 없는 이름을 쓰기 때문이다.
##    그래서 실행 중에 확인하는 것은 의미가 없고, 이 상수는 **검사와 문서가 한 곳을 보게** 하려고 둔다.
const MIN_ENGINE := [4, 6]


## 지금 엔진이 이 애드온을 돌릴 수 있는가.
static func engine_supported() -> bool:
	var info := Engine.get_version_info()
	if int(info.major) != int(MIN_ENGINE[0]): return int(info.major) > int(MIN_ENGINE[0])
	return int(info.minor) >= int(MIN_ENGINE[1])


## `"4.6"` 처럼 읽기 좋은 최소 버전 문구.
static func min_engine_string() -> String:
	return "%d.%d" % [MIN_ENGINE[0], MIN_ENGINE[1]]

## 설정 리소스의 경로를 담는 프로젝트 설정 키. 플러그인이 이 칸을 만든다.
const CONFIG_SETTING := "gohud/config/resource"

## 생김새 묶음 이름을 담는 프로젝트 설정 키. 플러그인이 이 칸을 만든다.
const PRESET_SETTING := "gohud/theme/preset"

const DEFAULT_THEME: Theme = preload("res://addons/gohud/themes/gohud_dark.tres")
const LIGHT_THEME: Theme = preload("res://addons/gohud/themes/gohud_light.tres")
const DEFAULT_ICONS: GoIconSet = preload("res://addons/gohud/icons/gohud_icons.tres")
const BUILTIN_TRANSLATIONS := "res://addons/gohud/i18n/gohud.csv"

## 기본 번역이 담고 있는 언어. 🛑 CSV 에 열을 더했으면 **여기도 더한다** — 없는 언어는
##    조각 파일이 만들어져도 등록되지 않아 조용히 영어로 나온다.
const LOCALES := [
	"en", "ko", "ja", "zh", "es", "pt", "de", "fr", "ru", "hi", "ar",
	"tr", "vi", "id", "th", "it", "pl", "uk", "nl", "zh_TW", "he",
]

## 설정이 바뀌었다 — 이미 떠 있는 위젯이 다시 그려야 한다.
## 🛑 `static signal` 은 Godot 4.x 에 없다. 그래서 콜백 목록을 직접 들고 있는다.
static var _watchers: Array[Callable] = []
static var _config: GoConfig
static var _resolved := false
static var _translations_loaded := false
static var _mobile_type := false
static var _base_font_sizes := {}
static var _default_skin: GoSkin


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

## 지금 고른 생김새 묶음. 이름이 비었거나 아직 임포트되지 않았으면 `null`.
## 설정 리소스가 비어 있으면 **프로젝트 설정**(`gohud/theme/preset`)을 본다 — 코드 없이 에디터에서 고를 수 있다.
static func preset() -> GoThemePreset:
	var id := config.preset
	if id.is_empty() and ProjectSettings.has_setting(PRESET_SETTING):
		id = StringName(str(ProjectSettings.get_setting(PRESET_SETTING, "")))
	return GoThemePresets.find(id)


## 🎁 생김새를 **통째로** 바꾼다 — 테마·스킨·아이콘이 함께 움직인다.
##
## ```gdscript
## GoUi.use_preset(GoThemePresets.SCIFI_DARK)
## GoUi.use_preset(my_preset)                    # GoThemePreset 을 직접 줘도 된다
## ```
##
## 🛑 직접 꽂아 둔 `config.theme`·`skin`·`icons` 를 **비운다** — 그래야 고른 묶음이 그대로 보인다.
##    한 칸만 자기 것으로 두고 싶으면 이 함수 뒤에 그 칸을 다시 채운다.
static func use_preset(value: Variant) -> void:
	var chosen: GoThemePreset = null
	var id: StringName = &""
	if value is GoThemePreset:
		chosen = value
		id = chosen.id
		GoThemePresets.register(chosen)
	elif value is StringName or value is String:
		id = StringName(value)
	var settings := config
	settings.theme = null
	settings.skin = null
	settings.icons = null
	settings.preset = id
	# 🛑 글자 크기 기준을 버린다 — 테마가 바뀌면 예전 테마의 크기를 되돌려 놓을 수 없다.
	_base_font_sizes.clear()
	_mobile_type = false
	_notify()


## 지금 쓰는 Theme. 설정이 비어 있으면 고른 묶음의 테마, 그것도 없으면 gohud 기본(어두운) 테마.
static func theme() -> Theme:
	var value := config.theme
	if value != null: return value
	var chosen := preset()
	if chosen != null and chosen.theme != null: return chosen.theme
	return DEFAULT_THEME


## 토큰을 채워 줄 예비 테마. `token_fallback` 이 꺼져 있으면 `null`.
static func _fallback_theme() -> Theme:
	return DEFAULT_THEME if config.token_fallback else null


## 지금 쓰는 **스킨** — 코드가 직접 그리는 자리(조이스틱·퀵슬롯·코치마크·칩)의 모양.
## 설정이 비어 있으면 고른 묶음의 스킨, 그것도 없으면 gohud 기본 모양.
static func skin() -> GoSkin:
	var value := config.skin
	if value != null: return value
	var chosen := preset()
	if chosen != null and chosen.skin != null: return chosen.skin
	# 🛑 상수로 두지 않는다 — `GoSkin` 은 `GoUi` 를 부르고 `GoConfig` 는 `GoSkin` 을 담는다.
	#    상수 초기화 시점에 만들면 그 고리가 로드 순서를 물고 늘어진다. 처음 쓸 때 만든다.
	if _default_skin == null: _default_skin = GoSkin.new()
	return _default_skin


## 지금 쓰는 아이콘 세트. 설정이 비어 있으면 고른 묶음의 세트, 그것도 없으면 gohud 기본 세트.
static func icons() -> GoIconSet:
	var value := config.icons
	if value != null: return value
	var chosen := preset()
	if chosen != null and chosen.icons != null: return chosen.icons
	return DEFAULT_ICONS


## 색 하나. `GoConfig.color_overrides` 가 테마보다 우선한다.
##
## 🔑 `*_fill`(막대 채움처럼 **넓은 면적**에 쓰는 색)은 **선택 토큰**이다 — 테마에 없으면 `_fill` 을
##    뗀 같은 이름으로 떨어진다. 덕분에 이 토큰을 모르는 테마를 꽂아도 자홍색이 뜨지 않는다.
static func color(key: StringName) -> Color:
	var overrides := config.color_overrides
	if overrides.has(key): return overrides[key]
	var name := String(key)
	if name.ends_with("_fill") and not _has_color(key):
		return color(StringName(name.trim_suffix("_fill")))
	return GoTheme.color_of(theme(), key, _fallback_theme())


## 이 색 토큰이 지금 테마(또는 예비 테마)에 **실제로 정의되어 있는가**.
static func _has_color(key: StringName) -> bool:
	var current := theme()
	if current != null and current.has_color(key, GoTheme.TYPE): return true
	var backup := _fallback_theme()
	return backup != null and backup.has_color(key, GoTheme.TYPE)


## 치수 하나(dp). `GoConfig.metric_overrides` 가 테마보다 우선한다.
static func metric(key: StringName) -> int:
	var overrides := config.metric_overrides
	if overrides.has(key): return overrides[key]
	if key == GoTheme.TOUCH: return config.min_touch_size
	return GoTheme.metric_of(theme(), key, _fallback_theme())


## 표면 StyleBox 한 장의 **사본**. 🛑 사본이 아니면 한 카드의 색 변경이 모든 카드에 번진다.
static func box(key: StringName) -> StyleBox:
	return GoTheme.box_of(theme(), key, _fallback_theme()).duplicate()


## 🪟 판 한 종류의 **불투명도(0.0~1.0)**. 1.0 은 꽉 찬 색, 0.8 이면 뒤가 20% 배어 나온다.
##
## ## 구체적인 것이 이긴다 — 네 층
## | 순서 | 어디서 | 단위 | 쓰는 때 |
## |---|---|---|---|
## | ① | `GoConfig.container_alpha_overrides[종류]` | 비율 | 이 프로젝트에서 **이 종류만** 다르게 |
## | ② | `GoConfig.metric_overrides[<종류>_alpha]` | **%** | 치수를 한 곳에 모아 두는 프로젝트의 관습을 따를 때 |
## | ③ | `GoConfig.container_alpha` | 비율 | 프로젝트의 **판 전부**를 한 번에 |
## | ④ | 테마의 `GoHud/constants/<종류>_alpha` | **%** | 생김새 묶음이 정한 값 — **정본** |
##
## 넷 다 없으면 1.0(꽉 찬 색)이다 — 이 토큰을 모르는 테마를 꽂아도 화면이 예전과 같다는 뜻이다.
##
## 🔑 **위젯 하나만** 다르게 하려면 이 함수를 거치지 않는다 — `GoSurface.alpha`,
##    `GoStyle.card(..., alpha)` 처럼 그 자리의 인자에 0.0~1.0 을 준다(음수면 이 함수로 떨어진다).
##
## ## 🛑 퍼센트는 **테마 상수 한 층에만** 있다
## 불투명도를 다루는 모든 자리는 비율(0.0~1.0)이다 — 위젯의 `alpha` 칸, `GoStyle` 인자,
## `GoConfig` 의 두 칸, 그리고 이 함수의 반환값까지. **`Theme` 의 constant 는 정수만 담을 수 있어서**
## 테마의 `<종류>_alpha` 와 그것을 덮는 통로(`metric_overrides` — 이름·타입이 테마 치수와 같다)만
## 퍼센트다. 그 두 자리에서만 100 으로 나눈다.
static func surface_alpha(variant := GoTheme.BOX_CARD) -> float:
	var settings := config
	var chosen: float = settings.container_alpha_overrides.get(variant, -1.0)
	if chosen >= 0.0: return clampf(chosen, 0.0, 1.0)
	var token := GoTheme.alpha_token(variant)
	# 🛑 이 통로만 퍼센트다 — 테마 치수를 덮는 일반 창구라 테마와 같은 단위를 쓴다.
	if settings.metric_overrides.has(token):
		return _alpha_ratio(settings.metric_overrides[token])
	if settings.container_alpha >= 0.0: return clampf(settings.container_alpha, 0.0, 1.0)
	# 🛑 없을 때는 **100** 으로 떨어진다 — `metric_of` 의 기본값 0 을 그대로 쓰면 판이 통째로 사라진다.
	return _alpha_ratio(GoTheme.metric_of(theme(), token, _fallback_theme(), 100))


## 테마 상수의 퍼센트(0~100) → 비율(0.0~1.0). 범위를 벗어난 값은 잘라 낸다 — 판이 사라지거나
## 두 배로 칠해지는 일이 테마 오타 하나로 일어나지 않게 한다.
static func _alpha_ratio(percent: int) -> float:
	return clampf(float(percent) / 100.0, 0.0, 1.0)


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


## ♿ 스크린리더가 한 마디로 읽을 수 있게 **조각들을 잇는다**. 빈 조각은 빠진다.
##
## ```gdscript
## node.accessibility_name = GoUi.spoken([label.text, error.text])
## ```
##
## 🛑 **위젯마다 `"%s %s"` 로 잇지 않는다.** 그렇게 하면 잇는 방식이 위젯마다 달라지고,
##    "화면에 나가는 글자를 코드에 박지 않는다" 는 규칙(검사가 지킨다)도 곳곳에서 새어 나간다.
##    잇는 규칙이 언어마다 달라져야 할 날이 오면 **여기 한 곳만** 고치면 된다.
## 🔑 구분자는 문구가 아니라 공백이다 — 번역 대상이 아니므로 키로 빼지 않는다.
static func spoken(parts: Array) -> String:
	var kept: Array[String] = []
	for part in parts:
		var word := str(part).strip_edges()
		if not word.is_empty(): kept.append(word)
	return " ".join(kept)


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
	_default_skin = null
	GoThemePresets.reset()
	_watchers.clear()
