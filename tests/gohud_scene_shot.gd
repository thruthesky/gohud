## 📸 **씬 한 장을 실제로 그려** PNG 로 남긴다 — 예제 화면을 눈으로 확인할 때.
##
##   bash <godot 스킬>/scripts/xvfb_run.sh --out <폴더> --size 1000x2400 \
##     -e SHOT_SCENE=res://addons/gohud/examples/medieval/medieval.tscn \
##     -s res://addons/gohud/tests/gohud_scene_shot.gd
##
## 🛑 `--headless` 로는 스크린샷이 나오지 않는다 — 그리지 않기 때문이다.
##
## ## 🔑 왜 `examples/demo/shot.gd` 가 아니라 여기인가 (2026-09-16)
## 데모의 `shot.gd` 는 **그 데모 프로젝트 안**에 있고, 그 프로젝트의 `addons/gohud` 는 저장소 루트를
## 가리키는 심링크다. 그래서 컨테이너로 옮길 때 `examples/demo/addons/gohud/examples/demo/…` 로
## **제 안에 제가 다시 들어가고**, 임포트가 끝나지 않아 촬영이 타임아웃한다(실측: 600초 초과, 두 번).
## 이 파일은 **애드온 안**에 있으므로 호스트 프로젝트(재귀가 없는 보통의 게임 프로젝트)에서 그대로
## 부를 수 있다 — 애드온이 `res://addons/gohud/` 에 있기만 하면 된다.
##
## 🛑 컨테이너에 한글 글꼴이 없다 — 한글은 두부(□)로 나온다. 모양을 보는 것이 목적이다.
extends SceneTree

const FRAMES := 14


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var path := OS.get_environment("SHOT_SCENE")
	if path.is_empty():
		push_error("SHOT_SCENE 이 비었다 — 찍을 씬을 준다")
		quit(2)
		return
	var packed: PackedScene = load(path)
	if packed == null:
		# 🛑 왜 못 읽었는지 적는다 — "null instance" 한 줄만 남으면 임포트 문제인지 경로 문제인지 모른다.
		push_error("씬을 못 읽었다: %s — 임포트를 먼저 돌렸는가(--import)" % path)
		quit(2)
		return
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	# 자리가 잡힐 때까지 기다린다 — 배지·팝오버는 부모가 놓인 **다음 프레임**에 자리를 찾는다.
	for _frame in FRAMES: await process_frame
	await RenderingServer.frame_post_draw
	var out := OS.get_environment("SHOT_PATH")
	if out.is_empty(): out = "/out/scene.png"
	var image := root.get_texture().get_image()
	var result := image.save_png(out)
	print("SHOT %s — %dx%d %s" % [out, image.get_width(), image.get_height(),
		"ok" if result == OK else "실패 %d" % result])
	quit(0 if result == OK else 1)
