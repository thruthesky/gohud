# gohud demo app

Open this folder in Godot, or run it straight from a terminal:

```bash
cd examples/demo
godot
```

There is nothing to set up first. When `addons/gohud` or the import cache is missing, the app
says so on screen, links the add-on, imports the project once and reopens itself; every run
after that starts on the home screen. (That link is generated locally and ignored by Git — it
points back at the add-on root, and a checked-in loop would send recursive tools into it.)

`bash examples/demo/run.sh` from the add-on root does the same and, in a copy installed from
the Asset Store, also restores `project.godot` from `project.godot.demo`. The shipped copy keeps
`project.godot` asleep on purpose — a nested one would make your own editor warn "Detected
another project.godot".

## Home screen

`main.tscn` is the main scene: a doorway that checks the add-on and then hands over to
`home.tscn`. The home screen is built from nothing but gohud widgets, and offers five ways in.

| Key | Screen | Source |
|---|---|---|
| `1` | **Widget gallery** — every widget on one page | `examples/gallery/gallery.gd` |
| `2` | **Guided tour** — 23 chapters, played or hands-on | `examples/demo/sim.gd` |
| `3` | **Showcase screen** — six cards on one screen | `examples/demo/demo.gd` |
| `4` | **Medieval look** — the same widgets, another preset | `examples/medieval/medieval.gd` |
| `5` | **Showreel** — 20 seconds, a widget every half second, the theme changing each step | `examples/demo/showreel.gd` |

The page is laid out in four numbered parts, and the whole of it is built from add-on widgets:

- **Hero** — the wordmark, a preset picker, and next to the pitch a *live* HUD: three `GoBar`
  gauges and four `GoSlot` quick slots. Press a slot and the health bar answers.
- **01 Pick a screen** — the five cards above, each one a `style_choice_card` button carrying an
  icon disc, its shortcut, its blurb and the source file it opens.
- **02 Try it right here** — six cards of real widgets: button tones and icon buttons, a text
  field with a toggle and a slider, segments with a picker and a colour grid, an avatar with list
  rows and a progress bar, the notice / dialog / sheet / prompt / coach-mark buttons, and a live
  activity card that prints every callback they fire.
- **03 The pieces** — all 19 classes grouped by the job they do (foundation, building a screen,
  talking to the player, the game HUD), each with a one-line description and the line of code that
  uses it.
- **04 Where to go next** — README, docs, the example sources and `/gohud features`.

Body text is held to a readable measure (`PAGE_MAX_WIDTH`, 1120 dp) instead of stretching to the
window, and every block sits in a responsive grid, so a wide window gains columns while the lines
stay the same length. On a phone the grids fold to one column and the wordmark row splits in two.
A faint grid and two soft blooms sit behind it all, drawn from the current theme's tokens, so the
backdrop changes with the preset.

The screen you pick opens inside the same window, with a bar across the top naming it and the
file it lives in; **Home** goes back. To skip the home screen entirely:

```bash
godot -- --open=gallery      # gallery | tour | showcase | medieval
```

## Guided tour

The tour waits on its Start screen and offers two ways in:

- **Start demo** plays a guided simulation of 23 chapters. The cursor uses real mouse and
  keyboard events to click buttons, type into fields, select menu items, drag sliders and
  joysticks, and scroll lists.
- **Explore widgets** (or any row in the left sidebar) builds a single chapter and hands it
  to you. Nothing moves on its own: press, drag and type yourself. The right panel describes
  the widget and its **Play this widget** button lets the bot demonstrate just that chapter,
  after which the widget is rebuilt for you again. Picking a sidebar row while the tour is
  running folds the tour and opens that widget. On narrow windows the sidebar becomes a
  **Widgets** menu in the top bar.

The **Theme** dropdown on the home screen and at the top of both `demo.tscn` and `sim.tscn` selects **Default theme**,
**Sci-fi theme**, or **Medieval theme** (the dark preset of each family). It is also available on
the simulation's Start and completion screens. Colours, frames and icons change together;
the Themes & icons example compares the selected family's dark and light variants.

Changing themes rebuilds the displayed controls, resetting their sample values. Explore stays
on the same widget. A playing tour restarts its current chapter with the new look, keeping speed
and pause state. Opening the dropdown temporarily pauses the bot; dismissing it resumes its
previous state. The choice lasts for the current run and does not edit project settings.

All display text and built-in widget actions use English. The chapters cover HUD bars and
slots, button styles, inputs, selection and menus, lists and accordions, data display,
notices, dialogs and sheets, prompt cards, all three joystick modes, coach marks, scrolling
and grids, forms, HUD anchors, themes and icons, container opacity, **waiting and counting**
(a button that becomes a spinner, a snackbar you can undo, unread badges, key caps),
**fields and pickers** (an error that lands on the row that is wrong, welded input groups, a
combobox that searches inside names, coupon cells) and **shapes games use** (daily attendance,
the stat pentagon with a dashed comparison, a damage-share ring with a written legend, and a
banner carousel that never advances on its own), **inventory and items** (a bag grid with each item in
its own colour, icon segments as a filter, the detail card, a tap route to move an item, and the game
icon set), **popovers, menus and drawers** (a detail card beside the button, a right-click menu, a side
drawer and the cheat console), **tables and pages** (a leaderboard that sorts numbers as numbers, page
buttons, and a server list in a sheet taller than the default ceiling with the pick marked by a border)
and **pick by picture** (colour swatches, choice cards, icon segments in a pill over a map, and HUD icon
buttons that never keep keyboard focus). The **Live activity**
panel reports actual widget callbacks, whether the bot or a person triggered them.

## Container opacity

Panels are translucent by default: 80% of the fill, with text, icons, borders and buttons left
at full strength. Three places in this repository let you drag the value and watch it land:

| Where | What it shows |
|---|---|
| **Home → Try it right here → SEEING THROUGH PANELS** | The home screen already draws a patterned backdrop, so lowering the value shows the grid and glow through the cards. **Apply to every panel** writes `GoConfig.container_alpha` and rebuilds the screen, so lists, notices and floating panels all follow. |
| **Guided tour → Container opacity** (chapter 16) | The bot drags the value down, states that the floor is not a target, and drags it back. It asserts the value reached the panel itself, not just the slider handle. |
| **Widget gallery → Container opacity** | The same lab, plus a **Busy background** toggle that puts a pattern behind the whole screen — the closest thing here to a HUD sitting over a game. |
| **Medieval look** | The same lab on a custom-drawn face (`GoStyleBoxMedieval`): the iron fill thins out while rivets, bevels and grain keep their strength. |

All four host the same widget, `examples/gallery/opacity_lab.gd`, which shows the four ways to
set the value side by side — a factory argument, restyling a node in place, `GoStyle.fade_panel()`
on a panel the add-on did not create, and the project-wide setting.

## Presentation and recording

Desktop windows use a reference canvas, so enlarging the window enlarges the text and
controls together. Narrow windows show a responsive single-column stage.

- **Cinema** or **C**: hide the side panels and playback toolbar during the simulation.
  Enabling Cinema on the Start screen adds a three-second countdown.
- **F11**: toggle fullscreen.
- **Space**, or the top-bar play button: pause or resume the tour. While exploring, play the
  current widget — on narrow windows, where the right panel is hidden, the top-bar button is the way.
- **Left / Right**: previous or next chapter, or previous or next widget while exploring.
- **Escape**: stop and return to the Start screen.
- The speed button cycles playback speeds. The Start screen offers Slow, Normal and Fast.
- While a text field has focus in explore mode, Space and the arrows go to the field.

To record a complete 1920×1080, 60 fps movie with Godot's Movie Maker:

```bash
bash examples/demo/run.sh --record /tmp/gohud-demo.avi
# OGV output is also supported. Override frame rate with DEMO_FPS=30.
```

Recording explicitly enables automatic Start, Cinema mode, the countdown and exit after
the tour. Ordinary launches always wait for Start. Video encoding may run slower than real
time; the saved movie uses a fixed frame rate. A dedicated recording viewport keeps the output at 1080p even on smaller displays.
See [Godot's Movie Maker documentation](https://docs.godotengine.org/en/stable/tutorials/animation/creating_movies.html).

For an on-screen recording preview or a still image:

```bash
bash examples/demo/run.sh -- --auto --cinema --exit
bash examples/demo/run.sh --shot /tmp/gohud-home.png                   # the home screen
SHOT_SCENE=res://sim.tscn bash examples/demo/run.sh --shot /tmp/gohud-start.png
bash examples/demo/run.sh --shot /tmp/gohud-hud.png -- --explore=hud   # one widget, explore mode
bash examples/demo/run.sh -- --explore=surfaces                          # open the app on a widget
```

`--explore=<key>` takes a chapter key: `hud`, `buttons`, `inputs`, `selection`, `lists`, `data`,
`states`, `surfaces`, `prompt`, `touch`, `coach`, `scrolling`, `forms`, `anchors`, `theming`,
`opacity`, `waiting`, `fields`, `shapes`, `inventory`, `overlays`, `records`, `choices`.

## Showreel

The tour takes minutes and shows one look at a time. The **showreel** is the trailer: in
**20 seconds** it walks the same chapters at **one widget every half second**, and every step
wears a different theme — default, sci-fi, medieval — so a short clip says "the same widgets,
three looks" without a word. The bot drives each widget for the half second it is up, so
bars fill, slots cool down, menus open and the cursor really presses; the caption under the
stage names the widget and shows the last callback it fired. It is the home screen's fifth
card (`5`), and `--open=showreel` opens it directly.

```bash
bash examples/demo/run.sh --record-showreel /tmp/gohud-showreel.avi    # 1920×1080 · 60 fps · 20 s, then quits
bash examples/demo/run.sh -- --open=showreel                           # watch it in a window; Replay at the end
bash examples/demo/run.sh --record-showreel /tmp/reel.avi --showreel-seconds=28.5 --showreel-order=random
```

| Argument | Default | Meaning |
|---|---|---|
| `--showreel-seconds=` | `20` | How long the whole reel runs |
| `--showreel-step=` | `0.5` | How long each widget stays up — the bot's speed follows it (6× at 0.5 s) |
| `--showreel-order=` | `cycle` | `cycle` walks the 23 chapters in order and rotates the three themes each step — no chapter–theme pair repeats before 69 steps, so 34.5 s shows every widget in every look (keep the chapter count off multiples of three, or each chapter wears one look only); `random` shuffles the chapters (each one once per round) and picks a theme that differs from the one before |
| `--showreel-seed=` | `0` | Fixes the random order; `0` draws a fresh one each run |
| `--exit` | off | Quit when the reel ends — `--record-showreel` passes it; without it a Replay card is shown |

Everything on the reel comes from the tour: the chapters are `SimActs`, the stage is `SimStage`,
the hand is `SimBot`, and the theme changes through the same `ThemePicker`. Widgets keep the theme
they were built with, so each step tears the stage down and builds the next one under its preset.
The picture is a 1280×720 logical canvas, letterboxed in other window shapes, which a 1080p movie
scales by exactly 1.5. `tests/showreel_test.gd` (run by `tools/check_demo.sh`) checks the pacing,
the theme per step, the callbacks, the clean end, Replay, and tearing the scene down mid-run.

## Languages

`demo.tscn` ends with a card that prints the built-in strings in all 21 languages at once.
It is there to answer two questions at a glance:

1. **Is the translation attached?** A raw key (`gohud_confirm`) means the `.translation`
   resource never loaded.
2. **Does the glyph draw?** the bundled medieval heading font does not cover every script, so Thai, Arabic, Hebrew, Devanagari and CJK
   are drawn by *your* theme font — or by the OS fallback when you have none. A missing glyph
   shows as an empty box and raises no error, which is exactly why the card exists.

```bash
bash examples/demo/run.sh --languages                      # headless check, no window
bash examples/demo/run.sh --shot-languages /tmp/langs.png  # capture the card
```

The headless check measures glyphs the way the screen does — through `TextServer`, not
`Font.has_char`. `has_char` ignores the system font fallback, so it reports Thai and CJK as
missing while they render perfectly.

## Verification

```bash
bash tools/check_demo.sh
# Optional: render chapter screenshots and verify interactions.
bash examples/demo/run.sh -- --auto --turbo --verify --trace --exit --shots=/tmp/gohud-shots
```

The integration check runs the entire tour at desktop, small landscape and portrait sizes, verifies actual
widget outcomes, then tests pause, navigation, cancellation and repeated restarts. It then exercises
explore mode: opening widgets from the Start screen and the sidebar, clicking a dialog by hand, playing a
single widget, keyboard navigation, folding a running tour, and leaving a full-screen chapter through
**Back to widgets**. A timeout, engine error, failed assertion or missing completion marker makes the
command fail.
`--shots` is ignored in headless mode because there is no rendered image to save.

## Add-on link

`addons/gohud` is a symlink to `../../..`, the add-on root, so the demo always runs the same
source code as the add-on. The nested demo is excluded from recursive scanning. The link is not
checked in; `main.gd` makes it on first run, and `bash examples/demo/run.sh --setup` makes the
same one without launching anything.

`main.tscn` is the main scene. It carries no gohud class name on purpose: with the link or the
import cache missing those names do not parse, and a main scene that cannot parse leaves an
empty window and one `Identifier "GoUi" not declared` line. The doorway stays up in that state,
which is how it can explain itself and repair the folder.

`sim.tscn` (the tour), `demo.tscn` (the card overview plus the language card), and the gallery
and medieval scenes under `addons/gohud/examples` all still open on their own.

## Adding a chapter

Each chapter in `sim_acts.gd` is a pair of functions: `build_<key>(stage, bot)` constructs the
screen and returns the nodes the bot needs, and `play_<key>(stage, bot, refs)` drives them with
real input. Explore mode calls only `build_`, so a chapter must be complete without the bot:
anything only the bot used to trigger (data arriving, a tour starting) is a button the person can
press too. Add the chapter **at the end** of `SimActs.list()` with a title, note, icon and explore hint —
`tests/sim_test.gd` opens chapters by number, and the showreel pairs chapter *N* with theme *N* % 3.
A chapter whose point is visual rather than behavioural should assert what the screen actually
received — chapter 16 reads the panel's own fill alpha, because a slider handle can move while
the panel stays exactly as it was.
