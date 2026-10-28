## A stage picture clipped to its island, so neighbouring art in a shared atlas cannot bleed into its rectangle.
@tool
class_name GoWorldTourPicture
extends Control

@export_range(1, 9) var stage := 1:
	set(value):
		stage = clampi(value, 1, 9)
		queue_redraw()
		if _glow != null: _glow.queue_redraw()

## Optional caller picture. Both ordinary textures and atlas regions work; the skin supplies the picture when unset.
@export var texture_override: Texture2D:
	set(value):
		texture_override = value
		queue_redraw()
		if _glow != null: _glow.queue_redraw()

var _glow: GoWorldTourGlow
var _stage_node: GoWorldTourNode
var _press_started := false
var _touch_index := -1
static var _atlas_images := {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	_glow = GoWorldTourGlow.new()
	_glow.visible = false
	add_child(_glow)
	_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	if get_parent() != null:
		_stage_node = get_parent().get_parent() as GoWorldTourNode
	# A picture in the detail pane remains inert; one in a node receives touches even beyond the button's rect.
	mouse_filter = Control.MOUSE_FILTER_STOP if _stage_node != null else Control.MOUSE_FILTER_IGNORE


func set_selected(on: bool) -> void:
	_glow.visible = on
	if on: _glow.queue_redraw()


## Transparent portions of a picture pass pointer events to the controls behind it, including neighbouring stages.
func _has_point(point: Vector2) -> bool:
	var data := _picture_data()
	if data.is_empty() or size.x <= 0.0 or size.y <= 0.0: return false
	var region: Rect2 = data.region
	var scale_factor := minf(size.x / region.size.x, size.y / region.size.y)
	var origin := (size - region.size * scale_factor) * 0.5
	var local_point := (point - origin) / scale_factor
	if not Geometry2D.is_point_in_polygon(local_point, _outline(stage, region, data.masked)): return false
	var source: Texture2D = data.source
	var key := source.get_instance_id()
	if not _atlas_images.has(key): _atlas_images[key] = source.get_image()
	var img: Image = _atlas_images[key]
	var pixel := Vector2i(region.position + local_point)
	return img != null and pixel.x >= 0 and pixel.y >= 0 and pixel.x < img.get_width() and pixel.y < img.get_height() and img.get_pixelv(pixel).a > 0.1


func _gui_input(event: InputEvent) -> void:
	if _stage_node == null: return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _touch_index == -1:
			_touch_index = touch.index
			_press_started = not _stage_node.disabled
			if _press_started: _stage_node.grab_focus()
		elif not touch.pressed and touch.index == _touch_index:
			if _press_started and not _stage_node.disabled and _has_point(touch.position): _stage_node.pressed.emit()
			_touch_index = -1
			_press_started = false
		accept_event()
		return
	if not (event is InputEventMouseButton): return
	var mouse := event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT: return
	# The GUI also receives mouse events synthesized for a finger. The screen-touch event already handled that press.
	if mouse.device == InputEvent.DEVICE_ID_EMULATION:
		accept_event()
		return
	if mouse.pressed:
		_press_started = not _stage_node.disabled
		if _press_started: _stage_node.grab_focus()
	else:
		if _press_started and not _stage_node.disabled and _has_point(mouse.position): _stage_node.pressed.emit()
		_press_started = false
	accept_event()


func _draw() -> void:
	draw_art(self, Vector2.ZERO, Color.WHITE)


## Draw the masked picture onto a canvas currently in its draw notification.
func draw_art(canvas: CanvasItem, offset: Vector2, tint: Color) -> void:
	var data := _picture_data()
	if data.is_empty() or size.x <= 0.0 or size.y <= 0.0: return
	var region: Rect2 = data.region
	var scale_factor := minf(size.x / region.size.x, size.y / region.size.y)
	var origin := (size - region.size * scale_factor) * 0.5
	var source: Texture2D = data.source
	var source_size := source.get_size()
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	for point in _outline(stage, region, data.masked):
		points.append(origin + point * scale_factor + offset)
		uvs.append((region.position + point) / source_size)
		colors.append(tint)
	canvas.draw_polygon(points, colors, uvs, source)


func _picture_data() -> Dictionary:
	var picture: Texture2D = texture_override if texture_override != null else GoUi.skin().world_tour_picture(stage)
	if picture == null: return {}
	var atlas := picture as AtlasTexture
	if atlas != null:
		if atlas.atlas == null: return {}
		var masked := texture_override == null and atlas.atlas.resource_path.ends_with("/world_tour_islands.png")
		return {"source": atlas.atlas, "region": atlas.region, "masked": masked}
	return {"source": picture, "region": Rect2(Vector2.ZERO, picture.get_size()), "masked": false}


## Coordinates are atlas pixels. Notches remove other islands where their bounding boxes overlap.
func _outline(n: int, region: Rect2, masked: bool) -> PackedVector2Array:
	if not masked: return PackedVector2Array([Vector2.ZERO, Vector2(region.size.x, 0), region.size, Vector2(0, region.size.y)])
	var atlas_points := PackedVector2Array()
	match n:
		6: atlas_points = PackedVector2Array([Vector2(435, 293), Vector2(713, 293), Vector2(713, 582), Vector2(425, 582), Vector2(425, 560), Vector2(250, 560), Vector2(250, 385), Vector2(335, 345), Vector2(435, 325)])
		7: atlas_points = PackedVector2Array([Vector2(40, 558), Vector2(250, 558), Vector2(250, 580), Vector2(424, 580), Vector2(424, 835), Vector2(40, 835)])
		8: atlas_points = PackedVector2Array([Vector2(427, 626), Vector2(750, 626), Vector2(750, 657), Vector2(911, 657), Vector2(911, 920), Vector2(427, 920)])
		9: atlas_points = PackedVector2Array([Vector2(1237, 638), Vector2(1601, 638), Vector2(1601, 933), Vector2(1116, 933), Vector2(1116, 657), Vector2(1237, 657)])
		_: return PackedVector2Array([Vector2.ZERO, Vector2(region.size.x, 0), region.size, Vector2(0, region.size.y)])
	var local := PackedVector2Array()
	for point in atlas_points: local.append(point - region.position)
	return local
