# -*- coding: utf-8 -*-
"""gohud 기본 아이콘 세트 — 직접 그린 24x24 선(stroke) 아이콘. 전부 MIT 로 재배포한다.
원·선·사각 같은 자명한 기하 도형만 쓴다(다른 아이콘 폰트의 path 를 복사하지 않았다).
참고로, 아이콘은 커스터마이징하여 stroke 색상을 바꾸거나, stroke-width 를 바꾸거나, fill 색상을 바꾸거나, viewBox 를 바꾸거나, width/height 를 바꾸거나, path 를 추가/삭제/변경할 수 있다."""
import os, sys

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "icons", "default")
os.makedirs(OUT, exist_ok=True)

HEAD = ('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" '
        'fill="none" stroke="#ffffff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">')
TAIL = '</svg>'

# 이름 -> svg 본문 조각
ICONS = {
  # ── 이동·구조 ─────────────────────────────────────────────
  "close":        '<path d="M6 6l12 12M18 6L6 18"/>',
  "back":         '<path d="M19 12H5M11 18l-6-6 6-6"/>',
  "forward":      '<path d="M5 12h14M13 6l6 6-6 6"/>',
  "up":           '<path d="M12 19V5M6 11l6-6 6 6"/>',
  "down":         '<path d="M12 5v14M18 13l-6 6-6-6"/>',
  "chevron_left": '<path d="M15 5l-7 7 7 7"/>',
  "chevron_right":'<path d="M9 5l7 7-7 7"/>',
  "chevron_up":   '<path d="M5 15l7-7 7 7"/>',
  "chevron_down": '<path d="M5 9l7 7 7-7"/>',
  "menu":         '<path d="M4 7h16M4 12h16M4 17h16"/>',
  "more":         '<circle cx="5" cy="12" r="1.4"/><circle cx="12" cy="12" r="1.4"/><circle cx="19" cy="12" r="1.4"/>',
  "external":     '<path d="M14 4h6v6M20 4l-9 9M18 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h5"/>',
  "expand":       '<path d="M4 9V4h5M20 15v5h-5M4 4l6 6M20 20l-6-6"/>',
  "collapse":     '<path d="M10 4v5H5M14 20v-5h5M4 5l5 5M20 19l-5-5"/>',

  # ── 상태·알림 ─────────────────────────────────────────────
  "check":        '<path d="M4 12.5l5 5L20 6.5"/>',
  "info":         '<circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 7.6v.8"/>',
  "warning":      '<path d="M12 3.5 2.6 20h18.8z"/><path d="M12 10v4.5M12 17.4v.6"/>',
  "error":        '<circle cx="12" cy="12" r="9"/><path d="M9 9l6 6M15 9l-6 6"/>',
  "success":      '<circle cx="12" cy="12" r="9"/><path d="M8 12.5l2.8 2.8L16.5 9.6"/>',
  "help":         '<circle cx="12" cy="12" r="9"/><path d="M9.4 9.2a2.7 2.7 0 1 1 3.1 3.3v1.3M12.5 17.1v.6"/>',
  "bell":         '<path d="M18 9a6 6 0 1 0-12 0c0 5-2 6-2 6h16s-2-1-2-6"/><path d="M10.3 20a2 2 0 0 0 3.4 0"/>',
  "clock":        '<circle cx="12" cy="12" r="9"/><path d="M12 7v5.3l3.4 2"/>',
  "hourglass":    '<path d="M7 3h10M7 21h10M8 3v3.6c0 1 .5 2 1.3 2.6L12 11l2.7-1.8A3.2 3.2 0 0 0 16 6.6V3M8 21v-3.6c0-1 .5-2 1.3-2.6L12 13l2.7 1.8c.8.6 1.3 1.6 1.3 2.6V21"/>',

  # ── 사람·소셜 ─────────────────────────────────────────────
  "user":         '<circle cx="12" cy="8" r="3.6"/><path d="M4.5 20a7.5 7.5 0 0 1 15 0"/>',
  "users":        '<circle cx="9" cy="8" r="3.2"/><path d="M2.5 20a6.5 6.5 0 0 1 13 0"/><path d="M16 5.3a3.2 3.2 0 0 1 0 6.2M17.5 14.2A6.5 6.5 0 0 1 21.5 20"/>',
  "user_plus":    '<circle cx="9" cy="8" r="3.4"/><path d="M2.5 20a6.5 6.5 0 0 1 13 0"/><path d="M18.5 8v6M21.5 11h-6"/>',
  "chat":         '<path d="M4 5h16a1 1 0 0 1 1 1v9a1 1 0 0 1-1 1H9l-5 4V6a1 1 0 0 1 1-1z"/>',
  "heart":        '<path d="M12 20.3 4.2 12.6a4.6 4.6 0 0 1 6.5-6.5l1.3 1.3 1.3-1.3a4.6 4.6 0 0 1 6.5 6.5z"/>',
  "star":         '<path d="m12 3.6 2.6 5.4 5.9.8-4.3 4.1 1 5.9-5.2-2.8-5.2 2.8 1-5.9L3.5 9.8l5.9-.8z"/>',
  "crown":        '<path d="M3 7.5 6.8 13 12 5.5 17.2 13 21 7.5V18a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1z"/>',

  # ── 설정·기기 ─────────────────────────────────────────────
  "settings":     '<circle cx="12" cy="12" r="3.2"/><path d="M12 2.6v2.6M12 18.8v2.6M21.4 12h-2.6M5.2 12H2.6M18.6 5.4l-1.8 1.8M7.2 16.8l-1.8 1.8M18.6 18.6l-1.8-1.8M7.2 7.2 5.4 5.4"/>',
  "sliders":      '<path d="M4 7h9M17 7h3M4 17h3M11 17h9"/><circle cx="15" cy="7" r="2"/><circle cx="9" cy="17" r="2"/>',
  "display":      '<rect x="2.5" y="4" width="19" height="12.5" rx="1.6"/><path d="M8.5 20.5h7M12 16.5v4"/>',
  "mobile":       '<rect x="6.5" y="2.5" width="11" height="19" rx="2"/><path d="M10.8 18.6h2.4"/>',
  "volume_high":  '<path d="M4 9.5h3.2L12 5.4v13.2L7.2 14.5H4z"/><path d="M15.6 9.2a4 4 0 0 1 0 5.6M18.2 6.6a7.6 7.6 0 0 1 0 10.8"/>',
  "volume_low":   '<path d="M4 9.5h3.2L12 5.4v13.2L7.2 14.5H4z"/><path d="M15.6 9.2a4 4 0 0 1 0 5.6"/>',
  "volume_off":   '<path d="M4 9.5h3.2L12 5.4v13.2L7.2 14.5H4z"/><path d="M16.2 9.8l5 4.4M21.2 9.8l-5 4.4"/>',
  "eye":          '<path d="M2.2 12S5.8 6 12 6s9.8 6 9.8 6-3.6 6-9.8 6-9.8-6-9.8-6z"/><circle cx="12" cy="12" r="2.8"/>',
  "eye_off":      '<path d="M6.3 6.9C3.8 8.4 2.2 12 2.2 12s3.6 6 9.8 6c1.9 0 3.5-.5 4.9-1.3M9.8 6.3A9.9 9.9 0 0 1 12 6c6.2 0 9.8 6 9.8 6a17 17 0 0 1-3 3.6"/><path d="M10 10a2.8 2.8 0 0 0 4 4M3.5 3.5l17 17"/>',
  "sun":          '<circle cx="12" cy="12" r="4"/><path d="M12 2.6v2M12 19.4v2M21.4 12h-2M4.6 12h-2M18.4 5.6 17 7M7 17l-1.4 1.4M18.4 18.4 17 17M7 7 5.6 5.6"/>',
  "moon":         '<path d="M20.5 14.3A8.8 8.8 0 0 1 9.7 3.5a8.8 8.8 0 1 0 10.8 10.8z"/>',
  "globe":        '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c2.4 2.5 3.6 5.5 3.6 9s-1.2 6.5-3.6 9c-2.4-2.5-3.6-5.5-3.6-9S9.6 5.5 12 3z"/>',

  # ── 동작 ──────────────────────────────────────────────────
  "plus":         '<path d="M12 5v14M5 12h14"/>',
  "minus":        '<path d="M5 12h14"/>',
  "trash":        '<path d="M4 7h16M9.5 7V4.8a1 1 0 0 1 1-1h3a1 1 0 0 1 1 1V7"/><path d="M6.5 7 7.4 20a1 1 0 0 0 1 .9h7.2a1 1 0 0 0 1-.9L17.5 7"/><path d="M10.5 11v6M13.5 11v6"/>',
  "edit":         '<path d="M4 20h4L19.3 8.7a2.1 2.1 0 0 0-3-3L5 17v3z"/><path d="M14.8 6.2l3 3"/>',
  "save":         '<path d="M5 3.5h11L20.5 8v11.5a1 1 0 0 1-1 1h-14a1 1 0 0 1-1-1v-15a1 1 0 0 1 1-1z"/><path d="M8 3.5v5h7v-5M7.5 20.5v-6h9v6"/>',
  "refresh":      '<path d="M20.2 11a8.3 8.3 0 1 0-.6 4.6"/><path d="M20.5 5.5V11h-5.4"/>',
  "search":       '<circle cx="10.8" cy="10.8" r="6.3"/><path d="M15.4 15.4 20.5 20.5"/>',
  "filter":       '<path d="M3.5 5h17l-6.6 7.8V19l-3.8 2v-8.2z"/>',
  "sort":         '<path d="M7 4.5v15M7 4.5 4 8M7 4.5 10 8M17 19.5v-15M17 19.5 14 16M17 19.5 20 16"/>',
  "copy":         '<rect x="8.5" y="8.5" width="12" height="12" rx="1.6"/><path d="M15.5 5.5v-1a1 1 0 0 0-1-1h-10a1 1 0 0 0-1 1v10a1 1 0 0 0 1 1h1"/>',
  "download":     '<path d="M12 3.5v11.5M7.5 10.5 12 15l4.5-4.5"/><path d="M4 18.5v1a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-1"/>',
  "upload":       '<path d="M12 15.5V4M7.5 8.5 12 4l4.5 4.5"/><path d="M4 18.5v1a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-1"/>',
  "play":         '<path d="M7 4.8 19 12 7 19.2z"/>',
  "pause":        '<path d="M9 4.5v15M15 4.5v15"/>',
  "stop":         '<rect x="5.5" y="5.5" width="13" height="13" rx="1.6"/>',
  "power":        '<path d="M12 3.5v8"/><path d="M17.3 6.7a7.5 7.5 0 1 1-10.6 0"/>',
  "logout":       '<path d="M14.5 3.5h4a1 1 0 0 1 1 1v15a1 1 0 0 1-1 1h-4"/><path d="M10 8.5 14.5 12 10 15.5M14.5 12h-11"/>',
  "login":        '<path d="M9.5 3.5h-4a1 1 0 0 0-1 1v15a1 1 0 0 0 1 1h4"/><path d="M15.5 8.5 20 12l-4.5 3.5M20 12H9"/>',

  # ── 보호·소유 ─────────────────────────────────────────────
  "lock":         '<rect x="4.5" y="10" width="15" height="10.5" rx="1.8"/><path d="M8 10V7.4a4 4 0 1 1 8 0V10"/>',
  "unlock":       '<rect x="4.5" y="10" width="15" height="10.5" rx="1.8"/><path d="M8 10V7.4A4 4 0 0 1 15.7 6"/>',
  "shield":       '<path d="M12 3 4.5 6v6c0 4.6 3.1 7.9 7.5 9.3 4.4-1.4 7.5-4.7 7.5-9.3V6z"/>',
  "shield_check": '<path d="M12 3 4.5 6v6c0 4.6 3.1 7.9 7.5 9.3 4.4-1.4 7.5-4.7 7.5-9.3V6z"/><path d="M8.8 11.8 11.3 14.3 15.6 10"/>',
  "key":          '<circle cx="8" cy="8" r="4.2"/><path d="M11 11 20 20M17 17l2-2M14.5 14.5l2.5-2.5"/>',

  # ── 장소·물건 ─────────────────────────────────────────────
  "home":         '<path d="M3.5 10.5 12 3.5l8.5 7"/><path d="M5.5 9.4v10.1a1 1 0 0 0 1 1h11a1 1 0 0 0 1-1V9.4"/><path d="M9.8 20.5v-6h4.4v6"/>',
  "map":          '<path d="M9 4.5 3.5 6.8v12.7L9 17.2l6 2.3 5.5-2.3V4.5L15 6.8z"/><path d="M9 4.5v12.7M15 6.8v12.7"/>',
  "location":     '<path d="M12 21.5s7-6.1 7-11.2a7 7 0 1 0-14 0c0 5.1 7 11.2 7 11.2z"/><circle cx="12" cy="10" r="2.6"/>',
  "bag":          '<path d="M4.5 7.5h15l-1 12a1 1 0 0 1-1 .9H6.5a1 1 0 0 1-1-.9z"/><path d="M8.8 10V6.6a3.2 3.2 0 1 1 6.4 0V10"/>',
  "box":          '<path d="M3.5 7.8 12 3.5l8.5 4.3v8.4L12 20.5l-8.5-4.3z"/><path d="M3.5 7.8 12 12.1l8.5-4.3M12 12.1v8.4"/>',
  "coin":         '<ellipse cx="12" cy="7" rx="7.5" ry="3.4"/><path d="M4.5 7v10c0 1.9 3.4 3.4 7.5 3.4s7.5-1.5 7.5-3.4V7"/><path d="M4.5 12c0 1.9 3.4 3.4 7.5 3.4s7.5-1.5 7.5-3.4"/>',
  "gift":         '<rect x="3.5" y="8.5" width="17" height="4" rx="1"/><path d="M5.2 12.5v7a1 1 0 0 0 1 1h11.6a1 1 0 0 0 1-1v-7M12 8.5v12"/><path d="M12 8.5 9.4 5.9a2.2 2.2 0 1 1 2.6-2.6 2.2 2.2 0 1 1 2.6 2.6z"/>',
  "book":         '<path d="M4 4.5h6a3 3 0 0 1 2 1 3 3 0 0 1 2-1h6v13h-6a3 3 0 0 0-2 1 3 3 0 0 0-2-1H4z"/><path d="M12 5.5v13"/>',

  # ── 목록·배치 ─────────────────────────────────────────────
  "list":         '<path d="M8.5 6.5h12M8.5 12h12M8.5 17.5h12"/><circle cx="4.3" cy="6.5" r="1.3"/><circle cx="4.3" cy="12" r="1.3"/><circle cx="4.3" cy="17.5" r="1.3"/>',
  "grid":         '<rect x="3.5" y="3.5" width="7" height="7" rx="1.4"/><rect x="13.5" y="3.5" width="7" height="7" rx="1.4"/><rect x="3.5" y="13.5" width="7" height="7" rx="1.4"/><rect x="13.5" y="13.5" width="7" height="7" rx="1.4"/>',
  "columns":      '<rect x="3.5" y="4.5" width="17" height="15" rx="1.6"/><path d="M9.2 4.5v15M14.8 4.5v15"/>',
  "chart":        '<path d="M4 20V4"/><path d="M4 20h16"/><path d="M8 17v-5M12.5 17V8M17 17v-8"/>',

  # ── 게임 ──────────────────────────────────────────────────
  "sword":        '<path d="M20.5 3.5 12 12l-1.5 4 4-1.5 8.5-8.5z"/><path d="M10.5 16 4 22.5M6.5 15.5 8.5 17.5M8.5 13.5l2 2"/>',
  "bolt":         '<path d="M13.5 2.5 4.5 13.5h6L10 21.5l9.5-11.5h-6.4z"/>',
  "target":       '<circle cx="12" cy="12" r="8.5"/><circle cx="12" cy="12" r="4.6"/><circle cx="12" cy="12" r="1.1"/>',
  "flag":         '<path d="M5 21V3.8"/><path d="M5 4.5h11l-2 3.4 2 3.4H5z"/>',
  "potion":       '<path d="M10 3h4M11 3v4.6L6.8 16a3.6 3.6 0 0 0 3.2 5.2h4a3.6 3.6 0 0 0 3.2-5.2L13 7.6V3"/><path d="M8 14.5h8"/>',
  "skull":        '<path d="M12 3a8 8 0 0 0-8 8c0 2.8 1.4 4.5 2.6 5.4.5.4.9 1 .9 1.7v1.4a1 1 0 0 0 1 1h7a1 1 0 0 0 1-1v-1.4c0-.7.3-1.3.9-1.7C18.6 15.5 20 13.8 20 11a8 8 0 0 0-8-8z"/><circle cx="9" cy="11.5" r="1.7"/><circle cx="15" cy="11.5" r="1.7"/>',
  "run":          '<circle cx="14.5" cy="4.8" r="2"/><path d="M8 21.5l3-5.2-2.6-2.9 1.2-4.9 3.9-1.3 3 2.8 3 .9"/><path d="M11.4 13.4 15 16.2l1.6 5.3M10.5 8.4 6.5 9.8 5 13.5"/>',
}

for name, body in ICONS.items():
    with open(os.path.join(OUT, name + ".svg"), "w", encoding="utf-8") as fh:
        fh.write(HEAD + body + TAIL + "\n")

print("아이콘 %d개 생성: %s" % (len(ICONS), OUT))
print(" ".join(sorted(ICONS)))
