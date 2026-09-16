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
`home.tscn`. The home screen is built from nothing but gohud widgets, and offers four ways in.

| Key | Screen | Source |
|---|---|---|
| `1` | **Widget gallery** — every widget on one page | `examples/gallery/gallery.gd` |
| `2` | **Guided tour** — 15 chapters, played or hands-on | `examples/demo/sim.gd` |
| `3` | **Showcase screen** — six cards on one screen | `examples/demo/demo.gd` |
| `4` | **Medieval look** — the same widgets, another preset | `examples/medieval/medieval.gd` |

Under those rows the home screen puts the kit itself within reach: one card of live widgets
(button tones, an HP bar with a slider, a toggle, a segmented control, quick slots, a notice, a
dialog, a bottom sheet, a prompt card and a coach-mark tour), and then one small card per class
carrying a one-line description and the line of code that uses it.

The screen you pick opens inside the same window, with a bar across the top naming it and the
file it lives in; **Home** goes back. To skip the home screen entirely:

```bash
godot -- --open=gallery      # gallery | tour | showcase | medieval
```

## Guided tour

The tour waits on its Start screen and offers two ways in:

- **Start demo** plays a guided simulation of 15 chapters. The cursor uses real mouse and
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
and grids, forms, HUD anchors, and themes and icons. The **Live activity** panel reports
actual widget callbacks, whether the bot or a person triggered them.

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
`states`, `surfaces`, `prompt`, `touch`, `coach`, `scrolling`, `forms`, `anchors`, `theming`.

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
press too. Add the chapter to `SimActs.list()` with a title, note, icon and explore hint.
