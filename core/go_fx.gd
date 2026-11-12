## ✨ **The look's light and sparkles** — the pieces a celebration is made of, shared by `GoRewardBurst` and
## `GoRevealFx`: a painted light (`fx_glow`, `fx_ring`, `fx_rays`, `fx_rays_thin`, `fx_sparkle`, `fx_glint` from
## `GoUi.skin().widget_art`, else a soft white gradient a tint colours), additive, and a one-shot sparkle spray.
##
## ```gdscript
## var glow := GoFx.light_rect(&"fx_glow", 240.0)       # centred on its position, additive
## layer.add_child(glow)
## var pop := GoFx.sparkles(14, 0.6, 260.0, 1.0)        # count, life (s), speed (dp/s), unit
## layer.add_child(pop); pop.position = centre; pop.restart()
## ```
## 🛑 Display only.
class_name GoFx
extends RefCounted


## The skin's painted light `art_name`, else a soft white radial (a ring for `fx_ring`) a tint colours.
static func light(art_name: StringName) -> Texture2D:
	var art := GoUi.skin().widget_art(art_name)
	return art if art != null else fallback_light(art_name)


## A square TextureRect of `side` dp showing `art_name`'s light, centred on its position (its pivot at its centre),
## additive, ignoring the mouse. A gradient stand-in is tinted the look's gold.
static func light_rect(art_name: StringName, side: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = light(art_name)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.size = Vector2.ONE * side
	rect.position = -rect.size * 0.5
	rect.pivot_offset = rect.size * 0.5
	rect.material = additive()
	if rect.texture is GradientTexture2D: rect.self_modulate = GoUi.color(GoTheme.WARNING_FILL).lerp(Color.WHITE, 0.4)
	return rect


## A look without the painted light: a soft white radial (or ring) the light's tint colours.
static func fallback_light(art_name: StringName) -> Texture2D:
	var g := Gradient.new()
	if art_name == &"fx_ring":
		g.offsets = PackedFloat32Array([0.0, 0.8, 0.9, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	elif art_name == &"fx_glow":
		g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
	else:
		g.offsets = PackedFloat32Array([0.0, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	return tex


## An additive blend (light adds onto what is under it).
static func additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


## A one-shot spray of `count` painted sparkles that fly out all round at up to `speed` dp/s (times `unit`), slow down
## and fade over `life` seconds. Not emitting: `restart()` fires it.
static func sparkles(count: int, life: float, speed: float, unit: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = count
	p.lifetime = life
	p.explosiveness = 1.0
	var art := GoUi.skin().widget_art(&"fx_sparkle")
	p.texture = art if art != null else fallback_light(&"fx_glow")
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = speed * 0.45 * unit
	p.initial_velocity_max = speed * unit
	p.damping_min = speed * 0.8 * unit
	p.damping_max = speed * 1.2 * unit
	p.scale_amount_min = 0.6 * unit
	p.scale_amount_max = 1.4 * unit
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.2))
	curve.add_point(Vector2(0.2, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curve
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	fade.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	p.color_ramp = fade
	p.material = additive()
	return p
