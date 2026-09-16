/* gohud 홈페이지 — 전역 검색.
 *
 * 한 언어의 세 쪽(소개·생김새·위젯)을 **한 번에** 뒤진다. 읽던 쪽이 어디든 `GoSheet` 를 치면
 * 그 위젯을 설명하는 자리로 곧장 간다.
 *
 * ## 왜 이렇게 만들었나
 * - 🛑 `fetch()` 를 쓰지 않는다. `tools/site_shots.sh` 가 페이지를 `file://` 로 열어 촬영하는데,
 *   그 자리에서 fetch 는 CORS 로 조용히 죽는다. 색인은 `<script src>` 로 불러온다
 *   (`tools/make_search.py` 가 전역 대입문으로 낸다).
 * - 색인은 **팔레트를 처음 열 때** 받는다. 글만 읽고 가는 사람은 한 바이트도 더 받지 않는다.
 * - 색인 파일의 주소는 이 스크립트 자신의 주소에서 만든다 — `ko/widgets.html` 이든 최상위든
 *   `../site/` 를 손으로 셀 필요가 없다.
 * - CSS 는 이 파일이 넣는다(`site/tooltip.js`·`site/toc.js` 의 선례). `site/style.css` 는 안 건드린다.
 * - 🛑 `tooltip.js` 가 전역 keydown 에서 Escape·Enter·Space·Tab 을 가로챈다. 팔레트가 열려 있는
 *   동안에는 캡처 단계에서 먼저 잡아 멈춘다.
 */
(function () {
  'use strict';

  var self = document.currentScript;
  if (!self || !self.src) return;
  var BASE = self.src.replace(/search\.js(\?.*)?$/, '');   // …/site/

  // ── 화면에 쓰는 말 ─────────────────────────────────────────
  // 🔑 한 곳에 두고 `<html lang>` 으로 고른다 — 언어판 51 장에는 아무것도 넣지 않는다.
  var SAY = {
    'en':      { ph: 'Search the docs',        open: 'Search',   none: 'Nothing found for',    all: 'All sections',      recent: 'Recent',        load: 'Loading…',     hint: 'to open' },
    'ko':      { ph: '문서 검색',                open: '검색',      none: '찾은 것이 없다:',          all: '모든 절',             recent: '최근 찾은 것',     load: '받는 중…',      hint: '로 열기' },
    'ja':      { ph: 'ドキュメントを検索',          open: '検索',      none: '見つかりません:',          all: 'すべての項目',          recent: '最近',           load: '読み込み中…',    hint: 'で開く' },
    'zh-Hans': { ph: '搜索文档',                 open: '搜索',      none: '没有找到:',              all: '全部章节',            recent: '最近',           load: '加载中…',       hint: '打开' },
    'zh-Hant': { ph: '搜尋文件',                 open: '搜尋',      none: '找不到:',               all: '全部章節',            recent: '最近',           load: '載入中…',       hint: '開啟' },
    'es':      { ph: 'Buscar en la doc',       open: 'Buscar',   none: 'Sin resultados para',  all: 'Todas las secciones', recent: 'Recientes',   load: 'Cargando…',    hint: 'para abrir' },
    'pt':      { ph: 'Pesquisar na doc',       open: 'Buscar',   none: 'Nada encontrado para', all: 'Todas as seções',   recent: 'Recentes',      load: 'Carregando…',  hint: 'para abrir' },
    'ru':      { ph: 'Поиск по документации',  open: 'Поиск',    none: 'Ничего не найдено:',   all: 'Все разделы',       recent: 'Недавние',      load: 'Загрузка…',    hint: 'открыть' },
    'fr':      { ph: 'Rechercher dans la doc', open: 'Chercher', none: 'Aucun résultat pour',  all: 'Toutes les sections', recent: 'Récents',     load: 'Chargement…',  hint: 'pour ouvrir' },
    'tr':      { ph: 'Belgelerde ara',         open: 'Ara',      none: 'Sonuç yok:',           all: 'Tüm bölümler',      recent: 'Son aramalar',  load: 'Yükleniyor…',  hint: 'ile aç' },
    'pl':      { ph: 'Szukaj w dokumentacji',  open: 'Szukaj',   none: 'Brak wyników dla',     all: 'Wszystkie sekcje',  recent: 'Ostatnie',      load: 'Wczytywanie…', hint: 'aby otworzyć' },
    'it':      { ph: 'Cerca nella doc',        open: 'Cerca',    none: 'Nessun risultato per', all: 'Tutte le sezioni',  recent: 'Recenti',       load: 'Caricamento…', hint: 'per aprire' },
    'vi':      { ph: 'Tìm trong tài liệu',     open: 'Tìm',      none: 'Không thấy:',          all: 'Tất cả mục',        recent: 'Gần đây',       load: 'Đang tải…',    hint: 'để mở' },
    'id':      { ph: 'Cari dokumentasi',       open: 'Cari',     none: 'Tidak ada hasil:',     all: 'Semua bagian',      recent: 'Terbaru',       load: 'Memuat…',      hint: 'untuk buka' },
    'uk':      { ph: 'Пошук у документації',   open: 'Пошук',    none: 'Нічого не знайдено:',  all: 'Усі розділи',       recent: 'Нещодавні',     load: 'Завантаження…', hint: 'відкрити' },
    'th':      { ph: 'ค้นหาเอกสาร',                open: 'ค้นหา',      none: 'ไม่พบ:',                 all: 'ทุกหัวข้อ',             recent: 'ล่าสุด',           load: 'กำลังโหลด…',     hint: 'เพื่อเปิด' },
    'ar':      { ph: 'ابحث في التوثيق',           open: 'بحث',      none: 'لا نتائج لـ',            all: 'كل الأقسام',          recent: 'الأخيرة',        load: 'جارٍ التحميل…',   hint: 'للفتح' }
  };
  // `<html lang>` → 색인 파일 이름. 🛑 중국어만 문자(Hans·Hant)로 갈린다.
  var FILE = { 'zh-Hans': 'zh', 'zh-Hant': 'zh-tw' };

  var lang = document.documentElement.lang || 'en';
  var say = SAY[lang] || SAY[lang.split('-')[0]] || SAY.en;
  var code = FILE[lang] || lang.split('-')[0] || 'en';
  var mac = /Mac|iPhone|iPad/.test(navigator.platform || navigator.userAgent);
  var KEY = mac ? '⌘K' : 'Ctrl K';

  // ── 생김새 ─────────────────────────────────────────────────
  var css = document.createElement('style');
  css.textContent = [
    /* 머리띠의 검색칸 — 눌러야 팔레트가 뜨는 가짜 입력칸이다(진짜 입력은 팔레트 안에서 한다). */
    '.gos-open{display:inline-flex;align-items:center;gap:8px;cursor:pointer;font:inherit;font-size:13px;',
    '  padding:6px 10px;border-radius:999px;border:1px solid var(--rule,#DCE3EA);',
    '  background:var(--card,#fff);color:var(--muted,#5B6B7B);min-width:184px}',
    '.gos-open:hover{border-color:var(--accent,#0878AE);color:var(--accent,#0878AE)}',
    '.gos-open .k{margin-inline-start:auto;font-size:11px;padding:1px 6px;border-radius:5px;',
    '  border:1px solid var(--rule,#DCE3EA);color:var(--muted,#5B6B7B);white-space:nowrap}',
    '.gos-ico{width:14px;height:14px;flex:none;stroke:currentColor;fill:none;stroke-width:2}',
    '@media (max-width:860px){.gos-open{min-width:0}.gos-open .t,.gos-open .k{display:none}}',

    /* 팔레트 */
    '.gos-veil{position:fixed;inset:0;z-index:90;background:rgba(8,16,24,.5);',
    '  backdrop-filter:blur(3px);display:flex;justify-content:center;padding:10vh 16px 16px}',
    '.gos-box{width:min(680px,100%);max-height:78vh;display:flex;flex-direction:column;',
    '  background:var(--card,#fff);color:var(--ink,#16202B);border:1px solid var(--rule,#DCE3EA);',
    '  border-radius:16px;box-shadow:0 30px 80px -20px rgba(0,0,0,.55);overflow:hidden}',
    '.gos-head{display:flex;align-items:center;gap:10px;padding:14px 16px;',
    '  border-bottom:1px solid var(--rule,#DCE3EA)}',
    '.gos-in{flex:1;border:0;background:none;font:inherit;font-size:17px;color:inherit;outline:none;min-width:0}',
    '.gos-esc{font-size:11px;padding:2px 7px;border-radius:6px;border:1px solid var(--rule,#DCE3EA);',
    '  color:var(--muted,#5B6B7B)}',
    '.gos-list{overflow-y:auto;overscroll-behavior:contain;padding:8px}',
    '.gos-lab{font-size:11px;letter-spacing:.07em;text-transform:uppercase;font-weight:700;',
    '  color:var(--muted,#5B6B7B);padding:10px 10px 6px}',
    '.gos-hit{display:block;text-decoration:none;color:inherit;padding:9px 11px;border-radius:10px;',
    '  border:1px solid transparent}',
    '.gos-hit:hover,.gos-hit.on{background:color-mix(in srgb,var(--accent,#0878AE) 10%,transparent);',
    '  border-color:color-mix(in srgb,var(--accent,#0878AE) 35%,transparent)}',
    /* 🛑 flex 로 두면 배지·절 이름·제목이 저마다 줄바꿈 대상이 되어 폭 400 에서 "G o Shee t" 처럼
       글자가 흩어진다(2026-09-16 촬영). 한 줄의 글로 흐르게 두고 배지만 붙여 놓는다.
       🛑 body 의 `overflow-wrap:anywhere` 도 여기서는 되돌린다 — 낱말 한가운데를 자른다. */
    '.gos-t{display:block;font-weight:600;font-size:15px;overflow-wrap:break-word}',
    '.gos-pg{margin-inline-end:8px;vertical-align:1px}',
    '.gos-hit.on .gos-t{color:var(--accent,#0878AE)}',
    '.gos-pg{font-size:10.5px;font-weight:700;letter-spacing:.05em;text-transform:uppercase;',
    '  display:inline-block;padding:2px 7px;border-radius:999px;color:var(--accent,#0878AE);',
    '  background:color-mix(in srgb,var(--accent,#0878AE) 13%,transparent)}',
    '.gos-up{font-weight:500;color:var(--muted,#5B6B7B);font-size:13px;margin-inline-end:2px}',
    '.gos-x{font-size:13px;color:var(--muted,#5B6B7B);margin-top:3px;line-height:1.5;',
    '  overflow-wrap:break-word;',
    '  display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}',
    '.gos-x.code{font-family:var(--mono,monospace);font-size:12px;direction:ltr;unicode-bidi:isolate}',
    '.gos-x mark,.gos-t mark{background:color-mix(in srgb,var(--accent,#0878AE) 26%,transparent);',
    '  color:inherit;border-radius:3px;padding:0 1px;font-weight:700}',
    '.gos-none{padding:26px 12px;text-align:center;color:var(--muted,#5B6B7B)}',
    '.gos-foot{display:flex;gap:14px;align-items:center;padding:9px 16px;font-size:11.5px;',
    '  color:var(--muted,#5B6B7B);border-top:1px solid var(--rule,#DCE3EA)}',
    '.gos-foot b{font-weight:700;font-family:var(--mono,monospace)}',
    '@media (max-width:640px){.gos-veil{padding:0}.gos-box{max-height:100%;height:100%;border-radius:0;border:0}',
    '  .gos-foot{display:none}}',

    /* 결과를 눌러 도착한 자리를 잠깐 밝힌다 — 어디로 왔는지 보이게. */
    '.gos-flash{animation:gos-flash 1.6s ease-out}',
    '@keyframes gos-flash{from{background:color-mix(in srgb,var(--accent,#0878AE) 28%,transparent)}',
    '  to{background:transparent}}',
    '@media (prefers-reduced-motion:reduce){.gos-flash{animation:none}}'
  ].join('');
  document.head.appendChild(css);

  function icon() {
    return '<svg class="gos-ico" viewBox="0 0 24 24" aria-hidden="true">' +
           '<circle cx="11" cy="11" r="7"/><path d="M20 20l-3.6-3.6"/></svg>';
  }

  // ── 머리띠의 검색 단추 ──────────────────────────────────────
  var nav = document.querySelector('header.top nav');
  var btn = document.createElement('button');
  btn.type = 'button';
  btn.className = 'gos-open';
  btn.innerHTML = icon() + '<span class="t">' + esc(say.ph) + '</span><span class="k">' + esc(KEY) + '</span>';
  btn.setAttribute('aria-label', say.ph);
  btn.addEventListener('click', function () { open(''); });
  if (nav) nav.insertBefore(btn, nav.firstChild);

  // 🔑 목차 사이드바(`site/toc.js`)가 있으면 그 위에도 같은 단추를 둔다 — 거기서 항목을 못 찾은
  //    사람이 곧바로 전체 검색으로 넘어간다.
  window.GOHUD_SEARCH_OPEN = open;

  // ── 색인 ───────────────────────────────────────────────────
  var index = null, loading = false;
  function load(then) {
    if (index) return then();
    if (loading) return;
    loading = true;
    var s = document.createElement('script');
    s.src = BASE + 'search/' + code + '.js';
    s.onload = function () {
      index = (window.GOHUD_SEARCH || {})[code] || null;
      loading = false;
      then();
    };
    s.onerror = function () { loading = false; index = null; then(); };
    document.head.appendChild(s);
  }

  // ── 찾기 ───────────────────────────────────────────────────
  // 낱말을 공백으로 쪼개 **모두** 들어 있는 조각만 고른다. 토큰은 부분 문자열로 견준다 —
  // 한국어·일본어·중국어·태국어에는 낱말 사이 공백이 없어서 이 방법이라야 걸린다.
  function norm(s) { return s.toLowerCase().normalize ? s.toLowerCase().normalize('NFC') : s.toLowerCase(); }

  function search(q) {
    var toks = norm(q).split(/\s+/).filter(Boolean);
    if (!toks.length || !index) return [];
    var out = [];
    for (var i = 0; i < index.d.length; i++) {
      var d = index.d[i], t = norm(d[2]), x = norm(d[4]), c = norm(d[5] || ''), score = 0, ok = true;
      for (var k = 0; k < toks.length; k++) {
        var tok = toks[k], at = t.indexOf(tok);
        if (at >= 0) {
          // 제목에 든 말이 가장 세다. 제목이 그 말로 시작하면 더 세다.
          score += t === tok ? 900 : at === 0 ? 420 : 200;
        } else {
          var bt = x.indexOf(tok);
          if (bt >= 0) {
            score += 14 + Math.min(8, count(x, tok)) * 3;
            if (bt < 120) score += 6;   // 절 첫머리에 나오면 그 절의 주제일 확률이 높다
          } else if (c.indexOf(tok) >= 0) {
            // 코드에만 있는 말 — `GoUi.use_preset()` 처럼 문장에는 안 나오는 이름이 여기서 걸린다.
            score += 11 + Math.min(6, count(c, tok)) * 3;
          } else { ok = false; break; }
        }
      }
      if (!ok) continue;
      if (!d[3]) score += 12;         // 소제목보다 절을 앞에
      out.push({ d: d, s: score, i: i });
    }
    out.sort(function (a, b) { return b.s - a.s || a.i - b.i; });
    return out.slice(0, 40);
  }

  function count(hay, needle) {
    var n = 0, at = 0;
    while ((at = hay.indexOf(needle, at)) >= 0) { n++; at += needle.length; }
    return n;
  }

  function esc(s) {
    return String(s).replace(/[&<>"]/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c];
    });
  }

  /** 적중한 낱말에 표시를 넣는다. 원문을 잘라 쓰므로 먼저 이스케이프한다. */
  function light(text, toks) {
    var low = norm(text), marks = [];
    toks.forEach(function (tok) {
      var at = 0;
      while ((at = low.indexOf(tok, at)) >= 0 && marks.length < 60) {
        marks.push([at, at + tok.length]);
        at += tok.length;
      }
    });
    if (!marks.length) return esc(text);
    marks.sort(function (a, b) { return a[0] - b[0]; });
    var out = '', at = 0;
    marks.forEach(function (m) {
      if (m[0] < at) return;
      out += esc(text.slice(at, m[0])) + '<mark>' + esc(text.slice(m[0], m[1])) + '</mark>';
      at = m[1];
    });
    return out + esc(text.slice(at));
  }

  /** 본문에서 적중한 자리 둘레만 잘라 보여 준다 — 어느 문장에서 걸렸는지 보이게. */
  function snip(text, toks) {
    var low = norm(text), at = -1;
    for (var i = 0; i < toks.length && at < 0; i++) at = low.indexOf(toks[i]);
    if (at < 0) return light(text.slice(0, 150), toks);
    var from = Math.max(0, at - 58);
    var cut = text.slice(from, from + 190);
    return (from ? '…' : '') + light(cut, toks) + (from + 190 < text.length ? '…' : '');
  }

  // ── 최근 찾은 것 ───────────────────────────────────────────
  // 🛑 `file://` 나 사생활 보호 창에서는 localStorage 가 통째로 막힌다 — 없어도 검색은 돌아간다.
  function recent(add) {
    var list = [];
    try {
      list = JSON.parse(localStorage.getItem('gohud.recent') || '[]');
      if (add) {
        list = [add].concat(list.filter(function (x) { return x !== add; })).slice(0, 5);
        localStorage.setItem('gohud.recent', JSON.stringify(list));
      }
    } catch (e) { /* 막혀 있으면 그냥 넘어간다 */ }
    return list;
  }

  // ── 팔레트 ─────────────────────────────────────────────────
  var veil = null, input = null, list = null, hits = [], cur = -1, toks = [];

  function open(seed) {
    if (veil) { input.focus(); return; }
    veil = document.createElement('div');
    veil.className = 'gos-veil';
    veil.innerHTML =
      '<div class="gos-box" role="dialog" aria-modal="true" aria-label="' + esc(say.ph) + '">' +
      '  <div class="gos-head">' + icon() +
      '    <input class="gos-in" type="search" autocomplete="off" spellcheck="false" placeholder="' + esc(say.ph) + '">' +
      '    <span class="gos-esc">Esc</span>' +
      '  </div>' +
      '  <div class="gos-list"></div>' +
      '  <div class="gos-foot"><span><b>↑↓</b> · <b>↵</b> ' + esc(say.hint) + '</span>' +
      '  <span style="margin-inline-start:auto"><b>' + esc(KEY) + '</b></span></div>' +
      '</div>';
    veil.addEventListener('mousedown', function (e) { if (e.target === veil) close(); });
    document.body.appendChild(veil);
    input = veil.querySelector('.gos-in');
    list = veil.querySelector('.gos-list');
    input.addEventListener('input', run);
    input.value = seed || '';
    input.focus();
    document.addEventListener('keydown', keys, true);
    list.innerHTML = '<div class="gos-none">' + esc(say.load) + '</div>';
    load(function () { run(); });
  }

  function close() {
    if (!veil) return;
    document.removeEventListener('keydown', keys, true);
    veil.remove();
    veil = null; hits = []; cur = -1;
  }

  function run() {
    var q = input.value.trim();
    toks = norm(q).split(/\s+/).filter(Boolean);
    if (!index) {
      list.innerHTML = '<div class="gos-none">' + esc(say.load) + '</div>';
      return;
    }
    var rows = q ? search(q) : null;
    var html = '', label;
    if (!rows) {
      // 빈 칸일 때는 할 일을 준다 — 최근에 찾은 것, 그리고 절 전체 목록.
      var old = recent();
      if (old.length) {
        html += '<div class="gos-lab">' + esc(say.recent) + '</div>';
        old.forEach(function (word) {
          html += '<a class="gos-hit" href="#" data-seed="' + esc(word) + '"><span class="gos-t">' +
                  icon() + esc(word) + '</span></a>';
        });
      }
      label = say.all;
      rows = [];
      index.d.forEach(function (d, i) { if (!d[3]) rows.push({ d: d, i: i }); });
    }
    if (q && !rows.length) {
      list.innerHTML = '<div class="gos-none">' + esc(say.none) + ' <b>' + esc(q) + '</b></div>';
      hits = []; cur = -1;
      return;
    }
    if (label) html += '<div class="gos-lab">' + esc(label) + '</div>';
    rows.forEach(function (r) {
      var d = r.d, line = '';
      if (q) {
        // 🔑 보여 줄 한 줄을 고르는 규칙. 사람이 먼저 읽어야 하는 것은 **문장**이다.
        //    1) 찾는 말이 산문에 있으면 그 자리를, 2) 제목에서 걸렸으면 산문 첫머리를,
        //    3) 코드에만 있는 이름이면 그때만 코드를 보인다.
        var prose = !!d[4] && toks.some(function (tok) { return norm(d[4]).indexOf(tok) >= 0; });
        var byTitle = toks.some(function (tok) { return norm(d[2]).indexOf(tok) >= 0; });
        var code = !prose && !(byTitle && d[4]) && !!d[5];
        var body = code ? d[5] : (d[4] || d[5]);
        if (body) line = '<span class="gos-x' + (code ? ' code' : '') + '">' + snip(body, toks) + '</span>';
      }
      var up = d[6] >= 0 && index.d[d[6]] ? index.d[d[6]][2] : '';
      html += '<a class="gos-hit" href="' + esc(href(d)) + '">' +
              '<span class="gos-t"><span class="gos-pg">' + esc(index.n[d[0]]) + '</span>' +
              (up ? '<span class="gos-up">' + esc(up) + ' \u203A</span>' : '') +
              (q ? light(d[2], toks) : esc(d[2])) + '</span>' + line +
              '</a>';
    });
    list.innerHTML = html;
    hits = [].slice.call(list.querySelectorAll('.gos-hit'));
    hits.forEach(function (a, i) {
      a.addEventListener('click', function (e) {
        if (a.dataset.seed) { e.preventDefault(); input.value = a.dataset.seed; run(); input.focus(); return; }
        e.preventDefault();
        go(a.getAttribute('href'), input.value.trim());
      });
      a.addEventListener('mousemove', function () { pick(i); });
    });
    cur = -1;
    pick(0);
    list.scrollTop = 0;
  }

  /** 결과 한 줄이 가리키는 주소. 같은 언어 폴더 안이라 파일 이름만 쓰면 된다. */
  function href(d) {
    var page = index.p[d[0]];
    var here = (location.pathname.split('/').pop() || 'index.html');
    return (page === here ? '' : page) + '#' + d[1];
  }

  function pick(i) {
    if (!hits.length) return;
    i = Math.max(0, Math.min(hits.length - 1, i));
    if (cur >= 0 && hits[cur]) hits[cur].classList.remove('on');
    hits[i].classList.add('on');
    cur = i;
    var box = list.getBoundingClientRect(), at = hits[i].getBoundingClientRect();
    if (at.top < box.top) list.scrollTop += at.top - box.top - 8;
    else if (at.bottom > box.bottom) list.scrollTop += at.bottom - box.bottom + 8;
  }

  function go(url, word) {
    if (word) recent(word);
    close();
    if (url.charAt(0) === '#') {
      var el = document.getElementById(url.slice(1));
      if (el) {
        // 🛑 데려가는 일부터 한다. `history.replaceState` 는 `file://` 에서 SecurityError 를 던지는데,
        //    이것을 먼저 부르면 그 예외에 걸려 **스크롤도 강조도 일어나지 않는다**(2026-09-16 실측).
        //    오프라인 사본으로 문서를 읽는 사람에게는 검색 결과가 통째로 죽는 고장이었다.
        flash(el);
        el.scrollIntoView({ behavior: 'smooth', block: 'start' });
        try { history.replaceState(null, '', url); } catch (e) { location.hash = url.slice(1); }
        return;
      }
    }
    location.href = url;
  }

  function flash(el) {
    var mark = el.tagName === 'SECTION' ? (el.querySelector('h2') || el) : el;
    mark.classList.remove('gos-flash');
    void mark.offsetWidth;
    mark.classList.add('gos-flash');
  }

  // ── 열쇠 ──────────────────────────────────────────────────
  // 🛑 캡처 단계에서 잡아 멈춘다 — tooltip.js 가 전역에서 Escape·Enter·Space·Tab 을 쓴다.
  function keys(e) {
    if (!veil) return;
    if (e.key === 'Escape') { e.preventDefault(); e.stopPropagation(); close(); return; }
    if (e.key === 'ArrowDown') { e.preventDefault(); e.stopPropagation(); pick(cur + 1); return; }
    if (e.key === 'ArrowUp') { e.preventDefault(); e.stopPropagation(); pick(cur - 1); return; }
    if (e.key === 'Enter') {
      e.preventDefault(); e.stopPropagation();
      if (hits[cur]) hits[cur].click();
      return;
    }
    e.stopPropagation();   // 글자 키가 풍선 단축키로 새지 않게
  }

  // 어디서나 열 수 있게 — `/` 한 글자, 그리고 ⌘K·Ctrl K.
  document.addEventListener('keydown', function (e) {
    if (veil) return;
    var el = e.target, tag = el && el.tagName;
    var typing = tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT' || (el && el.isContentEditable);
    if ((e.key === 'k' || e.key === 'K') && (e.metaKey || e.ctrlKey)) {
      e.preventDefault(); open('');
    } else if (e.key === '/' && !typing && !e.metaKey && !e.ctrlKey && !e.altKey) {
      e.preventDefault(); open('');
    }
  });
})();
