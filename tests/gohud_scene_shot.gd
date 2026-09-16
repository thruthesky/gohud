## 📸 **Really draws one scene** and saves it as a PNG — for eyeballing an example screen.
##
##   bash <godot skill>/scripts/xvfb_run.sh --out <folder> --size 1000x2400 \
##     -e SHOT_SCENE=res://addons/gohud/examples/medieval/medieval.tscn \
##     -s res://addons/gohud/tests/gohud_scene_shot.gd
##
## 🛑 `--headless` produces no screenshot — it does not draw.
##
## ## 🔑 Why here and not `examples/demo/shot.gd` (2026-09-16)
## The demo's `shot.gd` lives **inside that demo project**, and that project's `addons/gohud` is a symlink
## pointing at the repository root. So when it is copied into a container it walks into **itself again** as
## `examples/demo/addons/gohud/examples/demo/…`, the import never finishes and the shot times out (measured: over 600 s, twice).
## This file lives **inside the add-on**, so a host project (an ordinary game project with no recursion) can
## call it as-is — all it needs is the add-on sitting at `res://addons/gohud/`.
##
## 🛑 The container has no Korean font — Korean renders as tofu (□). Shapes are the point here.
extends SceneTree

const FRAMES := 14


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var path := OS.get_environment("SHOT_SCENE")
	if path.is_empty():
		push_error("SHOT_SCENE is empty — give it a scene to shoot")
		quit(2)
		return
	var packed: PackedScene = load(path)
	if packed == null:
		# 🛑 Say why it failed to load — a bare "null instance" line hides whether it is an import or a path problem.
		push_error("could not load the scene: %s — was the import run first (--import)?" % path)
		quit(2)
		return
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	# Wait until layout settles — badges and popovers find their place on the **frame after** the parent is placed.
	for _frame in FRAMES: await process_frame
	await RenderingServer.frame_post_draw
	var out := OS.get_environment("SHOT_PATH")
	if out.is_empty(): out = "/out/scene.png"
	var image := root.get_texture().get_image()
	var result := image.save_png(out)
	print("SHOT %s — %dx%d %s" % [out, image.get_width(), image.get_height(),
		"ok" if result == OK else "failed %d" % result])
	quit(0 if result == OK else 1)
