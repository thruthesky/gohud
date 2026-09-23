## 🎨 A swappable **icon set**. Every gohud widget calls an icon by *name* alone,
## and this one resource decides what that name gets drawn with.
##
## ## Why a resource
## `preload` an icon into the code and the user has no way to change it. So it is pulled out into **a single
## `.tres`**: a project builds its own set, plugs it into `GoConfig.icons`, and every icon changes without a
## single line of widget code being touched.
##
## ## Three ways to hold a drawing
## | Approach | Fields to fill | Where it is used |
## |---|---|---|
## | **Textures** (SVG·PNG) | `textures` | gohud's default set. Color goes on through `modulate` |
## | **Paths**, loaded when first drawn | `paths` | big sets — the game set and the 1,000-icon library |
## | **An icon font** (Font Awesome·Material Symbols and the like) | `font` + `codepoints` | projects already using a font |
##
## Mixing them is fine. That is what makes **partial replacement** possible: keep the default set as the
## `fallback` and override only the few you want changed.
##
## ## How a name is found
## 1. **Every set's own drawings first**, level by level — this set, then its `layers` in order, then the
##    `fallback` of each of those. A set's own drawing is `textures` → `paths` → `codepoints`.
##    Own drawings beat any fallback: a partial set whose fallback is the default set does not hide the
##    engraved icons of a medieval set layered after it.
## 2. Nothing drew the name → its **alias** (`aliases`, from the first set in that order that has one) is
##    looked up the same way. One hop only, and only after the real names failed — a set that draws `gear`
##    itself keeps it.
## 3. Still nothing → an empty box that keeps its space, and a warning in debug builds.
##
## ## How to use it
## ```gdscript
## # ① One node by name — the same call whether it is a texture or a font.
## var mark := icons.node(GoIconSet.CLOSE, 20, Color.WHITE)
##
## # ② Attaching it to a button (a texture goes to Button.icon, a font to a child Label, on its own)
## GoStyle.apply_icon(button, GoIconSet.SETTINGS)
##
## # ③ Building a partial-replacement set
## var mine := GoIconSet.new()
## mine.fallback = GoUi.icons()            # everything else stays the default set
## mine.textures = {GoIconSet.CLOSE: preload("res://my_close.svg")}
##
## # ④ A whole folder of your own drawings, file name = icon name
## GoUi.config.icons = GoIconSet.from_folder("res://art/icons", GoUi.icons())
##
## # ⑤ Finding a name — by words, or by group
## GoUi.icons().search("arrow left")             # best matches first
## GoUi.icons().names_in_group(&"navigation")
## ```
##
## 🛑 This resource **never references a widget** — `GoStyle`·`GoSurface` reference it, so a reference in the
##    other direction becomes a circular dependency and it collapses as early as `.new()`
##    (close the cycle style → icon → icon button → style and it really does die that way).
@tool
class_name GoIconSet
extends Resource

# ── Semantic name constants ────────────────────────────────────────────
# Widget and game code use nothing but these names. Swap the set and the names stay.
# 🛑 Names not listed here are fine too — put them in `textures`/`codepoints` and they are found all the same.
#    The constants are here to stop typos and get editor completion, not to be an allowlist.

const CLOSE := &"close"
const BACK := &"back"
const FORWARD := &"forward"
const UP := &"up"
const DOWN := &"down"
const CHEVRON_LEFT := &"chevron_left"
const CHEVRON_RIGHT := &"chevron_right"
const CHEVRON_UP := &"chevron_up"
const CHEVRON_DOWN := &"chevron_down"
const MENU := &"menu"
const MORE := &"more"
const EXTERNAL := &"external"
const EXPAND := &"expand"
const COLLAPSE := &"collapse"

const CHECK := &"check"
const INFO := &"info"
const WARNING := &"warning"
const ERROR := &"error"
const SUCCESS := &"success"
const HELP := &"help"
const BELL := &"bell"
const CLOCK := &"clock"
const HOURGLASS := &"hourglass"

const USER := &"user"
const USERS := &"users"
const USER_PLUS := &"user_plus"
const CHAT := &"chat"
const HEART := &"heart"
const STAR := &"star"
const CROWN := &"crown"

const SETTINGS := &"settings"
const SLIDERS := &"sliders"
const DISPLAY := &"display"
const MOBILE := &"mobile"
const VOLUME_HIGH := &"volume_high"
const VOLUME_LOW := &"volume_low"
const VOLUME_OFF := &"volume_off"
const EYE := &"eye"
const EYE_OFF := &"eye_off"
const SUN := &"sun"
const MOON := &"moon"
const GLOBE := &"globe"

const PLUS := &"plus"
const MINUS := &"minus"
const TRASH := &"trash"
const EDIT := &"edit"
const SAVE := &"save"
const REFRESH := &"refresh"
const SEARCH := &"search"
const FILTER := &"filter"
const SORT := &"sort"
const COPY := &"copy"
const DOWNLOAD := &"download"
const UPLOAD := &"upload"
const PLAY := &"play"
const PAUSE := &"pause"
const STOP := &"stop"
const POWER := &"power"
const LOGOUT := &"logout"
const LOGIN := &"login"

const LOCK := &"lock"
const UNLOCK := &"unlock"
const SHIELD := &"shield"
const SHIELD_CHECK := &"shield_check"
const KEY := &"key"

const HOME := &"home"
const MAP := &"map"
const LOCATION := &"location"
const BAG := &"bag"
const BOX := &"box"
const COIN := &"coin"
const GIFT := &"gift"
const BOOK := &"book"

const LIST := &"list"
const GRID := &"grid"
const COLUMNS := &"columns"
const CHART := &"chart"

const SWORD := &"sword"
const BOLT := &"bolt"
const TARGET := &"target"
const FLAG := &"flag"
const POTION := &"potion"
const SKULL := &"skull"
const RUN := &"run"

# ── What the set holds ─────────────────────────────────────────────────

## The human-readable set name — shown by the editor inspector and the gallery example.
@export var set_name := ""

## One line of source·license. 🛑 If you put somebody else's icons in, **write it here without fail** — the
##    release's `THIRD_PARTY_NOTICES.md` is written from this field.
@export_multiline var attribution := ""

## Name → `Texture2D`. The approach gohud's default set uses.
@export var textures: Dictionary[StringName, Texture2D] = {}

## Name → the `res://` path of a texture, **loaded the first time that name is drawn** and kept from then on.
## A big set lists its drawings here instead of in `textures`: a `.tres` holding 1,000 textures reads all 1,000
## the moment it opens (≈90 ms on a desktop), a table of paths ≈5 ms, and each icon ≈0.2 ms when first asked
## for (measured 2026-09-23, Godot 4.7 headless).
## 🛑 A path is a plain string, so Godot's export does not see it as a dependency. "Export all resources" (the
##    default) is fine; an export that picks resources must also include the folder the paths point into. A name
##    whose path does not load warns once in debug builds.
@export var paths: Dictionary[StringName, String] = {}

## The folder a `paths` value without `://` lives in — `folder = "res://my/icons"` + `paths = {&"fire": "fire.svg"}`.
## It keeps a big set's table short (the library's 1,000 paths read in a third of the time).
@export_dir var folder := ""

## The icon font. It pairs with `codepoints`.
@export var font: Font

## Name → Unicode codepoint (integer). Put a value like Font Awesome's `0xf00d` straight in.
@export var codepoints: Dictionary[StringName, int] = {}

## Glyphs in an icon font are usually drawn smaller than their box — the requested size is multiplied by this
## to match the visible size of a texture icon. 1.0 means no correction.
@export_range(0.5, 2.0, 0.01) var font_size_ratio := 1.0

## The next set to look in for a name this set lacks. Put the default set here and you get **partial replacement**,
## overriding only a few. A cycle (A→B→A) is harmless — a set reached twice is looked in once.
@export var fallback: GoIconSet

## More sets to look in, in this order, after this set's own drawings — each one brings its own `fallback`.
## Every set's own drawings are tried before any fallback (see "How a name is found" above), which is what lets
## `GoUi.icons()` stack a preset's engraved icons over the game icons without either hiding the other.
@export var layers: Array[GoIconSet] = []

## The default color multiplied into texture icons. Transparent means the color the caller gave is used as is.
@export var tint := Color.TRANSPARENT


# ── How to find a name ─────────────────────────────────────────────────
# None of this draws anything. It is what `search()`, `names_in_group()`, icon pickers and the website catalog read.

## Other names that lead to a name — `gear` → `settings`. Looked at **only after no set drew the name itself**, and
## only one hop (an alias of an alias is not followed).
@export var aliases: Dictionary[StringName, StringName] = {}

## Group key → its names, in display order. Keys are shared across sets: `names_in_group(&"food")` gathers the
## food icons of every set in the lookup order.
@export var groups: Dictionary[StringName, PackedStringArray] = {}

## Group key → a title to show above it (English — translate it in your own table if players see it).
@export var group_titles: Dictionary[StringName, String] = {}

## Name → extra search words (English) that are not already in the name. `search()` matches these too.
@export var tags: Dictionary[StringName, PackedStringArray] = {}

## Picture files `from_folder()` picks up.
const PICTURE_EXTENSIONS := ["svg", "png", "webp", "jpg", "jpeg"]

# Name → the texture a `paths` entry loaded (`null` when it did not load — so the warning comes once).
var _loaded := {}


# ── Lookups ────────────────────────────────────────────────────────────

## Can this name be drawn (fallback, layers and aliases included). It does not load anything.
func has_icon(icon: StringName) -> bool:
	return not _owner(icon).is_empty()


## The texture icon. `null` for a font-only name — the caller is safer using `node()`.
func texture(icon: StringName) -> Texture2D:
	return _resolve(icon).get("texture")


## A single character of the icon font. An empty string for a texture-only name.
func glyph(icon: StringName) -> String:
	var found := _resolve(icon)
	return String.chr(found.codepoint) if found.has("codepoint") else ""


## The font that draws this name (it may be the fallback set's font).
func glyph_font(icon: StringName) -> Font:
	return _resolve(icon).get("font")


## 🎯 **The unified API** — one name gets you a `Control` ready to draw.
## A texture set yields a `TextureRect`, an icon font a `Label`. The caller has no need to tell them apart.
##
## `size` is in dp (= the same coordinate space as the Theme constants), and the node takes exactly that square as
## its minimum size — which keeps the text start position from wobbling line to line as icon widths differ.
func node(icon: StringName, size: int, ink := Color.TRANSPARENT) -> Control:
	var found := _resolve(icon)
	var color := ink if ink.a > 0 else (tint if tint.a > 0 else Color.WHITE)
	if found.has("texture"):
		var rect := TextureRect.new()
		rect.name = "Icon"
		rect.texture = found.texture
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.custom_minimum_size = Vector2(size, size)
		rect.modulate = color
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 🛑 An icon must never flip left-right with the language (the close ×, a cog). The only ones that have to
		#    flip direction are `back`/`forward`, and the caller picks those by changing the name.
		rect.layout_direction = Control.LAYOUT_DIRECTION_LTR
		rect.set_meta(&"go_icon", true)
		return rect
	var label := Label.new()
	label.name = "Icon"
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(size, size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.layout_direction = Control.LAYOUT_DIRECTION_LTR
	label.clip_text = false
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	# 🛑 A glyph is a picture, not text — `GoStyle.form()` turns wrapping on for every label under a form unless told not to,
	#    and a wrapping glyph grew from 24 to 51dp tall: the crown made its reward cell a size larger than the others (2026-09-23).
	label.set_meta(&"go_no_wrap", true)
	label.set_meta(&"go_icon", true)
	label.add_theme_color_override(&"font_color", color)
	if found.has("codepoint"):
		label.text = String.chr(found.codepoint)
		if found.has("font"): label.add_theme_font_override(&"font", found.font)
		label.add_theme_font_size_override(&"font_size", maxi(1, roundi(size * float(found.get("ratio", 1.0)))))
	else:
		# 🛑 The name was not found — **hand back an empty box that still takes up the space.** If a whole row shifts
		#    because one icon is missing, the cause is hard to track down. During development the warning below tells you.
		label.text = ""
		if OS.is_debug_build() and not icon.is_empty():
			push_warning("[gohud] icon set has no '%s' (set: %s)" % [icon, set_name if not set_name.is_empty() else resource_path])
	return label


## Every name this set can draw (fallback and layers included, sorted — aliases are not in it). The gallery
## example and the checks use it. It does not load anything.
func icon_names() -> PackedStringArray:
	var names := {}
	for each in _chain():
		for key in each.textures: names[String(key)] = true
		for key in each.paths: names[String(key)] = true
		for key in each.codepoints: names[String(key)] = true
	var list := PackedStringArray(names.keys())
	list.sort()
	return list


## The name that actually draws `icon` — `icon` itself when a set draws it, what its alias points at otherwise,
## `&""` when nothing draws it. An icon picker uses it to show `gear` as `settings`.
func canonical(icon: StringName) -> StringName:
	var owner := _owner(icon)
	return owner[1] if not owner.is_empty() else &""


# ── Finding names ──────────────────────────────────────────────────────

## 🔎 Names that match `words`, best first. Every word has to match the name, one of its aliases, its group key or
## its search words (`tags`). The name itself comes first, then a name one of whose aliases is the query (`arrow left`
## finds `back`); after that a whole word beats the start of a word, which beats a match anywhere in the name, and a
## match in the name beats one in the aliases, which beats one in the tags.
## `limit` 0 means all of them. It does not load anything.
##
## ```gdscript
## GoUi.icons().search("volume")                       # volume_high, volume_low, volume_off
## GoIconLibrary.icon_set().search("arrow left", 5)    # arrow_left first, then its relatives
## ```
func search(words: String, limit := 0) -> PackedStringArray:
	var terms := PackedStringArray()
	for term in words.to_lower().replace("-", " ").replace("_", " ").split(" ", false):
		terms.append(term)
	if terms.is_empty(): return PackedStringArray()
	var whole := "_".join(terms)
	var chain := _chain()
	var words_of := {}   # name → the words to match beyond the name: [aliases (Array), tags, group key]
	for each in chain:
		for key: StringName in each.aliases:
			_words(words_of, each.aliases[key])[0].append(String(key))
		for key: StringName in each.tags:
			var found: Array = _words(words_of, key)
			if found[1].is_empty(): found[1] = each.tags[key]
		for key: StringName in each.groups:
			for name in each.groups[key]:
				var found: Array = _words(words_of, StringName(name))
				if found[2].is_empty(): found[2] = String(key)
	var scored: Array = []
	for name in icon_names():
		var extra: Array = words_of.get(StringName(name), [[], PackedStringArray(), ""])
		var total := 1000 if name == whole else (500 if extra[0].has(whole) else 0)
		for term in terms:
			var best := _match(term, name.split("_"), 60, 40, 25, name)
			for alias: String in extra[0]: best = maxi(best, _match(term, alias.split("_"), 30, 20, 10, alias))
			for tag: String in extra[1]: best = maxi(best, _match(term, PackedStringArray([tag]), 20, 12, 0, tag))
			if extra[2] == term: best = maxi(best, 10)
			if best == 0:
				total = 0
				break
			total += best
		if total > 0: scored.append([total, name])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	var found := PackedStringArray()
	for pair: Array in scored:
		if limit > 0 and found.size() >= limit: break
		found.append(pair[1])
	return found


## Every group key, in lookup order (this set's first, then its layers', then its fallbacks'). No duplicates.
func group_names() -> PackedStringArray:
	var keys := PackedStringArray()
	for each in _chain():
		for key: StringName in each.groups:
			if not keys.has(String(key)): keys.append(String(key))
	return keys


## The names in one group, gathered from every set in lookup order, in their display order. Empty for an unknown key.
func names_in_group(key: StringName) -> PackedStringArray:
	var names := PackedStringArray()
	for each in _chain():
		for name in each.groups.get(key, PackedStringArray()):
			if not names.has(name): names.append(name)
	return names


## The title of a group (English) — from the first set that gives one, else the key made readable.
func group_title(key: StringName) -> String:
	for each in _chain():
		if each.group_titles.has(key): return each.group_titles[key]
	return String(key).capitalize()


## The group a name is listed in (the first one, in lookup order). `&""` when it is in none.
func group_of(icon: StringName) -> StringName:
	for each in _chain():
		for key: StringName in each.groups:
			if each.groups[key].has(String(icon)): return key
	return &""


## 📁 A set made from a folder of pictures — each file name without its extension becomes an icon name
## (`res://art/icons/fire_rune.svg` → `&"fire_rune"`). The files load only when their name is first drawn.
##
## ```gdscript
## GoUi.config.icons = GoIconSet.from_folder("res://art/icons", GoUi.icons())   # yours first, gohud's for the rest
## ```
## 🔑 Give the SVGs the `DPITexture` importer (Import dock → "DPITexture") so they stay sharp in a 64dp slot, and draw
##    them in white — color goes on through `modulate`, which can only darken.
static func from_folder(folder: String, below: GoIconSet = null) -> GoIconSet:
	var made := GoIconSet.new()
	var base := folder.trim_suffix("/")
	made.set_name = base.get_file()
	made.folder = base
	made.fallback = below
	# 🛑 `DirAccess` lists `name.svg.import` in an exported game; `ResourceLoader.list_directory` lists what can be loaded.
	for file in ResourceLoader.list_directory(base):
		if file.ends_with("/") or not PICTURE_EXTENSIONS.has(file.get_extension().to_lower()): continue
		made.paths[StringName(file.get_basename())] = file
	return made


# ── Inside ─────────────────────────────────────────────────────────────

## Every set this one looks in, in lookup order: this set, its `layers`, then level by level the layers and
## `fallback` of those — so **every set's own drawings are tried before any set's fallback**. A set reached twice
## counts once, which is also what makes a cycle harmless.
func _chain() -> Array[GoIconSet]:
	var order: Array[GoIconSet] = [self]
	var seen := {get_instance_id(): true}
	var index := 0
	while index < order.size():
		var here := order[index]
		index += 1
		var next: Array = here.layers.duplicate()
		if here.fallback != null: next.append(here.fallback)
		for other in next:
			if other == null or seen.has(other.get_instance_id()): continue
			seen[other.get_instance_id()] = true
			order.append(other)
	return order


## Does this set draw the name **itself** (not counting its fallback or layers). Nothing is loaded.
func _holds(icon: StringName) -> bool:
	return textures.get(icon) != null or paths.has(icon) or codepoints.has(icon)


## `[the set that draws it, the name it draws]` — the name may be an alias's target. `[]` when nothing draws it.
func _owner(icon: StringName) -> Array:
	var chain := _chain()
	for each in chain:
		if each._holds(icon): return [each, icon]
	for each in chain:
		if each.aliases.has(icon):
			var target: StringName = each.aliases[icon]
			for other in chain:
				if other._holds(target): return [other, target]
			break
	return []


## Decides how one name gets drawn. **An empty Dictionary means "cannot be drawn"** (a `-> Dictionary` cannot hold null).
func _resolve(icon: StringName) -> Dictionary:
	var owner := _owner(icon)
	return owner[0]._own(owner[1]) if not owner.is_empty() else {}


## This set's own drawing of a name: `textures` → `paths` → `codepoints`.
func _own(icon: StringName) -> Dictionary:
	var drawn: Texture2D = textures.get(icon)
	if drawn != null: return {"texture": drawn}
	if paths.has(icon):
		drawn = _load_path(icon)
		if drawn != null: return {"texture": drawn}
	if codepoints.has(icon):
		var entry := {"codepoint": int(codepoints[icon]), "ratio": font_size_ratio}
		if font != null: entry["font"] = font
		return entry
	return {}


func _load_path(icon: StringName) -> Texture2D:
	if _loaded.has(icon): return _loaded[icon]
	var path: String = paths[icon]
	if not folder.is_empty() and not path.contains("://"): path = folder.path_join(path)
	var drawn: Texture2D = null
	if ResourceLoader.exists(path): drawn = load(path) as Texture2D
	if drawn == null and OS.is_debug_build():
		push_warning("[gohud] icon '%s' points at %s, which does not load — an export that picks resources must include that folder" % [icon, path])
	_loaded[icon] = drawn
	return drawn


## `[aliases, tags, group key]` for a name in `search()`, made on first use.
## 🛑 The aliases are a plain `Array` — a `PackedStringArray` taken out of an Array is a copy, and appending to it is lost.
static func _words(into: Dictionary, name: StringName) -> Array:
	if not into.has(name): into[name] = [[], PackedStringArray(), ""]
	return into[name]


## How well one search term matches a name split into words: the whole thing, a whole word, the start of a word,
## anywhere in it. 0 is no match.
static func _match(term: String, parts: PackedStringArray, word: int, start: int, inside: int, whole: String) -> int:
	if whole == term: return word + 20
	if parts.has(term): return word
	for part in parts:
		if part.begins_with(term): return start
	return inside if inside > 0 and whole.contains(term) else 0
