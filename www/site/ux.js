/* gohud 홈페이지 — 작은 손질 두 가지.
 *
 * 1. **코드 복사 단추** — 이 사이트의 코드 칸은 그대로 붙여 넣어 돌아가는 조각이다. 끌어서 고르다
 *    보면 줄 번호도 없는데 앞뒤 공백이 딸려 온다. 손을 올린 칸에만 단추가 뜬다.
 * 2. **그림 늦게 받기** — 스크린샷이 열 몇 장이라 첫 화면과 상관없는 것까지 한꺼번에 받으면 느리다.
 *
 * 🛑 CSS 는 `site/style.css` 의 `.gocopy` 규칙을 쓴다(이 파일은 스타일을 넣지 않는다).
 * 🛑 `navigator.clipboard` 는 `file://` 와 http 에서 막힌다 — 옛 방식으로 되돌아간다.
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

  /** 옛 방식 — 화면 밖 칸에 넣고 잘라낸다. 권한이 없으면 false 를 돌려준다. */
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

  /* 접힌 곳 안의 주소로 들어오면 열어 준다 — 다이얼 표는 스킨마다 접혀 있어서, 목차나 검색이
     그 안의 제목으로 데려가도 닫힌 채면 "아무 일도 안 일어난 것" 처럼 보인다.
     🛑 최신 브라우저는 스스로 열지만(Chrome 121·Safari 17.4 이후) 그 전 판에서는 열리지 않는다. */
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

  // 첫 화면에 없는 그림은 스크롤할 때 받는다.
  document.querySelectorAll('main img:not([loading])').forEach(function (img, i) {
    if (i > 1) img.setAttribute('loading', 'lazy');
    if (!img.hasAttribute('decoding')) img.setAttribute('decoding', 'async');
  });
})();
