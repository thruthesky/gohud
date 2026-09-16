# gohud documentation

The site lives in [`www/`](../www/index.html) at the repository root. English is the default; sixteen more
languages sit in their own folders (`www/ko/`, `www/ja/`, …) — the list is [`tools/site_langs.py`](../tools/site_langs.py).

Every language has the **same five pages**, listed in `PAGES` in that same file:

| Page | What it holds |
|---|---|
| `index.html` | Overview — showcase, what it takes off your hands, presets, skins, a widget summary, and signposts to install / quick start / AI skill |
| `install.html` | The AI-skill card first, then install, quick start, examples, and the repository's own checks |
| `ai.html` | AI SKILL — the block to paste into a coding agent, where each agent keeps skills, the commands, and "or just ask" |
| `widgets.html` | Widget reference |
| `theming.html` | Themes, tokens, skins and readability |

The three original names never change — released ZIPs link to them absolutely (see
[`tools/build_site.sh`](../tools/build_site.sh)); pages are only ever **added**.

Definitions are available by hovering, tapping or focusing a technical term. Escape closes
a definition; Tab reaches its reference link. The glossary button controls term underlines.

## What is generated, and from where

Do not hand-edit these — run `python3 tools/make_site.py`:

| Generated | Source of truth |
|---|---|
| The header menu on all 85 pages | [`tools/site_nav.py`](../tools/site_nav.py) — labels per language, and the four rules for what may appear there |
| `ai.html` in all 17 languages | [`tools/site_ai_text.py`](../tools/site_ai_text.py) + [`tools/make_ai_page.py`](../tools/make_ai_page.py) |
| Language picker, `hreflang`, heading anchors, script tags | `tools/make_site.py` |
| The dial tables in `theming.html` | the skin scripts' `@export` lines |
| Glossary and search index | `tools/make_site.py`, `tools/make_search.py` |

## GitHub Pages

Public entry: **https://thruthesky.github.io/gohud/** — `www/index.html` is the top of the site.

Repository settings: **Pages → Build and deployment → Source → GitHub Actions**.
"Deploy from a branch" can only publish `/` (root) or `/docs`, which is why a workflow is needed.
[`.github/workflows/pages.yml`](../.github/workflows/pages.yml) runs [`tools/build_site.sh`](../tools/build_site.sh)
and uploads the result: the contents of `www/` become the site root, so `www/theming.html` is served at
`/gohud/theming.html` and `www/ko/` at `/gohud/ko/`.

The workflow runs on pushes to `main` that change `www/**`, `tools/build_site.sh` or the workflow itself, and can
be started by hand from **Actions → Pages → Run workflow**. Dotfiles in `www/` (such as `.gdignore`) are not
uploaded, and no Jekyll step runs.

### Old addresses

The site moved here from `docs/www/` on 2026-09-15. Addresses already published elsewhere keep working:

- **Pages** — `www/404.html` forwards `/gohud/docs/www/…`, and the earlier `/gohud/docs/…` and
  `/gohud/docs/ko/…`, to the same page at its new address.
- **Images** — a 404 page cannot forward an `<img>` request, and the READMEs inside released ZIPs (1.0.2 and
  1.0.3) load `/gohud/docs/www/img/…`. `tools/build_site.sh` therefore places a second copy of `www/img/` at
  `docs/www/img/` in the deployed site only. New links use `/gohud/img/…`.

`check_site.py` builds the site with the same script and fails when an old image address, or a public address
written anywhere in this repository (READMEs, skills, the store description), is missing from the result.

Keep `examples/demo/addons/gohud` out of Git: it points back to the add-on root and previously
caused the branch-based Pages build to fail with “Too many levels of symbolic links”. The demo's
`run.sh --setup` creates this ignored link locally when needed.

## Editing and checking

From the add-on root:

```bash
python3 tools/make_site.py                 # refresh glossary entries and skin-dial tables
python3 tools/check_site.py                # links, generated content, the deployed layout and public addresses
python3 -m http.server 8765 -d www         # quick preview: http://localhost:8765/
bash tools/build_site.sh /tmp/gohud-site   # exactly what is uploaded, old image addresses included
```

Edit the six HTML pages and `www/site/style.css` directly. Edit glossary definitions in
`tools/make_site.py` or the source class comments, then regenerate; the files named
`glossary*.js` and the marked dial-table sections are generated. Validation uses a temporary
copy and leaves the source unchanged. No package installation or external frontend service
is required.

After validation, commit the changes and push `main`; the Pages workflow deploys the site automatically.

References: [GitHub Pages publishing sources](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site),
[Godot 4.6 DPITexture API](https://docs.godotengine.org/en/4.6/classes/class_dpitexture.html).
