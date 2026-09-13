## 📸 **데모(`examples/demo`)의 위젯 화면을 섹션마다 찍는다** — 갤러리에는 없는 배치가 여기 있다.
##
## ```
## bash addons/gohud/tools/demo_shots.sh /tmp/demo_shots      # 심링크·임포트까지 알아서
## ```
##
## 🛑 데모 코드는 손대지 않는다 — `sim.gd` 의 `_open_explore(index)` 를 밖에서 부를 뿐이다.
##    사용자가 지적한 그림(두 줄로 갈라진 `Done`·잘린 글로우·비좁은 슬롯·밋밋한 드롭다운)은 전부
##    **데모**에서 나왔는데, 촬영은 갤러리만 찍고 있었다(2026-09-13, I-56).
## 🛑 `--headless` 로는 그림이 나오지 않는다 · `frame_post_draw` 를 기다리지 않는다(갤러리와 같은 이유).
extends SceneTree

const SIZES := [
	{"name": "phone", "size": Vector2i(390, 844)},
	{"name": "desktop", "size": Vector2i(1280, 800)},
]

var out_dir := "user://demo_shots"
## 찍을 섹션만 고른다(`--only=selection,hud`). 비우면 전부.
var only: PackedStringArray = []
## 찍을 크기만 고른다(`--sizes=desktop`). 비우면 전부.
var sizes: PackedStringArray = []
## 🔑 **봇을 돌린 뒤에도 찍는다**(`--play`). 섹션을 열기만 하면 데모가 스테이지 위젯을 비활성으로 두어
##    회색만 찍힌다(2026-09-13, I-61·65). "Play this widget" 과 같은 길(`_play_current`)로 봇을 4× 로
##    돌리고 끝나면 **활성 상태의 마지막 장면**을 찍는다 — 코치마크의 `Done` 카드, 뜬 알림이 여기서 보인다.
##    데모의 `_shot_dir` 도 함께 켜서 봇이 장면 직후에 저장하는 그림(`NN-key.png`)까지 얻는다.
var play := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out_dir = arg.substr(6)
		elif arg.begins_with("--only="): only = arg.substr(7).split(",", false)
		elif arg.begins_with("--sizes="): sizes = arg.substr(8).split(",", false)
		elif arg == "--play": play = true
	GoUi.config.reduce_motion = true
	GoUi.config.surface_fade_in = false
	DirAccess.make_dir_recursive_absolute(out_dir)
	create_timer(240.0).timeout.connect(func() -> void:
		printerr("FAIL demo shots watchdog")
		quit(2))
	DisplayServer.window_set_position(Vector2i(40, 40))
	var scene: PackedScene = load("res://sim.tscn")
	var entries: Array = SimActs.list()
	for spec in SIZES:
		if not sizes.is_empty() and not sizes.has(spec.name): continue
		# 🛑 데모 프로젝트는 `window_width_override=2560` 을 갖고 있어 `root.size` 만으로는 첫 화면이
		#    2560×1600 으로 찍혔다(실측). 창과 뷰포트를 **둘 다** 맞추고 넉넉히 기다린다.
		DisplayServer.window_set_size(spec.size)
		await _settle(6)
		_pin_scale(spec.size)
		await _settle(8)
		var sim := scene.instantiate()
		root.add_child(sim)
		# 🛑 데모의 `_scale_window` 는 `_scaling` 가드로 시작한다 — 켜 두면 즉시 돌아가므로 데모 코드를
		#    손대지 않고도 배율 재설정을 막을 수 있다(`_pin_scale` 만으로는 다음 프레임에 다시 덮였다).
		sim.set("_scaling", true)
		_pin_scale(spec.size)
		if play:
			sim.set("_shot_dir", ProjectSettings.globalize_path(out_dir).path_join(spec.name + "_bot"))
			DirAccess.make_dir_recursive_absolute(sim.get("_shot_dir"))
			sim.call("_set_speed", 4.0)
		await _settle(12)
		_shot("%s_00_start" % spec.name)
		for index in entries.size():
			var key := String((entries[index] as Dictionary).get("key", str(index)))
			if not only.is_empty() and not only.has(key): continue
			sim.call("_open_explore", index)
			await _settle(14)
			_pin_scale(spec.size)
			await _settle(2)
			_shot("%s_%02d_%s" % [spec.name, index + 1, key])
			# 🔽 드롭다운은 **연 채로** 한 장 더 — 메뉴 판·라디오 표시는 열어야 보인다.
			for node in sim.find_children("*", "OptionButton", true, false):
				var picker := node as OptionButton
				if picker == null or not picker.is_visible_in_tree() or picker.item_count == 0: continue
				picker.show_popup()
				await _settle(6)
				_shot("%s_%02d_%s_open" % [spec.name, index + 1, key])
				picker.get_popup().hide()
				await _settle(2)
				break
			if play:
				sim.call("_play_current")
				# 🛑 `_running` 이 꺼질 때까지 기다린다 — 장면마다 길이가 달라 고정 프레임으로는 안 된다.
				#    🔑 **재생이 끝난 뒤의 화면은 쓸모없다** — 데모가 탐색 상태로 돌아가며 스테이지를 다시 지어
				#    회색이 된다(실측: `Clicks: 0` 으로 초기화). 활성 그림은 봇이 장면 직후 저장하는
				#    `<크기>_bot/NN-key.png` 이고, **순간 장면**(코치마크 카드·뜬 알림·프롬프트·시트)은 재생 중
				#    폴링해서 오버레이가 보이는 첫 순간을 잡는다.
				var waited := 0.0
				var seen: Dictionary = {}
				while sim.get("_running") and waited < 90.0:
					await create_timer(0.2).timeout
					waited += 0.2
					for cls in ["GoCoachMark", "GoSurface", "GoNotice", "GoPromptCard"]:
						for node in root.find_children("*", cls, true, false):
							var overlay := node as Control
							if overlay == null or not overlay.is_visible_in_tree() or overlay.get_global_rect().get_area() <= 0.0: continue
							# 코치마크는 **단계마다** 한 장 — 마지막 단계의 `Done` 이 두 줄로 갈라졌던 곳이다(사용자 지적).
							var tag: String = cls
							if cls == "GoCoachMark" and overlay.get("step") != null: tag = "%s_step%d" % [cls, int(overlay.get("step")) + 1]
							if seen.has(tag): break
							# 🛑 `visible` 이 켜진 **첫 프레임**은 페이드인 알파 0 이라 카드가 그림에 없다(실측: 화살표만
							#    남았다). 그렇다고 고정 시간을 기다리면 4× 봇이 그새 `Done` 을 눌러 카드가 사라진다(실측).
							#    코치마크는 **카드 알파가 찰 때까지만** 기다렸다가 곧바로 찍는다.
							if cls == "GoCoachMark":
								var card_node := overlay.get("card") as CanvasItem
								if card_node != null and card_node.modulate.a < 0.9: break
							else:
								await create_timer(0.3).timeout
							seen[tag] = true
							_pin_scale(spec.size)
							_shot("%s_%02d_%s_mid_%s" % [spec.name, index + 1, key, tag])
							break
				await _settle(4)
		sim.queue_free()
		await _settle(3)
	print("DEMO SHOTS DONE ", out_dir)
	quit(0)


## 🛑 데모의 `_scale_window` 는 창 크기가 바뀔 때마다 **화면 배율**(레티나 2×)을 곱해 콘텐츠를 키운다 —
##    헤드리스 검사는 창이 없어 배율이 1 이라 폰 배치가 나오지만, 창을 띄운 촬영에서는 390dp 창에
##    195dp 만 담겨 제목이 낱말 안에서 쪼개졌다(실측 `quic`/`k`). 찍기 직전에 배율을 1 로 되돌린다.
func _pin_scale(size: Vector2i) -> void:
	root.content_scale_factor = 1.0
	root.content_scale_size = size
	root.size = size


func _settle(count: int) -> void:
	for i in count:
		await process_frame


func _shot(label: String) -> void:
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	var path := out_dir.path_join(label + ".png")
	image.save_png(path)
	print("SHOT ", path, " ", image.get_size())
