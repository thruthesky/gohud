## Paragraph direction for translated UI prose, independent of the parent layout direction.
@tool
class_name GoLocaleParagraph
extends Node


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE or what == NOTIFICATION_TRANSLATION_CHANGED:
		apply()


func apply() -> void:
	var label := get_parent() as Label
	if label == null: return
	var rtl := TextServerManager.get_primary_interface().is_locale_right_to_left(TranslationServer.get_locale())
	label.text_direction = Control.TEXT_DIRECTION_RTL if rtl else Control.TEXT_DIRECTION_LTR
