## A picture's selected halo. Drawing the same silhouette behind it keeps the glow outside irregular island edges.
@tool
class_name GoWorldTourGlow
extends Control

## The halo's reach beyond the island, as a share of the picture's height.
const HALO_REACH := 0.15


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	var glow := ShaderMaterial.new()
	glow.shader = load("res://addons/gohud/themes/skins/world_tour_glow.gdshader")
	material = glow
	resized.connect(queue_redraw)


func _draw() -> void:
	var picture := get_parent()
	if picture == null or not picture.has_method(&"draw_art"): return
	var data: Dictionary = picture.call(&"_picture_data")
	if data.is_empty(): return
	(material as ShaderMaterial).set_shader_parameter(&"island_stage", int(picture.get("stage")) if data.masked else 0)
	var source: Texture2D = data.source
	var texel := Vector2.ONE / source.get_size()
	var region: Rect2 = data.region
	(material as ShaderMaterial).set_shader_parameter(&"atlas_pixel_size", texel)
	(material as ShaderMaterial).set_shader_parameter(&"atlas_region", Vector4(region.position.x * texel.x,
			region.position.y * texel.y, region.end.x * texel.x, region.end.y * texel.y))
	# One textured draw over the island's rectangle grown by the halo's reach; the shader samples neighbouring alpha
	# to form the halo (and masks other islands in the shared atlas) instead of redrawing the island.
	var scale_factor := minf(size.x / region.size.x, size.y / region.size.y)
	var origin := (size - region.size * scale_factor) * 0.5
	var reach := region.size.y * HALO_REACH
	var src := region.grow(reach)
	(material as ShaderMaterial).set_shader_parameter(&"reach", reach)
	draw_texture_rect_region(source, Rect2(origin - Vector2.ONE * reach * scale_factor, src.size * scale_factor), src)
