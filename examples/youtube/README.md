# gohud YouTube reel

A separate Godot project that shows **every gohud theme with fifteen widgets each**, made to be recorded for YouTube
at **1920×1080**. It is not part of the add-on: the release ZIP leaves `examples/youtube/` out (`tools/package.sh`).

Each theme gets five seconds — its name across the top, then five pages of three widgets, one second a page:

| Seconds | On screen |
| --- | --- |
| 0 – 2 | Intro card |
| 5 per theme | Theme name, dark or light, then 5 × 3 widgets |
| last 2.5 | Closing card |

All presets in `themes/presets/` are shown (fourteen today: Default, Sci-fi, Medieval, Material, Arcade, Comic and
Kids, each dark and light — 74.5 seconds in all), so a new theme joins the reel with no code change. Dark presets show
one set of fifteen widgets (bars, buttons, quick slots, settings, choices, alerts, radar, text fields, chips, joystick,
wheel picker, split button and combobox, spinner and empty state, folding sections, key hints) and light presets
another (donut, list rows, progress, inventory, prompts, navigation, leaderboard, ranges and codes, daily rewards,
app bar, stepper, tab view, reorder and swipe rows, swatches, date picker), so a family shows thirty.

```bash
bash examples/youtube/run.sh                          # watch it in a 1920×1080 window (it loops)
bash examples/youtube/run.sh --record /tmp/reel.avi   # 1920×1080 · 60 fps movie, then quit (REEL_FPS=30 to change)
bash examples/youtube/run.sh -- --themes=arcade_dark,kids_light   # only these presets
ffmpeg -i /tmp/reel.avi -c:v libx264 -crf 18 -pix_fmt yuv420p -movflags +faststart reel.mp4   # for upload
```

`run.sh` links `addons/gohud` to the repository root (the link is not committed) and imports before it runs.
The canvas is 1280×720 logical, so 1920×1080 is a clean 1.5×.
