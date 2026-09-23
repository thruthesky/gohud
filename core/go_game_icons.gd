## 🎮 Names for the **game icon set** — 187 icons for inventories, shops, equipment, food, resources,
## tech & space, places and rewards. The drawings live in `icons/game/`, the set in `icons/gohud_icons_game.tres`.
##
## ```gdscript
## GoUi.config.icons = GoGameIcons.icon_set()      # after use_preset(); the default names keep working (fallback)
## slot.icon_name = GoGameIcons.BACKPACK
## GoStyle.list_button(GoGameIcons.SHOP, "Shop", open_shop)
## for name in GoGameIcons.GROUPS[&"shop"]: …      # every icon of one group, in drawing order
## ```
##
## 🛑 **Generated** by `tools/make_game_icons.py` — edit the table there, not this file.
## 🛑 Kept apart from `GoIconSet`: those 84 constants promise "every theme and every icon set draws this name".
##    These names are drawn by **this set only**, so a project that plugs in its own set must keep this one
##    as its `fallback` (or redraw the names it uses).
@tool
class_name GoGameIcons
extends RefCounted

const SET_PATH := "res://addons/gohud/icons/gohud_icons_game.tres"

# ── Inventory & storage ───────────────────────────────────────────────
const BACKPACK := &"backpack"
const CHEST := &"chest"
const CRATE := &"crate"
const CRATES := &"crates"
const BARREL := &"barrel"
const BUCKET := &"bucket"
const STACK := &"stack"
const CUBE := &"cube"
const WAREHOUSE := &"warehouse"
const HAND_GRAB := &"hand_grab"

# ── Shop & trade ──────────────────────────────────────────────────────
const SHOP := &"shop"
const CART := &"cart"
const CART_ADD := &"cart_add"
const SHOPPING_BAG := &"shopping_bag"
const BASKET := &"basket"
const TAG := &"tag"
const TAGS := &"tags"
const RECEIPT := &"receipt"
const WALLET := &"wallet"
const CASH := &"cash"
const BANKNOTE := &"banknote"
const COINS := &"coins"
const MONEY_BAG := &"money_bag"
const PIGGY_BANK := &"piggy_bank"
const GEM := &"gem"
const SCALE := &"scale"
const DISCOUNT := &"discount"
const PERCENT := &"percent"
const CREDIT_CARD := &"credit_card"
const EXCHANGE := &"exchange"
const DELIVERY := &"delivery"
const TROLLEY := &"trolley"
const BANK := &"bank"
const AUCTION := &"auction"
const GIFT_CARD := &"gift_card"
const TICKET := &"ticket"
const PRICE_UP := &"price_up"
const PRICE_DOWN := &"price_down"
const CREDIT := &"credit"

# ── Equipment & tools ─────────────────────────────────────────────────
const HELMET := &"helmet"
const ARMOR := &"armor"
const BOOTS := &"boots"
const GLASSES := &"glasses"
const MASK := &"mask"
const WARDROBE := &"wardrobe"
const GLOVES := &"gloves"
const RING := &"ring"
const NECKLACE := &"necklace"
const SPACE_HELMET := &"space_helmet"
const SWORDS := &"swords"
const AXE := &"axe"
const BOW := &"bow"
const WAND := &"wand"
const HAMMER := &"hammer"
const PICKAXE := &"pickaxe"
const SHOVEL := &"shovel"
const WRENCH := &"wrench"
const TOOLS := &"tools"
const KNIFE := &"knife"
const FISH_HOOK := &"fish_hook"
const BRUSH := &"brush"
const BINOCULARS := &"binoculars"
const COMPASS := &"compass"
const MAGNET := &"magnet"
const BOMB := &"bomb"

# ── Food & consumables ────────────────────────────────────────────────
const APPLE := &"apple"
const MEAT := &"meat"
const BREAD := &"bread"
const BOTTLE := &"bottle"
const FLASK := &"flask"
const FLASK_ROUND := &"flask_round"
const PILL := &"pill"
const MEDKIT := &"medkit"
const BANDAGE := &"bandage"
const SYRINGE := &"syringe"
const CANDY := &"candy"
const MILK := &"milk"
const EGG := &"egg"
const FISH := &"fish"
const CARROT := &"carrot"
const MUSHROOM := &"mushroom"
const COOKIE := &"cookie"
const CHEESE := &"cheese"
const CAKE := &"cake"
const PIZZA := &"pizza"
const SOUP := &"soup"
const SALAD := &"salad"
const ICE_CREAM := &"ice_cream"
const COFFEE := &"coffee"
const CUP := &"cup"
const DRINK := &"drink"

# ── Resources & materials ─────────────────────────────────────────────
const WOOD := &"wood"
const LEAF := &"leaf"
const SEEDLING := &"seedling"
const PLANT := &"plant"
const FLOWER := &"flower"
const WHEAT := &"wheat"
const SEEDS := &"seeds"
const CACTUS := &"cactus"
const TREE := &"tree"
const DROPLET := &"droplet"
const FLAME := &"flame"
const SNOWFLAKE := &"snowflake"
const WIND := &"wind"
const BONE := &"bone"
const FEATHER := &"feather"
const MOUNTAIN := &"mountain"
const BRICKS := &"bricks"
const ORE := &"ore"
const CRYSTAL := &"crystal"
const INGOT := &"ingot"
const GOO := &"goo"
const SHELL := &"shell"
const SPORE := &"spore"
const STEEL_BEAM := &"steel_beam"
const FLOOR_PANEL := &"floor_panel"

# ── Tech & space ──────────────────────────────────────────────────────
const ATOM := &"atom"
const BATTERY := &"battery"
const BATTERY_FULL := &"battery_full"
const BULB := &"bulb"
const CHIP := &"chip"
const PLUG := &"plug"
const ENGINE := &"engine"
const ROCKET := &"rocket"
const PLANET := &"planet"
const SATELLITE := &"satellite"
const UFO := &"ufo"
const ALIEN := &"alien"
const SOLAR_PANEL := &"solar_panel"
const ANTENNA := &"antenna"
const TELESCOPE := &"telescope"
const METEOR := &"meteor"
const ROBOT := &"robot"
const DRONE := &"drone"
const RADAR := &"radar"
const MICROSCOPE := &"microscope"
const DNA := &"dna"
const TEST_TUBE := &"test_tube"
const RADIOACTIVE := &"radioactive"
const BIOHAZARD := &"biohazard"
const RECYCLE := &"recycle"
const FUEL := &"fuel"
const OXYGEN_TANK := &"oxygen_tank"
const DOME := &"dome"
const POWER_CORE := &"power_core"

# ── Buildings & furniture ─────────────────────────────────────────────
const FACTORY := &"factory"
const HOUSE := &"house"
const TOWER := &"tower"
const WINDMILL := &"windmill"
const TENT := &"tent"
const CAMPFIRE := &"campfire"
const BED := &"bed"
const LAMP := &"lamp"
const DOOR := &"door"
const WINDOW := &"window"
const FENCE := &"fence"
const LADDER := &"ladder"
const ARMCHAIR := &"armchair"
const CAR := &"car"
const TRACTOR := &"tractor"
const FORKLIFT := &"forklift"
const CRANE := &"crane"

# ── Creatures ─────────────────────────────────────────────────────────
const PAW := &"paw"
const BUG := &"bug"
const GHOST := &"ghost"
const PIG := &"pig"
const HORSE := &"horse"

# ── Rewards & social ──────────────────────────────────────────────────
const TROPHY := &"trophy"
const MEDAL := &"medal"
const AWARD := &"award"
const CERTIFICATE := &"certificate"
const SPARKLES := &"sparkles"
const CONFETTI := &"confetti"
const BALLOON := &"balloon"
const DICE := &"dice"
const PUZZLE := &"puzzle"
const ANCHOR := &"anchor"
const PALETTE := &"palette"
const NOTEBOOK := &"notebook"
const SCROLL := &"scroll"
const THUMB_UP := &"thumb_up"
const HANDSHAKE := &"handshake"
const MEGAPHONE := &"megaphone"
const STOPWATCH := &"stopwatch"
const MICROPHONE := &"microphone"
const MICROPHONE_OFF := &"microphone_off"
const SEND := &"send"

## Group key → its icon names, in drawing order. The gallery and icon pickers walk this.
const GROUPS: Dictionary[StringName, Array] = {
	&"inventory": [&"backpack", &"chest", &"crate", &"crates", &"barrel", &"bucket", &"stack", &"cube", &"warehouse", &"hand_grab"],
	&"shop": [&"shop", &"cart", &"cart_add", &"shopping_bag", &"basket", &"tag", &"tags", &"receipt", &"wallet", &"cash", &"banknote", &"coins", &"money_bag", &"piggy_bank", &"gem", &"scale", &"discount", &"percent", &"credit_card", &"exchange", &"delivery", &"trolley", &"bank", &"auction", &"gift_card", &"ticket", &"price_up", &"price_down", &"credit"],
	&"equipment": [&"helmet", &"armor", &"boots", &"glasses", &"mask", &"wardrobe", &"gloves", &"ring", &"necklace", &"space_helmet", &"swords", &"axe", &"bow", &"wand", &"hammer", &"pickaxe", &"shovel", &"wrench", &"tools", &"knife", &"fish_hook", &"brush", &"binoculars", &"compass", &"magnet", &"bomb"],
	&"food": [&"apple", &"meat", &"bread", &"bottle", &"flask", &"flask_round", &"pill", &"medkit", &"bandage", &"syringe", &"candy", &"milk", &"egg", &"fish", &"carrot", &"mushroom", &"cookie", &"cheese", &"cake", &"pizza", &"soup", &"salad", &"ice_cream", &"coffee", &"cup", &"drink"],
	&"resources": [&"wood", &"leaf", &"seedling", &"plant", &"flower", &"wheat", &"seeds", &"cactus", &"tree", &"droplet", &"flame", &"snowflake", &"wind", &"bone", &"feather", &"mountain", &"bricks", &"ore", &"crystal", &"ingot", &"goo", &"shell", &"spore", &"steel_beam", &"floor_panel"],
	&"tech": [&"atom", &"battery", &"battery_full", &"bulb", &"chip", &"plug", &"engine", &"rocket", &"planet", &"satellite", &"ufo", &"alien", &"solar_panel", &"antenna", &"telescope", &"meteor", &"robot", &"drone", &"radar", &"microscope", &"dna", &"test_tube", &"radioactive", &"biohazard", &"recycle", &"fuel", &"oxygen_tank", &"dome", &"power_core"],
	&"places": [&"factory", &"house", &"tower", &"windmill", &"tent", &"campfire", &"bed", &"lamp", &"door", &"window", &"fence", &"ladder", &"armchair", &"car", &"tractor", &"forklift", &"crane"],
	&"creatures": [&"paw", &"bug", &"ghost", &"pig", &"horse"],
	&"rewards": [&"trophy", &"medal", &"award", &"certificate", &"sparkles", &"confetti", &"balloon", &"dice", &"puzzle", &"anchor", &"palette", &"notebook", &"scroll", &"thumb_up", &"handshake", &"megaphone", &"stopwatch", &"microphone", &"microphone_off", &"send"],
}

## Group key → a title to show above it (English; translate in your own table if you show it to players).
const GROUP_TITLES: Dictionary[StringName, String] = {
	&"inventory": "Inventory & storage",
	&"shop": "Shop & trade",
	&"equipment": "Equipment & tools",
	&"food": "Food & consumables",
	&"resources": "Resources & materials",
	&"tech": "Tech & space",
	&"places": "Buildings & furniture",
	&"creatures": "Creatures",
	&"rewards": "Rewards & social",
}


## The set itself. 🛑 Loaded on first use rather than `preload`ed, and it holds **paths**, not textures —
##    a drawing is read the first time its name is drawn, so asking for the set costs a table of 187 paths.
static func icon_set() -> GoIconSet:
	return load(SET_PATH) as GoIconSet


## Every name of this set (without the default set's names), in drawing order.
static func names() -> Array[StringName]:
	var all: Array[StringName] = []
	for key: StringName in GROUPS:
		for icon: StringName in GROUPS[key]: all.append(icon)
	return all
