extends Control

var dialogs: GoDialogs

func _ready() -> void:
	GoUi.use_preset(&"medieval_dark")
	theme = GoUi.theme()
	var form := GoForm.new()
	add_child(form)
	var scroll := GoScroll.new()
	form.add_child(scroll)
	var content := GoStyle.column()
	content.add_child(GoStyle.label("My first gohud", GoTheme.ROLE_TITLE))
	content.add_child(GoStyle.button("Open Dialog", _on_open_pressed, GoStyle.Tone.PRIMARY))
	scroll.add_child(content)
	dialogs = GoDialogs.new()
	add_child(dialogs)

func _on_open_pressed() -> void:
	await dialogs.alert("Hello", "Gohud is working", "Ok")
	
	
	
