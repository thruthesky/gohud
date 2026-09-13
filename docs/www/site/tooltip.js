/* ------------------------------------------------------------------
   용어 호버 도움말 — 문서 어디서든 단어에 마우스를 올리면 뜻이 뜬다.
   site/glossary.js 를 먼저 불러와야 한다.

   원본: thruthesky 의 "Godot 3D 개발 스킬" 홈페이지(site/tooltip.js).
   gohud 의 영문·한국어 표시, 키보드·터치 접근을 함께 지원한다.
   ------------------------------------------------------------------ */
(function () {
  'use strict';
  var G = window.GLOSSARY;
  if (!G) return;

  var MODES = ['mark', 'all', 'off'];
  var korean = document.documentElement.lang.toLowerCase().indexOf('ko') === 0;
  var LABEL = korean
    ? { mark: '용어 밑줄 · 처음 3회', all: '용어 밑줄 · 전부', off: '용어 밑줄 · 끔' }
    : { mark: 'Glossary · first 3', all: 'Glossary · all', off: 'Glossary · off' };
  var INHERITS = korean ? '상속' : 'Inherits';
  var MORE = korean ? '자세히 보기 ↗' : 'Read more ↗';
  var KEY = 'gohud-glossary-mode';
  var mode = 'mark';
  try { if (MODES.indexOf(localStorage.getItem(KEY)) >= 0) mode = localStorage.getItem(KEY); } catch (e) {}

  var MARK_LIMIT = 3;          // mark 모드에서 한 용어를 몇 번까지 밑줄 칠 것인가
  var SKIP_TAGS = { SCRIPT: 1, STYLE: 1, NOSCRIPT: 1, TEXTAREA: 1, INPUT: 1, SELECT: 1, OPTION: 1, BUTTON: 1, MARK: 1, ABBR: 1 };

  /* ── 스타일 주입 ────────────────────────────────────────── */
  var css = document.createElement('style');
  css.textContent = [
    '.gl{cursor:help}',
    'body[data-gl="all"] .gl,body[data-gl="mark"] .gl.gl-m{',
    '  border-bottom:1px dashed color-mix(in srgb,var(--accent,#D9480F) 55%,transparent);',
    '  text-underline-offset:2px}',
    'body[data-gl="all"] .gl:hover,body[data-gl="mark"] .gl:hover{',
    '  background:color-mix(in srgb,var(--accent,#D9480F) 12%,transparent);border-radius:3px}',
    'body[data-gl="off"] .gl{cursor:inherit}',
    'pre .gl,code .gl{border-bottom-style:dotted}',
    'a .gl{border-bottom:0!important;background:none!important}',

    '#gltip{position:absolute;z-index:9999;max-width:min(420px,calc(100vw - 24px));',
    '  background:var(--card,#fff);color:var(--ink,#16202B);border:1px solid var(--rule,#C7D0DA);',
    '  border-radius:10px;padding:11px 13px 10px;box-shadow:0 6px 28px -8px rgba(0,0,0,.32);',
    '  font-size:13.5px;line-height:1.62;opacity:0;visibility:hidden;transition:opacity .12s;',
    '  font-family:inherit;text-align:left;white-space:normal;font-weight:400;',
    '  max-height:min(62vh,420px);overflow-y:auto;overscroll-behavior:contain}',
    '#gltip.on{opacity:1;visibility:visible}',
    '#gltip .h{display:flex;align-items:baseline;gap:7px;margin-bottom:5px;flex-wrap:wrap}',
    '#gltip .n{font-weight:700;font-size:14.5px;font-family:"IBM Plex Mono",ui-monospace,monospace}',
    '#gltip .n.ko{font-family:inherit}',
    '#gltip .k{font-size:10.5px;letter-spacing:.06em;padding:1px 6px;border-radius:999px;',
    '  background:color-mix(in srgb,var(--accent,#D9480F) 14%,transparent);color:var(--accent,#D9480F);font-weight:700}',
    '#gltip .d{margin:0}',
    '#gltip .c{margin-top:7px;padding-top:7px;border-top:1px dashed var(--rule,#C7D0DA);',
    '  font-size:11.5px;color:var(--muted,#5B6B7B);font-family:"IBM Plex Mono",ui-monospace,monospace;',
    '  word-break:break-word}',
    '#gltip .c b{color:var(--ink,#16202B)}',
    '#gltip .u{display:inline-block;margin-top:8px;font-size:12px;color:var(--blue,#1864AB);text-decoration:none}',
    '#gltip .u:hover{text-decoration:underline}',

    '#glbtn{position:fixed;right:14px;bottom:14px;z-index:9998;',
    '  background:var(--card,#fff);color:var(--muted,#5B6B7B);border:1px solid var(--rule,#C7D0DA);',
    '  border-radius:999px;padding:7px 13px;font-size:12px;font-family:inherit;cursor:pointer;',
    '  box-shadow:0 3px 14px -6px rgba(0,0,0,.3);line-height:1.4}',
    '#glbtn:hover{color:var(--ink,#16202B);border-color:var(--accent,#D9480F)}',
    '#glbtn b{color:var(--accent,#D9480F)}',
    '@media print{#glbtn,#gltip{display:none}}'
  ].join('\n');
  document.head.appendChild(css);

  /* ── 정규식 하나로 합친다 (긴 용어 우선) ────────────────── */
  var terms = Object.keys(G).sort(function (a, b) { return b.length - a.length || (a < b ? -1 : 1); });
  var esc = function (s) { return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); };
  var isKo = function (s) { return /^[가-힣]/.test(s); };
  var parts = terms.map(function (t) {
    return isKo(t)
      ? '(?<![가-힣])' + esc(t)
      : '(?<![A-Za-z0-9_@$가-힣])' + esc(t) + '(?![A-Za-z0-9_])';
  });
  var RE;
  try { RE = new RegExp(parts.join('|'), 'g'); }
  catch (e) { return; }   // lookbehind 미지원 브라우저에서는 조용히 넘어간다

  /* ── DOM 을 훑어 용어를 감싼다 ──────────────────────────── */
  var seen = Object.create(null);   // 용어별 등장 횟수

  function skip(node) {
    for (var p = node.parentNode; p && p !== document.body; p = p.parentNode) {
      if (p.nodeType !== 1) continue;
      if (SKIP_TAGS[p.tagName]) return true;
      if (p.classList && (p.classList.contains('gl') || p.classList.contains('no-gl'))) return true;
      if (p.id === 'gltip' || p.id === 'glbtn') return true;
      if (p.hasAttribute && p.hasAttribute('data-no-gl')) return true;
    }
    return false;
  }

  function apply(root) {
    if (!root) return 0;
    var walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
      acceptNode: function (n) {
        if (!n.data || n.data.length < 2) return NodeFilter.FILTER_REJECT;
        if (skip(n)) return NodeFilter.FILTER_REJECT;
        return NodeFilter.FILTER_ACCEPT;
      }
    });
    var nodes = [], n;
    while ((n = walker.nextNode())) nodes.push(n);

    var wrapped = 0;
    nodes.forEach(function (node) {
      RE.lastIndex = 0;
      var text = node.data, m, last = 0, frag = null;
      while ((m = RE.exec(text))) {
        var term = m[0], e = G[term];
        if (!e) continue;
        if (!frag) frag = document.createDocumentFragment();
        if (m.index > last) frag.appendChild(document.createTextNode(text.slice(last, m.index)));
        var s = document.createElement('span');
        s.className = 'gl';
        seen[term] = (seen[term] || 0) + 1;
        if (seen[term] <= MARK_LIMIT) s.className += ' gl-m';
        s.setAttribute('data-t', term);
        s.title = term + ' — ' + e.d + (e.c ? '\n\n' + INHERITS + ': ' + term + ' < ' + e.c : '');
        if (!node.parentElement.closest('a')) {
          s.tabIndex = mode === 'off' ? -1 : 0;
          s.setAttribute('role', 'button');
          s.setAttribute('aria-label', term + (korean ? ' — 용어 설명' : ' — definition'));
          s.setAttribute('aria-haspopup', 'dialog');
          s.setAttribute('aria-controls', 'gltip');
          s.setAttribute('aria-expanded', 'false');
        }
        s.textContent = term;
        frag.appendChild(s);
        last = m.index + term.length;
        wrapped++;
      }
      if (frag) {
        if (last < text.length) frag.appendChild(document.createTextNode(text.slice(last)));
        node.parentNode.replaceChild(frag, node);
      }
    });
    return wrapped;
  }

  /* ── 툴팁 ───────────────────────────────────────────────── */
  var tip = document.createElement('div');
  tip.id = 'gltip';
  tip.setAttribute('data-no-gl', '');
  tip.setAttribute('role', 'dialog');
  tip.setAttribute('aria-modal', 'false');
  tip.setAttribute('aria-hidden', 'true');
  tip.setAttribute('aria-labelledby', 'gltip-title');
  tip.setAttribute('aria-describedby', 'gltip-description');
  var hideT, showT, cur = null, restoringFocus = false;

  function restoreTrigger() {
    if (!cur) return;
    if (cur.hasAttribute('data-title')) {
      cur.title = cur.getAttribute('data-title');
      cur.removeAttribute('data-title');
    }
    if (cur.hasAttribute('aria-expanded')) cur.setAttribute('aria-expanded', 'false');
  }

  function close() {
    clearTimeout(hideT); clearTimeout(showT);
    tip.classList.remove('on');
    tip.setAttribute('aria-hidden', 'true');
    restoreTrigger();
    cur = null;
  }

  function place(el) {
    var r = el.getBoundingClientRect();
    tip.style.left = '0px'; tip.style.top = '0px';
    tip.classList.add('on');
    var tw = tip.offsetWidth, th = tip.offsetHeight;
    var x = r.left + r.width / 2 - tw / 2;
    x = Math.max(10, Math.min(x, document.documentElement.clientWidth - tw - 10));
    var vh = document.documentElement.clientHeight;
    var above = r.top > th + 14;
    var y = above ? r.top - th - 9 : r.bottom + 9;
    y = Math.max(8, Math.min(y, vh - th - 8));   // 화면 밖으로 나가지 않게 가둔다
    tip.style.left = (x + window.scrollX) + 'px';
    tip.style.top = (y + window.scrollY) + 'px';
  }

  function show(el) {
    if (mode === 'off') return;
    var term = el.getAttribute('data-t'), e = G[term];
    if (!e) return;
    clearTimeout(hideT); clearTimeout(showT);
    if (cur === el && tip.classList.contains('on')) { place(el); return; }
    restoreTrigger();
    cur = el;
    var html = '<div class="h"><span id="gltip-title" class="n' + (isKo(term) ? ' ko' : '') + '"></span>'
             + '<span class="k"></span></div><p id="gltip-description" class="d"></p>';
    tip.innerHTML = html;
    tip.querySelector('.n').textContent = term;
    tip.querySelector('.k').textContent = e.k;
    tip.querySelector('.d').textContent = e.d;
    if (e.c) {
      var c = document.createElement('div');
      c.className = 'c';
      c.innerHTML = INHERITS + ' <b></b> &lt; ';
      c.querySelector('b').textContent = term;
      c.appendChild(document.createTextNode(e.c));
      tip.appendChild(c);
    }
    if (e.u) {
      var a = document.createElement('a');
      a.className = 'u'; a.href = e.u; a.textContent = MORE;
      if (/^https?:/.test(e.u)) { a.target = '_blank'; a.rel = 'noopener'; }
      tip.appendChild(a);
    }
    // 브라우저 기본 툴팁과 겹치지 않게 잠시 치운다 (벗어나면 되돌린다)
    if (el.title) { el.setAttribute('data-title', el.title); el.title = ''; }
    tip.setAttribute('aria-hidden', 'false');
    if (el.hasAttribute('aria-expanded')) el.setAttribute('aria-expanded', 'true');
    place(el);
  }

  function hide() {
    hideT = setTimeout(close, 160);
  }

  document.addEventListener('mouseover', function (ev) {
    var el = ev.target.closest && ev.target.closest('.gl');
    if (el) { clearTimeout(showT); showT = setTimeout(function () { show(el); }, 90); return; }
    if (ev.target.closest && ev.target.closest('#gltip')) { clearTimeout(hideT); return; }
  });
  document.addEventListener('mouseout', function (ev) {
    if (ev.target.closest && (ev.target.closest('.gl') || ev.target.closest('#gltip'))) {
      if (cur === document.activeElement || tip.contains(document.activeElement)) return;
      clearTimeout(showT); hide();
    }
  });
  // 모바일 — 탭하면 뜨고 바깥을 누르면 사라진다
  document.addEventListener('click', function (ev) {
    var el = ev.target.closest && ev.target.closest('.gl');
    if (el) {
      // 링크 안의 용어는 링크 이동이 우선이다 — 툴팁만 띄우고 기본 동작을 막지 않는다
      if (!el.closest('a')) ev.preventDefault();
      (cur === el) ? close() : show(el);
      return;
    }
    if (!(ev.target.closest && ev.target.closest('#gltip'))) close();
  });
  document.addEventListener('focusin', function (ev) {
    if (tip.contains(ev.target)) { clearTimeout(hideT); return; }
    var el = ev.target.closest && ev.target.closest('.gl[role="button"]');
    if (el && !restoringFocus && el.matches(':focus-visible')) show(el);
    else if (!el) close();
  });
  document.addEventListener('focusout', function (ev) {
    if (ev.relatedTarget && (tip.contains(ev.relatedTarget) || ev.relatedTarget === cur)) return;
    if (ev.target === cur || tip.contains(ev.target)) hide();
  });
  addEventListener('keydown', function (e) {
    var el = e.target.closest && e.target.closest('.gl[role="button"]');
    if (e.key === 'Escape') {
      var trigger = cur, inside = tip.contains(document.activeElement);
      close();
      if (inside && trigger) {
        restoringFocus = true; trigger.focus(); restoringFocus = false;
      }
    } else if (el && mode !== 'off' && (e.key === 'Enter' || e.key === ' ')) {
      e.preventDefault(); show(el);
    } else if (e.key === 'Tab' && cur && tip.classList.contains('on')) {
      var link = tip.querySelector('a');
      if (el === cur && link && !e.shiftKey) {
        e.preventDefault(); link.focus();
      } else if (tip.contains(e.target)) {
        // Continue from the definition's trigger, not from the end of the document.
        var items = Array.from(document.querySelectorAll('a[href], button, [tabindex="0"]'))
          .filter(function (item) { return !tip.contains(item) && item.getClientRects().length; });
        var next = e.shiftKey ? cur : items[items.indexOf(cur) + 1];
        if (next) { e.preventDefault(); next.focus(); }
      }
    }
  });
  addEventListener('scroll', function () { if (cur) place(cur); }, { passive: true });
  addEventListener('resize', function () { if (cur) place(cur); });

  /* ── 켬/끔 버튼 ─────────────────────────────────────────── */
  var btn = document.createElement('button');
  btn.id = 'glbtn';
  btn.setAttribute('data-no-gl', '');
  btn.type = 'button';
  function paint() {
    document.body.setAttribute('data-gl', mode);
    document.querySelectorAll('.gl[role="button"]').forEach(function (el) {
      el.tabIndex = mode === 'off' ? -1 : 0;
    });
    btn.innerHTML = '';
    btn.appendChild(document.createTextNode(LABEL[mode].split(' · ')[0] + ' · '));
    var b = document.createElement('b');
    b.textContent = LABEL[mode].split(' · ')[1];
    btn.appendChild(b);
    btn.title = korean
      ? '용어에 마우스를 올리거나 탭·키보드로 선택하면 뜻이 나옵니다. 밑줄 표시: 처음 3회 → 전부 → 끔'
      : 'Hover, tap or focus a term to read its definition. Underlines: first 3 → all → off';
  }
  btn.addEventListener('click', function () {
    mode = MODES[(MODES.indexOf(mode) + 1) % MODES.length];
    close();
    try { localStorage.setItem(KEY, mode); } catch (e) {}
    paint();
  });

  function boot(root) {
    if (!document.getElementById('gltip')) document.body.appendChild(tip);
    if (!document.getElementById('glbtn')) { document.body.appendChild(btn); paint(); }
    apply(root || document.body);
  }

  window.GlossaryTip = { apply: apply, boot: boot, reset: function () { seen = Object.create(null); } };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () { boot(); });
  } else boot();
})();
