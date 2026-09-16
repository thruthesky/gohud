# gohud theme work — wrapped up

The user's request of 2026-09-13 to wrap up ended the iteration work. The iteration log below is history; it does not call for further iterations.

## Final verification — 2026-09-13

- **Themes**: default / sci-fi, each in dark / light. Colour contrast failures 0, 27 customization dials.
- **Compatibility**: on Godot 4.6 stable and on 4.7.2, **384/384 passed** on each of four screens (390×844, 844×390, 768×1024, 1280×800).
- **Render check**: on 4.6, four presets × 36 images = 144 generated; a representative phone and desktop screen checked. 0 errors in the render log.
- **Site**: three English pages and three Korean pages under the requested `docs/www`. The glossary holds 155 English entries and 159 Korean.
  The root links through to English. The term popups work with mouse, touch and keyboard, close on Escape, and let you reach the reference links.
- **Browsers**: 6 pages × 2 screens (390 · 1280) × 2 colour modes = 24 combinations, with 0 horizontal overflow, 0 missing images and 0 JS errors.
  Code wrapping on phones (I-78), dark mode (I-79), table group names (I-80) and a CSS brace error were fixed.
- **Trust in the verification**: failures were planted on purpose in a temporary copy — CSS, a wrong section link, a stale glossary, an already-fixed theme, a per-screen-size check — to confirm they are detected. No original was changed during the checks.
- **Installed copy**: the release ZIP was installed into a fresh project — **384/384 passed**. The skin-dial check data is provided from outside the installed copy.
- **Ready to publish**: the `main / (root)` setting is kept, with a root `index.html` and a `.nojekyll` added.
  The circular demo link that had made Pages fail before is kept out of Git and created by `run.sh --setup`.
  The real deploy address and how it is managed are in [README.md](README.md).

## Completion conditions of the past iteration work
 (set by the user)

1. **Theme quality** — make default and sci-fi far more striking, prettier, richer and more readable than they are
2. **Customization** — make the appearance changeable
3. **Godot 4.6+ compatibility**
4. **`docs/www`** — a documentation site to publish on GitHub Pages. Like the godot skill, **a popup explanation for every technical term**
5. Every iteration: ① unit tests → ② analyse the current work → ③ dig out new issues and problems and add them to the next plan

## Verification procedure of the past iterations (historical)

```bash
SP=/private/tmp/claude-501/-Users-thruthesky-apps-game-laryen3d-addons-gohud/<session>/scratchpad
bash "$SP/sync.sh"                                       # source → the 4.7 verification project
rsync -a --delete --exclude '.git' --exclude '.godot' --exclude 'builds' --exclude '.env' \
  --exclude 'examples/demo' --exclude 'examples/.gdignore' --exclude '.review' \
  ./ "$SP/verify46/addons/gohud/"                        # → the 4.6 verification project

GOHUD_PROJECT="$SP/verify" \
GODOT_46="$SP/godot46/Godot.app/Contents/MacOS/Godot" GOHUD_PROJECT_46="$SP/verify46" \
  bash tools/check_all.sh                                # ① checks — this one line runs them all
```

What `check_all.sh` runs: the unit tests (4.7 · 4.6) · theme contrast · the website · **whether the generated theme files match the source**.
If the verification projects are missing, follow "Rebuilding the verification environment" below.

🛑 If you made a new theme or SVG, **the verification project has to be imported once** before it is read:
`godot --headless --path "$SP/verify" --editor --quit`

🛑 **Look at the site's tables and bubbles with your own eyes** — `bash tools/site_shots.sh "$SP/site_shots"` captures the 6 pages at
desktop (1100) and phone (400) width, 12 images in all (pass a page name as the second argument for just one). Table widths, bubble
underlines and horizontal scrolling at phone width cannot be seen by reading the HTML. Inside the tool, a `--headless=new` Chrome is
launched with `&` and killed once the file appears — Chrome **does not exit** even after saving a screenshot, and macOS has no `timeout`.
The chrome-devtools MCP cannot be used: it clashes with the user's own browser profile. 🛑 Chrome **will not shrink a window below 500 CSS px**
— phone width is captured through an iframe wrapper (the tool does this). An image taken by narrowing the window alone is a 500px layout
cropped, and so shows **fake defects**. When a layout width is in doubt, measure it by putting a probe on the page that prints `innerWidth`
on screen (iteration 33).

## Progress at the point the iterations ended (historical)

| Condition | State | What is left |
|---|---|---|
| 1. Theme quality | 🟢 0 readability failures (63 pairs) · decoration · hierarchy · show-through · icons · bars · danger · focus · tooltips · **word wrapping · glow padding · slot badges · dropdowns** | phone code blocks (I-78) · site dark-mode captures (I-79) · card-style group names on phones (I-80) |
| 2. Customization | 🟢 **a theme in one file** · 23 skin numbers as dials · `--new-skin` · **the dials have one source, in GDScript** | — |
| 3. Godot 4.6 compatibility | 🟢 **verified for real** | run it on 4.6 as well, every iteration |
| 4. docs/ site | ✅ **3 English pages (root) + 3 Korean pages (`ko/`)** · 260 terms with popups · site checks | — |

## Iteration log

### Iteration 1 — 2026-09-13

- **Checks**: 265/265 → (after adding the engine item) **266/266**, passing on both 4.6 and 4.7
- **Analysis**:
  - The three theme layers (Theme + `GoSkin` + `GoThemePreset`) already stand. The four presets are confirmed working.
  - There was no `docs/` folder at all → started with this file.
  - `DPITexture` is confirmed to have landed in **4.5** ([renaming PR #105375](https://github.com/godotengine/godot/pull/105375)) → safe on 4.6.
  - **Parallel changes from other sessions** keep arriving in the repository (checks 190 → 265, `sim*.gd`, `check_demo.sh` and so on).
    They mix with mine, so **do not touch files I have not touched.**
- **What was done**
  - **Downloaded Godot 4.6 stable and ran the checks for real** — 266/266 passed, the 18 sci-fi gallery renders fine (I-02 ✅)
  - Stated the minimum version — `plugin.cfg`, both READMEs, `GoUi.MIN_ENGINE`/`engine_supported()`, and a check item (I-03 ✅)
  - **Started the `docs/www` site** (I-01 🟡) — one `index.html`, `site/style.css` (light and dark),
    the godot skill's `tooltip.js` ported over, and **129 term popups confirmed working** (measured in the browser: 108 spots auto-detected on the page, 0 console errors)
  - **`tools/make_site.py`** — **extracts the glossary from the source automatically** (the first paragraph of a class's `##` comment + tokens + type variations + presets).
    A hand-written glossary drifts as the code changes, so only general engine terms stay in the file and the rest are pulled in.

### Iteration 2 — 2026-09-13

- **Checks**: 266/266, on both 4.6 and 4.7
- **Analysis**: while making the preset comparison images for the site, **a problem was spotted by eye** — in `scifi_light`,
  Disabled and Compact were barely visible and the list rows were weakly separated. "Pretty" is a matter of taste, but
  "readable" can be measured, so a **measuring tool** came first.
- **What was done**
  - **`tools/check_contrast.py`** — parses `GoHud/colors/*` in a theme `.tres` and measures the WCAG contrast ratio.
    Colours with alpha are measured **after being composited** over the background beneath them (measuring a translucent colour as it is comes out better than reality).
  - Measured result: **21 failures** — `muted` failed against body text in all four themes, and in the light ones even the **button text**
    (`on_accent` on `accent`) failed.
  - Palette corrected → **0 failures**. What changed: `muted` (all four themes), the light themes' `accent`, `success` and `warning`,
    and `border` in all four (so a card's edge does not melt into the background).
  - Decorative borders are not a 3:1 target under WCAG 1.4.11, so they are **classified separately** as `DECOR = 2.0` —
    not a standard lowered at will, but a reflection of what the specification does not demand of decoration.
  - Added the images to the site: **4 presets compared + 2 sheets** (I-12 ✅).
- **🛑 Convention change**: the earlier work's "preserve default pixel for pixel" convention is **lifted**. The user explicitly asked
  for the default theme to be made prettier and more readable too. Instead, **the structure (the shapes) stays put and only the palette**
  moves, which narrows the risk of regression.

### Iteration 3 — 2026-09-13

- **Checks**: 266/266 (4.6 · 4.7), 0 contrast failures
- **Analysis**: iteration 2's contrast check looked at **text colours only**. On a real screen the text sits on a StyleBox background,
  so a button's pressed, danger and disabled states were entirely out of measurement. Widening the scope revealed **19 more**, all with
  one pattern — **a design that lays accent-coloured text on a pale tint of that same accent** (pressed buttons, danger buttons) is
  pretty in colour but, being the same hue, has no difference in lightness.
- **What was done**
  - The contrast check now reads the `sub_resource` panels of a `.tres` plus `Type/styles/*` and `Type/colors/font_*` and measures
    **(panel background → text) per button state**. Type variations walk up `base_type`, searching in the same order the engine does.
    Measured pairs 25 → **50**.
  - **Automatic correction** (`readable()` in `make_theme.py`) — pushes **the lightness only** of a text colour until it clears the
    threshold over its background. Hue and saturation are kept, so the palette's character survives. The point is that contrast follows
    when the palette changes.
  - Lowered the danger button tint from 0.14/0.26 to 0.12/0.20, and mixed the primary button's pressed background towards `text`
    rather than `background` (in a light theme, mixing towards the background makes it **lighter** and kills the white text).
  - **I-16 resolved** — five fill-only tokens, `*_fill`. In a theme that does not have them, `GoUi.color()` falls back automatically to
    the name without `_fill`, so **an old theme, or someone else's, still works when plugged in.**
  - Yellow in a light theme reads as brown the darker it gets, so the hue was moved towards orange —
    on a light ground a yellow bar **cannot physically be seen** (even white is 1.1:1). A dark orange is the right answer.

### Iteration 4 — 2026-09-13

- **Checks**: 266/266 (4.6 · 4.7), 0 contrast failures
- **Analysis**: the glow had fallen to an **effective alpha of 0.02** — 0.35 in the palette, ×0.55 in `build()`, then ×0.5 again when
  drawing. It said "rich" on paper while nothing was actually visible.
- **What was done**
  - **I-18 resolved** — `GoSlot`'s dimming was a `modulate.a = 0.55` **multiplication**. In a light theme it multiplied an already pale
    colour and the empty slot vanished altogether. Instead of multiplying alpha, **the colour moves towards muted** — in any theme that
    becomes "dim but visible". (Measured: the ×0 slot in the light gallery is now visible.)
  - Made the glow fall off on a **squared curve**. Linear leaves the edge looking cut into a band.
  - sci-fi decoration: a glow on primary buttons (7, hover 10), a thin accent edge on cards, glow on HUDs and notices, a glow on the selected tab.
  - **Focus became an aiming mark** — sci-fi's `focus` and `focus_soft` are now `GoStyleBoxBracket`. It does not draw a border round the
    content, so it hides nothing while still pointing at "here". Added a `bracket()` generator to `make_theme.py`.
  - 🔑 **Not one line of default's shape changed** — `git diff` confirms 0 changes to radii, padding, thickness and `draw_center`.
    Decoration arguments (`edge`, `glow`) are quietly dropped on rounded shapes.

### Iteration 5 — 2026-09-13

- **Checks**: 266/266 (4.6 · 4.7), 0 contrast failures
- **Analysis**
  - **I-20 was a misjudgement.** Measured with a probe, the glow goes **properly outside** the panel rectangle
    (`_get_draw_rect` is called even for GDScript inheritance). Zooming into the sheet screenshot showed the glow spread evenly around
    the Close button — it only looked cut off in the shrunken image. **The cause was judging from a downscaled screenshot instead of
    zooming into the screen.**
  - What was left was I-21 — `default` had only gained readability; its decoration was still 1.0.0 as it was.
- **What was done**
  - **Depth layers for default** (I-21). What a `StyleBoxFlat` can give without changing shape is **shadow**: the primary button lifts on
    an accent-coloured shadow, and when pressed the shadow **sinks** to 3dp (it feels like it settles under your fingertip).
    Cards, popups and notices were given depth in steps too.
  - Added a new `flat_shadow` argument — **for rounded shapes only**. On angular shapes the glow carries the depth, so turning the
    shadow on as well gives every card two layers and a mess.
  - 🔑 **The layout is untouched** — a shadow is not `content_margin` and has no effect on layout.
    `git diff` confirms 0 changes to padding, radii and thickness.

### Iteration 6 — 2026-09-13

- **Checks**: 266/266 → **270/270** (4 skin contrast items added), 4.6 · 4.7 · 0 contrast failures
- **Analysis**: `check_contrast.py` is Python and **cannot see outside the theme `.tres`.** The colours a skin makes at runtime can only
  be measured inside Godot, so a probe was run — and **11 failed**. Chips fell as low as 3.5:1 in a light theme. The cause was **the same
  pattern** as iteration 3 (same-colour text on a same-colour tint).
- **What was done**
  - **I-19 resolved** — the WCAG maths went into `GoSkin` in GDScript (`luminance`, `contrast_ratio`, `blend`, `readable_on`,
    `box_background`, all static). 🛑 `Color.get_luminance()` **does not undo gamma**, so it differs from the WCAG value — badly so for
    dark colours — and we undo it ourselves.
  - `chip_ink()` and `slot_ink()` live on the skin and chips and slots use them. **Failures 11 → 0.**
  - Turned this measurement into **a check section** (`skin contrast`). From now on a change to a skin is caught here —
    the Python checks and the Godot checks each cover the range only they can see.
  - **I-22 partly resolved** — the skin decides the divider (`divider_color`, `divider_thickness`).
    In sci-fi it becomes an accent line and the screen reads like an instrument panel divided into sections.

### Iteration 7 — 2026-09-13

- **Checks**: 270/270 (4.6 · 4.7) · contrast 0 · site problems 0
- **Analysis**: of the four completion conditions, `docs/www` was the least filled in — one page alone was too thin to call a
  "documentation website", and **no check caught the site when it broke.**
- **What was done**
  - **The site became three pages**: `index.html` (introduction, install, presets) · `theming.html` (the three layers, all the tokens,
    the list of skin methods, making your own preset, readability) · `widgets.html` (each widget plus its 🛑 traps).
    The term popups attach themselves on the new pages too — 73 spots on `theming.html` and 44 on `widgets.html`, measured.
  - **`tools/check_site.py`** (I-11 ✅) — checks that local links and image paths point at real files, that the glossary is valid JSON,
    that every entry has a description and a category, that **every page** loads the glossary and the tooltips (miss it on one page and
    it dies quietly on that page alone), and **that the glossary has not drifted from the source**.
  - Measured in the browser: the inheritance chain appears in the popup (`GoStyleBoxCut < StyleBox`), 0 console errors.
  - **`tools/check_all.sh`** (I-24 ✅) — the checks are split in three **because each can see a different range**, but running them from
    memory means one always gets missed. One entry point now also covers **the 4.6 unit tests** and **whether the generated theme files
    match the source** (for when the palette was edited but `make_theme.py` never run).

### Iteration 8 — 2026-09-13

- **Checks**: 271/271 (4.6 · 4.7) · contrast 0 · site 0 · generated files in sync
- **Analysis**: reproducing I-08 (the grid splits card text vertically) **in numbers** showed the cause was not the window width —
  the grid was a comfortable 350–460px wide while **the card was 25px at every width**.
  `GridContainer` gives the spare width only to children marked `SIZE_EXPAND`, and a card is `SIZE_FILL` by default, so it stays at
  **the minimum width of its content**. The labels inside the card have wrapping on, so their minimum width is nearly 0 and the card folded.
  🔑 The earlier note saying "it only happens at 430px" was wrong — the bug was there **at every width** and merely stood out at
  particular ones.
- **What was done**
  - **I-08 resolved** — `responsive_grid` gives the cells that go into it `SIZE_EXPAND_FILL`.
    Cards 25px → 169–224px, labels 6 lines → 1. A regression check was added too.
  - **I-22 finished** — the skin decides the section heading (`section_box`). The default is **an empty panel**, so the original shape is
    unchanged, while sci-fi gets an accent bar on the left and the screen reads as sections.

### Iteration 9 — 2026-09-13

- **Checks**: 271/271 (4.6 · 4.7) · contrast 0 · site 0 · generated files in sync
- **Analysis**
  - **I-25 was also a misjudgement.** The value text sits 12dp from the panel edge (the card padding) and is not clipped.
    After I-20, that is **the same mistake twice** — judging padding from a downscaled screenshot. It is now written into the conventions.
  - Instead, **looking at it at original scale found a real problem**: the bar's track is invisible. Measured, `scifi_dark`'s `track`
    was **1.003:1** against the background — effectively the same colour. For a widget whose job is to show "how much is left",
    **the maximum could not be seen.**
- **What was done**
  - **An outline on the bar's track.** Colour alone cannot guarantee it — a bar sits on the background, inside a card and on a HUD panel,
    and those three have quite different brightnesses. An outline makes an edge whatever it sits on.
  - **A glow on the bar's fill** (sci-fi). 🛑 The glow colour **follows the fill colour** — pin it and a red health bar glows cyan.
    `progress_fill_box()` changes the glow along with the fill.

### Iteration 10 — 2026-09-13

- **Checks**: 271/271 (4.6 · 4.7) · contrast 0 · site 0 · generated files in sync
- **Analysis**: the moment I-26 (the surface separation check) went in, **all four themes** were caught — panels and cards were
  1.07–1.14:1 against the background. That is why the screens looked flat. It is a layer that stayed invisible while only text contrast
  was being measured.
- **What was done**
  - **The surface separation check** (I-26 ✅) — measures whether neighbouring surface pairs are told apart. WCAG gives no threshold for
    such a pair (it is neither text nor decoration), so we set the minimum line at which an eye makes out the edge.
  - **Pulled the surface layers apart** — every neighbouring pair is ≥1.18 in all four themes. Sheets lift off the background and list
    items are told apart from the card.
  - **Text colours and borders became subjects of automatic correction too.** Moving the surfaces one step put `muted` back below the
    threshold in all four themes — a hand-picked value collapses every time a surface moves. Now the palette's value is the **starting
    point** and it is pushed until it reads on every surface it actually lands on (`readable_everywhere`).
  - 🔑 **A screenshot caught a pair the check had missed.** Without `surface_soft on background` in the list, the light themes' cards
    became **1.00:1** against the ground — invisible in the numbers and only seen in the image (the list-row panel had vanished entirely).
    Fixed by adding the pair and lowering the card colour.

### Iteration 11 — 2026-09-13

- **Checks**: 271/271 (4.6 · 4.7) · contrast 0 · site 0 · generated files in sync
- **What was done**
  - **I-27 resolved** — `make_theme.py` **prints what it pushed and by how much** (`muted #919bac → #a0a8b7 (surface contrast)`).
    Change it silently and someone who put in their own palette gets stuck on "why is the colour I wrote not showing?".
  - **Started the English edition** (I-10) — `docs/www/en/index.html` + `site/glossary.en.js` (125 entries).
    🛑 The Korean glossary is extracted from the `##` comments in the source, but **there is nowhere to extract English from**
    (the comments are in Korean). So the English descriptions are written by hand, and **a term with no description is left out of the
    English glossary** — better a missing term than a Korean description on an English page.
  - The site check now looks at **subfolders and the English glossary too**.
  - **I-28 found and resolved** — markdown left in the hand-written glossary descriptions (`**rounded**`) showed its symbols raw in the
    bubble (9 Korean, 9 English), because the bubble puts the description in with `textContent`. The generator strips it, and if it gets
    mixed in again the check catches it.

### Iteration 12 — 2026-09-13

- **Checks**: 271/271 (4.6 · 4.7) · contrast 0 · site 0 · generated files in sync · **packaging passes**
- **What was done**
  - **I-10 finished** — English `theming` and `widgets` added. The site is now **3 Korean pages + 3 English pages**, and you can move
    between the languages from either side. Completion condition 4 is filled.
  - **I-29 found and resolved** — packaging was **blocked.** The `docs/` I made went into the store ZIP, and a command example inside it
    (`res://…/tests/gallery_shots.gd`) pointed at a **`tests/` that is not in the ZIP**, so it hit the broken-reference gate.
    `docs/` is the website published through GitHub Pages, not something to ship with the asset (400KB of screenshots ride along too) —
    so it is excluded from the store ZIP, like `tools/`.
  - Added a **packaging gate** to `check_all.sh` (`GOHUD_CHECK_PACKAGE=1`). Being caught only when it is time to publish is too late.
    It is slow, so it is off by default and turned on in an iteration that moved files or added a folder.
- **Decisions — what was deliberately not done**
  - **I-23 (state transitions)**: Godot themes switch states instantly. Making it smooth needs a tween per button, and ① the cost
    multiplies by the number of buttons on screen, ② in a game UI an instant response **is not felt as input lag and is in fact better**,
    and ③ `reduce_motion` would need yet another branch. There is more to lose than to gain.
  - **I-09 (SVGs growing linearly)**: measured, the 88 SVGs come to **20KB** in total and the whole store ZIP is 340KB.
    Needing control images in a different colour per preset is an **engine constraint** (theme icons are not tinted), and while the file
    count grows, the size is negligible. Twisting the structure to reduce it would be worse.

### Iteration 13 — 2026-09-13

- **Checks**: 271/271 (4.6 · 4.7) · contrast 0 · site 0 · generated files in sync
- **Analysis**: with only one open issue left, I looked for what had never been tried — **I had never once followed the customization
  procedure written in the documentation myself.** So the "ordinary user" path (your own skin + registering a preset) was reproduced
  exactly as documented.
- **What was done**
  - The customization procedure **works** (register → `use_preset` → swap the skin → empty fields fall back to the defaults).
  - That experiment **exposed a hole**: painting the slot panel an opaque accent, as the documented example does, put the quantity text at
    **1.70:1** and an empty slot at **1.29:1**. How a panel is painted is up to the skin, while the text colour was fixed.
    Even the default preset already had an empty slot at 3.97:1 during cooldown, below the threshold.
  - `GoSlot` now **pushes the quantity, the timer and the shortcut colours until they read on the panel.** All four presets plus the
    custom one are ≥4.5.
  - 🛑🛑 **A check had been passing falsely.** Because of GDScript lambdas' **capture by value**, iteration 6's `skin contrast` never let
    the accumulated `worst` reach the outside, so **whatever it measured, it was green for seven iterations.**
    Changed to an array, and all four presets failed immediately (the light ones down to 2.91:1).
    **Written into the conventions — break a new check on purpose, watch it FAIL, then put it back.**

### Iteration 14 — 2026-09-13

- **Checks**: 271 → **275/275** (4.6 · 4.7) · contrast 0 · site 0 · generated files in sync
- **Analysis**: acted on iteration 13's lesson ("a check that passes may only have been built to pass") — a tool was made that breaks the
  code on purpose and measures whether the checks catch it.
- **What was done**
  - **`tools/check_mutations.sh`** (I-32) — breaks eleven rules one at a time and measures whether the checks catch each.
    🛑 The mutations go only into **a copy in the verification project**, never the original, and are reverted every time.
  - The first result was **"all ten missed"**, but the tool itself was wrong — `run_tests.sh` prints
    `gohud tests: 267/271 passed` even when it fails, so judging by "passed" always passes. Fixed to use **the exit code**.
  - After the fix, **7 of 10 caught**. Checks were added for the three missed: chip text colour (read from the real widget),
    label and button wrapping, and the touch floor of a slot forced small.
  - The mutation definitions were wrong twice as well — ① the slot touch rule **does not fire in the default settings** (the node is
    already 48dp; only the visible panel is 44dp). ② The wrapping line appears **three times** in the file, so the mutation landed on a
    label while the check was looking at buttons. Both were fixed by making the target spot specific.
  - In the end **all eleven mutations were caught**. Wired into `check_all.sh` as `GOHUD_CHECK_MUTATIONS=1`.

### Iteration 15 — 2026-09-13

- **Checks**: 275 → **279/279** (4.6 · 4.7) · 17 of 19 mutations caught · contrast 0 · site 0
- **What was done**
  - Widened the mutations from 11 to **19** (safe area, form width, virtual keyboard, window judgement, icon fallback, string priority).
  - **The three that were missed had the same cause — the test environment never fires that code.**
    · The form width cap **does not fire on a phone** (the mobile maximum width is 0, meaning no cap). Checking at phone size only made
      the rule pointless → make a desktop width and check there.
    · The virtual keyboard **does not come up** on desktop → reproduce it by feeding the height in directly with `_on_keyboard(300)`.
    · The safe area is **the whole screen** on desktop, so honouring it or not gives the same result → **it only shows on a real device.**
  - The first two were caught by adding checks, and the two safe-area ones were marked with `env` — **mixing what cannot be caught yet
    with what can never be caught** buries a missed rule under "that is just how it is".

### Iteration 16 — 2026-09-13

- **Checks**: 279 → **282/282**, now run on **four screens** (phone portrait, phone landscape, tablet, desktop) each.
  19 of 21 mutations caught · 2 real-device only.
- **What was done**
  - Made the test screen settable with `GOHUD_VIEWPORT=1280x800`, and `check_all.sh` runs **four sizes**.
  - Putting a mutation into landscape-only code showed it was **caught in neither portrait nor landscape** — the rule was there but the
    check was not. Checks were added for both the HUD's `landscape_spot` move and the window's landscape width ratio.
  - 🔑 **The landscape width ratio check failed at first** — hidden behind the `surface_max_width` (480dp) cap, 844×0.72 and 844×0.94 both
    come to 480. Fixed to **lift the cap and look at the ratio alone**.
    To check a rule you have to create **the conditions under which that rule actually changes the result** — the same lesson as iteration 15.

### Iteration 17 — 2026-09-13

- **Checks**: 282 → **285/285** (four screens · two engines) · 23 of 25 mutations caught · contrast 0 · site 0
- **Analysis**: the `rtl` check was confirming **only the value** of `layout_direction` — which is where "the setting is right but the
  screen is not mirrored" slips through. A mutation showed there really was a hole (the direction of the bar's numbers).
- **What was done**
  - **Mirroring is checked by coordinates** — with Arabic on, it looks at the real positions to see that a list row's icon comes
    **to the right of** the text. It also confirms the order comes back when switched to LTR.
  - Added a check that the bar's numbers still read left to right in RTL — flipped, the remaining health and the maximum swap places.
  - **The new check was broken on purpose to see it FAIL** (forcing the list row to LTR → failed with `icon 402 · text 428`).
    As the conventions require.

### Iteration 18 — 2026-09-13

- **Checks**: 285/285 (four screens · two engines) · contrast **58 pairs** (50 → 58), 0 failures · site 0 · generated files in sync
- **Analysis**: the capture tool had no locale argument, so the Arabic screen had never been seen (I-36). Adding it and capturing
  immediately revealed **two things** — one RTL-only, one nothing to do with language.
- **What was done**
  - Added `--locale=` to `gallery_shots.gd` → 18 images captured in Arabic. The mirroring itself was fine
    (titles right-aligned · button order reversed · list icons on the right · only the numbers left to right).
  - **Overlap at the bottom (RTL only)**: `GoForm` uses the whole screen while the quick slots float above it, so as a field's
    placeholder moved to the right, **its text poked out through the gaps between the slots.** Fixed in the gallery by pulling the body
    up by `HUD_RESERVE` (104dp).
  - **Overlap at the top (any language)**: the scrolling body passed **behind** the health bar at the top and the two texts tangled —
    in portrait a field's text, in landscape a toggle's knob, sat on the health bar. `head_room` only pushes the content's starting
    position; it cannot stop scrolling. Fixed by putting the bars **on a `hud` panel** so they cover what is behind them.
  - **The new rule that came out of it**: when a floating panel is translucent, **its colour changes wholesale with whatever is behind
    it.** Measured, in the two dark themes with something bright behind, `muted` was 3.74:1 and `secondary` 4.21:1 — below the body-text
    threshold, meaning the HUD's secondary text cannot be read when the game screen is a snowfield.
    Added `floating_rows` to the checks (it lays pure white and pure black underneath) and raised the `hud` panel alpha from 0.82 to
    **0.92** (0.88 is the boundary). After the fix, 5.26:1.
  - The new check **caught four real failures before anything was fixed** — which is how its catching power was seen with our own eyes,
    as the conventions require.
  - **In the light themes the quick-slot icons were buried in the panel.** After the fix above, recapturing the light themes caught the
    eye, and zoomed in, three of the four slots were down to outlines — `_icon.modulate` was **pinned** to `Color.WHITE`, a colour that
    is only right in a dark theme. Fixed to follow a colour that reads on the panel.
    The `tint = Color(1,1,1,1)` sitting in the default icon set's `.tres`, which made it look as though a colour had been chosen, was
    cleared away at the same time (multiplying by white is the identity, so it is the same as choosing nothing).
  - **Icons were added** to the skin contrast check, which had measured labels only. Broken on purpose, the two light themes came to
    **1.11:1 and 1.20:1** — meaning that with no check in place, this defect had sailed through eighteen iterations.
    The same rule went into the mutation list too (24 of 26 caught · 2 real-device only).

### Iteration 19 — 2026-09-13

- **Checks**: 285 → **291/291** (four screens · two engines) · mutations 27 → **27 of 29 caught** · contrast 0 · site 0
- **Analysis**: both overlaps stopped in iteration 18 were patched by **subtracting a number by hand in the example**
  (`HUD_RESERVE = 104`). That leaves anyone using gohud falling into the same trap, and the number is wrong the moment the screen turns
  landscape — in landscape the body really was losing 27% of its height (I-38).
- **What was done**
  - **`GoForm.avoid_hud`** — turn it on and it avoids the rectangles the `GoHudAnchor`s of the same screen hold.
    It is off by default, so existing behaviour is unchanged. The direction it avoids in is chosen as **the one that loses the least
    area**: the health bar at the top right is stepped around downwards in portrait and sideways in landscape.
  - **`GoHudAnchor.reserve_space`** — stops space being kept for a box **that is not normally on screen**, such as a joystick that only
    appears under a thumb. Left on, an invisible box carved a whole row off the bottom (measured).
  - **What has already been given up is subtracted before measuring the next box.** At first each box was computed on its own, so a slot
    that had already stepped 214dp to the right and was clear anyway still cost another 65dp at the bottom. The order is now pinned to
    **largest intruding area first**, so the same layout comes out however the node order changes.
  - The two constants in the gallery, `HUD_RESERVE` (104) and `head_room` (76), were **deleted** — the form measures it now.
  - **I-39 was moved into the checks.** For eighteen iterations an overlap could only be seen by opening a screenshot. Now it measures by
    coordinates whether the body and the HUD rectangles overlap, **which way** it stepped aside (down in portrait · sideways in
    landscape), and whether a box with `reserve_space` off is ignored.
  - **The check was wrong twice, and both times the check was the problem.** ① The form's side margins also come from **the width cap**,
    which was mistaken for avoidance, so at 768×1024 it judged "it stepped sideways" (the 164 on the right was the width cap; avoidance
    was 0). ② Pinning the direction as "landscape means sideways" judged 1280×800 (a ratio of 1.6:1) wrong when down was marginally
    cheaper (136k vs 141k). Fixed to measure **the area rule itself** rather than a name.
    🔑 A red check makes you suspect the code first, but this time, twice over, it was the check's premise that was too narrow.
  - Confirmed by breaking it — with avoidance disabled, `body [P:(20,16) S:(366,812)] avoids HUD [P:(214,738)
    S:(160,90)]` FAILs.

### Iteration 20 — 2026-09-13

- **Checks**: 291 → **299/299** (four screens · two engines) · mutations **29 of 31 caught** · contrast 0 · site 0
- **Analysis**: going to look at I-43 (should sheets and popups avoid the HUD too) showed **the premise was wrong** —
  sheets, popups and coach marks are **modal**, so they simply cover the HUD. What competes for space is what is not modal,
  namely **notices and prompt cards**. Looking at the screenshots again, the snackbar sat straight on the health bar and hid the
  leading digits of `320 / 500`.
- **What was done**
  - **`GoHudAnchor.avoid_peers`** — a box that shows for a moment **steps aside from a box whose place is fixed.**
    A box at the top moves down, one at the bottom moves up. It moves **vertically only** (move it sideways too and a centred notice
    appears somewhere new every time). The things it avoids are only **the boxes that have decided not to move** — if both avoid each
    other they swap places forever.
  - **Caught a side effect of iteration 19's feature.** When a notice appeared, `avoid_hud` avoided its box too and **the whole body
    lurched downwards.** Giving the notice and prompt boxes `reserve_space = false` stops the body keeping space in advance for
    something that shows for a moment. 🔑 A new feature's side effects must be **confirmed in the next iteration**.
  - Added five checks (overlaps → steps aside → downwards → keeps its horizontal place → a fixed box stays put). Broken on purpose to confirm.
  - **Again a check's premise depended on the screen.** With the notice width pinned at 300dp there was no overlap to begin with on an
    844dp screen, so "overlaps" failed on the very first line. It is now taken in proportion to the screen width. **The same mistake as
    iteration 19** — written into the conventions below.
  - **In landscape the notice ran off to the middle of the screen.** At first the things to avoid were "boxes with `avoid_peers` off",
    which makes **things that show for a moment**, such as prompt cards, avoid each other too. The criterion was changed to
    **fixtures with `reserve_space` on** — which is also the right meaning.
  - **When a fixture grew, the box that had stepped aside stayed where it was.** A notice has no way of knowing the health bar changed
    size. Now a change to a fixture's place wakes the boxes that step aside. 🔑 The hole in this rule only showed **after the check had
    passed once** — the check as first written took only the `reserve_space` setter path, so cutting the notification still went green.
  - 299 checks · 31 mutations (both broken on purpose to confirm). The duplicated `### Added` and `### Fixed` sections in the CHANGELOG were merged too.

### Iteration 21 — 2026-09-13

- **Checks**: 299 → **331/331** (four screens · two engines) · mutations **30 of 32 caught** · contrast 0 · site 0
- **Analysis**: the last four iterations had clung to layout and overlap. Going back to completion condition ① (more striking and more
  readable) and opening **a screen never once looked at** (a dialog in the sci-fi light theme) showed **the experience bar was brown**.
- **What was done**
  - **Found why the bar fill was brown.** In a light theme the status colours are darkened **so they read as text** (`warning #96500A`),
    and the fill inherited that colour. The whole point of the `*_fill` tokens was that "text and fill want opposite things", and yet they
    **started from the same value**.
  - It could not be solved with colour alone — **yellow is inherently high in luminance**, so it does not reach 3:1 over any grey ground.
    Darkening the track made it **worse** (1.52 → 1.06). So it was split in two: **the colour stays vivid** (fill-only pure colours,
    `*_vivid`, in the light palettes), and **the edge is an outline** (`GoSkin._edge_fill` puts a 1dp outline on the fill when it does not
    reach 3:1 over the ground, pushing 10% at a time until it clears).
  - **In sci-fi the outline was not being drawn at all** — the fill is a custom StyleBox, so it never took the `StyleBoxFlat` branch.
    The check caught it at 1.27:1.
  - Two lines of check are required **together**: ① it is told apart from the ground (by colour or outline) ② the colour is not dead
    (lightness 0.70). With only one, a return to brown still goes green. Both were broken to confirm (with the outline off, 1.49:1;
    without the pure colour, lightness 0.63).
  - Went over I-42: all 15 widget kinds do appear in the gallery. Of the hand-subtracted values only `tail = 220` (the bottom margin) was
    left, and since `avoid_hud` does that job, it was deleted.
  - **I-47 was closed in the same iteration.** A palette that goes by without knowing about `*_vivid` falls back to brown **silently** —
    so the generator now leaves a line: `the bar is drab — add warning_vivid to the palette`. Turned on, it caught `scifi_light`'s
    `accent_fill` at once (lightness 0.66), and `accent_vivid` was added to both light palettes.
    🔑 **Make the places that get worse silently speak** — the same principle as the generator announcing when it moves a colour.

### Iteration 22 — 2026-09-13

- **Checks**: 331 → **346/346** (four screens · two engines) · mutations **32 of 34 caught** · contrast 0 · site 0
- **User request** (arriving mid-iteration): "A bit more striking, prettier and more readable. Above all it has to support
  **desktop and mobile at the same time**." → from this iteration on, looking at the desktop screen with our own eyes is part of the procedure.
- **What was done**
  - **The confirm button for a dangerous action was not in the danger colour** (I-46). Trying a pale danger button was worse — with a pale
    panel the text has to be pushed so dark to read (`#9B2626`) that it becomes **just black text**. So a **filled danger button** was added
    (`Tone.DANGER_SOLID` · `GoDangerSolidButton`): white text at 5.7:1.
    The pressed panel mixes **towards the text colour** — mixed towards the background it fell to 3.87:1 in a light theme.
  - **On desktop the body was pushed 214dp to the left.** `avoid_hud` looked for overlap across **the whole safe area** — on a wide screen
    the width cap already gathers the form in the middle, nowhere near the HUD, and it was pushed anyway. Fixed to look for overlap within
    **the space the form will actually occupy**.
  - **The check was reading the child nodes' rectangles.** A container re-places its children **on the frame after** the margins change,
    so it was looking at the previous beat's layout (a 16dp difference, differing per screen). Changed to **the inner area the form hands
    out** — that is what we guarantee, and it is accurate at once.
  - **A mutation missed "do not push pointlessly on a wide screen"** — that rule **does not show on a phone** (with no cap, the form uses
    the whole screen). The check now switches to 1280×800 and confirms it directly.
  - Nearly filed an issue that the sheet had no scrim, but **measuring showed it working** (Primary 86 → 58). As the conventions require.
  - Put **the first two desktop images** on the site — until now it only showed phone screens.

### Iteration 23 — 2026-09-13

- **Checks**: 346/346 (four screens · two engines) · contrast pairs 58 → **62** (4 focus-ring pairs) · 32 of 34 mutations · site 0
- **Analysis**: as I-49 asked, **states that appear only on desktop** were captured for the first time. Mouse movement and focus movement
  went into the capture, adding two images, `_7_hover` and `_8_focus`.
- **What was done**
  - **The focus ring was invisible on an accent button.** The panel is the accent colour and so is the ring — **1.00:1**, the same colour
    drawn on the same colour. Moving about with the keyboard, "where am I now" disappears. Filled buttons now use **a ring that contrasts
    with the panel** (`btn_focus_on_fill`): a deep ring in dark themes, a white one in light themes, and a dark aiming mark in sci-fi.
    I-50 closed with it.
  - **The contrast check now measures focus rings** — **on the very panel** they land on. Custom StyleBoxes name their colour fields
    differently (the chamfer uses `border_color`, the aiming mark `color`), so both are read.
    Broken to confirm: back to an accent ring, all four themes fail at 1.00:1.
  - **The capture spun its wheels twice.** ① A coroutine was called without `await` and not one image was left.
    ② Capturing while an overlay was up **put hover on the popup's button** — the capture was moved ahead of the overlays.
  - To make the hover state, a **real `InputEventMouseMotion`** is sent rather than firing `mouse_entered`. Firing the signal alone does not
    change the engine's hover state, so nothing changes in the image.
  - Added a "screens with a mouse and a keyboard" section, and **a three-state comparison image**, to the site in Korean and English.

### Iteration 24 — 2026-09-13

- **Checks**: 346 → **353/353** (four screens · two engines) · mutations **33 of 35 caught** · contrast pairs 62 → **63** · site 0
- **Analysis**: I-51 and I-52 — tooltips and keyboard traversal are both places **a finger never reveals**.
- **What was done**
  - **Tooltip contrast is measured.** A tooltip is **split across two types** — the panel is `TooltipPanel` and the text `TooltipLabel` —
    so the old check, which looked for pairs within one type, could never catch it. All four themes were a comfortable 15–17:1 —
    this time it filled in **a blind spot** rather than a defect.
  - **Three keyboard traversal rules moved into the checks**: opening a window puts focus inside · focus leaking out is brought back ·
    closing returns it to where it was. gohud looks at **the last input device** and does not show a ring on a window opened by pointer,
    so the check had to **send one key event** to create the keyboard state.
  - **`GoSlot.keyboard_focus`** — quick slots stay out of Tab traversal by default (eight of them in the way means passing through them
    every time you go round a settings screen with a keyboard), but it can be turned on where keyboard-only operation is needed.
    Before, `FOCUS_NONE` was **pinned there for no reason**.
  - 🛑 **Reading the check results with `grep` hid a script error.** A call to a function that does not exist (`GoSurface.close()`) aborted
    a whole section, and looking only at the earlier sections' `passed` read as green. **The check count not growing** was the only clue.
    Written into the conventions.
  - "Closing returns focus to where it was" passes even with the implementation turned off — **because the engine does the same thing**.
    It stays as a check that guards the result, but it is kept out of the mutation list (in it, it would be caught as "missed").

### Iteration 25 — 2026-09-13

- **Checks**: 353 → **364/364** (four screens · two engines) · mutations **35 of 37 caught** · contrast 63 pairs, 0 failures · site 0
- **User feedback** (five images): ① the dropdown is bland ② the coach mark's `Done` is on two lines ③ a full-width button's glow is cut
  off on the left ④ the slot's icon and text stack vertically and are cramped ⑤ prettier overall, and **another theme is coming, so make
  customization easy**. The **parts** were fixed, not the screen (the demo).
- **What was done**
  - **Why `Done` split into `Don`/`e`**: a button with wrapping on **subtracts the text width** from its minimum width (it takes it as
    foldable). A 45dp word did not fit a natural-width button (72dp, 32 of padding), so it broke inside the word.
    `GoStyle.fit_words()` — a single word is never folded, and for several words **the longest word's** width is guaranteed as the minimum.
    Buttons, toggles and `form()` all use it, and the coach mark calls it again after changing the text.
  - **Why the glow was cut off only on the left**: a scroll always clips at its own edge, and on the right the rail's space
    (`use_panel_edge`) had already pushed that edge outwards, so it survived. The same trick was applied left, top and bottom —
    borrow the parent's padding, push the edge 12dp outwards, and take it back inside. Guarded by a coordinate check.
  - **The slot moved to a corner-badge layout**: the icon large in the middle (0.44 → 0.52), the shortcut at the top left, the quantity as
    a badge at the bottom right, and the remaining time as a badge laid **over** the icon while the icon recedes towards the panel colour.
    The badge panel comes from the skin's `badge_box()`, so sci-fi gets angular badges for free.
    At first the time text was laid over without a badge and tangled with the icon, unreadable (measured) — a badge went under it.
  - **The dropdown**: item hover used the button panel (`btn_hover`) and now uses **a pale accent panel meant for items**; the radio and
    check marks moved from the engine's defaults (a faint circle) to the same drawings as our checkboxes; and item height went from 27dp
    to the touch standard.
  - **Tooltips** (I-54): the engine's default tooltip computed a width of 1dp and split the text **one character per line** (measured
    width 1, height 186). `GoIconButton._make_custom_tooltip()` hands back a label in gohud's own shape. At first it drew another panel
    and the border came out **doubled** — it hands back the text alone. A `tooltip_key` argument was added to `icon_button()`, and the
    gallery's five icon buttons had **no description at all**.
  - Added the tour's last step (`_3b`), a cooling-down slot (`_3c`), an open dropdown (`_5b`) and a tooltip (`_9`) to the capture —
    all four of the scenes pointed out were states **that had never once been captured**.
  - 🛑 Three missteps on the check side: measuring the `ContentInset` container and reading "left 0" (the padding lands on its child) ·
    demanding 4.5:1 of an icon during cooldown (it recedes on purpose — made an exception) · measuring the toggle mutation inside a form,
    where `form()` fills it in instead (moved outside the form).

### Iteration 26 — 2026-09-13

- **Checks**: 364 → **368/368** (four screens · two engines) · 35 of 37 mutations · contrast 0 · site 0 · **a new scaffolding check**
- **User request** (I-55): another theme is coming — raise the freedom of customization and make it easy for a developer to make a theme.
  Until now four places had to be edited by hand (the generator's palette dict, the shape dict, the skin, the preset `.tres`).
- **What was done**
  - **`tools/new_theme.py`** — one command puts down `themes/palettes/<id>.json` and `themes/presets/<id>.tres`. The JSON **writes out in
    full** the values of the built-in theme it inherits through `from`, so that list is exactly "what you can change". `--remove` undoes it.
  - **The generator keeps a theme registry** — it walks the four built-ins plus `palettes/*.json`, and can build just one when given an
    argument. The shape dict can override `radius`, `gap`, `padding`, `button_height` and `button_padding`, and those values go all the way
    **down to the tokens**, so panel and widget calculations never drift apart.
  - **Presets are scanned from a folder** — `GoThemePresets.scan_folder()` and `names()`. Just drop a `.tres` in and it appears in the
    picker and in the project settings dropdown (a `.remap` suffix is stripped too). Four checks.
  - **The scaffolding check caught a defect on its first run** — a theme with only the accent changed had **8 pairs failing**. The generator
    pushed the text colours but used the accent, and the accent button's text, exactly as written. Two more digs in: white text cannot be
    made brighter and stopped at 3.97, and changing to dark text still gave 3.15 on the pressed panel — in the end the answer was
    **pushing the accent itself** until it reads against the text colour (contrast is symmetric). The four built-ins already clear it, so
    their values do not change.
  - 🛑 **Mid-task, the site was rearranged from `docs/www/` to `docs/` (English) + `docs/ko/` (Korean)** (17:24, including hreflang and the
    deploy URL — the user's work). At first it read as "deleted" and restoring came to mind, but looking at the state of things it was a move.
    The paths in the three tools (`make_site`, `check_site`, `check_all`) were moved and the `docs/www` remnants deleted.
    🔑 **When a file is gone, first work out whether it was deleted or moved** — never run a `--delete` sync before that.
  - Rewrote the site's "make your own preset" section in both Korean and English — four commands and **a one-page table of what you can change**.

### Iteration 27 — 2026-09-13

- **Checks**: 368 → **373/373** (four screens · two engines) · 35 of 37 mutations · contrast 0 · site 0 · scaffolding ✅
- **Analysis**: iteration 26's scaffolding went as far as colours and shapes. The skin's numbers (slot border 2dp, badge padding 5 · 1,
  joystick ring 0.45 …) were still pinned in code, so "make the slot border 3" meant inheriting `GoSkin` (I-59).
- **What was done**
  - **The skin numbers became dials** — 13 on `GoSkin` and 10 on `GoSkinSciFi` were exposed with `@export`. The JSON's `skin.dials` writes
    out every parent value, and the generator sends them down as `themes/skins/gohud_skin_<id>.tres`.
    The skin code is not touched. `tools/skin_dials.json` is the table of defaults and **a check compares it with the GDScript defaults**
    (a table that drifts writes nonsense values into a new theme).
  - **`--new-skin`** (I-58) — makes a `GoSkin` subclass shell only when the drawing itself is to change (with the list of methods to
    override as a comment).
  - sci-fi's chip border (0.55) and slot tint (0.26/0.10) were **unified** onto the default dials (0.45 · 0.24/0.08) — a fine change, so it
    was confirmed by capture, and the angular badges and glow are all as intended.
  - **The demo is captured** (I-56) — `tools/demo_shots.sh` opens the 15 sections at phone and desktop size, plus one more of the dropdown
    held open. It confirmed for the first time that the four scenes the user pointed out are fixed **in the demo** (glow symmetric left and
    right · dropdown hover panel and radios · slot badges). The demo code was not touched — `_open_explore` is called from outside.
  - 🛑 The demo capture spun its wheels twice: ① a window override (2560×1600) made the first image desktop-sized ② the demo's
    `_scale_window` multiplied by the **retina factor of 2×**, so only 195dp fitted into the phone window and the title split into
    `quic`/`k` (headless checks have no window, so the factor is 1). Turning the `_scaling` guard on stopped it without editing the demo code.
    🔑 **When a word looks split, first tell a widget defect apart from the capture's scaling.**

### Iteration 28 — 2026-09-13

- **Checks**: 373 → **377/377** (four screens · two engines) · mutations **37 of 39 caught** · contrast 0 · site 0 · scaffolding ✅
- **Analysis**: recent iterations had leaned towards infrastructure (scaffolding, captures). This time: ① the real defect candidate left
  over (I-57) ② a place kept in two hands (I-63) ③ **going through all 31 demo images for the first time** to dig out visual defects.
- **What was done**
  - **The word-wrapping rule was looking at the translation key** (I-57). The `text` in `button_key()` is a key (`confirm`) and the engine
    translates it just before drawing — looking at the key alone it is one word and is marked unfoldable, while the translation may be two.
    It now looks at **the visible text** via `atr(text)`, and the form reapplies the rule to descendant buttons on
    `NOTIFICATION_TRANSLATION_CHANGED`. Dialogs call it again from `_retranslate()`. Two checks (fake `xx`/`yy` translation locales are
    registered to switch between two words and one) — both broken on purpose to confirm (0 / 3).
  - **The dial table became a generated file** (I-63). The generator parses `@export var x := value` out of `go_skin.gd` and
    `go_skin_scifi.gd` — GDScript is the single source. `skin_dials.json` is left for the check to compare the parser against, and the
    scaffolding check asks "does the table match the script?" (23 entries).
  - **Went through the 31 demo images** — candidates picked from a downscaled montage and judged on the originals (as the conventions
    require). `More actions`, which looked like "a lighter grey panel" in the montage, was the same panel in the original (a shrinking
    illusion); the real difference was **the text alignment (centre vs left) and the arrow size**. `dropdown()` was matched to `select()`
    (left-aligned · OptionButton arrow size).
  - The first phone montage was captured **before** the scaling was pinned and so was useless as evidence — everything was recaptured (34 images).
  - 🛑 A script containing a heredoc terminator (`PY`) inside a heredoc was sent, and the shell cut it in the wrong place so the edit never
    ran at all — twice. Solved by naming the outer terminator differently (`PYEDIT`).

### Iteration 29 — 2026-09-13

- **Checks**: 377/377 (four screens · two engines) · 37 of 39 mutations · contrast 0 · site 0 — this iteration went into **the eyes** more than the code.
- **Analysis**: the demo capture only opened each section, so it caught grey (inactive) widgets alone (I-61 · 65), and the three scenes that
  were pointed out come out **while the bot is running**. The demo already had a capture feature (`_shot_dir`), so it could be used without
  touching the code.
- **What was done**
  - **`demo_shots.sh --play`** — runs the bot at 4× down the same path as "Play this widget" (`_play_current`), and while it runs, checks
    every 0.2s for overlays (coach marks, surfaces, notices, prompts) and captures **the moment each first becomes visible**.
    A coach mark gets one image **per step**. The `NN-key.png` (the active state) the bot saves right after a scene is kept as well.
  - It spun its wheels three times: ① after a play ends the demo returns the screen to the explore state and it is **grey again**
    (`Clicks: 0`) — useless, so it was dropped ② `var tag := cls` is a Variant and failed to parse ③ **the first frame after `visible` goes
    on has fade-in alpha 0**, so only the arrow was captured — it waits 0.4s.
  - **The three scenes were confirmed in the demo**: the `Done` on the 3/3 `Save` card on one line · the glow on an active button symmetric
    left and right with a notice up · identical text tone on the pair of active dropdowns (I-64's "tone difference" was the inactive
    illusion — what remained was the arrow's x by 12px).

### Iteration 30 — 2026-09-13

- **Checks**: 377 → **382/382** (four screens · two engines) · mutations **39 of 41 caught** · contrast 0 · site 0 · scaffolding ✅
- **Analysis**: the two defects the demo bot capture showed for the first time — the coach mark card covers the header's controls (I-66),
  and the arrows of two dropdowns side by side are 12dp apart in x (I-64).
- **What was done**
  - **The coach mark card does not cover a fixture.** The cause was the rule that sent the card to **the very top or bottom of the screen**
    in landscape — the header and the HUD live in those bands. It now sits **at the same height as its target**, avoids `reserve_space`
    anchors by itself, and is told about non-anchors through `keep_clear`. When avoiding, it moves the shortest distance among the
    directions that do not cover the target, and if it cannot avoid everything it stays put (overlapping beats the card disappearing).
  - **The arrow's place** — OptionButton used the engine's default `arrow_margin` (4) while MenuButton put the icon inside the panel padding
    (16), 12dp apart. The theme now gives `arrow_margin` the same value as the panel padding.
  - Five checks. 🛑 **A mutation missed one** — the check measured the "same height as the target" rule **with the fixture already standing**,
    so avoidance masked the rule. Fixed by reordering it to measure first, with no fixture.
  - Two missteps in the demo capture's timing: during a fixed 0.4s wait the 4× bot pressed `Done` and the card vanished → for coach marks it
    now waits **only until the card's alpha has filled** and then captures. Confirmed in the demo that the 3/3 card sits beside its target,
    at the same height.

### Iteration 31 — 2026-09-13

- **Checks**: 382 → **384/384** (four screens · two engines) · mutations 41 → **40 of 42** (the floating panel shadow rule) · contrast 0 · site 0 · dials 23 → **27**
- **Analysis**: when the coach mark card lay over the information panel, "floating" read weakly (I-69) — `floating_box`'s shadow was a
  shallow 8dp · α0.35 · 2dp, and sci-fi, with its angled panels, **cannot take a shadow at all**.
- **What was done**
  - **The depth of a floating panel became dials** — `float_shadow_alpha` (0.45) · `float_shadow_size` (14) · `float_shadow_lift` (4), and
    angled panels raise the glow instead through `float_glow_size` (10). The coach mark and the prompt card now read as floating above the
    body (confirmed by capture in a dark theme). They are included in the JSON's `skin.dials` automatically (the parser).
  - **I-67 was not the add-on's to fix** — the theme's `notice` box already has a shadow (12dp · (0,4)) and a glow. The notice hiding the
    first line is the demo's layout, which puts the notice over the body.
  - 🛑 A misstep in the check: making **the sci-fi skin instance alone** and measuring it gave the default theme's rounded panel — the
    angled panel comes from the theme, so the preset has to be switched to sci-fi before measuring.

### Iteration 32 — 2026-09-13

- **Checks**: **384/384** (four screens · two engines) · 40 of 42 mutations · contrast 0 · site 0 (+3 check items) · dials 27
- **Analysis**: there are 27 dials, but the site listed only their "kinds", so finding out what can be changed meant opening the JSON (I-70).
  The source is already the `@export`s in GDScript and the `##` comments above them, so there is no reason to write the table by hand.
- **What was done**
  - **The generator fills the dial table in** — `make_site.py` reads the `@export var`s of `GoSkin` and `GoSkinSciFi` and the `##` line
    directly above each, writes a name/default/meaning table between `<!-- dials:begin/end -->` on both copies of `theming.html`, and puts
    the 27 into the glossary as well, so their names get a bubble anywhere on the site. The English meanings are not in the source, so
    `DIALS_EN` is a hand-written dictionary — if one is missing, `check_site.py` catches it (it catches a stale table and a missing marker
    too — all three broken on purpose to confirm).
  - **One comment line per dial** (I-72) — a comment written for a group (`— during cooldown / normally`) left the table telling which of
    `_lit` and `_idle` is the cooldown only by order. Splitting the source comments gives the table a meaning per row for free.
  - **CSS just for the tables** — the site's tables are `display:block` (for horizontal scrolling) and so stretch only as far as their
    content, leaving two tables' columns standing in different places. The dial tables alone are `display:table` with the first two column
    widths pinned, and line up (confirmed by a headless Chrome capture).
  - A one-line pointer to the table in both READMEs. 🛑 A `--headless=new` Chrome **does not exit** even after saving a screenshot —
    once the file appears, reap it with `pkill -f chrome_tmp` (macOS has no `timeout` either).

### Iteration 33 — 2026-09-13

- **Checks**: **384/384** (four screens · two engines) · 40 of 42 mutations · contrast 0 · site 0 · 12 site captures
- **Analysis**: unlike the gallery and the demo, the site had **never once been rendered at phone width.** In the first phone-width images
  from the new capture tool, the tables stretched one word per line and the third column was off screen (I-77) — the kind of problem that
  reading the HTML can never show.
- **What was done**
  - **`tools/site_shots.sh`** (I-75) — 6 pages × desktop (1100) and phone (400) = 12 images. It also runs from `check_all.sh` through
    `GOHUD_CHECK_SITE_SHOTS=1`. 🛑 Headless Chrome **will not shrink a window below 500 CSS px** (innerWidth is 500 even given
    `--window-size=400`, and the same with a scale factor of 2 — measured with a probe page). The first phone image was a **fake defect**:
    a 500-wide layout cropped to 400, so the body text broke off at the right. Phones are captured through a wrapper that puts the page in
    a 400-wide iframe (measured at 400).
  - **Table widths unified** (I-73) — `display:block` was removed so every table fills the body width on desktop (confirmed by capture).
  - **At phone width, tables stack as cards** (I-77) — below 640px the rows go vertical, the headers hide, and the generated dial table
    labels each cell through `data-label`, as in "DEFAULT · 0.16". 🛑 The media query has to come **after** the `th, td` underline rules for
    the cell dividers to be cleared — put first, a line was left on every cell (caught by capture).
  - A one-line note on the dial types (int/float) (I-76). A sentence pointing to the table in both READMEs.

## Issues dug out (by priority)

### P0 — bearing directly on the completion conditions
- [x] ~~**I-02** verify Godot 4.6 for real~~ → 266/266 on 4.6 stable, plus screenshots checked
- [x] ~~**I-03** state the minimum engine version~~ → cfg · README ×2 · a code constant · a check
- [x] ~~**I-01** `docs/www`~~ → 3 pages + 129 term popups + the preset comparison images + the site check. What is left is I-10 (the English edition)

### P1 — quality
- [x] ~~**I-04** measure readability for real~~ → `tools/check_contrast.py`, failures 21 → 0
- [x] ~~**I-16** a status colour serving both text and fill~~ → five `*_fill` tokens + automatic fallback in `GoUi.color()`
- [x] ~~**I-17** the contrast check looks at text colours only~~ → now also text on the panel per button state, measured pairs 25 → 50
- [x] ~~**I-18** the slot's dimming is an alpha multiply and vanishes in a light theme~~ → replaced with moving the colour
- [x] ~~**I-20** the glow is clipped at the card's edge~~ → **it was a misjudgement.** Measured zoomed in, the glow is fine.
  The lesson: do not judge fine rendering from a downscaled screenshot — crop it and look at the original scale.
- [x] ~~**I-19** the colours a skin makes are out of measurement~~ → the WCAG maths went into `GoSkin`, plus a check section. Failures 11 → 0
- [x] ~~**I-05** sci-fi is too restrained~~ → glow, accent edges, bracket focus. What is left is I-21
- [x] ~~**I-21** default is still not pretty~~ → depth layers of shadow (lifting, sinking), depth on buttons
- [x] ~~**I-22** decoration for dividers and section headings~~ → the skin decides both. sci-fi gets an accent line and a bar on the left
- [x] ~~**I-25** the HUD bar's value text sits against the edge~~ → **a misjudgement.** Measured, it is 12dp from the panel edge
  (the card padding) and is not clipped. After I-20, that is **the same mistake twice** — written into the conventions below.
- [x] ~~**I-23** state transitions~~ → **decided against.** The cost multiplies by the number of buttons, and in a game UI an instant
  response is better anyway (see the iteration 12 entry above)
- [x] ~~**I-06** start improving the default theme~~ → palette readability corrected. What is left is the "richness" (along with I-05)

- [x] ~~**I-31** other checks could pass falsely too~~ → going through them, every other lambda **assigns through an array index**
  (`notified[0] += 1`) and is safe. Whoever wrote the existing checks knew the trap and used an array;
  the problem came of my not following that practice in iteration 6.
- [x] ~~**I-32** we do not know what the checks catch~~ → `check_mutations.sh`, all eleven rules confirmed caught
- [x] ~~**I-33** the mutation list has only 11 entries~~ → 19. Form width and the virtual keyboard were caught by adding checks,
  and the two safe-area ones are marked real-device only
- [x] ~~**I-34** the test environment is one phone~~ → it runs on four screens. Checks were added for two landscape-only rules
- [x] ~~**I-35** RTL is checked by value alone~~ → with Arabic on, mirroring is confirmed **by coordinates**
- [x] ~~**I-36** screenshots are taken in Korean and LTR only~~ → `--locale=` added, 18 Arabic images checked.
  It is how the two overlaps, below and above, were caught
- [x] ~~**I-37** a floating panel is translucent and the back shows through~~ → a check that measures against the worst backgrounds
  (pure white, pure black) was added and the `hud` alpha raised to 0.92. Two dark themes really were failing
- [x] ~~**I-38** in landscape the body is far too short~~ → `avoid_hud` steps aside **whichever way loses less area**.
  In landscape it steps sideways and no vertical space is lost
- [x] ~~**I-40** the slot icon is pinned white and is buried in a light theme~~ → now a colour that reads on the panel.
  Icons were added to the checks and the mutations (1.11:1 without it)
- [x] ~~**I-41** there are more places with a pinned icon colour~~ → going through them, **a glyph that falls to a child label** was the
  same trap (`GoIconButton` · `GoStyle.apply_icon`). A button theme's `icon_normal_color` does not reach the child and it comes out white —
  with a font icon set that is 1.41:1 in a light theme. Both were fixed to pick up the theme colour, and checks and mutations were added.
  Every other `Color.WHITE` was on a path that receives a colour.
- [x] ~~**I-39** overlap is caught by eye alone~~ → five checks measuring by coordinates. They confirm not just whether it overlaps
  but **which way** it stepped aside
- [x] ~~**I-42** the examples lag behind the add-on's features~~ → all 15 widget kinds are in the gallery. Of the hand-subtracted values
  only `tail = 220` was left, and `avoid_hud` does that job, so it was deleted
- [x] ~~**I-45** the bar fill is brown in the light themes~~ → fill-only pure colours + an outline. Two lines of check (told apart · vivid)
- [x] ~~**I-46** the confirm button for a dangerous action is not in the danger colour~~ → `Tone.DANGER_SOLID` (filled red +
  white text, 5.7:1). The window is reused, so **the tone is set every time** — otherwise the next dialog is red too
- [x] ~~**I-48** on desktop the body is pushed to the left~~ → overlap is looked for within the space the form will actually occupy
- [x] ~~**I-49** desktop-only states have never been looked at~~ → hover and focus images were added to the capture.
  The moment they were taken, the invisible focus ring showed up
- [x] ~~**I-50** the focus ring is pinned to the accent colour~~ → filled buttons get **a ring that contrasts with the panel**. The contrast check guards it
- [x] ~~**I-51** tooltips have never been looked at~~ → the panel and the text are **different types**, a place the old check could not see.
  Now it is measured (a comfortable 15–17:1)
- [x] ~~**I-52** we do not know whether a screen can be got round with the keyboard alone~~ → the three window focus rules became checks.
  `GoSlot.keyboard_focus` opens the quick slots to the keyboard too
- [ ] **I-53** 🆕 **the gamepad has never been thought about.** This is a game HUD kit, yet the path for moving between slots and buttons
  with a D-pad (`focus_neighbor_*`) has never once been set. It is a different problem from keyboard Tab order.
- [x] ~~**I-54** we have never seen what a tooltip actually looks like~~ → the moment it was captured it showed the text split one character
  per line (the engine's default width computation of 1dp). gohud draws it itself
- [x] ~~**I-55** adding a theme takes too long (user request)~~ → one line of `new_theme.py` + one JSON. Folder scanning removes the
  registration code. Shape measurements can be overridden from the JSON. With the accent correction, changing colours alone passes the checks
- [x] ~~**I-58** the scaffolding does not go as far as the skin code~~ → `--new-skin` makes a `GoSkin` subclass shell
- [x] ~~**I-59** the skin's numbers are pinned in code~~ → 23 dials (`@export`) · the JSON's `skin.dials` · a check comparing the table
- [x] ~~**I-61** the demo capture does not take the tour or the active states~~ → `--play`: it captures each coach mark step · a notice ·
  a prompt · the moment a sheet appears. The one-line `Done` was confirmed in the demo
- [ ] **I-62** 🆕 **in the demo's phone layout the top control row is cut off on the right** (`Widgets · 1.0x · Cinema · ← ▷ → ×`
  passes 390dp and the `×` is cut — measured on a capture). It is in the demo's code, so it was left alone — the user has to decide.
- [x] ~~**I-63** the dial defaults live in two places~~ → the generator parses the `@export`s. The table is a generated file
- [x] ~~**I-64** the arrows of a pair of dropdowns are 12px apart in x~~ → the theme's `arrow_margin` matches the panel padding
- [x] ~~**I-65** the demo capture takes the inactive states~~ → `--play` runs the bot and captures the active moments
- [x] ~~**I-66** the coach mark card covers a fixture~~ → target height in landscape · avoiding `reserve_space` anchors · `keep_clear`
- [ ] **I-68** 🆕 **the demo bot capture is sensitive to the bot's speed.** At 4× a momentary scene (the coach mark card) was missed by a
  fixed wait, and switching to an alpha threshold caught it, but something that **disappears quickly**, such as a notice, still rests on
  luck — the path of pausing the bot before capturing (`_bot.paused`) needs a look.
- [x] ~~**I-69** a card lying over text reads weakly as "floating"~~ → four shadow and glow dials, with deeper defaults
- [x] ~~**I-70** there are 27 dials but the site has no list of their names~~ → `make_site.py` fills the table in from the `@export`s and
  the `##` comments and puts them in the glossary too. `check_site.py` catches a stale table, a missing marker and a missing English meaning
- [x] ~~**I-72** the dial comments are grouped, so `_lit`/`_idle` were told apart only by order in the table~~ → one `##` line per dial
- [x] ~~**I-73** the site's other tables are all different widths~~ → `display:block` removed, card style on phones only
- [x] ~~**I-75** checking how the site renders is manual~~ → `tools/site_shots.sh` (phones through an iframe wrapper)
- [x] ~~**I-76** the dial table's defaults are a mix of `14` and `10.0`~~ → a one-line note on the types (the generator already matches them)
- [x] ~~**I-77** at phone width the tables stretch vertically and the third column is off screen~~ → card style below 640px + `data-label`
- [x] **I-78** (resolved in the final wrap-up; see the verification record above) 🆕 **on phones a long line in a code block scrolls sideways.**
  `pre` does not wrap, so at 400 wide the comments are cut off (it does scroll). Either split the example lines shorter or decide to give
  `pre-wrap` on phones only.
- [x] **I-79** (resolved in the final wrap-up; see the verification record above) 🆕 **the site's dark mode has never been looked at.**
  There is a `prefers-color-scheme: dark` palette, but the captures are light mode only — a `--dark` option that overrides the `:root`
  variables with the dark values in the wrapper would show the dark contrast of the tables, the bubbles and the warning boxes.
- [x] **I-80** (resolved in the final wrap-up; see the verification record above) 🆕 **in the phone card style a rowspan group name appears
  on the first row only.** `palette`, `shape` and `skin` in the "what you can change" table show on the first item alone, so on a phone
  there is no telling which group the `readability` row belongs to — either repeat the group name like a subheading or label it with
  `data-label`, as the generated table does.
- [x] ~~**I-71** the depth of a floating panel in a light theme has not been looked at~~ → in the `default_light` coach mark captures
  (desktop and phone portrait) the card's shadow is distinct. The light theme's `shadow` token (α0.30) multiplied by the α0.45 dial was enough
- [x] ~~**I-67** the demo's notice hides the first line of text~~ → the theme's `notice` already has a shadow and a glow. It is the demo's
  layout, so it is closed on the add-on side (the demo code is not touched)
- [x] ~~**I-60** the site check reports "0 problems" even with 0 pages~~ → it fails when there are no pages (closed in the same iteration)

- [x] ~~**I-56** the demo screens are not in the captures~~ → `tools/demo_shots.sh` (15 sections × phone and desktop + the dropdown held open).
  `check_all` turns it on with `GOHUD_CHECK_DEMO_SHOTS=1`
- [x] ~~**I-57** `fit_words` has to be called again when the text changes~~ → it judges by **the visible text** (`atr`), and the form
  reapplies it on the translation notification. Dialogs do so from `_retranslate()`
- [x] ~~**I-47** a palette that goes by without knowing `*_vivid` turns brown silently~~ → the generator says so. Turned on, it caught
  `accent_fill` at once and `accent_vivid` was added to both light palettes
- [x] ~~**I-43** `avoid_hud` is on the form only~~ → **the premise was wrong.** Sheets, popups and coach marks are modal and simply cover
  the HUD. What competes for space was **notices and prompts**, and `GoHudAnchor.avoid_peers` solved it
- [ ] **I-44** 🆕 **a new feature's side effects are not confirmed within the same iteration.** `avoid_hud` made the whole body lurch
  whenever a notice appeared, and that only showed **in the next iteration's screenshots**. In the iteration that adds a feature,
  capture "what happens when something else occurs while this is on" at least once.

### P2 — structure and regression risk
- [x] ~~**I-26** surface separation is not measured~~ → five neighbouring surface pairs are measured. The layers were pulled apart in all four themes
- [x] ~~**I-27** the generator corrects silently~~ → it prints each colour it changed, one per line
- [x] ~~**I-10** the English edition~~ → three pages (introduction, look, widgets) + a 125-entry English glossary
- [x] ~~**I-11** the site is not covered by any check~~ → `tools/check_site.py`
- [x] ~~**I-24** the checks have to be remembered and run separately~~ → `tools/check_all.sh` (including 4.6 · and whether the generated files match)
- [x] ~~**I-12** the site has no images~~ → 4 presets compared + 2 sheets (`docs/www/img/`)
- [x] **I-07** (resolved in the final wrap-up; see the verification record above) `examples/.gdignore` (an empty file) hides the whole
  examples folder, so **the gallery cannot be opened from any project.** The user has to decide.
- [x] ~~**I-08** the grid splits card text vertically~~ → `SIZE_EXPAND_FILL` on the cells. The bug was there at every width
- [x] ~~**I-09** the SVGs grow linearly~~ → **not a problem.** 88 of them come to 20KB · the whole ZIP is 340KB (measured)

## Conventions to keep

- 🛑🛑 **When you add a check, break it on purpose.** The `skin contrast` added in iteration 6 **verified nothing for seven iterations** —
  a GDScript lambda **captures an outer local by value**, so `worst = value` inside the lambda never reached the outside.
  Whatever it measured, it was always green. A check that passes **may only have been built to pass.**
  With a new check, always revert the code it guards, **watch it FAIL with your own eyes**, and then put it back.
  (Arrays and dictionaries are captured by reference, so use those for accumulating.)
- 🛑🛑 **If your eye suspects something, measure before you write it down.** Judging padding, glow and clipping from a downscaled
  screenshot (shrunk to 720px) **got it wrong twice** (I-20 the glow clipped, I-25 the text against the edge — both were fine when measured).
  When you suspect something, either ① crop that area and look at it at original scale, or ② put up a probe and print the coordinates —
  **and then** file the issue.
- 🛑🛑 **Do not read the check output through `grep` alone.** Skimming with `grep -E "FAIL|passed"` missed **a whole section aborted by a
  script error** — a call to a function that does not exist, read as green from the earlier sections' `passed`
  (2026-09-13, `GoSurface.close()`). After changing the checks, look at **the last few lines as they are**:
  `... | tail -5` carries the total together with `✅/🛑`. **If the check count has not grown**, the new check did not run —
  that is the quickest signal.
- 🛑🛑 **Write checks whose premises do not lean on the screen size.** The same mistake was made in two iterations running —
  ① "by default it overlaps" did not hold on a wide screen, where the form gathers in the middle, and ② with the notice width pinned at
  300dp it never reached anything on an 844dp screen in the first place. Take the numbers **from the screen** (`area.size.x * 0.9`).
  And do not pin a direction or a place by name: "landscape means sideways" was wrong at 1280×800 (1.6:1) —
  measure **the rule itself** (whichever way costs the least area). 🔑 A red check makes you suspect the code first, but in all three of
  these it was the check that was too narrow.
- 🛑 **In the iteration that adds a feature, capture its side effects at least once.** `avoid_hud` made the whole body lurch the moment a
  notice appeared, and that only showed **in the next iteration's screenshots**. Keep one image of a screen where something else
  (a notice, a sheet, the keyboard) happens while the new feature is on.
- 🛑 **When a file is gone, first work out whether it was deleted or moved.** The site being rearranged from `docs/www/` to `docs/` was
  read as "deleted" and restoring came to mind first (2026-09-13). Look at the neighbouring folder's timestamps and contents with `ls -la`
  first, and **never run a `--delete` sync before confirming the state of the original** — it deletes the copy as well.
  The site structure at that time was `docs/`. The final structure, following the user's request, is `docs/www/` (English),
  `docs/www/ko/` (Korean) and `docs/www/site/` (the glossary).
- 🛑 **After changing a theme, `python3 tools/check_contrast.py` has to say "0 failures in total".** Picking colours to be pretty always
  breaks the contrast somewhere — invisible to the eye and visible only on a phone in the sun.
- 🛑 Do not make a new shape by editing `SHAPE_DEFAULT` (**the shapes**) — **add a new dict.**
  Touch the shapes and the layout of all four themes moves at once, and the regression cannot be narrowed down. The palette may be edited.
- 🛑 **Check on both engines.** 4.7 alone does not guarantee 4.6 compatibility:
  `GOHUD_PROJECT=$SP/verify46 GODOT_BIN=$SP/godot46/Godot.app/Contents/MacOS/Godot bash tools/run_tests.sh`
- 🛑 `GoStyle.box()`, `floating()` and `disc()` must not break their promise to return a `StyleBoxFlat`. For custom shapes, `GoStyle.surface()`.
- 🛑 Do not touch files I did not make (`go_sheet.gd` · `go_surface.gd` · `examples/demo/*` · `sim*.gd` · `i18n/*`).

## Rebuilding the verification environment

```bash
SP=<scratchpad>
mkdir -p "$SP/verify/addons"
cat > "$SP/verify/project.godot" <<'EOF'
config_version=5
[application]
config/name="gohud verify"
run/main_scene="res://addons/gohud/examples/gallery/gallery.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")
[display]
window/size/viewport_width=390
window/size/viewport_height=844
[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
EOF
# sync.sh — copy without examples/.gdignore (with it there, the gallery cannot be opened)
rsync -a --delete --exclude '.git' --exclude '.godot' --exclude 'builds' --exclude '.env' \
  --exclude 'examples/demo' --exclude 'examples/.gdignore' --exclude '.review' \
  <add-on>/ "$SP/verify/addons/gohud/"
godot --headless --path "$SP/verify" --editor --quit     # class cache and import
```

Comparing screenshots:
```bash
godot --path "$SP/verify" -s res://addons/gohud/tests/gallery_shots.gd -- \
  --out="$SP/shots" --preset=scifi_dark --still
```
Without `--still`, the coach mark's pulse and the fades make **every run draw a different image** and pixel comparison is impossible.
