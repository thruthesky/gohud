# Changelog

All notable changes to gohud are recorded here. Versions follow [Semantic Versioning](https://semver.org/).

## [1.0.0] — 2026-09-12

First version. Extracted from the Laryen 3D shared UX layer and rebuilt as a standalone add-on that
depends on nothing outside `addons/gohud/`.

### Added

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
