## 🪙 **A reward burst** — the moment a player claims a reward: the screen dims, a coin rises from the button they pressed,
## bursts in a ring of light, "+N" stamps in under it, COLLECT appears, and on COLLECT the coins fly into the balance
## pill, which bumps and counts up as each lands. A daily quest's coins, an achievement's, a login gift's.
##
## ```gdscript
## var burst := GoRewardBurst.new()
## screen.add_child(burst)                       # a full-screen layer over the screen it plays on
## burst.collect_text = tr("COLLECT")
## burst.target = coin_pill                      # where the coins fly, which bumps on each landing
## burst.target_label = coin_label               # the balance it counts up (whole numbers)
## burst.balance = 120                           # what that label shows now
## burst.push(claim_button.get_global_rect(), quest_id, 20)   # on the tap: the build starts at once
## # … the server answers …
## burst.resolve(quest_id, reply.coins, reply.balance)        # "+20" stamps in; COLLECT follows
## # or, refused (or already paid): burst.refuse(quest_id)  — the effect fades, no reward is shown
## ```
##
## | t (s) | beat |
## |---|---|
## | 0–0.25 | the scrim and a navy dim fade in |
## | 0–0.6 | the coin rises from `from` on a curve, 0.2 → 0.9×, spinning on its edge, with a gold trail |
## | 0.6–0.75 | it draws in to 0.72×, the glow gathers, short faint rays |
## | 0.75 | burst to 1.25× (→ 1 by 1.2): flash, shockwave ring, 28 sparkles, a small jolt, the rays shoot out |
## | 0.75–1.9 | two ray layers turn opposite ways, grow to 1.22× and brighten; twinkles, six orbiting coins, a shine |
## | 1.2 | "+N" stamps in (2.6× → 1, a squash, a jolt, a sparkle pop), already reading the whole amount |
## | 1.5 | a glint on the rim |
## | 1.6–1.9 | COLLECT fades and grows in; it takes presses from 1.9 s, then breathes |
## | COLLECT | the coin gives out its coins, they curve into `target`; each landing bumps it and counts the balance on |
##
## 🛑 **The caller says what was paid.** The build covers the wait for an answer (the server's); "+N" and the count
##    show only what [method resolve] is given, and a build still waiting at 1.2 s idles in its light until then.
##    [method refuse] fades the effect out with no reward. An amount at or over [member heap_from] shows a heap of
##    coins instead of one.
## 👆 **Taps** (accidental-click safe): nothing for [member tap_lock]; then, until COLLECT is up, a tap jumps the build to
##    its revealed state and never collects; once up, only COLLECT collects (a tap elsewhere does nothing).
## ♿ **`GoConfig.reduce_motion`:** fades only (0.15 s) — no rise, spin, rays, orbit, jolt or flight — COLLECT takes
##    presses from [member tap_lock] and the balance changes once.
## 🔁 **In a row:** a [method push] while one plays waits its turn; each later one plays faster (no anticipation, a
##    shorter build) and the dim stays between them. [signal finished] once the last has gone.
## 🎨 arcade_light paints it (`assets/arcade_light/rewards/`: `coin`, `coin_heap`, `fx_rays`, `fx_rays_thin`, `fx_glow`,
##    `fx_ring`, `fx_sparkle`, `fx_glint`) and letters "+N" in `GoRewardAmount` (gold, ink edge); another look draws the
##    light from its `warning_fill` and the coin from its icon set.
## 🔔 `GoFeedback.fanfare()` at the burst; COLLECT says its own `tapped`.
## 📐 Every size is a base size times [member unit]. [member bottom_reserve] keeps a band at the bottom clear (an ad
##    banner and its gap): the coin and COLLECT move up above it rather than shrink; only a screen too short for them
##    even then scales the group down ([method fits] says whether it had to).
class_name GoRewardBurst
extends Control

## The build reached its reveal: COLLECT takes presses. [param id] is the entry's.
signal revealed(id: Variant)
## COLLECT was pressed.
signal collected(id: Variant)
## A coin landed in [member target]: [param value] is the balance shown now.
signal counted(value: int)
## An entry ended: collected and flown, or refused.
signal entry_finished(id: Variant, was_collected: bool)
## The last entry ended and the layer faded: nothing is left on screen.
signal finished

enum Phase { IDLE, BUILD, WAITING, REVEAL, SHOWN, COLLECTING, ENDING }

## The amount label's theme type (arcade_light: gold on an ink edge). A look without it: the title label in its gold.
const VAR_AMOUNT := &"GoRewardAmount"
## Base sizes (times [member unit]).
const COIN_SIZE := 150.0
const HEAP_SHARE := 1.6
const AMOUNT_FONT := 62
const AMOUNT_COIN := 56.0
const AMOUNT_GAP := 10.0
const COLLECT_SIZE := Vector2(230.0, 70.0)
const COLLECT_GAP := 26.0
const ORBIT_COIN := 38.0
const FLY_COIN := 48.0
## The ring of coins that fly: half the amount, at least and at most these.
const FLY_MIN := 6
const FLY_MAX := 10
const FLY_TIME := 0.55
const FLY_STAGGER := 0.045
const ORBITERS := 6
## A small gap kept between the group and the top of the room (times unit).
const TOP_MARGIN := 12.0

## The beats of one entry (seconds from its tap): the first one, and each later one in a row.
const BEATS := {
	"rise": 0.6, "burst": 0.75, "orbit": 0.95, "shine": 1.0, "stamp": 1.2, "glint": 1.5, "collect": 1.6, "collect_in": 0.3}
const QUICK_BEATS := {
	"rise": 0.35, "burst": 0.35, "orbit": 0.45, "shine": 0.5, "stamp": 0.6, "glint": 0.8, "collect": 0.85, "collect_in": 0.25}
## The scrim's depth (the look's scrim ink), under [member dim].
const SCRIM_ALPHA := 0.62
## Reduce motion's one fade.
const FADE := 0.15

## Where the coins fly; it bumps on each landing. Null: the coins fade where they burst.
var target: Control
## The label that shows the balance (whole numbers): each landing counts it on. Null: only [signal counted] says it.
var target_label: Label
## What [member target_label] shows now; the count starts here. A resolve's balance moves it on.
var balance := 0
## The word on the COLLECT key (the caller translates it).
var collect_text := ""
## How the amount reads (`%d` the whole number): "+%d" by default; a caller may write it its own way.
var amount_format := "+%d"
## Every base size is multiplied by this (the caller's screen scale).
var unit := 1.0
## Canvas units kept clear at the bottom of the room (an ad banner and its gap).
var bottom_reserve := 0.0:
	set(value):
		bottom_reserve = maxf(0.0, value)
		if _fx != null: _place()
## How deep the navy dim under the light is (0–1), over the look's own scrim, so the light reads.
var dim := 0.55
## From this amount on, a heap of coins instead of one.
var heap_from := 50
## Seconds after a tap before any tap counts.
var tap_lock := 0.3

var _queue: Array[Dictionary] = []
var _entry: Dictionary = {}
var _phase := Phase.IDLE
var _played := 0
var _age := 0.0
var _beats: Dictionary = BEATS
var _build: Tween
var _reveal: Tween
var _out: Tween # the collect or the fade, so stop() can end it
var _shrunk := false
var _shown_balance := 0

var _scrim: ColorRect
var _dim: ColorRect
var _fx: Control
var _glow: TextureRect
var _rays: TextureRect
var _rays2: TextureRect
var _ring: TextureRect
var _hero: Control
var _hero_art: Control
var _shine: ColorRect
var _glint: TextureRect
var _orbiters: Array[TextureRect] = []
var _amount_group: Control
var _amount_coin: TextureRect
var _amount_label: Label
var collect_button: GoGlyphButton
var _trail: CPUParticles2D
var _burst: CPUParticles2D
var _twinkle: CPUParticles2D
var _hit: CPUParticles2D
var _sparkle: Texture2D
var _spin := false
var _orbit := false
var _orbit_t := 0.0
var _pulse := 0.0
var _shake := 0.0
var _centre := Vector2.ZERO
var _box := COIN_SIZE
var _below := 0.0


func _init() -> void:
	name = "RewardBurst"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _ready() -> void:
	resized.connect(_place)


# ── API ──────────────────────────────────────────────────────────────────

## A claim was tapped: [param from] is the pressed key's global rect (the coin rises from its centre), [param id] the
## caller's name for it, [param hint] what the caller expects it to pay (only picks the coin or the heap; "+N" waits for
## [method resolve]). Plays now, or after the ones before it.
func push(from: Rect2, id: Variant = null, hint := 0) -> void:
	_queue.append({"from": from, "id": id, "hint": hint, "amount": -1, "balance": -1, "refused": false})
	if _phase == Phase.IDLE: _next()


## The answer for [param id]: it paid [param amount], and the balance is now [param new_balance] (-1: the old one plus
## the amount). "+N" stamps in as soon as the build reaches it.
func resolve(id: Variant, amount: int, new_balance := -1) -> void:
	var entry := _find(id)
	if entry.is_empty() or entry.refused: return
	entry.amount = maxi(0, amount)
	entry.balance = new_balance
	if is_same(entry, _entry) and _phase == Phase.WAITING: _stamp()


## [param id] paid nothing (refused, failed, or paid before): its effect fades with no reward; a queued one is dropped.
func refuse(id: Variant) -> void:
	var entry := _find(id)
	if entry.is_empty(): return
	entry.refused = true
	if is_same(entry, _entry):
		if _phase in [Phase.BUILD, Phase.WAITING, Phase.REVEAL, Phase.SHOWN]: _fade_out(false)
	else:
		for i in _queue.size():
			if is_same(_queue[i], entry):
				_queue.remove_at(i)
				break
		entry_finished.emit(id, false)


## Ends everything at once (the screen it plays on closed): each entry says `entry_finished(id, false)` unless it was
## already collected (then `true`, its balance counted to the end), then [signal finished]. Nothing fades.
func stop() -> void:
	if _phase == Phase.IDLE: return
	var ended: Array = []
	if not _entry.is_empty():
		var paid: bool = _phase == Phase.COLLECTING
		if paid: _count(_entry.balance if _entry.balance >= 0 else _shown_balance + _entry.amount)
		ended.append([_entry.id, paid])
	for entry in _queue: ended.append([entry.id, false])
	_queue.clear()
	_kill_tweens()
	_clear_parts()
	balance = maxi(balance, _shown_balance)
	_entry = {}
	_phase = Phase.IDLE
	_played = 0
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for node: CanvasItem in [_scrim, _dim]:
		if is_instance_valid(node): node.modulate.a = 0.0
	for pair in ended: entry_finished.emit(pair[0], pair[1])
	finished.emit()


## Whether anything plays or waits.
func is_active() -> bool:
	return _phase != Phase.IDLE


## The playing entry's id (null when idle).
func current_id() -> Variant:
	return _entry.get("id")


## The phase of the playing entry (tests, and a caller that times something to it).
func phase() -> Phase:
	return _phase


## Whether the group fitted above [member bottom_reserve] at its full size.
func fits() -> bool:
	return not _shrunk


## The group's scale in the room: 1 at its full size, less when even moved up it had to shrink (a caller keeping a
## band clear can weigh it against its readability floor).
func fit_scale() -> float:
	return _fx.scale.x if _fx != null else 1.0


## A tap on the layer: "ignored" inside [member tap_lock] (or when idle), "skipped" when it jumped the build to its
## reveal, "none" otherwise. Never collects.
func tap() -> String:
	if _phase == Phase.IDLE or _age < tap_lock: return "ignored"
	if _phase == Phase.BUILD or _phase == Phase.REVEAL:
		skip()
		return "skipped"
	return "none"


## Jumps the build to where it stands revealed (the answer known) or waiting for it.
func skip() -> void:
	if _build != null and _build.is_valid(): _build.custom_step(30.0)
	if _reveal != null and _reveal.is_valid(): _reveal.custom_step(30.0)
	if is_instance_valid(_trail): _trail.emitting = false
	if is_instance_valid(_hero_art): _hero_art.scale = Vector2.ONE
	_shake = 0.0
	if is_instance_valid(_fx): _fx.position = _centre


## COLLECT: the coins fly to [member target]. Only once COLLECT is up.
func collect() -> void:
	if _phase != Phase.SHOWN: return
	_phase = Phase.COLLECTING
	collected.emit(_entry.id)
	_orbit = false
	_twinkle.emitting = false
	collect_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := create_tween().set_parallel(true)
	_out = t
	t.tween_property(collect_button, "scale", Vector2.ONE * 0.9, 0.06)
	t.tween_property(collect_button, "modulate:a", 0.0, 0.15).set_delay(0.06)
	t.tween_property(_amount_group, "modulate:a", 0.0, 0.15)
	for c in _orbiters: t.tween_property(c, "modulate:a", 0.0, 0.15)
	var last := _queue.is_empty()
	var final_balance: int = _entry.balance if _entry.balance >= 0 else _shown_balance + _entry.amount
	if _reduced():
		t.tween_property(_fx, "modulate:a", 0.0, 0.2)
		if last: _fade_layer(t, 0.0, 0.2)
		t.tween_callback(func() -> void: _count(final_balance)).set_delay(0.1)
		t.tween_callback(_end_entry.bind(true)).set_delay(0.25)
		return
	t.tween_property(_hero, "scale", Vector2.ONE * 1.12, 0.08)
	t.tween_property(_hero, "scale", Vector2.ZERO, 0.22).set_delay(0.08).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_IN)
	for node: CanvasItem in [_glow, _rays, _rays2]:
		t.tween_property(node, "modulate:a", 0.0, 0.4).set_delay(0.15)
	if last: _fade_layer(t, 0.2, 0.35)
	var from := _shown_balance
	var count := clampi(_entry.amount / 2, FLY_MIN, FLY_MAX)
	var land_last := 0.0
	for i in count:
		var value := final_balance if i == count - 1 else from + roundi(float(final_balance - from) * (i + 1) / count)
		land_last = _fly_coin(i, count, 0.06 + i * FLY_STAGGER, value)
	t.tween_callback(_end_entry.bind(true)).set_delay(land_last + 0.3)


# ── One entry ────────────────────────────────────────────────────────────

func _find(id: Variant) -> Dictionary:
	if not _entry.is_empty() and _same(_entry.id, id) and _phase != Phase.ENDING: return _entry
	for entry in _queue:
		if _same(entry.id, id): return entry
	return {}


static func _same(a: Variant, b: Variant) -> bool:
	return typeof(a) == typeof(b) and a == b


func _next() -> void:
	if _queue.is_empty():
		_phase = Phase.IDLE
		_entry = {}
		return
	_entry = _queue.pop_front()
	var first := _played == 0
	_played += 1
	_beats = BEATS if first else QUICK_BEATS
	_age = 0.0
	_shown_balance = balance
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_parts()
	_place()
	if _reduced(): _play_reduced(first)
	else: _play(first)


func _play(first: bool) -> void:
	_phase = Phase.BUILD
	var b := _beats
	var t := create_tween().set_parallel(true)
	_build = t
	if first or _scrim.modulate.a < 0.99: _fade_layer_in(t, 0.25)
	# 1. Rise: from the pressed key's centre, spinning on its edge, growing, a gold trail behind it.
	var from := (_local(_entry.from.get_center()) - _centre) / _fx.scale.x
	_hero.position = from
	_hero.scale = Vector2.ONE * 0.2
	var lift := Vector2(0.0, -40.0 * unit)
	_trail.emitting = true
	t.tween_method(func(k: float) -> void:
		var mid := from * 0.35 + lift
		_hero.position = from.lerp(mid, k).lerp(mid.lerp(Vector2.ZERO, k), k)
		_hero.scale = Vector2.ONE * lerpf(0.2, 0.9, k)
		_hero_art.scale.x = maxf(0.08, absf(cos(k * 2.5 * TAU)))
		_trail.position = _fx.position + _hero.position * _fx.scale.x, 0.0, 1.0, b.rise).set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_OUT)
	t.tween_callback(func() -> void: _trail.emitting = false).set_delay(maxf(0.0, b.rise - 0.05))
	_spin = true
	for r: TextureRect in [_rays, _rays2]:
		r.modulate.a = 0.0
		r.scale = Vector2.ONE * 0.3
	# 2. Anticipation (the first only): it draws in, the light gathers, short and faint.
	var gather: float = b.burst - b.rise
	if gather > 0.0:
		t.tween_property(_hero, "scale", Vector2.ONE * 0.72, gather).set_delay(b.rise).set_trans(Tween.TRANS_QUAD) \
				.set_ease(Tween.EASE_IN)
		t.tween_property(_glow, "modulate:a", 0.45, gather).set_delay(b.rise)
		t.tween_property(_glow, "scale", Vector2.ONE * 0.45, gather).from(Vector2.ONE * 0.2).set_delay(b.rise)
		for r: TextureRect in [_rays, _rays2]:
			t.tween_property(r, "modulate:a", 0.35, gather).set_delay(b.rise)
	# 3. Burst: past full size and back; a flash, the shockwave, sparkles, a jolt; the rays shoot out.
	var at: float = b.burst
	t.tween_property(_hero, "scale", Vector2.ONE * 1.25, 0.1).set_delay(at).set_trans(Tween.TRANS_QUAD) \
			.set_ease(Tween.EASE_OUT)
	t.tween_property(_hero, "scale", Vector2.ONE, 0.35).set_delay(at + 0.1).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)
	t.tween_property(_glow, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.05).set_delay(at) # the flash
	t.tween_property(_glow, "modulate", Color.WHITE, 0.45).set_delay(at + 0.08)
	t.tween_property(_glow, "scale", Vector2.ONE * 1.35, 0.08).set_delay(at)
	t.tween_property(_glow, "scale", Vector2.ONE, 0.5).set_delay(at + 0.08).set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_OUT)
	t.tween_property(_ring, "scale", Vector2.ONE * 2.3, 0.5).from(Vector2.ONE * 0.4).set_delay(at) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_ring, "modulate:a", 0.0, 0.5).from(1.0).set_delay(at)
	t.tween_callback(_on_burst).set_delay(at)
	var grow: float = b.collect + b.collect_in - at - 0.3
	for r: TextureRect in [_rays, _rays2]:
		t.tween_property(r, "scale", Vector2.ONE, 0.3).set_delay(at).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(r, "modulate:a", 0.7, 0.15).set_delay(at)
		# 4. …and keep growing and brightening until COLLECT is up.
		t.tween_property(r, "scale", Vector2.ONE * 1.22, grow).set_delay(at + 0.3).set_trans(Tween.TRANS_SINE) \
				.set_ease(Tween.EASE_IN_OUT)
		t.tween_property(r, "modulate:a", 1.0, grow + 0.15).set_delay(at + 0.15)
	t.tween_callback(func() -> void: _twinkle.emitting = true).set_delay(at + 0.1)
	# 5. Small coins orbit it; a shine sweeps it.
	t.tween_callback(func() -> void: _orbit = true).set_delay(b.orbit)
	for c in _orbiters: t.tween_property(c, "modulate:a", 1.0, 0.3).set_delay(b.orbit)
	t.tween_callback(_sweep).set_delay(b.shine)
	# 6. The build ends where "+N" stamps: now if the answer came, else when it comes.
	t.tween_callback(_reached_stamp).set_delay(b.stamp)


func _on_burst() -> void:
	_burst.restart()
	_shake = 4.0 * unit
	GoFeedback.fanfare()


func _reached_stamp() -> void:
	if _phase != Phase.BUILD: return
	_phase = Phase.WAITING
	if _entry.amount >= 0: _stamp()


## "+N" and COLLECT, from the stamp's beat on.
func _stamp() -> void:
	_phase = Phase.REVEAL
	var b := _beats
	_set_amount(_entry.amount)
	var t := create_tween().set_parallel(true)
	_reveal = t
	if _reduced():
		t.tween_property(_amount_group, "modulate:a", 1.0, FADE)
		var arm := maxf(0.0, tap_lock - _age)
		t.tween_property(collect_button, "modulate:a", 1.0, FADE).set_delay(maxf(0.0, arm - FADE))
		t.tween_callback(_arm).set_delay(maxf(arm, FADE))
		return
	# The group stamps in from big, squashes and settles; the screen jolts; sparkles pop.
	t.tween_property(_amount_group, "modulate:a", 1.0, 0.06)
	t.tween_property(_amount_group, "scale", Vector2(1.12, 0.88), 0.14).from(Vector2.ONE * 2.6) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_amount_group, "scale", Vector2.ONE, 0.2).set_delay(0.14).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)
	t.tween_callback(func() -> void:
		_shake = 5.0 * unit
		_hit.position = _fx.position + _amount_group.position * _fx.scale.x
		_hit.restart()).set_delay(0.14)
	var glint: float = b.glint - b.stamp
	var show: float = b.collect - b.stamp
	t.tween_callback(_glint_once).set_delay(glint)
	t.tween_property(collect_button, "modulate:a", 1.0, b.collect_in).set_delay(show)
	t.tween_property(collect_button, "scale", Vector2.ONE, b.collect_in).from(Vector2.ONE * 0.6).set_delay(show) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(_arm).set_delay(show + b.collect_in)


func _play_reduced(first: bool) -> void:
	_phase = Phase.BUILD
	var t := create_tween().set_parallel(true)
	_build = t
	if first or _scrim.modulate.a < 0.99: _fade_layer_in(t, FADE)
	_hero.position = Vector2.ZERO
	_hero.scale = Vector2.ONE
	_hero.modulate.a = 0.0
	t.tween_property(_hero, "modulate:a", 1.0, FADE)
	_glow.scale = Vector2.ONE
	t.tween_property(_glow, "modulate:a", 1.0, FADE)
	_rays.visible = false
	_rays2.visible = false
	t.tween_callback(_reached_stamp).set_delay(FADE)


func _arm() -> void:
	if _phase != Phase.REVEAL: return
	_phase = Phase.SHOWN
	collect_button.modulate.a = 1.0
	collect_button.scale = Vector2.ONE
	collect_button.mouse_filter = Control.MOUSE_FILTER_STOP
	revealed.emit(_entry.id)
	if not _reduced(): _breathe()


func _breathe() -> void:
	var b := collect_button.create_tween().set_loops(3)
	b.tween_property(collect_button, "scale", Vector2.ONE * 1.05, 0.45).set_trans(Tween.TRANS_SINE)
	b.tween_property(collect_button, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)


func _glint_once() -> void:
	if _phase == Phase.COLLECTING or not is_instance_valid(_glint): return
	var g := _glint.create_tween().set_parallel(true)
	g.tween_property(_glint, "scale", Vector2.ONE * 1.3, 0.16).from(Vector2.ZERO).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)
	g.tween_property(_glint, "rotation", PI * 0.5, 0.4).from(0.0)
	g.tween_property(_glint, "scale", Vector2.ZERO, 0.22).set_delay(0.18).set_trans(Tween.TRANS_QUAD) \
			.set_ease(Tween.EASE_IN)


func _sweep() -> void:
	if _shine == null or not is_instance_valid(_shine) or _phase in [Phase.COLLECTING, Phase.ENDING]: return
	var box := _hero_art.size.x
	var s := _shine.create_tween()
	s.tween_property(_shine, "position:x", box * 1.1, 0.45).from(-box * 0.5).set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_IN_OUT)
	s.tween_interval(0.5)
	s.tween_callback(_glint_once)
	s.tween_interval(1.3)
	s.tween_callback(_sweep)


## Refused, failed or paid before: everything of this entry fades, and the layer too if nothing waits.
func _fade_out(was_collected: bool) -> void:
	_phase = Phase.ENDING
	_kill_tweens()
	_spin = false
	_orbit = false
	if is_instance_valid(_trail): _trail.emitting = false
	if is_instance_valid(_twinkle): _twinkle.emitting = false
	collect_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := create_tween().set_parallel(true)
	_out = t
	t.tween_property(_fx, "modulate:a", 0.0, 0.25)
	if not _reduced(): t.tween_property(_hero, "scale", _hero.scale * 0.6, 0.25).set_trans(Tween.TRANS_QUAD)
	if _queue.is_empty(): _fade_layer(t, 0.0, 0.25)
	t.tween_callback(_end_entry.bind(was_collected)).set_delay(0.26)


func _end_entry(was_collected: bool) -> void:
	var id: Variant = _entry.get("id")
	if was_collected:
		balance = _shown_balance
	_kill_tweens()
	_clear_parts()
	_phase = Phase.ENDING
	entry_finished.emit(id, was_collected)
	if _queue.is_empty():
		_phase = Phase.IDLE
		_entry = {}
		_played = 0
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		finished.emit()
	else:
		_next()


func _kill_tweens() -> void:
	for t: Tween in [_build, _reveal, _out]:
		if t != null and t.is_valid(): t.kill()
	_build = null
	_reveal = null
	_out = null


func _fade_layer_in(t: Tween, seconds: float) -> void:
	for node: CanvasItem in [_scrim, _dim]:
		node.modulate.a = 0.0
		t.tween_property(node, "modulate:a", 1.0, seconds)


func _fade_layer(t: Tween, delay: float, seconds: float) -> void:
	for node: CanvasItem in [_scrim, _dim]:
		t.tween_property(node, "modulate:a", 0.0, seconds).set_delay(delay)


func _reduced() -> bool:
	return GoUi.config.reduce_motion


# ── Flight ───────────────────────────────────────────────────────────────

## One coin: out from the hero, then a curve into the target. Returns when it lands.
func _fly_coin(i: int, count: int, delay: float, value: int) -> float:
	var coin := _art_rect(_art(&"coin"), FLY_COIN * unit)
	coin.name = "Flying"
	coin.modulate.a = 0.0
	add_child(coin)
	var start := _fx.position + _hero.position * _fx.scale.x
	var out := start + Vector2.from_angle(TAU * float(i) / float(count) + 0.3) * randf_range(70.0, 120.0) * unit
	var to := _target_point()
	var t := coin.create_tween()
	t.tween_interval(delay)
	t.tween_callback(func() -> void: coin.modulate.a = 1.0)
	t.parallel().tween_method(func(p: Vector2) -> void: coin.position = p - coin.size * 0.5, start, out, 0.18) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(coin, "scale", Vector2.ONE, 0.18).from(Vector2.ONE * 0.4)
	var ctrl := Vector2(lerpf(out.x, to.x, 0.25) + randf_range(-120.0, 120.0) * unit,
		minf(out.y, to.y) - randf_range(60.0, 200.0) * unit)
	var fly := FLY_TIME + randf_range(-0.05, 0.08)
	t.tween_method(func(k: float) -> void:
		coin.position = out.lerp(ctrl, k).lerp(ctrl.lerp(to, k), k) - coin.size * 0.5
		coin.rotation = k * PI, 0.0, 1.0, fly).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	var land := _target_size() / coin.size.x
	t.parallel().tween_property(coin, "scale", Vector2.ONE * land, fly).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void:
		_land(value)
		coin.queue_free())
	return delay + 0.18 + fly


func _land(value: int) -> void:
	_count(value)
	_hit.position = _target_point()
	_hit.restart()
	bump(target)


func _count(value: int) -> void:
	_shown_balance = maxi(_shown_balance, value)
	if is_instance_valid(target_label): target_label.text = str(_shown_balance)
	counted.emit(_shown_balance)


## A quick punch of [param node] about its centre (a balance pill taking a coin). Nothing under reduce motion.
static func bump(node: Control) -> void:
	if not is_instance_valid(node) or GoUi.config.reduce_motion: return
	node.pivot_offset = node.size * 0.5
	var p := node.create_tween()
	p.tween_property(node, "scale", Vector2.ONE * 1.16, 0.05)
	p.tween_property(node, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _target_point() -> Vector2:
	if not is_instance_valid(target) or not target.is_inside_tree(): return _fx.position + Vector2(0.0, -size.y)
	return _local(target.get_global_rect().get_center())


func _target_size() -> float:
	if not is_instance_valid(target): return FLY_COIN * unit
	return clampf(target.get_global_rect().size.y * 0.6, 16.0, FLY_COIN * unit)


func _local(global: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * global


# ── Parts ────────────────────────────────────────────────────────────────

func _build_parts() -> void:
	_clear_parts()
	theme = GoUi.theme()
	_sparkle = _art(&"fx_sparkle")
	if _scrim == null:
		# 🛑 The screen behind is read again here: a screen under the layer with a frosted scrim of its own (a backdrop)
		#    took the first copy of the frame before its own rows were drawn, and the blur would show that copy.
		var copy := BackBufferCopy.new()
		copy.name = "Behind"
		copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		add_child(copy)
		# 🌫 The look's scrim (frosted where the tier blurs) in its scrim ink, a little deeper than a dialog's, then the
		#    navy dim that lets the light read.
		_scrim = GoStyle.scrim(SCRIM_ALPHA, GoUi.color(GoTheme.SCRIM))
		_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_scrim.modulate.a = 0.0
		add_child(_scrim)
		_dim = GoStyle.scrim(dim, GoUi.color(GoTheme.TEXT))
		_dim.name = "Dim"
		_dim.material = null
		_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dim.modulate.a = 0.0
		add_child(_dim)
	_trail = _particles(36, 0.4, 40.0)
	_trail.name = "Trail"
	_trail.one_shot = false
	_trail.explosiveness = 0.0
	_trail.local_coords = false
	_trail.scale_amount_min = 0.5 * unit
	_trail.scale_amount_max = 1.0 * unit
	add_child(_trail)
	_fx = Control.new()
	_fx.name = "Fx"
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx)
	var big := COIN_SIZE * unit
	_glow = _light(&"fx_glow", big * 2.6)
	_glow.name = "Glow"
	_glow.modulate.a = 0.0
	_rays = _light(&"fx_rays", big * 4.6)
	_rays.name = "Rays"
	_rays2 = _light(&"fx_rays_thin", big * 3.2)
	_rays2.name = "RaysThin"
	_burst = _particles(28, 0.9, 420.0)
	_burst.name = "Sparkles"
	_fx.add_child(_burst)
	_twinkle = _twinkles(big)
	_fx.add_child(_twinkle)
	_ring = _light(&"fx_ring", big * 1.2)
	_ring.name = "Ring"
	_ring.modulate.a = 0.0
	_orbiters.clear()
	for i in ORBITERS:
		var c := _art_rect(_art(&"coin"), ORBIT_COIN * unit)
		c.name = "Orbit%d" % i
		c.modulate.a = 0.0
		c.z_index = 1
		_fx.add_child(c)
		_orbiters.append(c)
	_hero = Control.new()
	_hero.name = "Hero"
	_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero.z_index = 2
	_fx.add_child(_hero)
	_build_hero()
	_amount_group = Control.new()
	_amount_group.name = "Amount"
	_amount_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_amount_group.modulate.a = 0.0
	_amount_group.z_index = 4
	_fx.add_child(_amount_group)
	_amount_coin = _art_rect(_art(&"coin"), AMOUNT_COIN * unit)
	_amount_coin.name = "Coin"
	_amount_group.add_child(_amount_coin)
	_amount_label = Label.new()
	_amount_label.name = "Value"
	_amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_amount_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_amount_label.text_direction = Control.TEXT_DIRECTION_LTR
	_amount_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dress_amount()
	_amount_group.add_child(_amount_label)
	collect_button = GoGlyphButton.make(collect_text, &"", GoTheme.VAR_PRIMARY_BUTTON)
	collect_button.name = "Collect"
	collect_button.glow = true
	collect_button.fit_label = true
	collect_button.custom_minimum_size = COLLECT_SIZE * unit
	collect_button.size = COLLECT_SIZE * unit
	collect_button.pivot_offset = collect_button.size * 0.5
	collect_button.modulate.a = 0.0
	collect_button.z_index = 4
	collect_button.mouse_filter = Control.MOUSE_FILTER_IGNORE # pressable only once fully shown (_arm)
	collect_button.pressed.connect(collect)
	collect_button.resized.connect(func() -> void: if _fx != null: _place())
	_fx.add_child(collect_button)
	# The word grows with the key: a larger unit (a tablet) would leave the look's own size small in a big key. Never
	# below the look's size (a small unit's key is the look's own height); fit_label still shrinks a long word.
	collect_button.fit_base_size = roundi(collect_button.get_theme_font_size(&"font_size") * maxf(1.0, unit))
	_hit = _particles(10, 0.45, 200.0)
	_hit.name = "Pop"
	_hit.scale_amount_min = 0.25 * unit
	_hit.scale_amount_max = 0.5 * unit
	add_child(_hit)
	_fx.modulate.a = 1.0


## The coin, or the heap for a big amount, with its shine (clipped to the art) and its rim glint.
func _build_hero() -> void:
	var hint: int = _entry.amount if _entry.amount >= 0 else _entry.hint
	var heap := hint >= heap_from and _art(&"coin_heap") != null
	_box = COIN_SIZE * unit * (HEAP_SHARE if heap else 1.0)
	var art := _art(&"coin_heap" if heap else &"coin")
	_shine = null
	if art != null:
		var rect := _art_rect(art, _box)
		_hero_art = rect
		if not heap:
			# The shine: a slanted white band clipped to the coin's own shape (clip_children, no shader).
			rect.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
			_shine = ColorRect.new()
			_shine.name = "Shine"
			_shine.color = Color(1.0, 1.0, 1.0, 0.6)
			_shine.size = Vector2(_box * 0.16, _box * 2.0)
			_shine.rotation = deg_to_rad(25.0)
			_shine.position = Vector2(-_box * 0.6, -_box * 0.4)
			_shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rect.add_child(_shine)
	else:
		_hero_art = GoUi.icons().node(GoIconSet.COIN, roundi(_box), GoUi.color(GoTheme.WARNING_FILL))
		_hero_art.size = Vector2.ONE * _box
		_hero_art.pivot_offset = _hero_art.size * 0.5
	_hero_art.name = "Art"
	_hero_art.position = -_hero_art.size * 0.5
	_hero.add_child(_hero_art)
	_glint = _art_rect(_art(&"fx_glint") if _art(&"fx_glint") != null else _sparkle, _box * 0.42)
	_glint.name = "Glint"
	_glint.material = _additive()
	_glint.position = Vector2(-_box * 0.27, -_box * 0.3) - _glint.pivot_offset
	_glint.scale = Vector2.ZERO
	_hero.add_child(_glint)
	_below = 104.0 * unit if heap else _box * 0.62


func _clear_parts() -> void:
	for node: Node in [_trail, _fx, _hit]:
		if is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	for child in get_children():
		if child.name.begins_with("Flying"): child.queue_free()
	_trail = null
	_fx = null
	_hit = null
	_spin = false
	_orbit = false
	_orbit_t = 0.0
	_shake = 0.0


func _dress_amount() -> void:
	var font_px := roundi(AMOUNT_FONT * unit)
	var look := GoUi.theme()
	if look != null and look.get_type_variation_base(VAR_AMOUNT) != &"":
		_amount_label.theme_type_variation = VAR_AMOUNT
	else:
		_amount_label.theme_type_variation = GoTheme.VAR_TITLE_LABEL
		_amount_label.add_theme_color_override(&"font_color", GoUi.color(GoTheme.WARNING_FILL))
		_amount_label.add_theme_color_override(&"font_outline_color", GoUi.color(GoTheme.TEXT))
		_amount_label.add_theme_constant_override(&"outline_size", roundi(font_px * 0.16))
	_amount_label.add_theme_font_size_override(&"font_size", font_px)


## "+N" with the coin on its left as one centred group, scaled as one (the coin never runs into the "+").
func _set_amount(value: int) -> void:
	_amount_label.text = amount_format % value # the whole amount from the first frame: never "+0", never shortened
	var font := _amount_label.get_theme_font(&"font")
	var px := _amount_label.get_theme_font_size(&"font_size")
	var edge := _amount_label.get_theme_constant(&"outline_size")
	var text_w := font.get_string_size(_amount_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + edge
	var text_h := font.get_height(px) + edge
	var coin := AMOUNT_COIN * unit
	var gap := AMOUNT_GAP * unit
	var w := coin + gap + text_w
	var h := maxf(coin, text_h)
	_amount_coin.size = Vector2.ONE * coin
	_amount_coin.position = Vector2(-w * 0.5, -coin * 0.5)
	_amount_label.size = Vector2(text_w, text_h)
	_amount_label.position = Vector2(-w * 0.5 + coin + gap, -text_h * 0.5)
	_amount_group.size = Vector2(w, h)
	_amount_group.pivot_offset = Vector2.ZERO # its origin is its centre
	_place()


## The group in the room: centred a little above the middle, moved up above [member bottom_reserve], scaled down only
## when even that cannot keep COLLECT clear of it.
func _place() -> void:
	if _fx == null or _hero_art == null: return
	var room := Rect2(Vector2.ZERO, size)
	if is_inside_tree():
		var safe := GoSafeArea.usable_rect(get_viewport())
		room = Rect2(_local(safe.position), safe.size / maxf(get_global_transform().get_scale().y, 0.001))
		room = room.intersection(Rect2(Vector2.ZERO, size)) if room.intersects(Rect2(Vector2.ZERO, size)) \
				else Rect2(Vector2.ZERO, size)
	var top := _box * 0.5
	var amount_h := maxf(AMOUNT_COIN * unit, _amount_label.size.y if _amount_label.size.y > 0.0 else AMOUNT_FONT * unit)
	# The key as tall as it really is: its look's face (or a long word's fit) can make it taller than COLLECT_SIZE.
	var bottom := _below + amount_h + COLLECT_GAP * unit + maxf(COLLECT_SIZE.y * unit, collect_button.size.y)
	var floor_y := room.end.y - bottom_reserve
	var ceiling := room.position.y + TOP_MARGIN * unit
	var y := room.get_center().y - room.size.y * 0.06
	y = minf(y, floor_y - bottom)
	_shrunk = false
	var k := 1.0
	if y - top < ceiling:
		var whole := top + bottom
		var space := floor_y - ceiling
		k = clampf(space / whole, 0.3, 1.0) if whole > 0.0 else 1.0
		_shrunk = k < 0.999
		y = ceiling + top * k
	_centre = Vector2(room.get_center().x, y)
	_fx.position = _centre
	_fx.scale = Vector2.ONE * k
	_amount_group.position = Vector2(0.0, _below + amount_h * 0.5)
	collect_button.position = Vector2(-collect_button.size.x * 0.5, _below + amount_h + COLLECT_GAP * unit)


## The rect of COLLECT in this layer's space (tests, and a caller keeping a banner clear of it).
func collect_rect() -> Rect2:
	if collect_button == null or _fx == null: return Rect2()
	var k := _fx.scale.x
	return Rect2(_fx.position + collect_button.position * k, collect_button.size * k)


func _light(art_name: StringName, side: float) -> TextureRect:
	var rect := _art_rect(_art(art_name), side)
	if rect.texture == null: rect.texture = _fallback_light(art_name)
	rect.material = _additive()
	if rect.texture is GradientTexture2D: rect.self_modulate = GoUi.color(GoTheme.WARNING_FILL).lerp(Color.WHITE, 0.4)
	_fx.add_child(rect)
	return rect


func _art_rect(texture: Texture2D, side: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.size = Vector2.ONE * side
	rect.position = -rect.size * 0.5
	rect.pivot_offset = rect.size * 0.5
	return rect


## The skin's painted piece, else null (the caller falls back).
func _art(art_name: StringName) -> Texture2D:
	return GoUi.skin().widget_art(art_name)


## A look without the painted light: a soft white radial (or ring) the light's tint colours.
func _fallback_light(art_name: StringName) -> Texture2D:
	var g := Gradient.new()
	if art_name == &"fx_ring":
		g.offsets = PackedFloat32Array([0.0, 0.8, 0.9, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	elif art_name == &"fx_glow":
		g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
	else:
		g.offsets = PackedFloat32Array([0.0, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	return tex


static func _additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


func _particles(count: int, life: float, speed: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = count
	p.lifetime = life
	p.explosiveness = 1.0
	p.texture = _sparkle if _sparkle != null else _fallback_light(&"fx_glow")
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = speed * 0.45 * unit
	p.initial_velocity_max = speed * unit
	p.damping_min = speed * 0.8 * unit
	p.damping_max = speed * 1.2 * unit
	p.scale_amount_min = 0.6 * unit
	p.scale_amount_max = 1.4 * unit
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.2))
	curve.add_point(Vector2(0.2, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curve
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	fade.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	p.color_ramp = fade
	p.material = _additive()
	return p


func _twinkles(big: float) -> CPUParticles2D:
	var p := _particles(8, 1.0, 10.0)
	p.name = "Twinkles"
	p.one_shot = false
	p.explosiveness = 0.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = big * 0.85
	p.initial_velocity_min = 0.0
	p.damping_min = 0.0
	p.damping_max = 0.0
	p.scale_amount_min = 0.5 * unit
	p.scale_amount_max = 1.0 * unit
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.5, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curve
	return p


# ── Every frame ──────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _phase == Phase.IDLE or _fx == null: return
	_age += delta
	var big := COIN_SIZE * unit
	if _orbit:
		_orbit_t += delta
		for i in _orbiters.size():
			var a := _orbit_t * 2.0 + TAU * i / _orbiters.size()
			var c := _orbiters[i]
			var front := sin(a) # + : in front of the coin
			c.position = Vector2(cos(a) * big * 0.95, sin(a) * big * 0.3 - big * 0.05) - c.size * 0.5
			c.scale = Vector2.ONE * (0.8 + 0.25 * front)
			c.scale.x *= maxf(0.15, absf(cos(_orbit_t * 5.0 + i)))
			c.z_index = 3 if front > 0.0 else 1
	if _spin:
		_rays.rotation += deg_to_rad(28.0) * delta
		_rays2.rotation -= deg_to_rad(18.0) * delta
		_pulse += delta
		_glow.self_modulate.a = 0.85 + 0.15 * sin(_pulse * TAU / 1.2)
	if _shake > 0.0:
		_fx.position = _centre + Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
		_shake = maxf(0.0, _shake - 45.0 * unit * delta)
		if _shake == 0.0: _fx.position = _centre


func _gui_input(event: InputEvent) -> void:
	var down: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if down and _phase != Phase.IDLE:
		accept_event()
		tap()
