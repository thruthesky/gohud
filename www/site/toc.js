/* gohud 홈페이지 — 왼쪽 목차(사이드바).
 *
 * 긴 한 장을 여러 장으로 쪼개는 대신, **지금 어디를 읽고 있는지 늘 보이게** 한다. 언어가 17 개라
 * 페이지를 항목마다 쪼개면 51 장이 544 장이 된다 — 쪼개는 것은 파일이 아니라 길잡이다.
 *
 * ## 왜 이렇게 만들었나
 * - 목차는 **페이지의 제목을 읽어서** 만든다. 그래서 17 개 언어판에 번역문을 따로 넣을 필요가 없다.
 *   제목의 id 는 `tools/make_site.py` 가 영어 기준으로 박아 두어, 언어를 바꿔도 주소가 같다.
 * - CSS 는 이 파일이 직접 넣는다(`site/tooltip.js` 의 선례). `site/style.css` 는 건드리지 않는다.
 * - 🛑 `fetch()` 를 쓰지 않는다 — `tools/site_shots.sh` 가 페이지를 `file://` 로 열기 때문에
 *   브라우저에서는 되고 촬영 검증에서만 조용히 죽는다. 필요한 것은 전부 문서 안에 있다.
 * - 🛑 화면 오른쪽 아래는 용어 버튼(`#glbtn`)이 쓰고 있다. 좁은 화면의 목차 단추는 **왼쪽 아래**다.
 * - 🛑 `tooltip.js` 가 전역 keydown 에서 Escape·Enter·Space·Tab 을 가로챈다. 거르개 입력칸에서는
 *   키 이벤트를 멈춰 글자가 엉뚱하게 먹히지 않게 한다.
 */
(function () {
  'use strict';

  var main = document.querySelector('main');
  if (!main) return;

  // ── 사이드바가 쓰는 말 ─────────────────────────────────────
  // 🔑 여기 한 곳에 두고 문서의 `<html lang>` 으로 고른다. 이렇게 하면 언어판 51 장에는 아무것도
  //    넣지 않아도 목차가 그 나라 말로 뜬다. 모르는 언어는 영어로 떨어진다.
  var SAY = {
    'en': { title: 'On this page', filter: 'Filter' },
    'ko': { title: '이 페이지 차례', filter: '거르기' },
    'ja': { title: 'このページの目次', filter: '絞り込み' },
    'zh-Hans': { title: '本页目录', filter: '筛选' },
    'zh-Hant': { title: '本頁目錄', filter: '篩選' },
    'es': { title: 'En esta página', filter: 'Filtrar' },
    'pt': { title: 'Nesta página', filter: 'Filtrar' },
    'ru': { title: 'На этой странице', filter: 'Фильтр' },
    'fr': { title: 'Sur cette page', filter: 'Filtrer' },
    'tr': { title: 'Bu sayfada', filter: 'Süz' },
    'pl': { title: 'Na tej stronie', filter: 'Filtruj' },
    'it': { title: 'In questa pagina', filter: 'Filtra' },
    'vi': { title: 'Trong trang này', filter: 'Lọc' },
    'id': { title: 'Di halaman ini', filter: 'Saring' },
    'uk': { title: 'На цій сторінці', filter: 'Фільтр' },
    'th': { title: 'ในหน้านี้', filter: 'กรอง' },
    'ar': { title: 'في هذه الصفحة', filter: 'تصفية' }
  };
  var lang = document.documentElement.lang || 'en';
  var say = SAY[lang] || SAY[lang.split('-')[0]] || SAY.en;

  // ── 목차 거리 ──────────────────────────────────────────────
  // 절(`<section id>`)과 그 안의 소제목(`h3[id]`)만 담는다. 🛑 카드 안의 h3 은 뺀다 — `#what` 절의
  // 카드 여덟 장은 나열이지 절이 아니라서, 넣으면 목차가 본문만큼 길어진다.
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
  if (items.length < 3) return;

  // 머리띠의 페이지 링크(다른 장으로 가는 길)를 그대로 가져온다 — 번역문이 이미 들어 있다.
  var pageLinks = [];
  document.querySelectorAll('header.top nav a').forEach(function (a) {
    var href = a.getAttribute('href') || '';
    if (a.closest('.langs')) return;
    if (/^https?:|^#|^mailto:/.test(href)) return;
    if (!/\.html$|^\.\/$|^\.\.\/$/.test(href)) return;
    pageLinks.push({ href: href, text: a.textContent.replace(/\s*↗\s*$/, '').trim() });
  });

  // ── 생김새 ────────────────────────────────────────────────
  // 색은 style.css 의 변수를 그대로 쓴다 — 밝은 판·어두운 판이 저절로 따라온다.
  var W = '264px', HEAD = '58px';
  var css = document.createElement('style');
  css.textContent = [
    '.gotoc{position:fixed;inset-block-start:' + HEAD + ';inset-inline-start:0;width:' + W + ';',
    '  height:calc(100vh - ' + HEAD + ');overflow-y:auto;overscroll-behavior:contain;z-index:40;',
    '  padding:16px 12px 48px;background:var(--bg,#F7F9FB);',
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
    '.gotoc-none{padding:8px 9px;color:var(--muted,#5B6B7B)}',
    '.gotoc-pages{margin-top:16px;padding-top:12px;border-top:1px solid var(--rule,#DCE3EA)}',
    '.gotoc-pages a{font-weight:600;color:var(--ink,#16202B)}',
    'body.gotoc-on{padding-inline-start:' + W + '}',

    /* 제목 옆의 작은 고리 — 그 자리의 주소를 바로 집어갈 수 있게. 마우스를 올려야 보인다. */
    '.gotoc-anchor{margin-inline-start:.4em;color:var(--muted,#5B6B7B);text-decoration:none;',
    '  opacity:0;font-weight:400;transition:opacity .12s}',
    'h2:hover>.gotoc-anchor,h3:hover>.gotoc-anchor,.gotoc-anchor:focus{opacity:.75}',

    /* 좁은 화면 — 옆에 둘 자리가 없으니 단추로 여닫는다. 🛑 왼쪽 아래(오른쪽은 용어 버튼 자리). */
    '.gotoc-btn{display:none;position:fixed;inset-block-end:14px;inset-inline-start:14px;z-index:45;',
    '  padding:9px 14px;border-radius:999px;border:1px solid var(--rule,#DCE3EA);',
    '  background:var(--card,#fff);color:var(--ink,#16202B);font:inherit;font-size:13px;font-weight:600;',
    '  box-shadow:0 6px 20px -8px rgba(0,0,0,.35);cursor:pointer}',
    '@media (max-width:1079px){',
    '  body.gotoc-on{padding-inline-start:0}',
    '  .gotoc-btn{display:block}',
    /* 머리띠의 절 링크는 목차와 겹친다 — 좁은 화면에서는 뺀다. 머리띠가 세 줄에서 한 줄로 줄어
       본문이 그만큼 먼저 보인다. 🛑 목차가 실제로 떴을 때만(`body.gotoc-on`) 숨긴다. */
    '  body.gotoc-on header.top nav a[href^="#"]{display:none}',
    '  .gotoc{inset-block-start:0;height:100vh;width:min(320px,86vw);z-index:60;',
    '    box-shadow:0 0 40px -10px rgba(0,0,0,.4);transform:translateX(-110%);',
    '    transition:transform .18s;padding-top:20px}',
    '  [dir="rtl"] .gotoc{transform:translateX(110%)}',
    '  .gotoc.open{transform:none}',
    '  .gotoc-veil{position:fixed;inset:0;z-index:55;background:rgba(8,16,24,.45)}',
    '}',
    '@media (prefers-reduced-motion:reduce){.gotoc{transition:none}}'
  ].join('');
  document.head.appendChild(css);

  // ── 목차 만들기 ────────────────────────────────────────────
  var nav = document.createElement('nav');
  nav.className = 'gotoc';
  nav.setAttribute('aria-label', say.title);

  var title = document.createElement('div');
  title.className = 'gotoc-title';
  title.textContent = say.title;
  nav.appendChild(title);

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

  var none = document.createElement('div');
  none.className = 'gotoc-none';
  none.hidden = true;
  none.textContent = '—';
  list.appendChild(none);

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

  // 제목마다 주소 고리를 단다 — 읽다가 그 자리를 남에게 보낼 수 있게.
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

  // ── 지금 읽는 자리 표시 ────────────────────────────────────
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
    // 목차가 길면 지금 항목이 화면 밖일 수 있다 — 보이는 자리로 끌어온다.
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

  // ── 거르개 ────────────────────────────────────────────────
  // 🛑 키 이벤트를 여기서 멈춘다 — tooltip.js 가 전역에서 Escape·Space·Enter 를 가로채기 때문이다.
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
  }

  // ── 좁은 화면의 여닫이 ─────────────────────────────────────
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
