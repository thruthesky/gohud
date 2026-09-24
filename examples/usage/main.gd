# This file is an example of making a very simple screen with gohud.
#
# Words worth knowing first:
# - Node: the part a screen or a game is built from in Godot.
# - Scene: a bundle of nodes. This example's scene file is main.tscn.
# - Object: the actual thing made from that blueprint. A node is one kind of object.
#
# Control and RenderingServer in this file come with Godot.
# GoUi, GoTheme, GoForm, GoScroll, GoStyle and GoDialogs come from the gohud add-on.
# That is, the names beginning with Go are not GDScript syntax but this add-on's class names.
#
# [What exactly is GoUi?]
# GoUi is the class that picks gohud's shared design settings and hands out values matching the current one.
# Put simply, think of it as "the counter where our UI asks about the design settings it shares".
# Things such as "let us use the dark design", "what is the background color right now?" and "how big is
# the title text?" are handled through GoUi. Besides the theme it covers spacing, icons and shared strings.
# GoUi itself is not a button or a popup you see on screen.
# The actual screen parts are made with classes such as GoStyle.button() and GoDialogs, below.
#
# [Where does GoUi come from?]
# This example project contains the following file.
#   examples/usage/addons/gohud/core/go_ui.gd
# Open it and these two lines are near the top.
#   class_name GoUi
#   extends RefCounted
# `class_name GoUi` is the declaration "register this script's class under the name GoUi".
# Once Godot has read and registered the project's scripts, other .gd files can write GoUi too.
# A class usable from the project's other scripts like this is called a global class.
# That is why main.gd declares no GoUi variable and needs no separate import statement.
# The file name go_ui.gd alone does not give this; the class_name declaration registers the name.
# So to use it in a new project, that project has to have the gohud add-on files in it.
#
# When this example is opened as a Godot project, the path of the file above is this.
#   res://addons/gohud/core/go_ui.gd
# res:// means "the top folder of the Godot project currently open".
# Here examples/usage/project.godot exists, so examples/usage/ is that folder.
# Just keep the gohud development repository's core/go_ui.gd apart from the copy inside this example.
#
# [Why use GoUi directly instead of making GoUi.new()?]
# use_preset(), theme(), color() and the rest in go_ui.gd are defined as static func.
# A static function is called on the class name itself, without making a new object.
# So you simply write GoUi.theme(). GoUi is a class extending RefCounted and not a Node that goes into
# the scene tree, so it is never added to the screen with something like add_child(GoUi).
# GoForm.new() and GoDialogs.new(), by contrast, are code that makes the real nodes each screen uses.
#
# GoUi.config holds the settings object gohud shares.
# These settings are static too, so several screens share them through GoUi within one run.
# GoUi.use_preset(...) below is not a setting private to Main; it changes the shared preset.
# To have several screens use the same design, it is easiest to settle it at app start, before any UI is built.
# The design can be changed while running too, but a theme or a background color you applied yourself
# has to be applied again.
# The RenderingServer background color below in particular applies the color as of the moment that line runs.
#
# [Which function do you use when? The lines below are comments giving examples of use.]
#   GoUi.use_preset(&"default_dark")       → when picking the app's shared design bundle
#   GoUi.theme()                          → when you need the current Theme to apply to a Control node
#   GoUi.color(GoTheme.BACKGROUND)         → when you need the current design's background color
#   GoUi.color(GoTheme.ACCENT)             → when you need the current design's accent color
#   GoUi.metric(GoTheme.GAP)               → when you need the shared spacing value between UI parts
#   GoUi.font_size(GoTheme.ROLE_TITLE)     → when you need the font size for a title
# GoTheme.BACKGROUND is the label meaning "background color", and GoUi.color(...) fetches the real color.
# UI you wrote yourself, for instance, can match the other gohud parts by taking its colors and gaps from GoUi.
# GoStyle uses these values internally, so you need not fetch them yourself every time you make a plain button.
# In this main.gd, GoUi is used to "pick a design → get the theme → get the background color".
#
# [What is its relationship to GoRuntime in the project settings?]
# GoRuntime is a separate node (an autoload) created automatically when the app starts.
# This example's project.godot registers GoRuntime as an autoload.
# GoRuntime tracks window size changes, screen scaling, the virtual keyboard height and so on.
# The reason the name GoUi can be used is the class_name registration explained above.
# GoUi's theme and color lookups themselves work even without autoloading GoRuntime.
#
# The whole run goes like this.
# 1. Godot prepares the Main node of main.tscn and calls _ready().
# 2. _ready() settles the look of the screen and makes the title, the button and the popup manager node.
# 3. When the user presses the "Open popup" button, _on_open_pressed() is called.
# 4. That function opens an information popup and waits until the popup is closed.

# extends means "inherit this class's features and use them". This is called inheritance.
# Control is the basic node that handles a UI's position, size, theme and so on.
# This script is attached to the Main node, of type Control, inside main.tscn.
# Below, "the current node" means exactly that Main node.
extends Control

# var is the syntax that makes a variable. A variable is a place that gives a value a name.
# dialogs is a variable name we chose, and it will hold the popup manager object later.
# `: GoDialogs` is the type annotation "this variable will hold an object of type GoDialogs".
# A type means the kind of a value. String is text, for instance, and int is a whole number.
#
# This line only declares the variable; it does not make the popup manager object yet.
# Right now the value of dialogs is null, that is, "it points at no object yet".
# The real object is made by GoDialogs.new() inside _ready(), below.
#
# Declared outside any function, it can be used from several functions in this script.
# A variable declared this way is called a member variable.
# It is here so that the object stored in _ready() can be used in _on_open_pressed() as well.
var dialogs: GoDialogs


# func is the syntax that defines a function. A function name is followed by parentheses.
# _ready() is a special function name that Godot has settled on.
# Godot calls it automatically once this node and its children are in the scene tree and ready.
# The scene tree is the structure that connects the running nodes as parents and children.
# It usually runs once, when a node is first prepared; it is not a function that runs every frame.
# That makes it a good place for work such as building the first screen, as in this example.
#
# Empty parentheses mean this function takes no values (no parameters).
# -> void means "it hands no result back to the caller".
# The indented lines after the closing : are this function's body.
# GDScript tells what belongs where by indentation, so the indentation has to be kept.
func _ready() -> void:
	# 1. Settle the design the screen will use.
	# A Theme is the UI design settings — font sizes, colors, button shapes and the like.
	# A preset is a design bundle prepared in advance so it can be picked and used straight away.
	# Passing "default_dark" to use_preset() picks gohud's default dark design.
	# The UI uses these settings as it is built, so pick them before making any node.
	#
	# Let us read GoUi.use_preset(&"default_dark") one part at a time.
	#   GoUi           → the name of the class that handles the shared UI settings.
	#   use_preset     → the name of a function defined inside the GoUi class.
	#   "default_dark" → the preset name passed to that function.
	# So it means "call GoUi's use_preset function and pick the default_dark preset".
	# use_preset() is the function that picks a design; a theme is the settings data of the design picked.
	# A preset holds a skin (the way things are decorated) and an icon set along with the theme.
	# The dot (.) is the symbol used to reach an item belonging to the class or object on its left.
	# On this line it reaches a function, but it also reaches settings properties, as in GoUi.config.
	# The value inside the parentheses is the material passed to the function, and is called an argument.
	# Functions like this on GoUi are static, so they are called without making an object with GoUi.new().
	# &"default_dark" is a value of the type StringName.
	# It is much like the plain string "default_dark", but is a type for handling names used over and over.
	# Here, read it as "the name of the preset to pick".
	GoUi.use_preset(&"medieval_light")


	# GoUi.theme() hands back the Godot Theme object currently picked.
	# The theme on the left is the current node's theme property, inherited from Control. It came through extends Control.
	# Through Control you can use not only theme but font, font_size, color, position, size and many more properties.
	# A property can be thought of as a setting the object holds. Writing self.theme is the same thing.
	# Give a parent Control a theme and the child UI can inherit and use that theme too.
	theme = GoUi.theme()

	# Match the default background color, seen in the empty parts of the screen, to the theme as well.
	# GoTheme.BACKGROUND is the label (a constant) used when looking up "the background color".
	# A constant, unlike a variable, is a name whose settled value does not change.
	# GoUi.color(...) hands back the real color (a Color) for that label.
	# That color is passed to RenderingServer, Godot's screen-drawing feature.
	# When parentheses nest, read it as the inner result being passed to the outer function.
	RenderingServer.set_default_clear_color(GoUi.color(GoTheme.BACKGROUND))

	# 2. Make a form that keeps a sensible margin inside the screen.
	# GoForm is a container that works the content's margins out from the screen size, the safe area and so on.
	# A Container is a node that arranges the position and size of its child UI.
	# .new() is the function that makes one real object from a class, its blueprint.
	# GoForm.new() makes a real GoForm node and puts that node into the form variable.
	#
	# := means "settle the variable's type automatically from the value on the right, and store that value".
	# Here it is the same as writing var form: GoForm = GoForm.new().
	# form, declared inside a function, is a local variable reachable by name only inside this function.
	var form := GoForm.new()

	# .new() alone does not put the node into the scene tree.
	# add_child(form) attaches form as a child of the current Main node.
	# add_child(...) with no target in front of it is the same as self.add_child(...).
	# self points at the current node this script is attached to.
	# A node takes part in the screen only once it is connected to the running scene tree like this.
	add_child(form)

	# 3. Make an area that can be moved up and down when the content grows longer than the screen.
	# GoScroll turns horizontal scrolling off by default and uses vertical scrolling when it is needed.
	# Right now there is only a title and a button, so with everything fitting no scrollbar is needed.
	var scroll := GoScroll.new()

	# This time it is form.add_child(...), so the parent is form, not Main.
	# The parents and children are now connected in the order Main -> form -> scroll.
	form.add_child(scroll)

	# 4. Make a box that lays the title and the button out from top to bottom.
	# GoStyle.column() is a helper function that makes and hands back a VBoxContainer for vertical layout.
	# It also matches the gap between children to gohud's settings.
	# content is a variable name chosen to mean "the box that holds the actual screen content".
	var content := GoStyle.column()

	# Put content inside the scrolling area.
	# From now on, a title or a button added to content is laid out vertically and scrolls with it.
	scroll.add_child(content)

	# 5. Make the screen's title.
	# A Label is the node that shows text for the user to read.
	# The first argument to GoStyle.label() is the string shown on screen as it is.
	# A String is text data wrapped in quotes, such as "My first gohud".
	# The second argument, GoTheme.ROLE_TITLE, says to use the text style meant for titles.
	# The comma (,) separates the arguments passed to a function.
	#
	# This one line does two things, from the inside out.
	#   ① GoStyle.label(...) makes the title node.
	#   ② content.add_child(...) puts that title into the vertical box.
	# Rather than being stored in a variable, the node just made is passed straight to another function.
	content.add_child(GoStyle.label("My first gohud", GoTheme.ROLE_TITLE))

	# 6. Prepare the node that will take care of opening and closing popups.
	# Put a real GoDialogs object into dialogs, declared at the top of the file.
	# The variable is already declared, so var is not written again here.
	# A variable does not copy the object itself into place; it points at the object that was made.
	dialogs = GoDialogs.new()

	# The popup manager node is attached as a child of Main, not of content.
	# GoDialogs manages the popup screens internally, so it is kept out of the title-and-button column.
	# Here we only get ready to use popups; no information popup is opened yet.
	add_child(dialogs)

	# 7. Make the button the user will press.
	# GoStyle.button() is passed these three values, in order.
	#   first: "Open popup" — the text shown on the button.
	#   second: _on_open_pressed — the function to run when the button is pressed.
	#   third: GoStyle.Tone.PRIMARY — the button style that emphasises a main action.
	# Tone is an enum gathering the button style choices, and PRIMARY is one of them.
	#
	# It matters that _on_open_pressed has no () after it here.
	# _on_open_pressed passes the function itself, saying "please run this function later".
	# A function value that can be called later like this is called a Callable.
	# Write _on_open_pressed() instead and the function runs right there and then.
	#
	# A button has a pressed signal that announces "I was pressed".
	# GoStyle.button() connects that signal to the function it was given, internally.
	# So no popup opens now; the function runs when the button is actually pressed.
	# Finally, the button just made is put into content as a child.
	# The title was added first, so the button sits below the title.
	# Inside parentheses, code can be split over several lines, as below.
	content.add_child(GoStyle.button(
		"Open popup", _on_open_pressed, GoStyle.Tone.PRIMARY
	))

	# Once this much has run, the work of building the first screen is done.
	# The local variable names form, scroll and content cannot be used outside this function, but
	# the nodes attached as children stay in the scene tree and keep making up the screen.
	# The main nodes we made are related like this (the add-on's internal helper nodes are left out).
	# Main (the current node)
	# ├─ form (GoForm: margins)
	# │  └─ scroll (GoScroll: vertical scrolling)
	# │     └─ content (VBoxContainer: vertical layout)
	# │        ├─ title (Label)
	# │        └─ "Open popup" button (Button)
	# └─ dialogs (GoDialogs: popup management)


# This function is the one passed above as the button's action.
# Unlike _ready(), Godot does not find this name and call it by itself.
# It runs when the button is pressed because it was passed to GoStyle.button() and connected there.
# A name shaped _on_<target>_<event> is a naming convention often used for event-handling functions.
# Here, read it as "what to do when the open button was pressed".
func _on_open_pressed() -> void:
	# dialogs is the very popup manager object made in _ready().
	# dialogs.alert(...) opens an information popup with a confirm button.
	# The three strings in the parentheses appear in these places.
	#   "Hello"                              → the popup title
	#   "gohud is working."                  → the popup body
	#   "OK"                                 → the text on the button inside the popup
	# To change what the screen says, change the text inside these quotes.
	#
	# await makes this function wait, before running its next line, until an asynchronous job finishes.
	# Here, having opened the popup, it waits until the user answers it — by pressing OK, for instance.
	# The whole game does not stop. While it waits, the screen and button input keep working.
	# Press "OK" and the popup side reports the answer, and this waiting function carries on.
	await dialogs.alert("Hello", "gohud is working.", "OK")

	# Once the popup is answered, the wait above ends and running carries on below here.
	# There is no further command right now, so the function ends.
	# Note that alert() hands back no result, which is why no result is stored in a variable here either.
	# If you need "something to do after the popup closes", write it below at the same indentation.
