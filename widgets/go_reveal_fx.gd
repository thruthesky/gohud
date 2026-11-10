## 🎆 **A reveal's celebration on a window** — the light a result card comes in with: a burst where an item lands (a
## flash, a shockwave ring, a spray of sparkles), rays turning behind the window, confetti raining down, the window
## jolting on an impact, and a key breathing once it is up.
##
## ```gdscript
## var fx := GoRevealFx.mount(end_window)        # once per window: one layer behind its card, one over it
## var reveal := GoReveal.new(self)
## reveal.fx = fx                                # its slams burst and jolt as they land, its entrance thumps
## reveal.enter(end_window, 0.0).slam(star, 0.6)
## reveal.play()
## fx.rays(stars, 3.0)                           # later: rays behind the window, centred on the stars
## fx.confetti()
## fx.breathe(next_key)
## fx.clear()                                    # the window closes or shows another card
## ```
##
## Its layers fill the window (`GoSurface`): `under` sits behind the card (over the scrim) and holds the rays, the
## layer itself sits over the card and holds the bursts and the confetti. Every size follows the item it is about (its
## size on screen), so one call reads the same on a phone and a desktop.
## ♿ **`GoConfig.reduce_motion`:** no burst, confetti, jolt or breathing; the rays show still and soft.
## 🎨 arcade_light paints the light (`fx_glow`, `fx_ring`, `fx_rays`, `fx_rays_thin`, `fx_sparkle` — `GoFx`); the
##    confetti takes the look's fills (`WARNING_FILL`, `INFO_FILL`, `DANGER_FILL`, `SUCCESS_FILL`, `ACCENT_FILL`).
## 🛑 Display only: what it celebrates, and when, is the caller's.
class_name GoRevealFx
extends Control

const _META := &"go_reveal_fx"
## A burst: the flash's and the ring's length (s), the sparkles' life (s).
const BURST_SECONDS := 0.5
const BURST_SPARKLES := 14
const BURST_LIFE := 0.6
## The rays: how fast the two layers turn (degrees a second, opposite ways) and how long they take to open.
const RAYS_TURN := 22.0
const RAYS_TURN_THIN := -15.0
const RAYS_OPEN_SECONDS := 0.5
## Confetti: pieces, how long each falls.
const CONFETTI_PIECES := 72
const CONFETTI_LIFE := 2.6
## A jolt's start (dp at scale 1, for strength 1) and how fast it dies (dp a second).
const SHAKE_DP := 9.0
const SHAKE_DECAY := 70.0
## A breath: how much bigger at its peak, and one breath's length (s).
const BREATHE_TO := 1.06
const BREATHE_SECONDS := 1.1

## The window it plays on.
var surface: GoSurface
## The layer behind the card (the rays).
var under: Control

var _rays: Array[Dictionary] = [] # {holder, item, layers: Array[TextureRect], turns: Array[float]}
var _breathing: Array[Control] = []
var _breath_pivots: Array[Vector2] = []
var _shake := 0.0
var _clock := 0.0


## The fx layers of `window` (made on the first call; the same pair after).
static func mount(window: GoSurface) -> GoRevealFx:
	if window.has_meta(_META):
		var found: Variant = window.get_meta(_META)
		if is_instance_valid(found): return found as GoRevealFx
	var fx := GoRevealFx.new()
	fx.name = "RevealFx"
	fx.surface = window
	fx.under = Control.new()
	fx.under.name = "RevealFxUnder"
	for layer: Control in [fx.under, fx]:
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		window.add_child(layer)
	window.move_child(fx.under, window.card.get_index()) # behind the card, over the scrim
	window.set_meta(_META, fx)
	return fx


func _init() -> void:
	set_process(false)


## A flash, a shockwave ring and a spray of sparkles on `item`'s centre, sized to it (`strength` 1: a star landing).
func burst(item: Control, strength := 1.0) -> void:
	if GoUi.config.reduce_motion or not _ready_on(item): return
	var side := _side(item)
	var holder := _holder(self, item)
	var glow := GoFx.light_rect(&"fx_glow", side * 2.4 * strength)
	var ring := GoFx.light_rect(&"fx_ring", side * 1.1 * strength)
	var spray := GoFx.sparkles(roundi(BURST_SPARKLES * strength), BURST_LIFE, side * 3.4, side / 90.0)
	for part: CanvasItem in [glow, ring, spray]: holder.add_child(part)
	spray.restart()
	var t := holder.create_tween().set_parallel(true)
	t.tween_property(glow, "scale", Vector2.ONE * 1.3, BURST_SECONDS).from(Vector2.ONE * 0.5) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(glow, "modulate", Color(1.0, 1.0, 1.0, 0.0), BURST_SECONDS).from(Color(1.6, 1.6, 1.6, 1.0))
	t.tween_property(ring, "scale", Vector2.ONE * 2.3, BURST_SECONDS).from(Vector2.ONE * 0.35) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(ring, "modulate:a", 0.0, BURST_SECONDS).from(1.0)
	t.chain().tween_interval(maxf(0.0, BURST_LIFE + 0.1 - BURST_SECONDS))
	t.chain().tween_callback(holder.queue_free)


## Rays turning behind the window, centred on `item` and `size_share` times its size across; they open, then turn
## until `clear`.
func rays(item: Control, size_share := 3.0) -> void:
	if not _ready_on(item): return
	var side := _side(item) * size_share
	var holder := _holder(under, item)
	var layers: Array[TextureRect] = [GoFx.light_rect(&"fx_glow", side * 0.7), GoFx.light_rect(&"fx_rays", side),
			GoFx.light_rect(&"fx_rays_thin", side * 0.8)]
	for layer in layers: holder.add_child(layer)
	_rays.append({holder = holder, item = item, layers = layers, turns = [0.0, RAYS_TURN, RAYS_TURN_THIN]})
	if GoUi.config.reduce_motion:
		holder.modulate.a = 0.55
	else:
		holder.modulate.a = 0.0
		holder.scale = Vector2.ONE * 0.2
		var t := holder.create_tween().set_parallel(true)
		t.tween_property(holder, "modulate:a", 1.0, RAYS_OPEN_SECONDS * 0.6)
		t.tween_property(holder, "scale", Vector2.ONE, RAYS_OPEN_SECONDS).set_trans(Tween.TRANS_BACK) \
				.set_ease(Tween.EASE_OUT)
	set_process(true)


## Confetti in the look's colours rains from the top of the window's area over the card.
func confetti() -> void:
	if GoUi.config.reduce_motion or not is_inside_tree() or size.x <= 0.0: return
	var unit := size.y / 720.0
	var p := CPUParticles2D.new()
	p.name = "Confetti"
	p.one_shot = true
	p.amount = CONFETTI_PIECES
	p.lifetime = CONFETTI_LIFE
	p.explosiveness = 0.8
	p.randomness = 0.5
	p.texture = _confetti_piece()
	p.position = Vector2(size.x * 0.5, -20.0 * unit)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(size.x * 0.5, 10.0 * unit)
	p.direction = Vector2.DOWN
	p.spread = 30.0
	p.gravity = Vector2(0.0, 420.0 * unit)
	p.initial_velocity_min = 120.0 * unit
	p.initial_velocity_max = 380.0 * unit
	p.damping_min = 40.0 * unit
	p.damping_max = 90.0 * unit
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.scale_amount_min = 0.7 * unit
	p.scale_amount_max = 1.3 * unit
	# Each piece flips as it falls: its width swings through the turn.
	var flip := Curve.new()
	for i in 9: flip.add_point(Vector2(i / 8.0, 0.25 + 0.75 * absf(cos(i * PI * 0.75))))
	p.split_scale = true
	p.scale_curve_x = flip
	var keep := Curve.new()
	keep.add_point(Vector2(0.0, 1.0))
	keep.add_point(Vector2(1.0, 1.0))
	p.scale_curve_y = keep
	var colours := Gradient.new()
	colours.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var fills: Array[StringName] = [GoTheme.WARNING_FILL, GoTheme.INFO_FILL, GoTheme.DANGER_FILL, GoTheme.SUCCESS_FILL,
			GoTheme.ACCENT_FILL]
	colours.offsets = PackedFloat32Array(range(fills.size()).map(func(i: int) -> float: return float(i) / fills.size()))
	colours.colors = PackedColorArray(fills.map(func(fill: StringName) -> Color: return GoUi.color(fill)))
	p.color_initial_ramp = colours
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.8, 1.0])
	fade.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	p.color_ramp = fade
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## The window jolts (`strength` 1: a star landing), dying out by itself.
func shake(strength := 1.0) -> void:
	if GoUi.config.reduce_motion or surface == null: return
	_shake = maxf(_shake, SHAKE_DP * strength)
	set_process(true)


## `item` (a key) breathes, a little bigger and back, until `clear`.
func breathe(item: Control) -> void:
	if GoUi.config.reduce_motion or item == null or _breathing.has(item): return
	_breathing.append(item)
	_breath_pivots.append(item.pivot_offset)
	set_process(true)


## Whether any rays or breathing play (tests).
func is_playing() -> bool:
	return not _rays.is_empty() or not _breathing.is_empty() or _shake > 0.0


## Every effect off at once: the rays, the bursts, the confetti, the breathing (its key back to its own size), the
## jolt (the window back in its place).
func clear() -> void:
	for layer: Control in [self, under]:
		if layer == null: continue
		for child in layer.get_children(): child.queue_free()
	_rays.clear()
	for i in _breathing.size():
		var item := _breathing[i]
		if is_instance_valid(item):
			item.scale = Vector2.ONE
			item.pivot_offset = _breath_pivots[i]
	_breathing.clear()
	_breath_pivots.clear()
	if _shake > 0.0 and surface != null: surface.pose_offset = Vector2.ZERO
	_shake = 0.0
	set_process(false)


func _process(delta: float) -> void:
	_clock += delta
	for r in _rays:
		var item: Control = r.item
		if not is_instance_valid(item): continue
		r.holder.position = _local(under, item.get_global_rect().get_center())
		if GoUi.config.reduce_motion: continue
		for i in r.layers.size():
			(r.layers[i] as TextureRect).rotation += deg_to_rad(r.turns[i]) * delta
	var breath := 1.0 + (BREATHE_TO - 1.0) * (0.5 - 0.5 * cos(_clock * TAU / BREATHE_SECONDS))
	for item in _breathing:
		if not is_instance_valid(item): continue
		# Every frame: a container's sort puts the scale back, and the size can change.
		item.pivot_offset = item.size * 0.5
		item.scale = Vector2.ONE * breath
	if _shake > 0.0 and surface != null:
		_shake = maxf(0.0, _shake - SHAKE_DECAY * delta)
		surface.pose_offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake) * 0.7) \
				if _shake > 0.0 else Vector2.ZERO
	if _rays.is_empty() and _breathing.is_empty() and _shake <= 0.0: set_process(false)


func _ready_on(item: Control) -> bool:
	return item != null and is_inside_tree() and item.is_inside_tree()


## A holder on `layer` at `item`'s centre.
func _holder(layer: Control, item: Control) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.position = _local(layer, item.get_global_rect().get_center())
	layer.add_child(holder)
	return holder


## `item`'s larger side on screen, in this layer's units.
func _side(item: Control) -> float:
	var on_screen := item.get_global_rect().size
	var k := get_global_transform().get_scale().x
	return maxf(on_screen.x, on_screen.y) / (k if k > 0.0 else 1.0)


static func _local(layer: Control, global: Vector2) -> Vector2:
	return layer.get_global_transform().affine_inverse() * global


static var _piece: Texture2D


## A small white strip a confetti piece is drawn from (the ramp colours it).
static func _confetti_piece() -> Texture2D:
	if _piece == null:
		var image := Image.create(14, 8, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_piece = ImageTexture.create_from_image(image)
	return _piece
