## A picture's selected halo. Drawing the same silhouette behind it keeps the glow outside irregular island edges.
@tool
class_name GoWorldTourGlow
extends Control


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
	# One textured draw; the shader samples neighboring alpha to form the halo instead of redrawing the island.
	picture.call(&"draw_art", self, Vector2.ZERO, Color.WHITE)
