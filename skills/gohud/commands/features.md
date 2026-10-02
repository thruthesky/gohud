---
description: Explain everything gohud can do — grouped, one line of code per feature, with links to the details
argument-hint: "[optional area: surfaces | hud | style | layout | app | flutter | theming | icons | i18n | accessibility | config]"
allowed-tools: Read
---

Explain gohud's features. Optional focus area: `$ARGUMENTS`.

## 1. Read the catalogue

Use the first path that exists:

```
${CLAUDE_PLUGIN_ROOT}/skills/gohud/references/features.md
~/.claude/skills/gohud/references/features.md
.claude/skills/gohud/references/features.md
.agents/skills/gohud/references/features.md
```

## 2. Go deeper when an area is named

| Area | Also read (same `references/` folder) |
|---|---|
| surfaces, dialogs, sheets, forms, windows | `surfaces.md` |
| hud, bars, slots, joystick, notices, prompts, tour, badges, charts, carousel, summon column | `hud.md` |
| style, buttons, inputs, lists, tables, factory | `style.md` |
| layout, edge bars, side bars, grid | `style.md` §1 "Layout classes" (and `hud.md` §19) |
| app screens, navigation bar, app bar, FAB, search, dates | `hud.md` §16 |
| flutter, scaffold, list view, refresh, swipe, tabs, pickers, stepper | `flutter.md` |
| every class by name, "is there a widget for …" | `catalog.md` |
| theming, presets, themes, skins, colours | `theming.md` |
| icons, i18n, languages, sound, haptics, accessibility, safe area | `platform.md` |
| config, install, plugin, setup | `setup.md` |
| menus, screens, examples, recipes | `recipes.md` |

## 3. Answer

- Without an area: present the twelve groups of the catalogue (§1–§12 of `features.md`) as short tables — feature,
  one line of code.
- With an area: explain that area fully with the real signatures and one runnable snippet.
- End with how to see it live: `/gohud:preview` (gallery), `/gohud:preview demo --explore <chapter>`, and the
  site https://thruthesky.github.io/gohud/.
- Do not invent APIs; everything you name must appear in the references.
- Reply in the language the user writes in.
