/* gohud site — the left-hand table of contents (sidebar).
 *
 * Keeps **where you are reading right now always in sight**. The table of contents and splitting
 * pages up do not stand in for each other.
 *
 * 🔑 On 2026-09-16, by human instruction, the front door was split into **five pages**
 *   (index · install · ai · widgets · theming), and later the same day split again **by section**
 *   (`tools/split_site.py` — widgets cover + 8 · theming cover + 6, so 19 pages × 17 languages).
 *   The section translations were carried over as they stood and split by machine, so no new
 *   translation went in anywhere.
 *
 * 🛑 **This spot used to read "no splitting further by section — from here on this table of contents
 *   takes over."** On the strength of that one line and the same words in `tools/site_nav.py`, the
 *   human's request to **"break the docs into smaller pieces" was repeatedly treated as 'already
 *   decided'.** The table of contents and splitting do not stand in for each other — the table of
 *   contents guides you **inside** one page, splitting shrinks the page **itself**. On a single
 *   40 KB page you had to scroll past the other thirty-one things to see the one you came for.
 *
 * ## What shows up in the sidebar — two layers
 * 1. **The pages of this group** — the document's own `<nav class="subnav">` (put there by the
 *    splitter) is lifted to the top as it is. Its labels are already in that language, so there is
 *    no translation to keep here.
 * 2. **This page's contents** — `items` below. Same as before.
 *
 * ## Why it is built this way
 * - The table of contents is built **by reading the page's own headings**. That way no translated
 *   text has to be added to the 17 language editions. Heading ids are stamped in English by
 *   `tools/make_site.py`, so the address stays the same whatever the language.
 * - The CSS is injected by this file itself (following `site/tooltip.js`). `site/style.css` is left
 *   alone.
 * - 🛑 No `fetch()` — `tools/site_shots.sh` opens the pages over `file://`, so it would work in the
 *   browser and die silently only in the screenshot check. Everything needed is already inside the
 *   document.
 * - 🛑 The bottom right of the screen is taken by the glossary button (`#glbtn`). On a narrow screen
 *   the table-of-contents button goes **bottom left**.
 * - 🛑 `tooltip.js` grabs Escape, Enter, Space and Tab on a global keydown. In the filter input we
 *   stop key events so letters do not get eaten by the wrong thing.
 */
(function () {
  'use strict';

  var main = document.querySelector('main');
  if (!main) return;

  // ── Words the sidebar uses ─────────────────────────────────
  // 🔑 Kept here in one place and picked by the document's `<html lang>`. That way the table of
  //    contents comes up in the reader's language without putting anything into the 51 translated
  //    pages. An unknown language falls back to English.
  var SAY = {
    'en': { title: 'On this page', filter: 'Filter', search: 'Search all pages' },
    'ko': { title: '이 페이지 차례', filter: '필터', search: '문서 전체 검색' },
    'ja': { title: 'このページの目次', filter: '絞り込み', search: '全ページを検索' },
    'zh-Hans': { title: '本页目录', filter: '筛选', search: '搜索全部页面' },
    'zh-Hant': { title: '本頁目錄', filter: '篩選', search: '搜尋全部頁面' },
    'es': { title: 'En esta página', filter: 'Filtrar', search: 'Buscar en todo' },
    'pt': { title: 'Nesta página', filter: 'Filtrar', search: 'Buscar em tudo' },
    'ru': { title: 'На этой странице', filter: 'Фильтр', search: 'Искать везде' },
    'fr': { title: 'Sur cette page', filter: 'Filtrer', search: 'Chercher partout' },
    'tr': { title: 'Bu sayfada', filter: 'Süz', search: 'Tümünde ara' },
    'pl': { title: 'Na tej stronie', filter: 'Filtruj', search: 'Szukaj wszędzie' },
    'it': { title: 'In questa pagina', filter: 'Filtra', search: 'Cerca ovunque' },
    'vi': { title: 'Trong trang này', filter: 'Lọc', search: 'Tìm toàn bộ' },
    'id': { title: 'Di halaman ini', filter: 'Saring', search: 'Cari semua' },
    'uk': { title: 'На цій сторінці', filter: 'Фільтр', search: 'Шукати всюди' },
    'th': { title: 'ในหน้านี้', filter: 'กรอง', search: 'ค้นหาทุกหน้า' },
    'ar': { title: 'في هذه الصفحة', filter: 'تصفية', search: 'ابحث في كل الصفحات' }
  };
  var lang = document.documentElement.lang || 'en';
  var say = SAY[lang] || SAY[lang.split('-')[0]] || SAY.en;

  // ── What the table of contents is made of ──────────────────
  // Only sections (`<section id>`) and the subheadings inside them (`h3[id]`). 🛑 An h3 inside a
  // card is left out — the eight cards of the `#what` section are a list, not sections, and putting
  // them in makes the table of contents as long as the page itself.
  var items = [];
  main.querySelectorAll('section[id]').forEach(function (sec) {
    var h2 = sec.querySelector('h2');
    if (!h2) return;
    items.push({ id: sec.id, text: h2.textContent.trim(), sub: false, el: sec });
    sec.querySelectorAll('h3[id]').forEach(function (h3) {
      if (h3.closest('.card')) return;
      items.push({ id: h3.id, text: h3.textContent.trim(), sub: true, el: h3 });
    });
  });
  // 🔑 The list of this group's pages, put there by the splitter (`tools/split_site.py`). Absent means an unsplit page.
  var groupNav = main.querySelector('nav.subnav');

  // 🛑 A split page has only one or two sections — but dropping the table of contents for that
  //    takes **the group list down with it**, leaving the header as the only way across to the next
  //    page. If there is a group, show it whatever the section count.
  if (items.length < 3 && !groupNav) return;

  // Take the header's page links (the way to the other chapters) as they are — the translation is already in them.
  var pageLinks = [];
  document.querySelectorAll('header.top nav a').forEach(function (a) {
    var href = a.getAttribute('href') || '';
    if (a.closest('.langs')) return;
    if (/^https?:|^#|^mailto:/.test(href)) return;
    if (!/\.html$|^\.\/$|^\.\.\/$/.test(href)) return;
    pageLinks.push({ href: href, text: a.textContent.replace(/\s*↗\s*$/, '').trim() });
  });

  // ── Looks ─────────────────────────────────────────────────
  // The colors come straight from style.css variables — light and dark follow on their own.
  var W = '264px', HEAD = '58px';
  var css = document.createElement('style');
  css.textContent = [
    '.gotoc{position:fixed;inset-block-start:' + HEAD + ';inset-inline-start:0;width:' + W + ';',
    '  height:calc(100vh - ' + HEAD + ');overflow-y:auto;overscroll-behavior:contain;z-index:40;',
    '  padding:16px 12px 48px;background:var(--bg-2,#EDF2F7);',
    '  border-inline-end:1px solid var(--rule,#DCE3EA);font-size:13.5px;line-height:1.5}',
    '.gotoc-title{font-weight:700;font-size:12px;letter-spacing:.06em;text-transform:uppercase;',
    '  color:var(--muted,#5B6B7B);padding:0 8px 10px}',
    '.gotoc-find{width:100%;padding:7px 10px;margin-bottom:10px;border-radius:8px;font:inherit;',
    '  border:1px solid var(--rule,#DCE3EA);background:var(--card,#fff);color:var(--ink,#16202B)}',
    '.gotoc-find:focus{outline:2px solid var(--accent,#0878AE);outline-offset:1px}',
    '.gotoc a{display:block;padding:5px 9px;border-radius:7px;text-decoration:none;',
    '  color:var(--muted,#5B6B7B);border-inline-start:2px solid transparent}',
    '.gotoc a:hover{color:var(--accent,#0878AE);background:color-mix(in srgb,var(--accent,#0878AE) 9%,transparent)}',
    '.gotoc a.sub{padding-inline-start:20px;font-size:13px}',
    '.gotoc a.on{color:var(--accent,#0878AE);font-weight:700;',
    '  border-inline-start-color:var(--accent,#0878AE);background:color-mix(in srgb,var(--accent,#0878AE) 10%,transparent)}',
    '.gotoc a[hidden]{display:none}',
    '.gotoc-all,.gotoc-none{display:block;width:100%;text-align:start;font:inherit;font-size:13px;',
    '  padding:7px 10px;margin-bottom:10px;border-radius:8px;cursor:pointer;',
    '  border:1px dashed var(--rule,#DCE3EA);background:none;color:var(--muted,#5B6B7B)}',
    '.gotoc-all:hover,.gotoc-none:hover{border-color:var(--accent,#0878AE);color:var(--accent,#0878AE);',
    '  border-style:solid}',
    '.gotoc-none{margin-top:6px;border-style:solid}',
    '.gotoc-pages{margin-top:16px;padding-top:12px;border-top:1px solid var(--rule,#DCE3EA)}',
    '.gotoc-pages a{font-weight:600;color:var(--ink,#16202B)}',
    'body.gotoc-on{padding-inline-start:' + W + '}',
    /* 🔑 Only the header is pulled back across the table of contents — the logo stands at the very
       top left and the table of contents tucks in below it, so no meaningless gap opens up at the
       top left (in the 2026-09-16 screenshot 264px sat empty). */
    'body.gotoc-on header.top{margin-inline-start:-' + W + '}',
    'body.gotoc-on header.top .wrap{max-width:none}',
    /* 🛑 Once the table of contents is up, the header's section links are already there on the left
       — keeping both sets folds the header onto two lines and pushes the search box and the language
       picker out (screenshot, 2026-09-16). Hide them only when the table of contents is really up. */
    'body.gotoc-on header.top nav a[href^="#"]{display:none}',

    /* The little link beside a heading — so its address can be picked up on the spot. Shows on hover only. */
    '.gotoc-anchor{margin-inline-start:.4em;color:var(--muted,#5B6B7B);text-decoration:none;',
    '  opacity:0;font-weight:400;transition:opacity .12s}',
    'h2:hover>.gotoc-anchor,h3:hover>.gotoc-anchor,.gotoc-anchor:focus{opacity:.75}',

    /* Narrow screens — no room beside the text, so a button opens and closes it. 🛑 Bottom left (bottom right is the glossary button's spot). */
    '.gotoc-btn{display:none;position:fixed;inset-block-end:14px;inset-inline-start:14px;z-index:45;',
    '  padding:9px 14px;border-radius:999px;border:1px solid var(--rule,#DCE3EA);',
    '  background:var(--card,#fff);color:var(--ink,#16202B);font:inherit;font-size:13px;font-weight:600;',
    '  box-shadow:0 6px 20px -8px rgba(0,0,0,.35);cursor:pointer}',
    '@media (max-width:1079px){',
    '  body.gotoc-on{padding-inline-start:0}',
    '  body.gotoc-on header.top{margin-inline-start:0}',
    '  .gotoc-btn{display:block}',
    '  .gotoc{inset-block-start:0;height:100vh;width:min(320px,86vw);z-index:60;',
    '    box-shadow:0 0 40px -10px rgba(0,0,0,.4);transform:translateX(-110%);',
    '    transition:transform .18s;padding-top:20px}',
    '  [dir="rtl"] .gotoc{transform:translateX(110%)}',
    '  .gotoc.open{transform:none}',
    '  .gotoc-veil{position:fixed;inset:0;z-index:55;background:rgba(8,16,24,.45)}',
    '}',
    /* The group layer at the top of the sidebar — the way across to the other pages of this group. */
    '.gotoc-group{padding-bottom:12px;margin-bottom:14px;border-bottom:1px solid var(--rule,#DCE3EA)}',
    '.gotoc-group a{font-weight:600;color:var(--ink,#16202B)}',
    '.gotoc-group a[aria-current]{color:var(--accent,#0878AE);',
    '  border-inline-start-color:var(--accent,#0878AE);',
    '  background:color-mix(in srgb,var(--accent,#0878AE) 10%,transparent)}',

    /* 🔑 The same list at the top of the page body — this one shows even with JavaScript off. It is
       hidden once the table of contents is up (so the same list is not shown twice). On a narrow
       screen the table of contents folds away behind a button, so it comes back. */
    'main>nav.subnav{display:flex;flex-wrap:wrap;gap:8px;margin:0 0 26px;padding:0 0 18px;',
    '  border-bottom:1px solid var(--rule,#DCE3EA)}',
    'main>nav.subnav a{padding:6px 13px;border-radius:999px;text-decoration:none;font-size:14px;',
    '  border:1px solid var(--rule,#DCE3EA);color:var(--muted,#5B6B7B)}',
    'main>nav.subnav a:hover{border-color:var(--accent,#0878AE);color:var(--accent,#0878AE)}',
    'main>nav.subnav a[aria-current]{border-color:var(--accent,#0878AE);color:var(--accent,#0878AE);',
    '  font-weight:700}',
    'body.gotoc-on main>nav.subnav{display:none}',
    '@media (max-width:1079px){body.gotoc-on main>nav.subnav{display:flex}}',
    '@media (prefers-reduced-motion:reduce){.gotoc{transition:none}}'
  ].join('');
  document.head.appendChild(css);

  // ── Building the table of contents ─────────────────────────
  var nav = document.createElement('nav');
  nav.className = 'gotoc';
  nav.setAttribute('aria-label', say.title);

  // 🔑 This group's pages go on top — the title is the `subnav`'s `aria-label` (already in that language).
  if (groupNav) {
    var group = document.createElement('div');
    group.className = 'gotoc-group';
    var groupTitle = document.createElement('div');
    groupTitle.className = 'gotoc-title';
    groupTitle.textContent = groupNav.getAttribute('aria-label') || '';
    group.appendChild(groupTitle);
    groupNav.querySelectorAll('a').forEach(function (a) {
      var copy = document.createElement('a');
      copy.href = a.getAttribute('href');
      copy.textContent = a.textContent;
      if (a.hasAttribute('aria-current')) copy.setAttribute('aria-current', 'page');
      group.appendChild(copy);
    });
    nav.appendChild(group);
  }

  var title = document.createElement('div');
  title.className = 'gotoc-title';
  title.textContent = say.title;
  nav.appendChild(title);

  // 🔑 Hands anyone who cannot find it on this page over to the global search. `site/search.js` opens it.
  var all = document.createElement('button');
  all.className = 'gotoc-all';
  all.type = 'button';
  all.textContent = '\u2315 ' + say.search;
  all.addEventListener('click', function () { openSearch(find.value.trim()); });
  nav.appendChild(all);

  var find = document.createElement('input');
  find.className = 'gotoc-find';
  find.type = 'search';
  find.placeholder = say.filter;
  find.setAttribute('aria-label', say.filter);
  nav.appendChild(find);

  var list = document.createElement('div');
  nav.appendChild(list);

  var links = items.map(function (it) {
    var a = document.createElement('a');
    a.href = '#' + it.id;
    a.textContent = it.text;
    if (it.sub) a.className = 'sub';
    list.appendChild(a);
    return a;
  });

  var none = document.createElement('button');
  none.className = 'gotoc-none';
  none.type = 'button';
  none.hidden = true;
  none.addEventListener('click', function () { openSearch(find.value.trim()); });
  list.appendChild(none);

  function openSearch(word) {
    if (typeof window.GOHUD_SEARCH_OPEN === 'function') window.GOHUD_SEARCH_OPEN(word);
  }

  if (pageLinks.length) {
    var pages = document.createElement('div');
    pages.className = 'gotoc-pages';
    pageLinks.forEach(function (p) {
      var a = document.createElement('a');
      a.href = p.href;
      a.textContent = p.text;
      pages.appendChild(a);
    });
    nav.appendChild(pages);
  }

  document.body.appendChild(nav);
  document.body.classList.add('gotoc-on');

  // Hang an address link on every heading — so a spot can be sent to someone else while reading.
  main.querySelectorAll('section[id] > h2, h3[id]').forEach(function (h) {
    var id = h.tagName === 'H2' ? (h.parentNode.id || '') : h.id;
    if (!id || h.closest('.card')) return;
    var a = document.createElement('a');
    a.className = 'gotoc-anchor';
    a.href = '#' + id;
    a.textContent = '#';
    a.setAttribute('aria-hidden', 'true');
    a.tabIndex = -1;
    h.appendChild(a);
  });

  // ── Marking where you are reading ──────────────────────────
  var current = null;
  function mark() {
    var line = window.scrollY + 90, pick = links[0];
    for (var i = 0; i < items.length; i++) {
      if (items[i].el.getBoundingClientRect().top + window.scrollY <= line) pick = links[i];
      else break;
    }
    if (pick === current) return;
    if (current) current.classList.remove('on');
    pick.classList.add('on');
    current = pick;
    // A long table of contents can leave the current entry off-screen — pull it into view.
    var box = nav.getBoundingClientRect(), at = pick.getBoundingClientRect();
    if (at.top < box.top + 8 || at.bottom > box.bottom - 8) {
      nav.scrollTop += at.top - box.top - box.height / 2;
    }
  }
  var waiting = false;
  window.addEventListener('scroll', function () {
    if (waiting) return;
    waiting = true;
    requestAnimationFrame(function () { waiting = false; mark(); });
  }, { passive: true });
  mark();

  // ── The filter ────────────────────────────────────────────
  // 🛑 Key events are stopped here — tooltip.js grabs Escape, Space and Enter globally.
  find.addEventListener('keydown', function (e) {
    e.stopPropagation();
    if (e.key === 'Escape') { find.value = ''; filter(); find.blur(); }
  });
  find.addEventListener('input', filter);
  function filter() {
    var q = find.value.trim().toLowerCase(), hit = 0;
    links.forEach(function (a) {
      var ok = !q || a.textContent.toLowerCase().indexOf(q) >= 0;
      a.hidden = !ok;
      if (ok) hit++;
    });
    none.hidden = hit > 0;
    none.textContent = '\u2315 ' + say.search + (q ? ' \u00b7 \u201c' + find.value.trim() + '\u201d' : '');
  }

  // ── Opening and closing on a narrow screen ─────────────────
  var veil = null;
  var btn = document.createElement('button');
  btn.className = 'gotoc-btn';
  btn.type = 'button';
  btn.textContent = '☰ ' + title.textContent;
  btn.setAttribute('aria-expanded', 'false');
  btn.addEventListener('click', function () { open(!nav.classList.contains('open')); });
  document.body.appendChild(btn);

  function open(on) {
    nav.classList.toggle('open', on);
    btn.setAttribute('aria-expanded', on ? 'true' : 'false');
    if (on && !veil) {
      veil = document.createElement('div');
      veil.className = 'gotoc-veil';
      veil.addEventListener('click', function () { open(false); });
      document.body.appendChild(veil);
    } else if (!on && veil) {
      veil.remove();
      veil = null;
    }
  }
  nav.addEventListener('click', function (e) {
    if (e.target.tagName === 'A' && window.innerWidth < 1080) open(false);
  });
})();
