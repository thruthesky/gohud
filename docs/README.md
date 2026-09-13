# gohud documentation

The site lives in [`www/`](www/index.html). English is the default; Korean is available at
[`www/ko/`](www/ko/index.html). Both languages include overview, theming and widget pages,
with definitions available by hovering, tapping or focusing a technical term. Escape closes
a definition; Tab reaches its reference link. The glossary button controls term underlines.

## GitHub Pages

Public entry: **https://thruthesky.github.io/gohud/**

Repository settings: **Pages → Deploy from a branch → main → / (root)**.
The root `index.html` opens `docs/www/` in English and preserves section links.
The root `.nojekyll` serves the static files without Jekyll processing.
The older `docs/*.html` and `docs/ko/*.html` addresses redirect to the corresponding pages.

Keep `examples/demo/addons/gohud` out of Git: it points back to the add-on root and previously
caused the Pages build to fail with “Too many levels of symbolic links”. The demo's
`run.sh --setup` creates this ignored link locally when needed.

## Editing and checking

From the add-on root:

```bash
python3 tools/make_site.py      # refresh glossary entries and skin-dial tables
python3 tools/check_site.py     # links, sections, language, CSS and generated content
python3 -m http.server 8765     # open http://localhost:8765/
```

Edit the six HTML pages and `www/site/style.css` directly. Edit glossary definitions in
`tools/make_site.py` or the source class comments, then regenerate; the files named
`glossary*.js` and the marked dial-table sections are generated. Validation uses a temporary
copy and leaves the source unchanged. No package installation or external frontend service
is required.

After validation, commit the changes and push `main`; the configured Pages deployment runs
automatically. Its source remains **main / (root)**.

References: [GitHub Pages publishing sources](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site),
[Godot 4.6 DPITexture API](https://docs.godotengine.org/en/4.6/classes/class_dpitexture.html).
