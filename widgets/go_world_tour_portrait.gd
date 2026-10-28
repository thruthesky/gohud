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


func _update_clip() -> void:
	var clip := material as ShaderMaterial
	if clip == null: return
	clip.set_shader_parameter(&"control_size", size)
	clip.set_shader_parameter(&"corner_radius", minf(size.x, size.y) * corner_share)
