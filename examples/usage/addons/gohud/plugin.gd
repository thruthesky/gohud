## 🔌 gohud 에디터 플러그인.
##
## ## 🛑 켜지 않아도 위젯은 전부 동작한다
## 이 플러그인이 하는 일은 **편의** 셋뿐이다.
##   ① Project Settings 에 `gohud/config/resource`(설정 `.tres` 경로)와
##      `gohud/theme/preset`(생김새 묶음 이름) 칸을 만든다
##   ② `GoRuntime` 오토로드를 등록한다(브레이크포인트·dp 배율·가상 키보드 추적)
##   ③ 기본 번역 CSV 를 프로젝트 번역 목록에 넣는다
##
## 끄면 그 셋만 빠지고, `GoSurface`·`GoSheet`·`GoStyle` 등은 그대로 쓸 수 있다.
## 애셋으로 배포할 때 "설치하자마자 동작" 이 중요하기 때문이다.
@tool
extends EditorPlugin

const AUTOLOAD_NAME := "GoRuntime"
const AUTOLOAD_PATH := "res://addons/gohud/core/go_runtime.gd"
const CONFIG_SETTING := "gohud/config/resource"
const PRESET_SETTING := "gohud/theme/preset"
const TRANSLATION_CSV := "res://addons/gohud/i18n/gohud.csv"
const TRANSLATION_SETTING := "internationalization/locale/translations"


func _enter_tree() -> void:
	_declare_config_setting()
	_declare_preset_setting()


func _exit_tree() -> void:
	pass


## 플러그인을 **활성화할 때 한 번** 불린다(`_enter_tree` 와 달리 에디터 재시작마다 불리지 않는다).
func _enable_plugin() -> void:
	_declare_config_setting()
	_declare_preset_setting()
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
	_register_translations()


func _disable_plugin() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)
	_unregister_translations()


## 설정 리소스 경로 칸을 만든다 — 에디터에서 골라 넣을 수 있게 파일 힌트를 준다.
func _declare_config_setting() -> void:
	if not ProjectSettings.has_setting(CONFIG_SETTING):
		ProjectSettings.set_setting(CONFIG_SETTING, "")
	ProjectSettings.set_initial_value(CONFIG_SETTING, "")
	ProjectSettings.add_property_info({
		"name": CONFIG_SETTING,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_FILE,
		"hint_string": "*.tres,*.res",
	})
	ProjectSettings.set_as_basic(CONFIG_SETTING, true)
	ProjectSettings.save()


## 생김새 묶음을 **고르는 칸**. 비워 두면 gohud 기본 모양이다.
## 🔑 코드 한 줄 없이 에디터에서 sci-fi 로 바꿀 수 있게 하는 것이 이 칸의 목적이다.
func _declare_preset_setting() -> void:
	if not ProjectSettings.has_setting(PRESET_SETTING):
		ProjectSettings.set_setting(PRESET_SETTING, "")
	ProjectSettings.set_initial_value(PRESET_SETTING, "")
	var names := PackedStringArray()
	# 🔑 폴더의 프리셋까지 — `tools/new_theme.py` 로 더한 테마가 코드 수정 없이 여기 뜬다.
	#    `names()` 는 로드하지 않고 이름만 보므로 임포트가 끝나기 전에도 안전하다.
	for id in GoThemePresets.names(): names.append(String(id))
	ProjectSettings.add_property_info({
		"name": PRESET_SETTING,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM_SUGGESTION,
		"hint_string": ",".join(names),
	})
	ProjectSettings.set_as_basic(PRESET_SETTING, true)
	ProjectSettings.save()


## 🛑 이미 있으면 넣지 않는다 — 플러그인을 껐다 켤 때마다 같은 항목이 쌓이면 안 된다.
func _register_translations() -> void:
	if not ResourceLoader.exists(TRANSLATION_CSV): return
	var list := PackedStringArray(ProjectSettings.get_setting(TRANSLATION_SETTING, PackedStringArray()))
	var base := TRANSLATION_CSV.get_basename()
	var added := false
	for locale in GoUi.LOCALES:
		var path := "%s.%s.translation" % [base, locale]
		if not ResourceLoader.exists(path) or list.has(path): continue
		list.append(path)
		added = true
	if added:
		ProjectSettings.set_setting(TRANSLATION_SETTING, list)
		ProjectSettings.save()


func _unregister_translations() -> void:
	var list := PackedStringArray(ProjectSettings.get_setting(TRANSLATION_SETTING, PackedStringArray()))
	var kept := PackedStringArray()
	var base := TRANSLATION_CSV.get_basename()
	for path in list:
		if not path.begins_with(base): kept.append(path)
	if kept.size() != list.size():
		ProjectSettings.set_setting(TRANSLATION_SETTING, kept)
		ProjectSettings.save()
