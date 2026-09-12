# Changelog

All notable changes to gohud are recorded here. Versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

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

### Fixed

- `GoIconButton` texture icons are centred explicitly (`icon_alignment` / `vertical_icon_alignment`). `Button`
  defaults to left alignment, which showed as soon as a texture was drawn without `expand_icon`.
- `GoNotice.set_content()` also sets `mouse_filter = IGNORE` on the whole content subtree.
  `mouse_behavior_recursive` already blocked input, but code that reads `mouse_filter` (layout logic, host tests)
  saw stale values.

## [1.0.0] — 2026-09-12

First version. Rebuilt from a production game's shared UX layer into a standalone add-on that
depends on nothing outside `addons/gohud/`.

### Added

- **`examples/demo/`** — a complete screen built from the add-on alone (HUD bars, quick slots, buttons,
  dialogs, sheets, notices, touch controls, both themes). A regular Godot project: `cd examples/demo && godot`.
  It sees the add-on through a symlink `addons/gohud → ../../..`; a `.gdignore` there stops the host project
  from scanning the demo. ZIP installs get the link from `run.sh --setup`.
- **`GoConfig`** — one settings resource for appearance, responsive breakpoints, surface behaviour,
  sound/haptic feedback, localization and accessibility. Every field has a working default.
- **`GoIconSet`** — swappable icon sets: SVG/PNG textures, icon fonts with codepoints, and partial
  overrides through `fallback`. Ships 84 original MIT icons imported as `DPITexture`.
- **Themes** — dark (default) and light, sharing the `GoHud` token type and 14 type variations.
  `tools/make_theme.py` regenerates both from a palette.
- **Widgets** — `GoSurface`, `GoSheet`, `GoDialogs`, `GoForm`, `GoScroll`, `GoNotice`,
  `GoPromptCard`, `GoCoachMark`, `GoHudAnchor`, `GoBar`, `GoSlot`, `GoJoystick`, `GoIconButton`.
- **`GoStyle`** factories — buttons, labels, list rows, inputs, chips, cards, wrap rows with
  last-line alignment, responsive grids, `FoldableContainer` sections and empty states.
- **`GoRuntime`** optional autoload — breakpoint and keyboard events, optional 1 unit = 1 dp scaling.
  **`GoScale`** exposes the underlying pure functions.
- **`GoFeedback`** — routes UI sound cues to your audio system and plays three haptic strengths on
  Android/iOS. No audio is bundled.
- Built-in strings in 11 languages.
- Accessibility: 48 dp touch targets with smaller visuals, `accessibility_name` on icon-only buttons,
  `reduce_motion`, focus rings only for keyboard/gamepad users.
- Gallery example, headless test suite, empty-project check, screenshot runner and release packager.
