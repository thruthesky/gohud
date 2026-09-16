---
description: Update gohud — the add-on in this project and this skill — then verify the two agree
argument-hint: "[optional: addon | skill | check]"
allowed-tools: Read, Bash, Edit
---

Update gohud. Scope: `$ARGUMENTS` (empty = both the add-on and the skill).

Read `references/setup.md` §7 for the full table of install kinds — use the first path that exists:

```
${CLAUDE_PLUGIN_ROOT}/skills/gohud/references/setup.md
~/.claude/skills/gohud/references/setup.md
.claude/skills/gohud/references/setup.md
.agents/skills/gohud/references/setup.md
```

## 0. Scope

| Argument | Do |
|---|---|
| *(empty)* | §1 → §2 → §3 → §4 |
| `addon` | §1 → §2 → §4 |
| `skill` | §3 → §4 |
| `check` | §1 and §4 only — report versions and whether they agree, change nothing |

## 1. Find out what is installed — before touching anything

```bash
test -f addons/gohud/plugin.cfg && grep -m1 '^version=' addons/gohud/plugin.cfg
git -C addons/gohud rev-parse --short HEAD 2>/dev/null || echo "(not a git checkout)"
git config --file .gitmodules --get-regexp 'addons/gohud' 2>/dev/null || echo "(not a submodule)"
git -C addons/gohud status --short 2>/dev/null | head
```

Report the four answers before going on. **If the fourth shows local modifications, stop and ask** — an
update overwrites them. Offer `git -C addons/gohud diff > /tmp/gohud-local.patch` first.

🛑 If `addons/gohud/plugin.cfg` does not exist, this is an **install**, not an update — go to setup.md §1.

## 2. Update the add-on

Pick the row in setup.md §7.2 that matches what §1 found. Rules that are not negotiable:

- **A plain copy or ZIP install replaces the whole folder.** Confirm with the user first, and only after §1
  showed a clean tree.
- **A submodule needs the pointer committed** in the parent repository afterwards (`git add addons/gohud`),
  or the next clone gets the old version.
- **Never merge the user's edits back into `addons/gohud/`.** If §1 found local changes, move them to a
  supported seam instead — `GoConfig`, `color_overrides`, a project-local `GoThemePreset`, a `GoSkin`
  subclass, or the subclass hooks (surfaces.md §6).

Then, always:

```bash
godot --headless --path . --import
```

Without this the new `class_name` globals are not registered and every script that mentions them fails with
"Identifier not declared" — which looks like a broken update but is only a missing import.

## 3. Update the skill

Pick the row in setup.md §7.3. The repository copy `addons/gohud/skills/gohud/` is the source of truth; the
plugin and any `~/.claude/skills/gohud/` copy are built from it.

- Installed as a Claude Code plugin → `/plugin update gohud` (tell the user to run it; you cannot).
- Installed as a personal or project skill and the add-on is a git checkout → copy from
  `addons/gohud/skills/gohud/` over it.

## 4. Verify, then report

```bash
grep -m1 '^version=' addons/gohud/plugin.cfg
grep -m1 'Version described' <skill>/references/features.md
godot --headless --path . -s res://addons/gohud/tests/gohud_test.gd 2>&1 | tail -1
godot --headless --path . -s res://addons/gohud/tests/gohud_extra_test.gd 2>&1 | tail -1
```

Both test lines must end `N/N passed`. The last two files exist only in a git checkout — skip them for a
ZIP install and say so.

Report:

- The version before and after, for **both** the add-on and the skill.
- What `CHANGELOG.md` lists above the previous version — especially anything under **Changed** (breaking).
- Whether the checks pass.
- Anything the user must still do themselves (`/plugin update gohud`, committing a submodule pointer,
  re-applying edits that were moved out of `addons/gohud/`).

🛑 If the skill mentions classes the add-on does not have, say which — that gap is what makes an agent
recommend an API the project cannot run.

Reply in the language the user writes in.
