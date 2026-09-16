# Changelog

All notable changes to gohud are recorded here. Versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- **`GoSnackbar` — a snackbar that places itself, queues, and can carry a button.** It sits at the bottom
  (or the top), above the safe area and the virtual keyboard, and goes away on its own.
  `snack.show_text("Saved", GoTheme.SUCCESS)` for a line; `await snack.post({"text": "Item dropped",
  "actions": ["Undo"]})` returns the index of the button that was pressed, or `-1` when it timed out.
  This is what `GoNotice` structurally could not be: that widget turns input and focus off for its whole
  subtree, so a button inside it can never be pressed, and the screen that owns it decides where it goes.
  Messages **queue** instead of overwriting each other, repeats of the same line are merged (a server that
  fails four times a second no longer stacks four minutes of alerts), and a snackbar with no button lets
  input through so the game underneath keeps working.

- **Six widgets that games reach for constantly.** `GoSpinner` (an indeterminate wait; `GoSpinner.busy(button,
  true)` turns a button into a spinner in place, keeps its size, and blocks the double press that duplicates a
  purchase), `GoBadge` (the unread dot, the NEW tag, `99+`; `GoBadge.attach(button, count)` hangs it on a
  corner and hides itself at zero), `GoField` (label + control + hint + **per-field error**, so a sign-up form
  can say which box is wrong instead of one line at the top), `GoInputGroup` (an input and its button welded
  into one shape), `GoContextMenu` (long-press on touch, right-click on desktop, cancelled the moment the
  finger moves so scrolling a list no longer pops menus), and `GoPopover` (`GoSurface`'s anchored placement in
  one line, for item cards and skill descriptions — one open at a time).

- **Four more that round out lists and screens.** `GoTable` (sortable headers and selectable rows; numeric
  columns sort as numbers, so `9124` no longer outranks `91240`), `GoPagination` (numbered pages that keep the
  current one centred, plus a mobile-friendly "more" row), `GoDrawer` (a panel that slides in from the left or
  right for tablet and desktop layouts, where `GoSheet`'s bottom sheet covers too much), and `GoCombobox`
  (a picker with a search line that matches **inside** names, not just their start — the difference between
  finding "불꽃의 검" by typing "검" and finding nothing).

- **Five shaped for games rather than for web forms.** `GoRewardCalendar` (daily attendance rewards — what
  matters is which day you are on, not which date), `GoRadar` (the character stat pentagon, with a dashed
  overlay to compare gear), `GoDonut` (damage share, currency split; collapses past five slices and carries a
  legend with words, not only colour), `GoCodeInput` (coupon and gift codes — one hidden field receives the
  text and the cells are drawn, so pasting `ABCD-EFGH-IJKL` works and IME input cannot lose a character), and
  `GoCarousel` (store banners and character select; it does **not** advance on its own by default, and never
  when `reduce_motion` is on).

- **`GoUi.spoken(parts)`** joins the pieces a screen reader should hear as one phrase. Widgets were each
  building `"%s %s"` inline, which both scattered the rule and leaked past the check that keeps display text
  out of the code.

- **`.github/workflows/tests.yml`** runs `tools/check_all.sh` on every push and pull request. Every check was
  already headless; nothing ran them automatically, so a broken one could sit in the tree for days.

- **`tests/gohud_extra_test.gd`** — 134 checks covering the widgets above, including one that would have
  caught the theme bug below, and one that measures every fault the review turned up.

- **`/gohud update`** and `setup.md` §7 — how to update the add-on **and** the skill, and how to tell when the
  two have drifted apart. A skill that is ahead of the add-on makes an agent recommend APIs the project cannot
  run; a skill that is behind hides the widgets that exist.

- **The demo and the gallery show every new widget, live.** The gallery has sections for feedback, badges,
  fields, lists, overlays and game shapes; the demo's home screen grew a *Newest widgets* card you can press,
  plus cards for all eighteen classes. Nothing there is a picture — every button reports to the activity log.

### Changed

- **The documentation site is five pages instead of three, and its menu is generated.** `index.html` had
  grown to 563 lines carrying a landing page, an install guide, a tutorial, a reference summary and the
  repository's own tooling; it is now an overview that signposts [`install.html`](www/install.html) and a
  new [`ai.html`](www/ai.html). The three original file names never move — released ZIPs link to them
  absolutely — so pages are only ever added. `#install`, `#start` and `#ai` stay on the front page as
  signposts, which keeps every published anchor working.

  The header menu was the worse problem. It was hand-written in 51 files and had drifted: `www/ko/widgets.html`
  was missing the `#messages` entry the other sixteen languages had, `#factory` read `GoStyle` everywhere
  except Korean, and `#tokens` was `令牌` in Simplified Chinese but `Token` in Traditional. `check_site.py`
  compares `<section id>` lists, so none of it was ever caught. The menu is now generated from
  [`tools/site_nav.py`](tools/site_nav.py), which also records the four rules for what may appear there —
  in particular that a section inside a document (`#medieval`, `#tokens`, `#own`) is not a global menu item.
  That is the left-hand table of contents' job, and `toc.js` had in fact been hiding those links all along.

- **The site leads with the AI skill.** The hero's first button and a bordered menu entry both open
  [`ai.html`](www/ai.html), whose first section is the block to paste into a coding agent; the install page
  opens with a card pointing at the same block. The block stays in English in all seventeen languages — it
  is an instruction to an agent, and every command, path and folder name inside it is English — with the
  reason, and the fact that you may ask your own questions in any language, written underneath in the
  reader's language. Every line in it is checked against the repository: the plugin id against
  `.claude-plugin/marketplace.json`, the three skill folders against `skills/gohud/commands/preview.md`.

- **`GoDialogs.alert()` now queues instead of vanishing.** When a dialog was already open, the second
  `alert()` returned in 0 ms without showing anything; because it returns `void`, the caller could not tell
  and moved on believing the player had read it. Two server errors in a row meant the second was never seen.
  Alerts now wait their turn. `confirm()` is unchanged and still returns `false` immediately — a question that
  arrives late gets answered by someone who no longer knows what they are agreeing to, and the caller can see
  the `false`. Set `queue_when_busy` to make questions queue too, and `clear_pending()` releases anything
  waiting when you leave the screen.

### Fixed

- **The code "copy" button never appeared on a phone.** It was shown by `pre:hover`, and a finger has no
  hover state — the trap this site's own widgets page warns about. Since copying the install block into an
  agent is the shortest path through the whole site, the button now shows unconditionally where there is no
  hover, at a 44px touch size.

- **Long lines in Korean, Japanese and Chinese.** Body text was capped at `74ch`, but `ch` measures the
  digit zero; full-width characters are twice that, so those pages ran 80–95 characters per line against a
  45–75 recommendation. They are now capped in `em`, where one full-width character is 1em.

- **Table headers were letter-spaced and uppercased in Arabic.** Arabic letters join, so extra tracking
  pulls a word apart into separate glyphs, and the script has no case for `uppercase` to change. Both are
  now off for Arabic, the CJK languages and Thai.

- **The skin dial tables are collapsible.** All three open at once is 32 rows, and on a phone each row
  becomes three stacked blocks — roughly 2,900px of scrolling to reach the next paragraph. The first skin
  stays open; `site/ux.js` opens a collapsed one when a link points inside it.


- **Changing the look at runtime now reaches widgets that are already on screen.** `GoUi.use_preset()`
  promises that theme, skin and icons move together, but only newly created widgets changed: an HP bar and a
  quick slot built before the switch kept the old accent colour and sat next to new ones in a second theme.
  Only `GoSurface` and `GoForm` had registered `GoUi.watch()`; `GoBar`, `GoSlot`, `GoJoystick`, `GoNotice`,
  `GoPromptCard`, `GoIconButton`, `GoCoachMark` and `GoHudAnchor` — which between them read theme values in
  over ninety places — had not. They now re-read colours, icons and metrics in place, without rebuilding
  their nodes.

- **The `standalone` check no longer fails on files that are not part of the add-on.** It walked `builds/`
  (unpacked copies of older releases, git-ignored) and `examples/usage/` (a separate project with its own
  `project.godot`, carrying an add-on copy two versions behind), so it reported `res://` references that
  belong to neither. It also fed those stale copies to `_own_symbols()`, which **weakened** the check by
  accepting names that no longer exist. Both are skipped now.

- **The `standalone` check recognises inner classes.** `class Ticket extends RefCounted` inside a file was not
  counted as the add-on's own name, so using it read as a dependency on the host project.

- **Twelve faults a five-AI review found, each confirmed against the code before it was touched.** Four of the
  five reviewers were out of quota, so every claim the one that ran made was checked by hand or by running it —
  and one was **disproved** (a lambda followed by an argument does parse; the button's tone was applied). What
  survived: `GoCodeInput`'s hidden field sat in a container that pushed it into its own column, so tapping a
  cell never opened the keyboard; `GoBadge`'s dot read as "Nothing here yet" to a screen reader — the exact
  opposite of what a notification dot means; `GoSpinner` froze instead of pulsing under `reduce_motion`;
  `GoSnackbar`'s repeat-merging answered a caller that was still waiting; `GoDialogs` and `GoSnackbar` left
  `await` parked forever when their node left the tree; `GoDrawer` read the **editor's** locale, so RTL never
  flipped it; `GoContextMenu`'s danger colour was applied to the whole menu; a long-pressed control could not
  be re-attached; `GoCarousel`'s dots were below the touch minimum and kept animating while hidden;
  `GoConsole` had Korean strings compiled in; and `GoTable` appended its sort arrow to a **translation key**.
  Running the demo then turned up one more that no reviewer named: `get_meta(key, default)` logs an error when
  the key is absent, so three widgets now ask `has_meta` first. Details and the disproof:
  `.cowork/gohud-new-widgets/final-report.md`.

- **Five layout faults that only a screenshot could find.** Every one passed the headless checks and was
  caught by drawing the widgets on a virtual monitor: `GoTable` rows lost their text entirely (a wrapping
  label first laid out at zero width froze its minimum height at 1 dp, leaving rows that were painted but
  empty — table cells no longer wrap); `GoBadge.attach()` placed the badge outside its host, then on the
  wrong corner (`Control.position` is parent-space and ignores anchors — it now sets `offset_*`, so the badge
  follows a host whose size is decided later); `GoSpinner.busy()` put its spinner outside the button, leaving
  a blank one; `GoKbd` broke `Ctrl` across two lines and let one cap eat the whole row; and `GoCodeInput`
  pushed twelve cells past the edge of a 720 dp phone. The regression test now measures each of these.

- **The demo app opens with `godot` alone, and starts on a home screen.** `examples/demo` now has
  `main.tscn` as its main scene: a doorway that carries no gohud class name, so it still parses and draws when the
  `addons/gohud` link or the import cache is missing — the state that used to leave an empty window and one
  `Identifier "GoUi" not declared` line. In that state it says what is missing, makes the link, imports the project
  once and reopens the window; otherwise it hands straight over to `home.tscn`.
  The home screen is built from nothing but add-on widgets, and it is itself a tour of the kit. Four
  `style_choice_card` buttons open the widget gallery, the 15-chapter guided tour, the showcase screen and the
  medieval look inside the same window (`1`–`4`, or a click; a bar across the top names the screen and its source
  file, and **Home** returns). Beside the pitch sits a live HUD — three `GoBar` gauges and four `GoSlot` quick slots
  that answer each other. Below it, six cards of widgets to press (button tones and icon buttons; a field, a toggle
  and a slider; segments, a picker and a colour grid; an avatar, list rows and a progress bar; the notice, dialog,
  sheet, prompt and coach-mark buttons; and a live activity card that prints every callback they fire), then all 19
  classes grouped by the job they do, each with its one-line description and the line of code that uses it.
  Body text is held to a readable measure (1120 dp) rather than stretched to the window, every block sits in a
  responsive grid so a wider window gains columns instead of longer lines, the wordmark row splits in two on a
  phone, and a faint grid with two soft blooms — drawn from the current theme's own tokens — sits behind it all.
  `godot -- --open=<gallery|tour|showcase|medieval>` skips the home screen; recording flags (`--auto`, `--cinema`,
  `--exit`) open the tour with no shell around it, so `run.sh --record` is unchanged. `shot.gd` now takes
  `SHOT_SCENE` and defaults to the home screen.

- **`GoStyle.style_choice_card(node, accent, selected, toggle, dim_disabled, filter)`** gives a `Button` the faces of a
  pick-one card. Every state has zero content margin — the card's inner `MarginContainer` pads once, so the chosen
  card never grows and the row never shifts. The chosen state gets an accent border (0.9, 2 dp) and a 16 % accent
  fill; hover tints only the border. Faces come from `surface()`, so chamfered and medieval skins keep their shape
  and only change colour. With `toggle` on, the pressed state is the selection (group cards with a `ButtonGroup`);
  with it off, `selected` draws a list that is rebuilt on every change. `dim_disabled = false` keeps the disabled
  face identical to the normal one. `mouse_filter` is left alone unless `filter` is given — pass
  `MOUSE_FILTER_PASS` for cards inside a scroll, and keep the default for buttons laid over the game.
- **`GoStyle.card_body(card, padding, spacing)`** builds the content column inside a card whose own face has no
  padding, such as a `style_choice_card` button: one inner margin, a vertical list, and a card height that follows
  the content, wrapped text included. `GoStyle.let_input_through(node)` makes a subtree ignore the mouse, so the card
  takes the press and shows its hover face instead of the text on it. `GoStyle.line(text, role, ink)` is a
  one-line label that ellipsizes instead of wrapping.
- **`GoStyle.chip` takes an icon and an urgency flag**: `chip(text, ink, translate, icon, icon_size, urgent)`. With an
  icon and no text you get an icon-only chip, which is what a HUD buff row is made of; `urgent` swaps the border for
  the danger colour so a buff about to expire reads as such without changing its shape. The face still comes from
  `GoSkin.chip_box`, so a skin that redefines it keeps its own shape (its signature is unchanged).
- **`GoStyle.style_chip_button(node, accent, filled, urgent)`** puts that same tinted pill face on every state of a
  `Button` — the HUD's status buttons, badges and small list actions. `filled` paints the face in the accent for an
  emphasised action; the caller sets the label colour. The focus face and `mouse_filter` are left alone, because a
  button laid over the game must keep `MOUSE_FILTER_STOP` or its press leaks into the world.
- **`GoStyle.style_chip_label(node, accent, urgent)`** puts the chip face on a `Label` you already built, for places
  that measure their own width and cannot use the `chip()` container — a badge in a HUD status bar, for one.
- **`GoStyle.hud_panel(accent, pad_x, pad_y)` and `GoStyle.chip_panel(accent, fill_alpha)`** are the container versions
  of the floating and chip faces: a dock or status bar laid over the game, and a pill that holds more than one line (a
  roster card with a name, a level and a gauge). The host adds children and never builds a face of its own. A HUD has
  touch geometry fixed per screen, so `hud_panel` takes the inner padding as an argument (negative keeps the skin's
  own) — do **not** wrap a `padding()` box around it as well. Two layers of padding halve the content width, and a
  one-line label that ellipsizes then disappears entirely while an assertion on its `text` still passes.
  `GoStyle.face_padding(face, pad_x, pad_y)` applies the same to a face you hold yourself; the shape (border, glow,
  corners) is untouched, so chamfered and medieval skins keep theirs.
- **`GoStyle.choice_grid(items, selected, action, translate)`** lays out swatch, icon or text cards and keeps exactly
  one picked — for character colours, avatars or difficulty cards, where `segmented` (text only) and `chip`/`avatar`
  (not pressable) do not fit. An item is `{color, icon, texture, text, tooltip}`; a colour swatch is drawn with the
  real colour and the picked cell gets a thick accent border instead of a fill, so the swatch colour never shifts
  and the choice is visible without relying on colour. Cells keep the touch minimum, pass drags to scrolls, keep the
  same inset in every state, and keep their own style inside a `GoForm`. New skin faces `GoSkin.choice_box(state)`
  and `GoSkin.swatch_box(diameter, color)` let a skin restyle them.
- **Compact button padding tokens.** `compact_padding_x` and `compact_padding_y` (`GoTheme.COMPACT_PADDING_X` /
  `COMPACT_PADDING_Y`) set the side and top/bottom content margin of the `GoCompactButton` style. They are separate
  from `padding_compact`, which insets cards and notices, so changing one no longer moves the other. Built-in themes
  keep 10 and 5 (no visual change), and a palette file can override both through its `shape`.
- **`GoStyle.audit_compact_padding(root)`** lists compact buttons that show text but whose style has less side margin
  than the token. That is how text ends up touching the capsule border when a host theme reuses an icon or close
  style for compact buttons. Icon-only buttons and per-button overrides are skipped unless `include_overrides` is set;
  a host that chains its own variation to `GoCompactButton` passes that name in `variations`.
- **`GoDialogs` button layout.** `action_layout` chooses `VERTICAL` (default, unchanged), `HORIZONTAL` (one row, half
  each) or `AUTO` (one row only when both labels fit half the card on one line, otherwise stacked). `action_gap` sets
  the space between the buttons and `body_gap` the space between the message and the buttons, so the question and
  the choice read as two parts. `set_next_action_layout()` changes only the next dialog. The row is built the first
  time a dialog opens, so an autoloaded `GoDialogs` adds no nodes at startup, and `confirm()` / `alert()` keep their
  signatures.
- `GoSurface.section_gap()` and `GoSurface.content_inset()` return the gap and card padding actually applied (both
  shrink one step on small screens).
- `GoStyle.segmented(..., compact = true)` makes tight segments to sit inside a pill over a map or the game: each
  segment is at least the touch size wide (instead of 1.5×), uses the compact button padding in every state so
  pressing never changes its width, and only the selected segment is filled — unselected segments draw no face and
  keyboard focus is a soft ring, so the pill and the segments never show two borders.
- `GoSkin.overlay_box(h_margin, v_margin, fill_alpha)` is the pill face for controls laid over the game or a map —
  the background color at 0.82 opacity with a 1 dp border, so text stays readable whatever is behind it.
- `GoSheet.add_footer(node)` puts a node in the current page's footer and shows the footer; the next `open()`
  removes it. `open()` only hides the footer, so a page that called `footer().add_child()` on every open stacked a
  new Close button next to the old ones (the gallery's sheet did). Nodes added with `footer().add_child()` still stay
  across pages, for sheet-wide parts such as a snackbar.
- **`GoStyle.style_brand_button(node, fill, ink, edge, mark, gap, inset, base, mark_ink)`** puts the faces of a
  provider's sign-in button on a `Button` — the one place where a review guideline, not the skin, owns the colour.
  gohud holds the states and the caller holds the values: the face is painted `fill`, hover and press move it away
  from that colour (a dark plate lightens, a light plate darkens, as the vendors' own bundles do), disabled pulls
  toward grey, and focus empties the centre so only the border is left for the shared focus ring. `mark` caps the
  mark with `icon_max_width` and `gap` is the space to the label; `inset` is the side padding (top and bottom go to
  zero — the height belongs to the caller); `base` is a face to clone so the button keeps the *shape* of the screen's
  other buttons while carrying the brand's colour; `mark_ink` stays white by default so a multi-colour official mark
  (Google's four-colour G) is never tinted by the theme. Negative `mark`, `gap` and `inset` leave those alone.
- **`GoStyle.center_button_content(node, min_inset)`** sets the mark and the label together in the middle of a
  button — the shape both Google and Apple ship. 🛑 `icon_alignment = CENTER` draws the mark *on top of* the label;
  this keeps the label left-aligned and writes the left padding `(width − mark − gap − text) / 2` into every state
  instead, with `min_inset` (negative: the face's own left margin) as the floor. Call it on `resized`, on a language
  change and when the mark arrives late; an unchanged value is not written back, so there is no resize loop.
- **`GoStyle.apply_icon(..., inset)`** insets a font-set glyph from the button's left edge and widens the *both* side
  text margins to the end of the icon, so a centred label in a narrow full-width button can no longer overlap it.
  Negative (the default) keeps the previous behaviour, and texture sets are unaffected.
- **`GoStyle.tint_button(node, ink, active)`** sets only the label and icon colours of a button that draws no face —
  a links row or a quiet menu that speaks through colour. A transparent argument is left alone, so a button whose
  resting colour already came from `typography()` can take just the pressed colour.
- **`GoStyle.bare_panel(node)`** drops the face of a container and keeps its place, stacking and spacing. Removing
  the node instead would take the paths and the assertions with it.
- **`GoStyle.style_notice_panel(node, accent, tint, padding)`** puts the skin's `notice` face on a container you
  already built (`alert()` builds its own): an accent border, and with `tint` the background pulled that far from
  the background colour toward the accent — one semantic colour instead of a new palette.
- **`GoStyle.style_mono_text(node, font, selection, selected_ink)`** makes a `RichTextLabel` a monospaced, selectable
  block for a diagnostic code or a log line. gohud ships no font, so the caller passes one (a `SystemFont` that finds
  the device's own is enough); `selection` and `selected_ink` replace the default light-grey selection that swallows
  light text.
- **`GoStyle.pin_font_size(node, size)`** nails a font size in pixels for the rare place where the size is fixed from
  outside (a sign-in button whose guideline ties the text to the button height). Everything else should use a
  `typography()` role, which follows the theme and the screen.
- **`GoStyle.style_popup(popup, spacing)`** spaces a `PopupMenu`'s rows out to the touch minimum — popup text is body
  size, so the rows come out thinner than a finger. The value survives clearing and refilling the items.
- **`GoStyle.overlay_panel(pad_x, pad_y, fill_alpha)` and `GoStyle.style_overlay_panel(node, …)`** are the container
  versions of `GoSkin.overlay_box` — the small pills that sit **on a drawing**, such as the title and the view switch
  floating over a map. `hud_panel()` is the dock laid over the game; this one is the chrome laid over a picture, dark
  enough that a label stays readable whatever the drawing does underneath. The same rule applies: do not wrap a
  `padding()` box around it as well.
- **`GoStyle.face_insets(face, left, top, right, bottom)`** sets a face's four sides separately, leaving any negative
  side alone. `face_padding()` covers the symmetric case; this is for a pill whose right edge is already a 48 dp icon
  button, where another face margin would push the row past the card.
- **`GoStyle.hud_panel(…, variant)` and `GoStyle.style_hud_panel(node, accent, pad_x, pad_y, variant)`**: the floating
  face can now be any token box (a sheet unfolded over the game is the `card` box with a shadow, not the HUD box), and
  a `PanelContainer` you already built can be re-faced. A badge whose colour follows a value — green, amber or grey by
  how much experience a place is worth — restyles instead of rebuilding its node. The existing signature is unchanged.
- **`GoStyle.style_disc_button(node, diameter, accent, fill, fill_alpha, press_alpha)`** gives a `Button` the six
  states of a round control — the zoom and recentre discs floating over a map. Content margin is zero in every state
  and the corner radius is half the diameter, so the visible size is exactly what the caller asked for and pressing it
  never shifts the row. Being round *is* the meaning here, so the face comes from `box()` rather than `surface()`: a
  chamfered or forged skin would otherwise keep its outline and turn the circle into a square, as `style_hud_disc()`
  already decided. `mouse_filter` and the focus ring behaviour follow `style_chip_button`: a button laid over the
  game must keep `MOUSE_FILTER_STOP` or its press leaks into the world. `style_hud_disc()` remains the face for a
  `panel`-keyed container; this is the button.
- **`GoStyle.glyph_text(node, icons, …)` takes more than one icon**, joined by a space — a button whose meaning is
  made of two glyphs (a list plus a chevron reads as "a list that unfolds"). **`GoStyle.glyph_width(icons, size, set)`**
  measures what that text will be, so a layout can decide whether a cell folds without asking the button: a button's
  minimum width depends on whether it currently shows a word or a glyph, so asking it feeds the decision its own
  output and the cell flips back and forth on every press.
- **`GoStyle.font_role(node, role, ink)`** sets a node's font size (and colour) from a role token **without touching
  `theme_type_variation`**. `typography()` swaps the variation as well, so it cannot be used on a node whose variation
  carries its face — a button, or one cell of a segmented control, loses its face entirely. It also clears the font
  override, which is how a cell that `glyph_text()` switched to the icon font returns to ordinary words.
- **`GoStyle.style_hud_disc(node, diameter, edge_width, edge_ink, fill, detail)`** puts the face of a round HUD button
  on a `panel`-keyed container. The corner radius is half the **visible** diameter, so buttons of different sizes stay
  round — a radius fixed in the theme turns a 104×64 control into a pill. With no `fill` the face does not draw its
  centre: the disc itself is a shared gradient image drawn by a child, and painting the face as well lays another
  colour over it. `detail` defaults to 1 because a HUD carries twenty of these and each corner otherwise costs a
  triangle fan; pass 8 or 16 for a large disc that must read as a smooth circle.
- **`GoStyle.style_slot_face(node, accent, lit)`** puts `GoSkin.slot_box` on any container, so a game whose slot stacks
  its own rows (icon, count, remaining seconds) gets the same face as `GoSlot` without adopting its layout, and follows
  a skin swap with it.
- **`GoStyle.style_count_badge(node, fill, ink, edge, edge_width, radius, pad_x, detail)`** fills a small `Label` with a
  meaning colour and rings it in a contrasting one — the count on a notification badge, which has to be seen.
  `GoSkin.badge_box` is the quiet badge that sits on a surface; this is the loud one. The font size is **not** set here:
  give the label a role with `typography()`, or pinning it leaves that one badge behind on a mobile type shrink.
- **`GoStyle.glyph_type(node, size, ink, states)`** re-inks a node that already carries a glyph, for a button restyled
  on every press, hover and toggle. A negative `size` is left alone — HUD glyph size is geometry proportional to the
  touch diameter, not a token. On a `Button` the hover, pressed, hover-pressed and focus colours are set as well: miss
  one and the glyph flips to the theme default the moment it is pressed with the pointer over it.
- **`GoStyle.spacing(node, horizontal, vertical)` and `GoStyle.edge_insets(node, left, top, right, bottom)`** give a
  container's separation and a `MarginContainer`'s margins as plain values, for the two cases a token cannot express:
  a **negative** gap, where touch boxes are deliberately overlapped (48 dp slots stepped 40 apart), and a zero one,
  where rows must meet with no seam. `edge_insets` leaves any negative side untouched, so a HUD pinned to one screen
  edge sets only the sides it pads.
- **`GoStyle.card(accent, border_alpha, border_width, pad)`** takes the emphasis of its border and its inner padding,
  so a list can draw one card louder than the rest — the character last played, the warning that has to be read —
  without the caller building a face. Negative values keep whatever the skin's own face carries, and the face still
  comes from `surface()`, so chamfered and medieval skins keep their shape. The one-argument call is unchanged.
- **`GoStyle.plate(variant, fill, edge, radius, border)`** is a `Panel` laid *behind* something: the tinted cell a
  portrait sits in, or the visible surface of a HUD card that is shorter than its 48 dp touch box. `card()` and
  `hud_panel()` hold children; this one is a single panel the caller anchors and sizes. Only the values given are
  applied, the shadow and content margin are zeroed (a face laid behind another blurs the text above it), and it
  ignores the mouse so a button on top still takes the press.
- **`GoStyle.disc_panel(diameter, accent, fill_alpha, edge_alpha)` and `GoStyle.style_disc_panel(node, …)`** are the
  container versions of `disc()` — the round play mark on a card, an avatar well — and `style_disc_panel` re-faces a
  `Panel` already on screen, for a disc whose colour follows a choice (a preview that turns with the gender picked).
  `GoStyle.style_disc_label(node, diameter, accent, fill_alpha, edge_alpha)` puts the same disc on a `Label` pinned by
  anchors, which cannot use the container — an index badge in the corner of a thumbnail.
- **`GoStyle.style_overlay_button(node, accent, fill_alpha)`** gives a `Button` laid over a card the faces of a press
  area that draws no shape of its own: no border, no shadow, zero padding in every state, and a faint accent wash on
  hover and press only. A whole card that is one tap is built this way — the card's own face already draws the border,
  and a second one over it doubles it. `mouse_filter` is left alone.
- **`GoStyle.text_shadow(node, ink, offset_y, offset_x)`** drops a shadow behind text that sits directly on the world
  or a picture with no face under it — a HUD name and level. A negative offset leaves that axis to the theme.

### Changed

- **Documentation site moved to `www/`.** The site now lives in `www/` at the repository root, and a GitHub Actions
  workflow publishes that folder as the top of https://thruthesky.github.io/gohud/ — pages are at `/gohud/`,
  `/gohud/theming.html` and `/gohud/ko/` instead of under `/gohud/docs/www/`. `www/404.html` forwards the old
  page addresses, and the deployed site keeps a copy of every image at its old `docs/www/img/` address, so the
  READMEs inside released ZIPs still show their pictures. The add-on itself is unchanged.

### Fixed

- `GoSurface` counted the gaps between header, body and footer with the `gap` token even on small screens, where the
  column uses `gap_small`, so short cards came out taller than their content and the space above the footer grew.
- A reused `GoDialogs` kept the minimum button width of a long label when the next label was a single short word.
- `GoSurface` placed centered and anchored cards at fractional positions (for example on a phone screen 349.09 units
  wide). Godot stores a control's size as position plus size, so a 184-unit card became 183.99997, and the card
  padding (a `MarginContainer`) rounds its child down to whole units — the body lost one unit and a one-line message
  showed a scroll bar the first time a dialog opened. Card size and position are now whole units.
- `GoStyle.box()` (and `floating()` / `disc()`, which build on it) returned an empty `StyleBoxFlat` when the skin gave
  a custom StyleBox, as sci-fi and medieval do. The flat box had no content margin, so cards built through the legacy
  API put their text against the border. It now copies the frame's content margin, background, border colour and
  width, radius and shadow; only the chamfered or forged outline is lost.
- A `GoForm` built in code stopped routing Android Back when `%BackButton` was owned by the form (or by a holder
  that owned only the form and the button). The form moves its scroll into an edge frame in `_ready`, and Godot's
  `reparent()` restores only the owners shared with the moved node, so the button's owner was cleared and the lookup
  failed silently. `GoScroll.use_panel_edge()` now restores every descendant's owner after the move. Scenes saved as
  `.tscn`, where the root owns every node, were not affected.
- `GoDialogs` filled `{placeholders}` from `args` only in the body, so a title such as `Drop {item}?` showed the
  braces. The title is now formatted with the same `args` (after translation for `confirm_key()` / `alert_key()`).

## [1.0.3] - 2026-09-14

### Added

- **Showcase images on the homepage.** The English and Korean overview pages now open with medieval
  (character, inventory and quests; forms, grids and prompt cards) and sci-fi (touch controls)
  showcase images, served from `docs/www/img/showcase-*.webp`.

### Changed

- `LICENSE` names the copyright holder: Copyright (c) 2026 JaeHo Song.

## [1.0.2] - 2026-09-13

### Added

- Both standalone demo scenes now have a top Theme dropdown for Default, Sci-fi and Medieval.
  The simulation pauses its bot while choosing, safely rebuilds the current chapter and preserves
  playback speed and pause state. Start, completion and explore screens support the same selector.

- **Medieval presets:** `medieval_dark` (iron and leather) and `medieval_light` (parchment),
  with antique-gold frames, restrained corner engraving, rivets, readable red/blue/olive bars,
  16 original engraved icons and Cinzel headings (bundled with its OFL license). Default and
  sci-fi resources remain unchanged. Try `examples/medieval/medieval.tscn` for character,
  inventory and quest interfaces built with the existing widgets.
- **Custom medieval themes:** palette JSON supports `shape.kind = "medieval"`, material grain,
  ornaments, bevels and per-role fonts. Themes can inherit other JSON themes, preserving their
  fonts, icon set and skin dials; inheritance cycles fail explicitly. Medieval skin dials cover
  slots, rivets and metal highlights. English and Korean docs include usage and term popups.
- **README and website brought up to date.** Both READMEs link the homepage
  (https://thruthesky.github.io/gohud/), describe the six presets, the JSON theme blocks, the
  `destructive` dialog flag, `keyboard_focus`, fill tokens and the latest verification run, and drop
  the stale "no bundled font" and "84 icons" claims. The site's overview pages gain preset tables,
  medieval screenshots, runnable examples and a checks/releases section; theming and widget pages
  cover medieval shapes and icons, `GoStyleBoxMedieval`, dialog options, tour steps and two-line list rows.

### Fixed

- **Balanced list rows.** Rows with a title and description now use roomier, equal vertical
  padding and center the text pair alongside the icons, including when the row grows taller.
  Wrapped descriptions retain their spacing and the whole row remains tappable.
- Exclude the standalone `examples/usage` project and its installed addon copy from release ZIPs.

## [1.0.1] - 2026-09-13

### Added

- **Automatic package versions.** `tools/package.sh` increments the patch version by default;
  `--increase-minor-version` increments minor and resets patch to zero. Successful packaging
  updates `plugin.cfg`, `GoUi.VERSION` and dated changelog entries together. Failures preserve
  the source version; checks exercise packaging in temporary copies without creating a release.

- **GitHub Pages completion.** English-first documentation lives in `docs/www`, with Korean
  counterparts, 27 documented skin dials, and a root entry for the configured `main / (root)`
  deployment. Technical terms support hover, touch and keyboard access, including Escape and
  focus restoration. Fixed responsive CSS, mobile code wrapping and table group labels.
- **Reliable completion checks.** Theme freshness compares generated file contents in an isolated
  copy; viewport failures now propagate through the aggregate checker. Site checks validate CSS
  braces, local section links, the English entry and the absence of a tracked recursive demo link.
  Demo setup generates that ignored link locally, fixing the previous Pages build loop.

- **The site lists every skin dial, generated from the scripts.** The theming page said only what
  *kinds* of numbers `skin.dials` accepts; the names themselves lived in the JSON (I-70). `make_site.py`
  now reads each `@export var` and the `##` line above it from `GoSkin` and `GoSkinSciFi` and writes a
  name · default · meaning table into `theming.html` (both languages) between `<!-- dials:begin/end -->`
  markers, and adds every dial to the glossary so its name pops up anywhere on the site. `check_site.py`
  fails when the table is stale, a marker is missing, or a dial has no English text.
- **The site is photographed too.** `tools/site_shots.sh` renders every page of `docs/` at desktop and
  phone width with headless Chrome (`GOHUD_CHECK_SITE_SHOTS=1` runs it from `check_all.sh`). Table widths,
  glossary underlines and phone-width overflow are invisible in the HTML source; the first run showed every
  table on a page ending at a different right edge, because tables were `display: block` and grew only to
  their content — they now fill the column on desktop. The first phone-width render showed the other
  half: a scrolling table at 400px collapses every column to one word per line and hides the third column
  off-screen, so under 640px tables now stack each row as a card, headings hidden, with a small
  "Default" label in front of generated dial values. (Headless Chrome will not lay out narrower than
  500 CSS px, so the phone shots render the page inside a 400px iframe.)
- **Floating cards sit visibly above the page.** The coach-mark and prompt cards used an 8dp, 35% shadow
  lifted 2dp — over a panel of text the card barely read as "on top" (I-69). `GoSkin` now exposes the
  depth as dials (`float_shadow_alpha` 0.45, `float_shadow_size` 14, `float_shadow_lift` 4) and, for
  chamfered skins that cannot draw shadows, `float_glow_size` 10 raises the glow instead. All four are
  JSON `skin.dials`, so a theme can flatten or deepen its floating cards without code.
- **Skin numbers are dials, not code.** The values that were hard-coded in `GoSkin` and `GoSkinSciFi` —
  slot border width and tint, badge padding and edge opacity, chip and alert opacity, joystick ring width
  and opacity, and the sci-fi chamfer sizes, glow and bracket — are now `@export` properties. A theme's
  JSON carries them under `skin.dials`; `make_theme.py` writes them into a per-theme skin resource, so a
  designer changes a slot border from 2 to 3 without touching GDScript. `new_theme.py --new-skin`
  scaffolds a `GoSkin` subclass for the cases where the drawing itself must change.
  `tools/skin_dials.json` is generated by parsing the scripts' `@export` defaults — GDScript is the
  single source — and a test keeps the parser honest.
- **The demo is photographed too.** `tools/demo_shots.sh` opens every widget section of `examples/demo`
  at phone and desktop size (and the dropdown open) — the four issues reported on 2026-09-13 all came
  from the demo, which the gallery screenshots never covered. With `--play` it also runs the demo's own
  bot through each section at 4× and captures every overlay the moment it appears (each coach-mark step,
  notices, prompt cards, sheets), since a section opened by hand shows only disabled widgets and the
  screen after the bot finishes is rebuilt grey again.
- **A new theme is one file.** `tools/new_theme.py neon --from scifi_dark` writes `themes/palettes/neon.json`
  and `themes/presets/neon.tres`; `make_theme.py neon` builds the theme and its control artwork. The JSON
  spells out every value inherited from the parent theme, so it doubles as the list of what can be
  changed — delete a key to keep the parent's value. `GoThemePresets` now scans `themes/presets/`, so the
  preset appears in the picker and the project-setting dropdown without touching registry code.
  Shape dictionaries (and the JSON `shape` block) can override `radius`, `radius_small`, `radius_large`,
  `gap`, `gap_small`, `gap_large`, `padding`, `button_height` and `button_padding`; the values flow into
  the theme's constant tokens so panels and widget maths stay in step. `tools/check_scaffold.sh` (run by
  `check_all.sh`) creates a throwaway theme, changes its accent and radius, and verifies generation,
  token propagation and a clean contrast pass.
- **The theme builder now pushes the accent colour, not just text.** The first scaffold run found a theme
  with only its accent changed failing eight contrast pairs — accent borders and focus rings at 2.2:1,
  the primary button label at 2.7:1. The accent is now pushed until it clears 3:1 on the background and
  4.5:1 under its own label; the label falls back to a dark candidate only if a light one cannot reach
  the threshold. Built-in themes already cleared both, so their values are unchanged.
- **Demo: explore any widget by hand.** The demo used to be a film — press Start and watch fifteen
  chapters go by. It now has a sidebar listing every widget; picking one builds just that chapter and
  leaves it alone for you to press, drag and type on, while the activity panel logs the callbacks your
  own clicks fire. **Play this widget** runs the bot on that single chapter and hands the widget back
  rebuilt afterwards. Picking a row mid-tour folds the tour; narrow windows get a **Widgets** menu in
  the top bar instead of the sidebar; `--explore=<key>` opens the app straight onto one widget. Each
  chapter is now a `build_`/`play_` pair, so anything only the bot used to trigger — data arriving,
  a coach-mark tour starting, a sheet or popup opening — is a button a person can press too. The
  integration check covers the new mode: Start-screen and sidebar selection, hands-on dialog use,
  single-widget play, keyboard navigation, folding a running tour, and leaving a full-screen chapter.
- **Demo: a showcase, not a test harness.** Dot-grid backdrop with two soft light pools, a logo mark
  and version chip, a mode chip (READY · TOUR · EXPLORE · DONE), icon rows in the widget list, an
  "about this widget" card with the explore hint, and an empty state in the activity log.

- **`GoSlot.keyboard_focus`** — quick slots stay out of the Tab order by default (eight of them would sit
  between a keyboard user and every settings control), but can now be reached by keyboard or gamepad when
  that is the only input. The `FOCUS_NONE` was previously hard-coded with no way to opt in.
- **Keyboard navigation is now tested, not assumed.** Three rules a finger never exercises: focus moves
  into a window when it opens, focus that leaks outside is pulled back (otherwise Enter presses a button
  nobody can see), and closing returns focus where it was. Tooltips are measured too — their panel and
  their label are *different theme types*, so the existing per-type check could never have caught them.
- **`GoStyle.Tone.DANGER_SOLID` — a filled button for irreversible actions.** The existing danger tone is a
  faint tinted panel, and on a light theme the label has to darken to `#9B2626` to stay readable on it —
  which reads as black text, not as danger. The filled variant carries white text at 5.7:1. `GoDialogs`
  takes a `destructive` flag that uses it; the tone is re-applied on every dialog, since one window is
  reused and a red confirm would otherwise persist into the next, ordinary one.
- **`GoForm.avoid_hud` — content no longer slides under a floating HUD.** When a scrolling screen shares
  the display with HUD pieces, the content passes *behind* them and the two sets of text overlap until
  neither reads. Turning this on makes the form keep clear of every visible `GoHudAnchor`. It is off by
  default, so existing screens are untouched. Each rectangle is avoided in whichever direction **costs the
  least area** — a bar in the top-right is stepped around downwards on a portrait phone and sideways in
  landscape, where avoiding it vertically would cost 27% of the screen. Ground already given up is
  subtracted before the next rectangle is measured, so a corner HUD is not paid for twice.
- **`GoHudAnchor.reserve_space`** — turn it off for HUD pieces that only appear under a finger, such as a
  joystick with `hide_when_idle`. Left on, a panel that is not even visible costs the content a whole row.
  It also decides who an `avoid_peers` anchor steps around: only fixtures.
- **`GoHudAnchor.avoid_peers` — HUD pieces no longer land on each other.** The nine spots divide the screen
  but do not guarantee the pieces miss: a wide snackbar at `TOP_CENTER` sat squarely on the health bar at
  `TOP_RIGHT`, hiding the value. A transient anchor with this on settles clear of the fixed ones — **only
  vertically**, so a centred toast does not appear somewhere new each time it shows, and only around
  anchors that reserve space, so two transient pieces do not chase each other across the screen. A fixture
  that moves or resizes wakes the pieces dodging it, since they have no other way to learn it changed.
- **Translucent panels are measured against the worst backdrop they can land on.** A floating HUD is drawn
  over whatever the game is showing — a snowfield or a cave — and a translucent panel takes on that colour.
  The contrast check now composites every translucent `GoHud` StyleBox over **pure white and pure black**
  before measuring the text on it, which is what exposed the `hud` panel above. 50 → **58 pairs**.
- **The skin-contrast test now measures icons, not just labels.** It read the colour of every label a slot
  draws and stopped there, so a glyph painted with a fixed colour sailed past it for eighteen iterations.
- **`tools/check_contrast.py`** — WCAG contrast measurement for every theme, covering both plain token
  pairs and **button state panels** (the label colour against the StyleBox background it is drawn on,
  following `base_type` the way the engine resolves it). Decorative borders are scored separately (2:1),
  since WCAG 1.4.11 does not apply its 3:1 rule to decoration.
- **Surface layers are now distinguishable.** Measuring only text contrast had hidden a whole
  dimension: panels and cards sat 1.07–1.14:1 against the background across all four themes, which is
  why screens looked flat. Adjacent surfaces now differ by at least 1.18:1, so a sheet lifts off the
  background and list rows separate from the card they sit in.
- **Text and border colours are derived from the palette rather than taken from it.** Moving the surface
  ramp one step pushed `muted` below the readable minimum in all four themes — hand-picked values break
  every time the surfaces move. The palette entry is now a *starting point*: the builder pushes it until
  it clears the threshold on **every** surface it can land on.
- **A progress bar's track is now outlined, so you can see how much is left.** The track colour alone
  could not guarantee this — a bar sits on the background, inside a card, or on a HUD panel, and those
  three differ in brightness. On `scifi_dark` the track measured 1.003:1 against the background: the same
  colour, in practice. An outline works whatever it sits on.
- Sci-fi bars glow in **their own fill colour** — the glow follows `GoBar.ink`, so a red health bar does
  not glow cyan.
- **`GoSkin` carries WCAG maths, so runtime-built colours are checked too.** A Python pass over the
  theme files cannot see colours a skin mixes while running — chips tint the panel with the *same* colour
  as the label, and on light themes that fell to 3.5:1. `chip_ink()` and `slot_ink()` push the label until
  it clears the threshold, and a `skin contrast` test section now measures it on every preset.
  (`Color.get_luminance()` is not used: it skips gamma decoding and diverges from WCAG on dark colours.)
- Section headings and dividers are skin decisions (`section_box`, `divider_color`,
  `divider_thickness`). The default skin draws an empty box for headings, so the default look is
  unchanged; the sci-fi presets add an accent bar to the left of each heading.
- Dividers are a skin decision (`divider_color`, `divider_thickness`); the sci-fi presets draw them in the
  accent colour.
- **The default presets have depth.** Shape is unchanged — that is what makes them *default* — but a
  primary button now lifts off the surface on an accent-tinted shadow and **sinks** when pressed (the
  shadow drops to 3dp), and cards, popups and notices sit on a graded shadow scale. Shadows do not
  affect `content_margin`, so no layout moved.
- **The sci-fi presets actually glow now.** The outer glow was being multiplied down three times
  (palette alpha, builder, draw) and landed at an effective 0.02 — written as decoration, invisible in
  practice. Falloff is now quadratic (linear banding showed a hard edge), and glow is applied to primary
  buttons, HUD panels, notices and the selected tab.
- **Sci-fi focus is a targeting bracket, not a border.** `focus` and `focus_soft` in both sci-fi themes
  use `GoStyleBoxBracket`, which marks the corners without enclosing the content.
- `GoSlot` no longer dims empty/disabled slots by multiplying alpha. On a light theme that multiplied an
  already-pale colour and the slot vanished; the colour is moved toward `muted` instead, which reads as
  "dimmed but present" on any theme.
- **Fill-only colour tokens** — `success_fill`, `warning_fill`, `danger_fill`, `info_fill`, `accent_fill`.
  A status colour used as *text* must be dark enough to read on a light background; the same colour used
  as a *bar fill* must be bright enough to notice. One token cannot be both, and the light theme's XP bar
  went brown as a result. `GoUi.color()` falls back to the base name when a theme does not define the
  `_fill` variant, so existing and third-party themes are unaffected.
- **`tools/make_site.py`** — builds the documentation glossary **from the source tree** (class names and
  their doc comments, theme tokens, type variations, preset ids), so term explanations cannot drift from
  the code. Engine-level terms are the only hand-written entries.
- **`docs/`** — a three-page GitHub Pages site with hover/tap **term popups** on 129 terms:
  an overview, a theming guide (token reference, skin methods, building your own preset, the contrast
  rules) and a widget reference. Terms are detected in prose *and* code blocks, and a popup shows the
  inheritance chain where the glossary has one.
- **An English edition of the site** at `docs//en/` — overview, theming and widgets — with its own glossary. Korean entries are
  extracted from the source doc comments; English has no such source, so those descriptions are written
  by hand and a term without one is simply left out — better absent than explained in the wrong language.
- `tools/make_theme.py` **reports every colour it moved** (`muted #919bac → #a0a8b7 (surface contrast)`).
  Adjusting silently leaves anyone supplying their own palette wondering why their colour did not survive.
- **`tools/check_site.py`** — verifies local links and images resolve, the glossary is valid and complete,
  every page loads the glossary and tooltip scripts, and the glossary has not drifted from the source.
- **`tools/check_mutations.sh`** — measures what the test suite actually catches by breaking one rule at
  a time and checking the suite notices. The count of passing tests says nothing about this: a check added
  seven iterations earlier had been green no matter what it measured. Eleven rules are covered and all
  eleven are caught; wire it in with `GOHUD_CHECK_MUTATIONS=1`.
- **`tools/check_all.sh`** — one entry point for every check. The checks are split because they can see
  different things (Godot for widget behaviour and runtime colours, Python for theme files and the site);
  running them separately means eventually forgetting one. Also runs the suite on Godot 4.6 when
  `GODOT_46` is set, and verifies the generated themes still match their source palettes.
- **Godot 4.6 is the verified floor.** The suite runs against 4.6 stable and 4.7.2; `GoUi.MIN_ENGINE`,
  `GoUi.engine_supported()` and a test assertion record it.
- `tests/gallery_shots.gd` takes `--preset=<id>` and `--still` (motion off, so shots are reproducible and
  can be compared pixel by pixel).
- **Theme presets — pick colours *and* shape in one line.** `GoUi.use_preset(GoThemePresets.SCIFI_DARK)`
  swaps the theme, the skin and the icon set together. Four ship: `default_dark`, `default_light`,
  `scifi_dark`, `scifi_light`. Also selectable from **Project Settings → Gohud → Theme → Preset**, or
  via the new `GoConfig.preset` field. Explicit `theme` / `skin` / `icons` still win over the preset.
  Hosts register their own with `GoThemePresets.register()`.
- **`GoSkin`** — the shapes a `Theme` cannot reach, in one resource: the joystick, quick-slot faces, the
  coach-mark ring and pointer, chips, skeletons, alerts, segmented controls, discs and progress fills.
  The base class is gohud's original look moved verbatim, so not setting a skin changes nothing
  (verified pixel-identical across 18 gallery screenshots). Subclass and override only what you want.
- **`GoStyleBoxCut` and `GoStyleBoxBracket`** — custom `StyleBox` classes for shapes `StyleBoxFlat`
  cannot make: chamfered corners with an accent edge and outer glow, and corner-only targeting marks.
  Both serialise into a `Theme` resource, so a theme can now change *shape*, not just colour.
- **`GoStyle.surface()`** — like `box()` but returns whatever shape the skin produced, including custom
  StyleBoxes. `box()`, `floating()` and `disc()` keep returning `StyleBoxFlat` as before.
- **`tools/make_theme.py` separates palette from shape.** `SHAPE_DEFAULT` is the original geometry;
  `SHAPE_CUT` drives both sci-fi themes, translating radii into chamfers, single-side borders into accent
  edges and shadows into glow. Geometry is unchanged for the default themes — only their palettes moved
  (see *Changed*).
- **`GoDialogs._make_surface()`** — subclass hook for the dialog surface, like `GoSheet._make_surface()`.

### Fixed

- **The coach-mark card no longer covers the header or a floating HUD.** In landscape the card was sent
  to the very top (or bottom) edge of the screen — exactly where headers and HUD pieces live — and in the
  demo it sat on the header's controls. It now stays level with its target, steps around any
  `GoHudAnchor` that reserves space, and can be told about other things to avoid via `keep_clear`
  (a header bar, a toolbar). It moves the shortest distance that clears the obstacle without covering the
  target, and stays put if the screen is too small to clear everything.
- **Both dropdowns put their arrow in the same place.** `OptionButton` used the engine's 4px
  `arrow_margin` while `MenuButton` drew its chevron inside the 16px panel padding, so the two arrows sat
  12px apart when stacked. The theme now sets `arrow_margin` to the panel padding.
- **Word-wrap on buttons is decided from the displayed text, not the translation key.** `button_key()`
  stores the key and the engine translates at draw time; the rule saw a one-word key (`confirm`) and
  switched wrapping off even when the translation was two words. It now reads `atr(text)`, and a form
  re-applies the rule to its buttons on `NOTIFICATION_TRANSLATION_CHANGED`, so switching language cannot
  leave a label split mid-word. `GoDialogs` re-applies it in `_retranslate()`.
- **`dropdown()` (MenuButton) now lines up with `select()` (OptionButton).** Stacked in the demo, the two
  looked like different parts — one left-aligned with a small chevron, the other centred with a larger
  one. Both are left-aligned and the chevron is sized from the OptionButton's arrow icon.
- **Short button labels split mid-word.** A button with wrapping enabled subtracts its text width from its
  minimum size, so a natural-width button that got squeezed broke `Done` into `Don` / `e` (the coach mark's
  last step). `GoStyle.fit_words()` now decides per label: a single word never wraps; several words wrap
  but the longest word is guaranteed a full line. Buttons, toggles and `GoStyle.form()` all use it, and
  the coach mark re-applies it after changing the label.
- **A full-width button's glow was clipped on the left.** A scroll container clips at its bounds; the right
  side only survived because the scrollbar gutter already pushed that edge out. `GoScroll` now borrows the
  parent's padding on the left, top and bottom too — the clip edge moves 12dp outward and the content is
  moved back by the same amount, so nothing shifts and glows and shadows have room.
- **Quick slots were cramped.** Time, icon and count were stacked in three rows inside 48dp. The icon now
  sits large in the centre, the shortcut top-left, the count as a bottom-right badge and the remaining time
  as a badge over the (dimmed) icon. Badge panels come from `GoSkin.badge_box()`, so the sci-fi skin gets
  chamfered badges for free.
- **Dropdown menus were flat and the chosen item was invisible.** Item hover used the button panel (borders
  and shadow included) and the radio marks were the engine's faint defaults. Menus now have their own soft
  accent hover panel, the same radio/check artwork as checkboxes, a real separator style, and item height
  sized for touch (27dp → ~44dp).
- **Tooltips rendered one character per line.** The engine's default tooltip computed a width of 1dp with
  wrapping on, so `settings` came out as a 186dp-tall column. `GoIconButton` now supplies its own
  gohud-styled tooltip label (short text on one line, long text wrapped at a real width).
  `GoStyle.icon_button()` gained a `tooltip_key` argument — the same value feeds the tooltip and the
  accessibility name — and the gallery's icon buttons, which had no description at all, now use it.
- **The focus ring was invisible on filled buttons.** A primary button's panel *is* the accent colour, and
  the focus ring was drawn in that same colour — **1.00:1**, one colour over itself, in all four themes.
  Moving by keyboard there was no way to tell where you were, which is exactly what WCAG 2.4.11 is about.
  Filled buttons now take a ring that contrasts with their own panel: dark on dark themes, white on light
  ones, a dark targeting bracket in sci-fi. The contrast checker measures focus rings against the panel
  they sit on, so a palette change cannot quietly undo it.
- **On a wide screen the content sat off-centre.** `GoForm.avoid_hud` measured overlap against the whole
  safe area, so a form that was already centred by its width cap — nowhere near the corner HUD — was pushed
  aside anyway: 214dp off-centre at 1280×800. Overlap is now measured against the space the form will
  actually occupy, so a wide screen keeps its centred column and a phone still steps around the HUD.
- **Progress fills went brown on light themes.** A status colour has to darken to stay readable as *text*
  on a light background (`warning` sits at `#96500A`), and the bar fill inherited that — an experience bar
  the colour of mud. Colour alone cannot fix it: yellow is intrinsically bright, so it clears 3:1 over no
  grey track at all, and darkening the track made it **worse** (1.52 → 1.06). Fill colour and edge contrast
  are now separate concerns — the light palettes carry vivid fill-only colours, and `GoSkin` draws a 1dp
  outline on any fill that cannot reach 3:1 against its track, stepping the outline until it does. Sci-fi
  fills were missing the outline entirely, since they are custom StyleBoxes and only the `StyleBoxFlat`
  branch drew one.
- **Quick-slot icons were hard-coded white, so they vanished on light themes.** `GoSlot` painted its
  glyph with `Color.WHITE` regardless of the panel underneath — correct on a dark theme, invisible on a
  light one (measured **1.11:1** on `default_light`, **1.20:1** on `scifi_light`; three of four slots in
  the gallery were reduced to a faint outline). The icon now follows the same readability rule the slot's
  labels already used. An icon set that declares its own `tint` still wins, so coloured artwork is never
  repainted — but a white `tint` no longer counts as "a colour was chosen", since multiplying by white
  changes nothing. The bundled icon set had exactly such a `tint` baked into its `.tres`; it is gone.
- **Glyphs that fall back to a child label ignored the button's icon colour.** When an icon set has no
  texture for a name — a font icon set, or a typo — `GoIconButton` and `GoStyle.apply_icon()` draw the
  glyph as a child `Label`, and a Button's `icon_normal_color` does not reach a child. The glyph came out
  white: **1.41:1** on `default_light`. Both now pick up the same colour the texture path uses.
- **Floating panels lost contrast over bright backdrops.** The `hud` StyleBox was 82% opaque, so whatever
  sits behind it bleeds through and shifts the panel's colour. Over a bright game scene the dark themes'
  `muted` text fell to **3.74:1** and `secondary` to 4.21:1 — below the 4.5:1 body minimum. The panel is
  now 92% opaque (0.88 is the break-even point), which keeps the glassy look and measures 5.26:1 against
  the worst case.

- **RTL is checked by position, not by property.** The previous test read `layout_direction` values,
  which cannot tell "the setting is right but the screen did not mirror" apart from working code. The
  suite now switches to Arabic and verifies a list row's icon actually sits to the *right* of its label,
  and that the order returns when switching back. A bar's numeric readout is checked to stay
  left-to-right — mirrored, current and maximum health swap places.
- **The suite now runs at four screen sizes** (phone portrait and landscape, tablet, desktop) via
  `GOHUD_VIEWPORT`. Landscape-only behaviour — the HUD anchor's alternate spot and the surface's
  narrower landscape width — had no test at all, in either orientation.
- Two rules were never exercised because the test viewport is a phone: the form's width cap does nothing
  on mobile (where the cap is "unlimited"), and the virtual keyboard never appears on desktop. Both are
  now tested by creating the conditions — a desktop-width viewport, and an injected keyboard height.
- Three rules had no test behind them at all, found by the mutation run: chip label colour (the check
  read the skin method rather than the widget's actual colour), label and button wrapping, and the touch
  floor on a slot forced below 48dp.
- **A test was passing without testing anything.** The `skin contrast` section accumulated its worst
  measurement inside a lambda, and GDScript captures outer local variables **by value** — the assignment
  never reached the outer scope, so the check was green whatever it measured. Switched to an array
  (captured by reference); it immediately failed on all four presets, down to 2.91:1 on the light ones.
- **Quick-slot text is now readable on whatever face the skin paints.** A skin decides how the slot face
  is filled, but the label colours were fixed: following the documented example and filling the face with
  an opaque accent put the quantity at 1.70:1 and an empty slot at 1.29:1. Even the shipped presets had an
  empty slot at 3.97:1 while a cooldown ran. Quantity, timer and shortcut colours are now pushed to clear
  the threshold on the face they sit on.
- **The store package could not be built.** `docs/` was being included, and a shell example inside it
  referenced `res://…/tests/gallery_shots.gd` — a path the store ZIP deliberately omits — which tripped
  the broken-reference gate. `docs/` is the website, published through GitHub Pages; it is excluded from
  the ZIP alongside `tools/`, which also keeps ~400KB of screenshots out of the add-on.
- Glossary descriptions written by hand kept their markdown, so tooltips showed `**rounded**` with the
  asterisks (the popup inserts text verbatim). Stripped at generation, and checked from now on.
- **`GoStyle.responsive_grid()` cells collapsed to the width of a single character.** `GridContainer`
  only hands spare width to children flagged `SIZE_EXPAND`, and cards defaulted to `SIZE_FILL`, so each
  card shrank to its content's minimum width — and since labels inside wrap, that minimum is near zero.
  Measured at 25px per card at *every* window width; the earlier note that it only happened at 430px was
  wrong. Cards now measure 169–224px and titles sit on one line.
- The gallery scene and script paths still pointed at `examples/gallery.tscn` after the move into
  `examples/gallery/`, so the gallery failed to load from `tests/gallery_shots.gd` and
  `tools/new_project_check.sh`.
- A guided, English-only simulation in `examples/demo`: 15 chapters driven by real mouse and keyboard input,
  including forms and HUD anchors. Start/replay, pause, previous/next, and cancellation are supported.
- A larger presentation layout that scales with desktop windows, Cinema mode, a recording countdown,
  fullscreen shortcuts, and `run.sh --record` for 1080p movie capture.
- `tools/check_demo.sh` verifies the full tour and playback controls at desktop and portrait sizes.

- **More subclass hooks** — `GoSurface._make_scroll()` / `_make_close_button()` and `GoSheet._make_surface()`,
  same idea as the coach-mark and prompt-card hooks.
- **Every on-screen string is customisable.** Widgets no longer build display text in code: the value
  readouts (`GoBar`), the coach-mark step counter and the slot quantity now go through named strings like
  the rest, so a host can reword or re-translate all of them. Formats are translatable because punctuation
  is not universal — Turkish writes the percent sign in front (`%50`). Placeholders switched to `{name}`
  so a translation that drops one renders instead of crashing. Digit grouping became a hook
  (`GoConfig.number_formatter`) rather than a format string, because Korean/Japanese/Chinese break at
  10,000 rather than 1,000 — the arithmetic differs, not just the text. A test now fails the build if any
  literal display string appears in `widgets/`, `core/` or `services/`.
- **Demo: a language card.** `examples/demo/demo.tscn` now ends with a card printing the built-in strings in
  all 21 languages side by side, so a missing translation and a missing glyph are both visible at a glance.
  `run.sh --languages` checks it headlessly and `run.sh --shot-languages` captures it. The check measures
  glyphs through `TextServer` rather than `Font.has_char`, which ignores the system font fallback and so
  reports Thai and CJK as missing while they render fine.
- **Ten more built-in languages — 11 → 21.** Added Turkish, Vietnamese, Indonesian, Thai, Italian,
  Polish, Ukrainian, Dutch, Traditional Chinese (`zh_TW`) and Hebrew to `i18n/gohud.csv` and
  `GoUi.LOCALES`, matching the locale set used by web game portals. Hebrew joins Arabic as a
  right-to-left locale; layout already follows the application locale, so nothing else changed.
  Traditional Chinese uses Taiwanese wording (搜尋 · 載入中 · 略過), not converted Simplified.
- **`GoCoachMark._should_pause()`** — hook that decides when the coach card hides (default: any `GoSurface` is open).
  A host with its own modal system overrides it so the tour also pauses behind those.
- **Subclass hooks for child widgets** — `GoCoachMark._make_scroll()` and `GoPromptCard._make_close_button()`
  let a host that subclasses `GoScroll` / `GoIconButton` (its own type hints, its own close glyph) get those
  subclasses inside the widgets. Defaults are unchanged.
- **`GoIconButton.native_texture_size`** — draw a texture icon at its own pixel size instead of scaling it to
  58 % of `visual_size`. Hosts that ship an SVG at exactly the size they want avoid the 1 px resampling difference.
- **`GoScroll.as_horizontal(node)`** — the configuration step of `horizontal()`, so a subclass can rebuild the
  factory with its own instance (`static func horizontal() -> MyScroll: return GoScroll.as_horizontal(MyScroll.new())`).
  Static factories do not know the subclass, so `MyScroll.horizontal()` inherited from `GoScroll` would return a
  plain `GoScroll` and fail to assign to a `MyScroll`-typed variable.

- Demo popup selection now uses actual input and selects the intended item. Prompt cards use their real close
  button; floating HUD controls and coach marks stay above the correct content. Scroll-to-control motion is
  bounded and never reverses repeatedly. Grid cards retain their full cell width, and the compact
  header keeps chapter counters on one line. Cancelling a chapter releases held input before restarting.

- `GoIconButton` texture icons are centred explicitly (`icon_alignment` / `vertical_icon_alignment`). `Button`
  defaults to left alignment, which showed as soon as a texture was drawn without `expand_icon`.
- `GoNotice.set_content()` also sets `mouse_filter = IGNORE` on the whole content subtree.
  `mouse_behavior_recursive` already blocked input, but code that reads `mouse_filter` (layout logic, host tests)
  saw stale values.

### Changed

- **All four themes are now readable by measurement, not by eye.** A new contrast check
  (`tools/check_contrast.py`) measures every colour pair against WCAG 2.2 and found **21 failures**:
  `muted` text fell below the 4.5:1 body minimum in *all four* themes, and both light themes failed on
  **button label text** (`on_accent` over `accent`). The palettes were corrected until the count reached
  **zero**. Shapes and layout are untouched — only colours moved, so no widget geometry changed.
  Affected tokens: `muted` (all four), `accent` · `success` · `warning` (light themes), `border` (all four,
  so a card no longer dissolves into the background).
- Alpha colours are composited over their real backdrop before measuring; measuring a translucent
  border directly reports a better ratio than the screen actually shows.
- **Button label colours are now derived, not hand-picked.** Putting accent-coloured text on an
  accent-tinted panel (a pressed button, a danger button) looks good in a palette swatch and fails as
  soon as it is measured — the two are the same hue, so there is no lightness difference. The theme
  builder now pushes label lightness until it clears the threshold on the panel it actually sits on,
  keeping hue and saturation, so a changed palette keeps its contrast automatically.

## [1.0.0] — 2026-09-12

First version. Rebuilt from a production game's shared UX layer into a standalone add-on that
depends on nothing outside `addons/gohud/`.

### Added

- **Widgets** — `GoSurface`, `GoSheet`, `GoDialogs`, `GoForm`, `GoScroll`, `GoNotice`, `GoPromptCard`,
  `GoCoachMark`, `GoHudAnchor`, `GoBar`, `GoSlot`, `GoJoystick`, `GoIconButton`.
- **`GoStyle`** factories — buttons, labels, list rows, inputs, chips, cards, responsive grids,
  foldable sections and empty states.
- **`GoConfig`** — one settings resource for appearance, breakpoints, surface behaviour, feedback,
  localization and accessibility. Every field has a working default.
- **`GoIconSet`** — swappable icon sets (textures, icon fonts, partial `fallback` overrides), shipping
  84 original MIT icons. **Themes** — dark and light, sharing 14 type variations.
- **`GoRuntime`** optional autoload — breakpoint and keyboard events, optional 1 unit = 1 dp scaling.
  **`GoFeedback`** routes sound cues to your audio system and plays haptics on Android/iOS.
- Built-in strings in 11 languages; 48 dp touch targets, `reduce_motion`, keyboard-only focus rings.
- `examples/demo/` (a complete screen, runnable as its own project), gallery, headless tests, packager.
