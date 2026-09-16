/* gohud homepage — two small touches.
 *
 * 1. **Copy button on code blocks** — every code block here is a snippet meant to be pasted and
 *    run as is. Selecting it by hand drags along leading and trailing whitespace even though
 *    there are no line numbers. The button appears only on the block under the pointer.
 * 2. **Lazy images** — there are a dozen-odd screenshots, and fetching the ones below the fold
 *    along with everything else makes the first paint slow.
 *
 * 🛑 The CSS lives in the `.gocopy` rules of `site/style.css` (this file injects no styles).
 * 🛑 `navigator.clipboard` is blocked on `file://` and over plain http — fall back to the old way.
 */
(function () {
  'use strict';

  var SAY = {
    'en':      ['Copy', 'Copied'],       'ko':      ['복사', '복사함'],
    'ja':      ['コピー', 'コピーしました'],   'zh-Hans': ['复制', '已复制'],
    'zh-Hant': ['複製', '已複製'],          'es':      ['Copiar', 'Copiado'],
    'pt':      ['Copiar', 'Copiado'],    'ru':      ['Копировать', 'Скопировано'],
    'fr':      ['Copier', 'Copié'],      'tr':      ['Kopyala', 'Kopyalandı'],
    'pl':      ['Kopiuj', 'Skopiowano'], 'it':      ['Copia', 'Copiato'],
    'vi':      ['Chép', 'Đã chép'],      'id':      ['Salin', 'Tersalin'],
    'uk':      ['Копіювати', 'Скопійовано'], 'th':  ['คัดลอก', 'คัดลอกแล้ว'],
    'ar':      ['نسخ', 'تم النسخ']
  };
  var lang = document.documentElement.lang || 'en';
  var say = SAY[lang] || SAY[lang.split('-')[0]] || SAY.en;

  document.querySelectorAll('main pre').forEach(function (pre) {
    var btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'gocopy';
    btn.textContent = say[0];
    btn.addEventListener('click', function () {
      copy(pre.textContent.replace(/\s+$/, ''), function (ok) {
        if (!ok) return;
        btn.textContent = say[1];
        btn.classList.add('done');
        setTimeout(function () { btn.textContent = say[0]; btn.classList.remove('done'); }, 1400);
      });
    });
    pre.appendChild(btn);
  });

  function copy(text, then) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(function () { then(true); }, function () { then(old(text)); });
      return;
    }
    then(old(text));
  }

  /** The old way — put it in an off-screen box and cut. Returns false when permission is denied. */
  function old(text) {
    var box = document.createElement('textarea');
    box.value = text;
    box.setAttribute('readonly', '');
    box.style.cssText = 'position:fixed;top:-1000px;opacity:0';
    document.body.appendChild(box);
    box.select();
    var ok = false;
    try { ok = document.execCommand('copy'); } catch (e) { ok = false; }
    box.remove();
    return ok;
  }

  /* Open a collapsed section when the URL points inside one — the dial tables are folded per skin,
     so when the table of contents or search sends you to a heading in there and it stays closed,
     it reads as "nothing happened".
     🛑 Recent browsers open it themselves (Chrome 121 · Safari 17.4 and later); older ones do not. */
  function openFor(hash) {
    if (!hash || hash.length < 2) return;
    var target = null;
    try { target = document.getElementById(decodeURIComponent(hash.slice(1))); } catch (e) { return; }
    if (!target) return;
    for (var node = target.parentNode; node && node !== document.body; node = node.parentNode) {
      if (node.tagName === 'DETAILS' && !node.open) node.open = true;
    }
    target.scrollIntoView();
  }
  window.addEventListener('hashchange', function () { openFor(location.hash); });
  if (location.hash) setTimeout(function () { openFor(location.hash); }, 0);

  // Images below the fold are fetched as you scroll.
  document.querySelectorAll('main img:not([loading])').forEach(function (img, i) {
    if (i > 1) img.setAttribute('loading', 'lazy');
    if (!img.hasAttribute('decoding')) img.setAttribute('decoding', 'async');
  });
})();
