## 🎁 **One sheet, one pick.** It bundles the theme (colors·engine controls), the skin (the shapes the code draws) and the icons.
##
## ## Why bundle them
## Changing the look wholesale, the way sci-fi does, takes all three moving together — swap the palette to teal
## while the joystick stays round and it sits half-done. Leave the three to be plugged in separately and
## **combinations missing one or two of them** are certain to appear.
##
## ```gdscript
## GoUi.use_preset(GoThemePresets.SCIFI_DARK)     # all three change at once
## ```
##
## ## Making your own preset
## 1. Duplicate one of the `.tres` files in `themes/presets/`.
## 2. Put your own `Theme` in `theme` and your own `GoSkin` in `skin` (empty means gohud's default look).
## 3. `GoThemePresets.register(preload("res://ui/my_preset.tres"))` — now it can be picked by name.
##
## 🛑 A field left empty **falls back to the default** — leave `skin` empty and you get gohud's original look;
##    leave `icons` empty and you get the default icon set. A preset that only changes colors fills in `theme` alone.
@tool
class_name GoThemePreset
extends Resource

## The name used to pick it from code (`&"scifi_dark"`). 🛑 Empty and the registry cannot find it.
@export var id: StringName = &""

## The name to show on screen. Empty uses `id` as is.
@export var title := ""

## Is it a dark one — used to group the pickers. It has no effect on behavior.
@export var dark := true

## The look of colors, metrics, type and the engine's controls. Empty means gohud's default (dark) theme.
@export var theme: Theme

## The look of the spots the code draws itself. Empty means gohud's default look.
@export var skin: GoSkin

## The icon set. Empty means gohud's default set.
@export var icons: GoIconSet


## The name to show on screen.
func label() -> String:
	return title if not title.is_empty() else String(id)
