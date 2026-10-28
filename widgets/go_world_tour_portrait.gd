## A world-tour detail picture with the softly rounded corners of the painted frame.
@tool
class_name GoWorldTourPortrait
extends TextureRect

const ROUND_CLIP := preload("res://addons/gohud/themes/skins/world_tour_portrait.gdshader")

## Radius as a share of the smaller side, keeping the frame proportionate on every screen.
@export_range(0.0, 0.5, 0.01) var corner_share := 0.065:
	set(value):
		corner_share = clampf(value, 0.0, 0.5)
		_update_clip()

## Softly blend the picture's top and bottom into artwork behind it. Zero leaves the image unchanged.
@export_range(0.0, 0.15, 0.01) var edge_fade := 0.0:
	set(value):
		edge_fade = clampf(value, 0.0, 0.15)
		_update_clip()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	var clip := ShaderMaterial.new()
	clip.shader = ROUND_CLIP
	material = clip
	resized.connect(_update_clip)


func _ready() -> void:
	_update_clip()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAW:
		# Texture and stretch mode can change without a resize; update the drawn image bounds then.
		_update_clip()


func _update_clip() -> void:
	var clip := material as ShaderMaterial
	if clip == null: return
	var image_top := 0.0
	var image_height := size.y
	if texture != null and stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
		var dimensions := texture.get_size()
		if dimensions.x > 0.0 and dimensions.y > 0.0:
			image_height = dimensions.y * minf(size.x / dimensions.x, size.y / dimensions.y)
			image_top = (size.y - image_height) * 0.5
	_set_uniform(clip, &"control_size", size)
	_set_uniform(clip, &"corner_radius", minf(size.x, size.y) * corner_share)
	_set_uniform(clip, &"edge_fade", edge_fade)
	_set_uniform(clip, &"image_top", image_top)
	_set_uniform(clip, &"image_height", maxf(image_height, 0.001))


func _set_uniform(clip: ShaderMaterial, key: StringName, value: Variant) -> void:
	if clip.get_shader_parameter(key) != value:
		clip.set_shader_parameter(key, value)
