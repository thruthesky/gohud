# -*- coding: utf-8 -*-
"""gohud 기본 테마(.tres)와 테마별 컨트롤 그림(SVG) 생성기.

    python3 addons/gohud/tools/make_theme.py          # themes/*.tres 와 assets/<테마>/*.svg 를 다시 만든다

손으로 쓰면 색 하나를 바꿀 때 수십 군데를 고쳐야 해서 팔레트에서 계산해 내보낸다.
어두운 테마와 밝은 테마가 **같은 토큰 이름**을 갖는 것이 핵심이다 — 그래야 통째로 갈아 끼워도
위젯 코드가 그대로 돈다.

🛑 토글·체크박스·슬라이더 손잡이·드롭다운/접기 화살표는 **테마마다 따로 그린다.** 엔진은 이
   테마 아이콘들에 색을 입히지 않고 그림 그대로 그린다 — 흰 그림 하나로 두 테마를 쓰면 밝은
   테마에서 흰 바탕에 흰 토글이 되어 보이지 않는다(2026-09-12 발견).
🛑 새 SVG 에는 DPITexture 임포트 설정(.import)을 함께 쓴다 — UI 배율이 커져도 다시 래스터화된다.
   이미 있는 .import 는 건드리지 않는다(에디터가 붙인 uid 를 지키기 위해).
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.normpath(os.path.join(HERE, ".."))
RES = "res://addons/gohud"


def hexc(h, a=1.0):
    h = h.lstrip('#')
    r, g, b = (int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    return (round(r, 6), round(g, 6), round(b, 6), round(a, 6))


def C(c):
    return "Color(%g, %g, %g, %g)" % c


def mix(c1, c2, t):
    return tuple(round(c1[i] + (c2[i] - c1[i]) * t, 6) for i in range(4))


def alpha(c, a):
    return (c[0], c[1], c[2], round(a, 6))


def svg_hex(c):
    return "#%02x%02x%02x" % tuple(int(round(v * 255)) for v in c[:3])


# ── 대비 보정 ───────────────────────────────────────────────────────────
#
# 🛑 **강조색 글자를 그 강조색의 옅은 배경 위에 얹으면 반드시 읽기 어려워진다.** 눌린 버튼(accent
#    틴트 배경 + accent 글자), 위험 버튼(danger 틴트 배경 + danger 글자)이 그렇다 — 색은 예쁜데
#    같은 색끼리라 명도 차가 나지 않는다. 팔레트를 손으로 고를 때마다 이 함정에 다시 빠지므로,
#    **글자색을 배경에 맞춰 자동으로 밀어낸다.** 그래야 팔레트만 바꿔도 대비가 따라온다.

def _linear(v):
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def luminance(c):
    return 0.2126 * _linear(c[0]) + 0.7152 * _linear(c[1]) + 0.0722 * _linear(c[2])


def contrast(front, back):
    a, b = luminance(front), luminance(back)
    hi, lo = max(a, b), min(a, b)
    return (hi + 0.05) / (lo + 0.05)


def flatten(top, bottom):
    """알파를 깔린 색 위에 합성해 **실제로 보이는 색**으로."""
    a = top[3]
    if a >= 1.0:
        return top
    return tuple(top[i] * a + bottom[i] * (1.0 - a) for i in range(3)) + (1.0,)


def readable_everywhere(ink, backs, need=4.6, rounds=6):
    """`ink` 가 **주어진 배경 전부**에서 `need` 를 넘게 민다.

    🛑 한 배경씩 차례로 밀면 마지막 것만 맞는다 — 어두운 표면에 맞춰 밝힌 색이 밝은 표면에서 다시
       무너지기 때문이다. 그래서 **매번 가장 나쁜 배경을 다시 찾아** 그쪽으로 민다.
    """
    out = ink
    for _round in range(rounds):
        worst = min(backs, key=lambda b: contrast(flatten(out, b), b))
        if contrast(flatten(out, worst), worst) >= need:
            break
        out = readable(out, worst, need)
    return out


def fill_color(base, track, need=3.0, vivid=None):
    """막대 채움용 — 막대 **바탕 위에서** 눈에 들어오는 선명한 색.

    글자와 달리 4.5 가 아니라 3:1 이면 된다(글이 아니라 면이다). 대신 **채도를 올려** 회색으로
    가라앉지 않게 한다 — 어두운 색을 그냥 밝히면 탁해진다.

    🛑 **색만으로 대비를 맞추려 하면 안 되는 색이 있다.** 노랑은 휘도가 본래 높아 어떤 회색 바탕
       위에서도 3:1 이 나오지 않고, 기준을 맞추려 명도를 내리면 경험치 막대가 **갈색**이 된다
       (밝은 테마에서 실제로 `#A05000` 이었다 — 2026-09-13). 그런 테마는 `*_vivid` 로 채움 전용
       원색을 주고, 경계는 `GoSkin._edge_fill` 이 그리는 **윤곽**이 책임진다.
    """
    import colorsys
    if vivid is not None:
        h, l, s = colorsys.rgb_to_hls(vivid[0], vivid[1], vivid[2])
        r, g, b = colorsys.hls_to_rgb(h, l, min(1.0, s * 1.1 + 0.04))
        return (round(r, 6), round(g, 6), round(b, 6), 1.0)
    h, l, s = colorsys.rgb_to_hls(base[0], base[1], base[2])
    s = min(1.0, s * 1.25 + 0.06)
    best = None
    for i in range(0, 90):
        nl = min(0.72, l + 0.01 * i)
        r, g, b = colorsys.hls_to_rgb(h, nl, s)
        cand = (round(r, 6), round(g, 6), round(b, 6), 1.0)
        if best is None:
            best = cand
        if contrast(cand, track) >= need:
            return cand
        best = cand
    return best


def readable(ink, back, need=4.5, limit=0.9):
    """`ink` 를 `back` 위에서 `need` 를 넘을 때까지 민다 — 색조는 지키고 **명도만** 옮긴다.

    배경이 밝으면 어둡게, 어두우면 밝게 간다. `limit` 까지 밀어도 안 되면 그 지점에서 멈춘다
    (여기서 흑백으로 튀면 팔레트의 성격이 통째로 사라진다 — 읽히는 것과 별개로 그것은 실패다).
    """
    flat = flatten(ink, back)
    if contrast(flat, back) >= need:
        return ink
    darken = luminance(back) > 0.22
    import colorsys
    h, l, s = colorsys.rgb_to_hls(flat[0], flat[1], flat[2])
    step = -0.01 if darken else 0.01
    for i in range(1, 100):
        nl = min(limit, max(1.0 - limit, l + step * i))
        r, g, b = colorsys.hls_to_rgb(h, nl, s)
        if contrast((r, g, b, 1.0), back) >= need:
            return (round(r, 6), round(g, 6), round(b, 6), 1.0)
    return ink


DARK = dict(
    background=hexc("0E1117"), surface=hexc("1C222D"), surface_soft=hexc("282F3D"),
    surface_high=hexc("313B4C"), border=hexc("4B5A70", 0.85), text=hexc("F2F5F9"),
    secondary=hexc("A8B3C2"), muted=hexc("919BAC"), accent=hexc("56CCF2"),
    on_accent=hexc("0B1016"), success=hexc("5FD9A6"), warning=hexc("F5C563"),
    danger=hexc("F27272"), info=hexc("7EA6FF"), scrim=hexc("000000", 0.32),
    shadow=hexc("000000", 0.80), track=hexc("070B11", 0.90),
)

LIGHT = dict(
    background=hexc("E7ECF3"), surface=hexc("FFFFFF"), surface_soft=hexc("D1DAE6"),
    surface_high=hexc("BDC8DC"), border=hexc("8492A8", 0.85), text=hexc("121721"),
    secondary=hexc("47536A"), muted=hexc("5D687E"), accent=hexc("0D7DB3"),
    on_accent=hexc("FFFFFF"), success=hexc("15764F"), warning=hexc("9A5407"),
    danger=hexc("C02F2F"), info=hexc("2A5BD7"), scrim=hexc("1B2432", 0.28),
    shadow=hexc("10161F", 0.30), track=hexc("D3DAE5", 0.95),
    # 막대 채움 전용 — 글자로 읽히려고 어두워진 색 대신 **원색**을 쓴다. 경계는 윤곽이 만든다.
    success_vivid=hexc("10A86B"), warning_vivid=hexc("F2A007"),
    danger_vivid=hexc("DC3545"), info_vivid=hexc("2F6FE0"),
    accent_vivid=hexc("0E9AD8"),
)

CONST = dict(
    touch=48, button_height=52,
    gap_tiny=4, gap_small=8, gap=12, gap_large=20,
    padding=20, padding_compact=12,
    # 작은 버튼 판의 좌우·위아래 여백 — 표면 여백(`padding_compact`)과 따로 둔다. 형태 dict 가 덮어쓸 수 있다.
    compact_padding_x=10, compact_padding_y=5,
    radius=12, radius_small=8, radius_large=18,
    screen_margin=16,
    scroll_deadzone=18, scroll_edge=4, scrollbar_width=6,
    list_glyph=18, icon_size=20,
    notice_duration_ms=3000,
    # 🪟 판(컨테이너) 바탕의 **불투명도(%)** — 100 은 꽉 찬 색, 80 이면 뒤가 20% 배어 나온다.
    #    글자·아이콘·버튼은 이 값을 따르지 않는다(`core/go_theme.gd` 의 `PANEL_ALPHA` 주석).
    # 🛑 `popup_alpha` 만 100 이다 — `PopupMenu` 는 엔진이 **창**으로 띄울 수 있고, 그때는 OS 가
    #    게임 화면과 합성해 주지 않아 반투명이 뒤가 보이는 대신 검게 나온다.
    #    게임 안에 박아 띄우는(`gui_embed_subwindows`) 프로젝트는 팔레트에서 내려도 된다.
    panel_alpha=80, card_alpha=80, hud_alpha=80, notice_alpha=80, popup_alpha=100,
)

FONTS = dict(micro=10, compact=12, caption=13, body=16, button=16, subtitle=22, title=28)

SCIFI_DARK = dict(
    background=hexc("05080E"), surface=hexc("121D2E"), surface_soft=hexc("1A2B42"),
    surface_high=hexc("213754"), border=hexc("3D8FB5", 0.90), text=hexc("D8F4FF"),
    secondary=hexc("7FB4CC"), muted=hexc("6791AD"), accent=hexc("00E5FF"),
    on_accent=hexc("03121A"), success=hexc("3BFFA5"), warning=hexc("FFC53D"),
    danger=hexc("FF4D6D"), info=hexc("5B8CFF"), scrim=hexc("000914", 0.55),
    shadow=hexc("00E5FF", 0.35), track=hexc("04090F", 0.95),
)

# 설계도(blueprint) 느낌 — 밝은 바탕에 청록 선. 어두운 sci-fi 와 **같은 형태**를 쓴다.
SCIFI_LIGHT = dict(
    background=hexc("E0E8EE"), surface=hexc("F7FAFC"), surface_soft=hexc("C8D8E2"),
    surface_high=hexc("AEC8D8"), border=hexc("2F6E8A", 0.90), text=hexc("071A26"),
    secondary=hexc("2E5A70"), muted=hexc("466372"), accent=hexc("007EA9"),
    on_accent=hexc("FFFFFF"), success=hexc("0A7A55"), warning=hexc("96500A"),
    danger=hexc("BE2B43"), info=hexc("2A5BD7"), scrim=hexc("0A1A24", 0.35),
    shadow=hexc("0086B3", 0.28), track=hexc("C6D6DF", 0.95),
    # 막대 채움 전용 — sci-fi 는 한 단계 더 형광에 가깝게 간다.
    success_vivid=hexc("00BE7B"), warning_vivid=hexc("FFAE00"),
    danger_vivid=hexc("E82749"), info_vivid=hexc("2F7BFF"),
    accent_vivid=hexc("00AEE0"),
)


# ── 형태(shape) — "무슨 색인가" 와 별개로 "어떤 모양인가" ────────────────
#
# 🛑 `SHAPE_DEFAULT` 는 gohud 원래 모양의 **정본**이다. 여기 숫자를 하나라도 바꾸면 기존 두 테마의
#    생김새가 바뀐다. 새 생김새는 **새 dict 를 더해서** 만든다 — 이것을 고쳐서 만들지 않는다.

SHAPE_DEFAULT = dict(
    kind="flat",         # StyleBoxFlat — 둥근 모서리
    controls="rounded",  # 토글·체크·라디오·손잡이 그림의 계열
)

SHAPE_CUT = dict(
    kind="cut",          # GoStyleBoxCut — 사선으로 잘린 모서리
    controls="cut",
    cut_ratio=0.85,      # 잘라 내는 크기 = 원래 반경 × 이 값
    cut_max=14,          # 아무리 큰 반경이라도 이보다 크게 자르지 않는다
    corners="diagonal",  # 좌상 + 우하만 자른다 — 한쪽으로 흐르는 느낌
    glow=8,              # 그림자가 있던 자리에 넣을 발광 거리
    edge=2,              # 한 변만 굵게 긋는 강조 변의 두께
)

CUT_SCRIPT = RES + "/widgets/go_stylebox_cut.gd"
MEDIEVAL_SCRIPT = RES + "/widgets/go_stylebox_medieval.gd"
BRACKET_SCRIPT = RES + "/widgets/go_stylebox_bracket.gd"

# `corners=(tl, tr, br, bl)` → GoStyleBoxCut 의 비트마스크
CUT_TOP_LEFT, CUT_TOP_RIGHT, CUT_BOTTOM_RIGHT, CUT_BOTTOM_LEFT = 1, 2, 4, 8
CUT_DIAGONAL = CUT_TOP_LEFT | CUT_BOTTOM_RIGHT
CUT_ALL = CUT_TOP_LEFT | CUT_TOP_RIGHT | CUT_BOTTOM_RIGHT | CUT_BOTTOM_LEFT


# ── 테마별 컨트롤 그림 ───────────────────────────────────────────────────

def control_svgs(pal, shape=SHAPE_DEFAULT):
    acc, on, mut, sec, hi = (svg_hex(pal[k]) for k in ("accent", "on_accent", "muted", "secondary", "surface_high"))

    def wrap(w, h, body, disabled=False):
        group = '<g opacity=".38">%s</g>' % body if disabled else body
        return '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">%s</svg>' % (w, h, w, h, group)

    def toggle(state_on, disabled, mirrored):
        knob_x = 28 if state_on != mirrored else 12
        if state_on:
            # 켜짐 — 채운 트랙 + 대비색 손잡이(Material 3 의 primary / on-primary 짝)
            body = ('<rect x="1" y="1" width="38" height="22" rx="11" fill="%s"/>'
                    '<circle cx="%d" cy="12" r="8" fill="%s"/>') % (acc, knob_x, on)
        else:
            # 꺼짐 — 테두리 트랙 + 작은 흐린 손잡이. 켜짐과 모양이 달라 색을 못 봐도 구분된다.
            body = ('<rect x="1.75" y="1.75" width="36.5" height="20.5" rx="10.25" fill="%s" stroke="%s" stroke-width="1.5"/>'
                    '<circle cx="%d" cy="12" r="6" fill="%s"/>') % (hi, mut, knob_x, mut)
        return wrap(40, 24, body, disabled)

    def check(state_on, disabled):
        if state_on:
            body = ('<rect x="1" y="1" width="18" height="18" rx="5" fill="%s"/>'
                    '<path d="M5.5 10.2 8.6 13.3 14.6 7.2" fill="none" stroke="%s" stroke-width="2" '
                    'stroke-linecap="round" stroke-linejoin="round"/>') % (acc, on)
        else:
            body = '<rect x="1.75" y="1.75" width="16.5" height="16.5" rx="4.5" fill="none" stroke="%s" stroke-width="1.5"/>' % mut
        return wrap(20, 20, body, disabled)

    def radio(state_on, disabled):
        if state_on:
            body = ('<circle cx="10" cy="10" r="9" fill="%s"/>'
                    '<circle cx="10" cy="10" r="3.6" fill="%s"/>') % (acc, on)
        else:
            body = '<circle cx="10" cy="10" r="8.25" fill="none" stroke="%s" stroke-width="1.5"/>' % mut
        return wrap(20, 20, body, disabled)

    def arrow(path):
        return ('<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16" fill="none" '
                'stroke="%s" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="%s"/></svg>') % (sec, path)

    # ── 각진 계열 ──────────────────────────────────────────────────────
    # 🛑 둥근 것을 그대로 쓰면 판만 각지고 토글·체크는 알약·원으로 남아 **한 화면에 두 문법**이 섞인다.
    #    엔진은 이 그림들에 색조차 입히지 않으므로 테마마다 새로 그리는 수밖에 없다.

    def points(x, y, w, h, c, every=False):
        if every:
            return [(x + c, y), (x + w - c, y), (x + w, y + c), (x + w, y + h - c),
                    (x + w - c, y + h), (x + c, y + h), (x, y + h - c), (x, y + c)]
        return [(x + c, y), (x + w, y), (x + w, y + h - c), (x + w - c, y + h), (x, y + h), (x, y + c)]

    def poly(pts, fill="none", stroke=None, width=1.5):
        body = '<polygon points="%s" fill="%s"' % (" ".join("%g,%g" % p for p in pts), fill)
        if stroke:
            body += ' stroke="%s" stroke-width="%g" stroke-linejoin="miter"' % (stroke, width)
        return body + "/>"

    def diamond(cx, cy, r):
        return [(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)]

    def cut_toggle(state_on, disabled, mirrored):
        knob_x = 27 if state_on != mirrored else 13
        if state_on:
            body = (poly(points(1, 1, 38, 22, 6), fill=acc)
                    + poly(points(knob_x - 6, 5, 12, 14, 4), fill=on))
        else:
            body = (poly(points(1.75, 1.75, 36.5, 20.5, 6), fill=hi, stroke=mut)
                    + poly(points(knob_x - 5, 7, 10, 10, 3), fill=mut))
        return wrap(40, 24, body, disabled)

    def cut_check(state_on, disabled):
        if state_on:
            body = (poly(points(1, 1, 18, 18, 5), fill=acc)
                    + '<path d="M5 10 8.8 13.8 15 6.8" fill="none" stroke="%s" stroke-width="2.2" '
                      'stroke-linecap="square" stroke-linejoin="miter"/>' % on)
        else:
            body = poly(points(1.75, 1.75, 16.5, 16.5, 5), stroke=mut)
        return wrap(20, 20, body, disabled)

    def cut_radio(state_on, disabled):
        if state_on:
            body = poly(diamond(10, 10, 9), fill=acc) + poly(diamond(10, 10, 3.6), fill=on)
        else:
            body = poly(diamond(10, 10, 8.25), stroke=mut)
        return wrap(20, 20, body, disabled)

    def hexagon(cx, cy, r):
        return [(cx - r * 0.5, cy - r), (cx + r * 0.5, cy - r), (cx + r, cy),
                (cx + r * 0.5, cy + r), (cx - r * 0.5, cy + r), (cx - r, cy)]

    def cut_arrow(path):
        return ('<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16" fill="none" '
                'stroke="%s" stroke-width="2" stroke-linecap="square" stroke-linejoin="miter"><path d="%s"/></svg>') % (sec, path)

    angular = shape.get("controls") == "cut"
    if angular:
        toggle, check, radio, arrow = cut_toggle, cut_check, cut_radio, cut_arrow

    out = {}
    for state_on in (True, False):
        for disabled in (False, True):
            for mirrored in (False, True):
                name = "toggle_%s%s%s" % ("on" if state_on else "off", "_disabled" if disabled else "", "_mirrored" if mirrored else "")
                out[name] = toggle(state_on, disabled, mirrored)
        for disabled in (False, True):
            out["check_%s%s" % ("on" if state_on else "off", "_disabled" if disabled else "")] = check(state_on, disabled)
            out["radio_%s%s" % ("on" if state_on else "off", "_disabled" if disabled else "")] = radio(state_on, disabled)
    if angular:
        out["grabber"] = wrap(20, 20, poly(hexagon(10, 10, 8), fill=acc))
        out["grabber_highlight"] = wrap(20, 20, poly(hexagon(10, 10, 10), fill=acc) .replace('fill="%s"' % acc, 'fill="%s" fill-opacity=".22"' % acc) + poly(hexagon(10, 10, 8), fill=acc))
        out["grabber_disabled"] = wrap(20, 20, poly(hexagon(10, 10, 7), fill=mut))
    else:
        out["grabber"] = wrap(20, 20, '<circle cx="10" cy="10" r="8" fill="%s"/>' % acc)
        out["grabber_highlight"] = wrap(20, 20, '<circle cx="10" cy="10" r="10" fill="%s" fill-opacity=".22"/><circle cx="10" cy="10" r="8" fill="%s"/>' % (acc, acc))
        out["grabber_disabled"] = wrap(20, 20, '<circle cx="10" cy="10" r="7" fill="%s"/>' % mut)
    out["arrow_down"] = arrow("M4 6l4 4 4-4")
    out["arrow_right"] = arrow("M6 4l4 4-4 4")
    out["arrow_left"] = arrow("M10 4 6 8l4 4")
    return out


IMPORT_TEMPLATE = ('[remap]\n\nimporter="svg"\ntype="DPITexture"\n\n[deps]\n\nsource_file="%s"\n\n[params]\n\n'
                   'base_scale=1.0\nsaturation=1.0\ncolor_map={}\nfix_alpha_border=false\npremult_alpha=false\ncompress=true\n')


def write_assets(variant, pal, shape):
    folder = os.path.join(ADDON, "assets", variant)
    os.makedirs(folder, exist_ok=True)
    names = []
    for name, svg in control_svgs(pal, shape).items():
        path = os.path.join(folder, name + ".svg")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(svg + "\n")
        importer = path + ".import"
        if not os.path.exists(importer):
            with open(importer, "w", encoding="utf-8") as fh:
                fh.write(IMPORT_TEMPLATE % ("%s/assets/%s/%s.svg" % (RES, variant, name)))
        names.append(name)
    return names


# ── StyleBox ────────────────────────────────────────────────────────────

def flat(bg=None, border=None, bw=0, radius=0, margins=None, shadow=None, shadow_offset=None,
         draw_center=True, corners=None, borders=None):
    out = []
    if margins:
        for side, value in zip(("left", "top", "right", "bottom"), margins):
            out.append("content_margin_%s = %g" % (side, value))
    if not draw_center:
        out.append("draw_center = false")
    if bg is not None:
        out.append("bg_color = %s" % C(bg))
    widths = borders if borders is not None else ((bw,) * 4 if bw else None)
    if widths and any(widths):
        for side, value in zip(("left", "top", "right", "bottom"), widths):
            if value:
                out.append("border_width_%s = %d" % (side, value))
        out.append("border_color = %s" % C(border))
    radii = corners if corners is not None else ((radius,) * 4 if radius else None)
    if radii and any(radii):
        for corner, value in zip(("top_left", "top_right", "bottom_right", "bottom_left"), radii):
            if value:
                out.append("corner_radius_%s = %d" % (corner, value))
        out.append("corner_detail = 8")
    if shadow is not None:
        out.append("shadow_color = %s" % C(shadow[0]))
        out.append("shadow_size = %d" % shadow[1])
        if shadow_offset:
            out.append("shadow_offset = Vector2(%g, %g)" % shadow_offset)
    return out


def cut(shape, bg=None, border=None, bw=0, radius=0, margins=None, shadow=None, shadow_offset=None,
        draw_center=True, corners=None, borders=None, edge=None, glow=None):
    """`flat()` 과 **같은 인자**를 받아 각진 판(GoStyleBoxCut)으로 번역한다.

    같은 인자를 받는 것이 핵심이다 — 그래야 `build()` 안의 박스 정의를 한 줄도 고치지 않고
    형태만 갈아 끼울 수 있다. 둥근 반경은 자르는 크기가 되고, 한 변짜리 테두리는 강조 변이,
    그림자는 발광이 된다.
    """
    out = ['script = ExtResource("cut")']   # 🛑 맨 앞 — 이 줄보다 뒤에 와야 커스텀 칸이 인식된다
    if margins:
        for side, value in zip(("left", "top", "right", "bottom"), margins):
            out.append("content_margin_%s = %g" % (side, value))
    if not draw_center:
        out.append("draw_center = false")
    if bg is not None:
        out.append("bg_color = %s" % C(bg))

    base = max([radius] + list(corners or []))
    out.append("cut = %g" % min(base * shape["cut_ratio"], shape["cut_max"]))
    if corners is not None:
        mask = 0
        for value, bit in zip(corners, (CUT_TOP_LEFT, CUT_TOP_RIGHT, CUT_BOTTOM_RIGHT, CUT_BOTTOM_LEFT)):
            if value:
                mask |= bit
    else:
        mask = CUT_DIAGONAL if shape["corners"] == "diagonal" else CUT_ALL
    out.append("cut_corners = %d" % mask)

    widths = borders if borders is not None else ((bw,) * 4 if bw else None)
    if widths and any(widths):
        # 인덱스 0·1·2·3 이 그대로 SIDE_LEFT·TOP·RIGHT·BOTTOM 이다.
        marked = [index for index, value in enumerate(widths) if value]
        if len(marked) == 1 and edge is None:
            # 한 변만 그리는 것(탭 밑줄)은 테두리가 아니라 **강조 변**이다.
            out.append("border_width = 0.0")
            out.append("edge_color = %s" % C(border))
            out.append("edge_width = %g" % widths[marked[0]])
            out.append("edge_side = %d" % marked[0])
            edge = None
        else:
            out.append("border_width = %g" % max(widths))
            out.append("border_color = %s" % C(border))
    else:
        out.append("border_width = 0.0")

    if edge is not None:
        out.append("edge_color = %s" % C(edge))
        out.append("edge_width = %g" % shape["edge"])
        out.append("edge_side = 1")     # 위쪽

    # 발광 — `glow` 로 직접 준 것이 먼저, 없으면 그림자가 있던 자리를 대신한다.
    if glow is not None:
        out.append("glow_color = %s" % C(glow[0]))
        out.append("glow_size = %g" % glow[1])
    elif shadow is not None:
        out.append("glow_color = %s" % C(shadow[0]))
        out.append("glow_size = %g" % min(shadow[1], shape["glow"]))
    return out


def medieval(shape, bid, **kw):
    """Reuse the shared component palette/metrics with an opt-in forged frame."""
    out = ['script = ExtResource("medieval")']
    for side, value in zip(("left", "top", "right", "bottom"), kw.get("margins") or (0, 0, 0, 0)):
        out.append("content_margin_%s = %g" % (side, value))
    for name in ("bg_color", "border_color"):
        source = "bg" if name == "bg_color" else "border"
        if kw.get(source) is not None:
            out.append("%s = %s" % (name, C(kw[source])))
    out.append("border_width = %g" % max(kw.get("borders") or [kw.get("bw", 0)]))
    out.append("radius = %g" % min(shape.get("radius_large", 6), max([kw.get("radius", 0)] + list(kw.get("corners") or []))))
    out.append("draw_center = %s" % ("true" if kw.get("draw_center", True) else "false"))
    ornate = bid in ("panel", "panel_solid", "card", "popup", "fold_panel")
    quiet = bid in ("hud", "bar_bg", "bar_fill", "separator", "menu_separator", "menu_hover") or bid.startswith(("scroll_", "slider_", "list_"))
    out.append("ornament = %d" % (0 if quiet else 2 if ornate else 1))
    out.append("material = %d" % shape.get("material", 1))
    for key, default in (("ornament_scale", 1.0), ("grain_alpha", 0.035), ("bevel_strength", 0.18)):
        out.append("%s = %g" % (key, 0.0 if quiet and key == "grain_alpha" else shape.get(key, default)))
    shadow = kw.get("shadow")
    if shadow is not None:
        out += ["shadow_color = %s" % C(shadow[0]), "shadow_size = %d" % shadow[1]]
        if kw.get("shadow_offset"):
            out.append("shadow_offset = Vector2(%g, %g)" % tuple(kw["shadow_offset"]))
    return out


def build(pal, shape, variant, out_path):
    # 🔑 **글자로 쓰이는 색은 손으로 고르지 않는다.** 표면 계층을 한 단계만 조정해도 흐린 글자가
    #    곧바로 기준 아래로 떨어진다(2026-09-13: 표면을 벌렸더니 `muted` 가 네 테마 모두 미달로 돌아갔다).
    #    팔레트에 적힌 값을 **출발점**으로 삼아, 실제로 얹히는 표면 전부에서 읽히는 자리까지 민다.
    pal = dict(pal)
    # 🛑 **채움은 글자용으로 민 값에서 출발하면 안 된다.** 아래 `settle()` 은 색을 배경에서 읽히도록
    #    어둡게/밝게 미는데, 막대 채움의 요구는 그 반대다. 보정 전 값을 따로 남겨 둔다.
    raw = dict(pal)
    _bg = flatten(pal["background"], (0, 0, 0, 1.0))
    _surfaces = [_bg] + [flatten(pal[key], _bg) for key in ("surface", "surface_soft", "surface_high")]
    # 🔑 **무엇을 얼마나 밀었는지 알려 준다.** 말없이 바꾸면 자기 팔레트를 넣은 사람이
    #    "내가 적은 색이 왜 안 나오지" 에서 막힌다. 바꾼 것만 아래에서 한 줄씩 출력한다.
    moved = []

    def settle(key, backs, need=4.6, why="표면 대비"):
        before = pal[key]
        pal[key] = readable_everywhere(pal[key], backs, need)
        if pal[key][:3] != before[:3]:
            moved.append((key, before, pal[key], why))

    for key in ("secondary", "muted"):
        settle(key, _surfaces)
    # 상태색은 바탕과 판 위에 글자로 얹힌다(카드 안쪽 표면까지는 쓰이지 않는다).
    for key in ("success", "warning", "danger", "info"):
        settle(key, _surfaces[:2])
    # 🛑 테두리는 글자가 아니라 **장식**이므로 기준이 낮다(2:1). 그래도 아예 안 보이면 카드가
    #    배경에 녹으므로 최소선은 지킨다. 알파는 여기서 합성돼 없어진다 — 은은함은 색 자체로 낸다.
    settle("border", _surfaces[1:3], 2.12, "카드 경계")
    # 🛑 **강조색도 손으로 고른 값을 믿지 않는다.** 스캐폴딩으로 강조색 하나만 바꿔 넣었더니 강조
    #    테두리·포커스 링이 2.2:1, 강조 버튼 글자가 2.7:1 로 한꺼번에 무너졌다(2026-09-13 실측).
    #    강조색은 바탕·표면 위에서 부품 기준(3:1)을, 그 위 글자는 본문 기준을 넘을 때까지 민다 —
    #    그래야 "팔레트만 바꾸면 검사를 통과한다" 는 약속이 지켜진다.
    settle("accent", _surfaces[:2], 3.1, "강조 표시")
    # 🛑 **글자를 미는 것으로는 모자란다.** 밝은 보라 강조색 위에서는 흰 글자도 검은 글자도 4.5 에
    #    못 미치고, 눌린 판(글자색 쪽으로 섞여 더 어두워진다)에서는 3.15 까지 떨어졌다(실측).
    #    그래서 강조색 **자체를** 글자색 위에서 읽히는 자리까지 민다 — 대비는 대칭이라, 그러면 글자도
    #    강조색 위에서 읽힌다. 이미 넘는 내장 테마는 손대지 않는다(`readable` 은 넘으면 그대로 둔다).
    _on_solid = flatten(pal["on_accent"], _bg)
    _before_accent = pal["accent"]
    pal["accent"] = readable(pal["accent"], _on_solid, 4.5)
    if pal["accent"][:3] != _before_accent[:3]:
        moved.append(("accent", _before_accent, pal["accent"], "강조 버튼 글자가 읽히도록"))
    _accent_solid = flatten(pal["accent"], _bg)
    # 🛑 흰 글자는 더 밝힐 수 없다 — 밝은 보라 강조색 위에서 3.97:1 에 멈췄다(실측). 적힌 글자색이
    #    기준을 넘으면 그대로 두고(내장 테마가 바뀌지 않게), **못 넘을 때만** 바탕색·본문색에서 출발한
    #    어두운/밝은 후보 중 가장 잘 읽히는 쪽으로 바꾼다.
    _before_on = pal["on_accent"]
    _first = readable(pal["on_accent"], _accent_solid, 4.6)
    if contrast(_first, _accent_solid) >= 4.5:
        pal["on_accent"] = _first
    else:
        _options = [_first] + [readable(pal[k], _accent_solid, 4.6) for k in ("background", "text")]
        pal["on_accent"] = max(_options, key=lambda c: contrast(c, _accent_solid))
    if pal["on_accent"][:3] != _before_on[:3]:
        moved.append(("on_accent", _before_on, pal["on_accent"], "강조 버튼 글자"))

    # 🔑 **모양의 숫자는 형태 dict 가 먼저 말한다.** 반경·버튼 여백·간격을 형태에서 덮어쓸 수 있으므로
    #    스킨 코드를 안 만지고도 "모서리를 더 각지게" · "버튼을 더 납작하게" 가 된다(2026-09-13 —
    #    테마마다 자유도를 높여 달라는 요청). 없으면 `CONST` 의 기본값이다.
    consts = dict(CONST)
    for key in ("radius", "radius_small", "radius_large", "gap", "gap_small", "gap_large", "padding", "button_height",
                "compact_padding_x", "compact_padding_y"):
        if key in shape: consts[key] = shape[key]
    R, G = consts["radius"], consts["radius_small"]
    PAD = tuple(shape.get("button_padding", (16, 10, 16, 10)))
    boxes = {}
    cutting = shape["kind"] == "cut"
    forging = shape["kind"] == "medieval"

    def box(bid, **kw):
        # `edge`(강조 변)·`glow`(발광)는 각진 형태에만 있는 장식이다 — 둥근 형태에서는 조용히 버린다.
        accent_edge = kw.pop("edge", None)
        glow = kw.pop("glow", None)
        # 🛑 `flat_shadow` 는 **둥근 형태 전용**이다. 각진 형태에서는 발광이 깊이를 맡으므로,
        #    그림자까지 켜면 카드마다 두 겹이 겹쳐 지저분해진다.
        flat_shadow = kw.pop("flat_shadow", None)
        if cutting:
            boxes[bid] = ("StyleBox", cut(shape, edge=accent_edge, glow=glow, **kw))
        else:
            if flat_shadow is not None and kw.get("shadow") is None:
                kw["shadow"] = flat_shadow[:2]
                if len(flat_shadow) > 2:
                    kw["shadow_offset"] = flat_shadow[2]
            boxes[bid] = ("StyleBox", medieval(shape, bid, **kw)) if forging else ("StyleBoxFlat", flat(**kw))

    def bracket(bid, color, arm=11, thickness=2.0, inset=0.0, margins=None, bg=None):
        """네 모서리만 긋는 표식 판. 🛑 각진 형태에서만 쓴다 — 둥근 형태에는 부르지 않는다."""
        out = ['script = ExtResource("bracket")']
        if margins:
            for side, value in zip(("left", "top", "right", "bottom"), margins):
                out.append("content_margin_%s = %g" % (side, value))
        if bg is not None:
            out.append("bg_color = %s" % C(bg))
        out.append("color = %s" % C(color))
        out.append("arm = %g" % arm)
        out.append("thickness = %g" % thickness)
        out.append("inset = %g" % inset)
        boxes[bid] = ("StyleBox", out)

    hover_bg = mix(pal["surface"], pal["text"], 0.10)
    press_bg = mix(pal["surface"], pal["accent"], 0.22)

    # 🛑 버튼은 **바탕 위에도, 카드 안에도** 놓인다 — 둘 중 **더 나쁜 쪽**에서 읽혀야 한다.
    #    카드 안(`surface_soft`)이 보통 더 나쁘다: 카드 배경이 판의 반투명 틴트를 밝혀 놓기 때문이다.
    #    검사(`tools/check_contrast.py`)도 같은 기준으로 재므로 여기서 물러서면 그대로 미달로 잡힌다.
    under = pal["surface_soft"]

    def ink_on(box_bg, wanted, need=4.65):
        """`wanted` 색 글자가 `box_bg` 판 위에서 읽히도록 민다.

        🛑 목표를 4.5 가 아니라 조금 위로 잡는다 — 딱 맞추면 `.tres` 에 적힐 때의 반올림만으로
           기준 아래로 떨어져, 생성한 직후의 검사가 실패한다.
        """
        return readable(wanted, flatten(box_bg, flatten(under, (0, 0, 0, 1.0))), need)

    danger_bg = alpha(pal["danger"], 0.12)
    danger_bg_hover = alpha(pal["danger"], 0.20)
    danger_ink = ink_on(danger_bg, pal["danger"])
    danger_ink_hover = ink_on(danger_bg_hover, pal["danger"])
    press_ink = ink_on(press_bg, pal["accent"])
    list_press_ink = ink_on(alpha(pal["text"], 0.09), pal["accent"])
    # 주 버튼이 눌렸을 때 — 밝은 테마에서 accent 를 배경 쪽으로 섞으면 **밝아져** 흰 글자가 죽는다.
    # 글자 쪽(text)으로 섞어 언제나 어두워지게 한다.
    primary_press_bg = mix(pal["accent"], pal["text"], 0.22)

    # 버튼
    box("btn_normal", bg=pal["surface"], border=pal["border"], bw=1, radius=R, margins=PAD)
    box("btn_hover", bg=hover_bg, border=alpha(pal["text"], 0.42), bw=1, radius=R, margins=PAD)
    box("btn_pressed", bg=press_bg, border=alpha(pal["accent"], 0.75), bw=1, radius=R, margins=PAD)
    box("btn_disabled", bg=alpha(pal["surface"], 0.55), border=alpha(pal["border"], 0.35), bw=1, radius=R, margins=PAD)
    if cutting:
        # 🔑 sci-fi 의 포커스는 테두리가 아니라 **조준 표식**이다 — 내용을 가리지 않고 가리킨다.
        bracket("btn_focus", pal["accent"], arm=12, thickness=2.0, margins=PAD)
        bracket("btn_focus_on_fill", pal["on_accent"], arm=12, thickness=2.0, margins=PAD)
    else:
        box("btn_focus", draw_center=False, border=pal["accent"], bw=2, radius=R, margins=PAD)
        # 🛑 **채워진 판 위에서는 강조색 링이 보이지 않는다** — 판이 바로 그 색이기 때문이다.
        #    키보드로 옮겨 다닐 때 "지금 어디" 가 사라진다(2026-09-13 데스크톱 실측: 호버와
        #    포커스가 구별되지 않았다). 채운 버튼에는 **판과 대비되는** 링을 쓴다.
        box("btn_focus_on_fill", draw_center=False, border=pal["on_accent"], bw=2, radius=R, margins=PAD)
    box("btn_primary", bg=pal["accent"], border=pal["accent"], bw=1, radius=R, margins=PAD,
        glow=(alpha(pal["accent"], 0.55), 7),
        flat_shadow=(alpha(pal["accent"], 0.34), 8, (0, 3)))
    box("btn_primary_hover", bg=mix(pal["accent"], pal["text"], 0.18), border=pal["accent"], bw=1, radius=R, margins=PAD,
        glow=(alpha(pal["accent"], 0.75), 10),
        flat_shadow=(alpha(pal["accent"], 0.46), 11, (0, 4)))
    box("btn_primary_pressed", bg=primary_press_bg, border=pal["accent"], bw=1, radius=R, margins=PAD,
        flat_shadow=(alpha(pal["shadow"], pal["shadow"][3] * 0.25), 3, (0, 1)))
    box("btn_danger", bg=danger_bg, border=alpha(pal["danger"], 0.85), bw=1, radius=R, margins=PAD)
    box("btn_danger_hover", bg=danger_bg_hover, border=pal["danger"], bw=1, radius=R, margins=PAD)
    # 🛑 **되돌릴 수 없는 동작의 확인 버튼**은 옅은 판으로는 모자란다. 판이 옅으면 글자를 아주
    #    어둡게 밀어야 읽히고(밝은 테마에서 `#9B2626`), 그러면 "빨강" 이 아니라 그냥 검은 글자가 된다.
    #    채워서 흰 글자를 얹으면 대비도 5.7:1 로 오르고 위험이 한눈에 읽힌다.
    box("btn_danger_solid", bg=pal["danger"], border=pal["danger"], bw=1, radius=R, margins=PAD,
        flat_shadow=(alpha(pal["danger"], 0.34), 8, (0, 3)))
    box("btn_danger_solid_hover", bg=mix(pal["danger"], pal["text"], 0.18), border=pal["danger"], bw=1,
        radius=R, margins=PAD, flat_shadow=(alpha(pal["danger"], 0.46), 11, (0, 4)))
    # 🛑 눌린 판은 **글자색 쪽으로** 섞는다(강조 버튼과 같은 방식). 배경 쪽으로 섞으면 밝은 테마에서
    #    판이 밝아져 흰 글자가 3.87:1 까지 떨어진다(2026-09-13 측정).
    danger_solid_press_bg = mix(pal["danger"], pal["text"], 0.22)
    box("btn_danger_solid_pressed", bg=danger_solid_press_bg, border=pal["danger"],
        bw=1, radius=R, margins=PAD,
        flat_shadow=(alpha(pal["shadow"], pal["shadow"][3] * 0.25), 3, (0, 1)))

    # 얇은 버튼 · 아이콘 버튼 · 목록 항목
    # 🔑 작은 버튼 판 여백은 토큰(`compact_padding_x/y`)에서 — 형태가 값을 바꿔도 판과 토큰이 늘 같다.
    #    🛑 여기 숫자를 박으면 `GoStyle.audit_compact_padding` 이 보는 토큰과 실제 판이 갈라진다.
    CPX, CPY = consts["compact_padding_x"], consts["compact_padding_y"]
    box("compact_normal", bg=alpha(pal["surface_soft"], 0.85), border=alpha(pal["border"], 0.55), bw=1, radius=G, margins=(CPX, CPY, CPX, CPY))
    box("compact_hover", bg=hover_bg, border=alpha(pal["text"], 0.36), bw=1, radius=G, margins=(CPX, CPY, CPX, CPY))
    box("icon_hover", bg=alpha(pal["text"], 0.10), radius=G)
    box("list_normal", bg=alpha(pal["surface_soft"], 0.55), radius=G, margins=(0, 0, 0, 0))
    box("list_hover", bg=alpha(pal["text"], 0.09), border=alpha(pal["border"], 0.5), bw=1, radius=G, margins=(0, 0, 0, 0))
    if cutting:
        bracket("focus_soft", alpha(pal["accent"], 0.85), arm=9, thickness=1.5)
    else:
        box("focus_soft", draw_center=False, border=alpha(pal["accent"], 0.7), bw=1, radius=G)

    # 표면
    box("panel", bg=pal["surface"], border=pal["border"], bw=1, radius=CONST["radius_large"],
        margins=(0, 0, 0, 0), shadow=(alpha(pal["shadow"], pal["shadow"][3] * 0.55), 18), shadow_offset=(0, 6),
        edge=pal["accent"])
    box("panel_solid", bg=pal["surface"], border=pal["border"], bw=1, radius=R, margins=(0, 0, 0, 0))
    gap = consts["gap"]
    box("card", bg=pal["surface_soft"], border=alpha(pal["border"], 0.6), bw=1, radius=R, margins=(gap, gap, gap, gap),
        edge=alpha(pal["accent"], 0.55),
        flat_shadow=(alpha(pal["shadow"], pal["shadow"][3] * 0.30), 6, (0, 2)))
    box("popup", bg=mix(pal["surface"], pal["background"], 0.25), border=pal["border"], bw=1, radius=R, margins=(gap, gap, gap, gap),
        edge=pal["accent"],
        flat_shadow=(alpha(pal["shadow"], pal["shadow"][3] * 0.55), 16, (0, 5)))
    # 🔑 **드롭다운 메뉴는 버튼이 아니다.** 항목 호버에 버튼 판(`btn_hover`)을 쓰면 테두리·그림자까지
    #    따라와 목록이 덜컥거린다 — 항목에는 **옅은 강조 채움**만 준다(2026-09-13 사용자 지적).
    box("menu_hover", bg=alpha(pal["accent"], 0.16), radius=G, margins=(gap, 6, gap, 6))
    box("menu_separator", bg=alpha(pal["border"], 0.7), margins=(0, CONST["gap_small"], 0, CONST["gap_small"]))
    small = consts["gap_small"]
    # 🛑 **HUD 판은 게임 화면 위에 얹힌다** — 눈밭일 수도, 동굴일 수도 있다. 뒤가 밝으면 어두운 판이
    #    통째로 밝아져 흐린 글자가 3.74:1 까지 묽어졌다(2026-09-13 측정). 유리 느낌은 남기되
    #    **최악의 뒷배경(순백·순흑)에서도 본문 4.5:1** 을 지키는 선까지 올린다 — 0.88 이 경계, 0.92 로 둔다.
    box("hud", bg=alpha(pal["surface"], 0.92), border=alpha(pal["border"], 0.8), bw=1, radius=R, margins=(small, small, small, small),
        edge=pal["accent"], glow=(alpha(pal["accent"], 0.30), 6))
    box("notice", bg=mix(pal["surface"], pal["background"], 0.15), border=pal["border"], bw=1, radius=R, margins=(gap, gap, gap, gap),
        edge=pal["accent"], glow=(alpha(pal["accent"], 0.30), 6),
        flat_shadow=(alpha(pal["shadow"], pal["shadow"][3] * 0.45), 12, (0, 4)))
    boxes["empty"] = ("StyleBoxEmpty", [])

    # 입력칸
    box("edit_normal", bg=alpha(pal["background"], 0.65), border=pal["border"], bw=1, radius=G, margins=(12, 8, 12, 8))
    box("edit_focus", bg=alpha(pal["background"], 0.85), border=pal["accent"], bw=2, radius=G, margins=(12, 8, 12, 8))

    # 스크롤바 — 얇고 옅게. 내용을 가리지 않는 것이 목적이다.
    sb_w = CONST["scrollbar_width"]
    half = (sb_w / 2.0,) * 4
    box("scroll_track", bg=alpha(pal["muted"], 0.14), radius=sb_w // 2, margins=half)
    box("scroll_grab", bg=alpha(pal["secondary"], 0.50), radius=sb_w // 2, margins=half)
    box("scroll_grab_hover", bg=alpha(pal["secondary"], 0.80), radius=sb_w // 2, margins=half)

    # 슬라이더 — 스크롤바와 **다른** StyleBox (공유하면 한쪽을 고칠 수 없다)
    box("slider_track", bg=alpha(pal["track"], 0.9), radius=3, margins=(0, 3, 0, 3))
    box("slider_grab", bg=alpha(pal["accent"], 0.55), radius=3, margins=(0, 3, 0, 3))
    box("slider_grab_hover", bg=pal["accent"], radius=3, margins=(0, 3, 0, 3))

    # 진행 막대 · 구분선 · 툴팁
    # 🛑 막대 **바탕이 보여야** 얼마나 남았는지 읽힌다. 색만으로는 보장할 수 없다 — 막대는 바탕 위에도,
    #    카드 안에도, HUD 판 위에도 놓이는데 그 셋의 밝기가 제각각이기 때문이다(scifi_dark 는 바탕과
    #    대비 1.003:1 로 사실상 같은 색이었다 — 2026-09-13 실측). 그래서 **윤곽선**으로 경계를 만든다.
    box("bar_bg", bg=alpha(pal["track"], 0.85), radius=G,
        border=alpha(pal["border"], 0.65), bw=1)
    # 🛑 발광 색은 **채움색을 따라간다** — `GoSkin.progress_fill_box()` 가 채움을 바꿀 때 함께 바꾼다.
    #    고정해 두면 빨간 체력 막대가 시안으로 빛난다.
    box("bar_fill", bg=pal["accent"], radius=G, glow=(alpha(pal["accent"], 0.50), 4))
    box("separator", bg=alpha(pal["border"], 0.8), margins=(0, 0.5, 0, 0.5))
    box("tooltip", bg=mix(pal["surface"], pal["background"], 0.35), border=pal["border"], bw=1, radius=G, margins=(10, 6, 10, 6))

    # 접이식 섹션(FoldableContainer, 4.5+) — 펼치면 제목 판과 내용 판이 한 장의 카드로 이어진다.
    # 🛑 제목 판 높이 = 글자 한 줄 + 위아래 여백 13 두 번 ≈ 48 — 제목 줄이 곧 터치 대상이다.
    fold_pad = (14, 13, 14, 13)
    edge = alpha(pal["border"], 0.6)
    edge_hover = alpha(pal["border"], 0.95)
    box("fold_title", bg=pal["surface_soft"], border=edge, borders=(1, 1, 1, 0), corners=(R, R, 0, 0), margins=fold_pad)
    box("fold_title_hover", bg=hover_bg, border=edge_hover, borders=(1, 1, 1, 0), corners=(R, R, 0, 0), margins=fold_pad)
    box("fold_title_collapsed", bg=pal["surface_soft"], border=edge, bw=1, radius=R, margins=fold_pad)
    box("fold_title_collapsed_hover", bg=hover_bg, border=edge_hover, bw=1, radius=R, margins=fold_pad)
    box("fold_panel", bg=alpha(pal["surface_soft"], 0.5), border=edge, borders=(1, 0, 1, 1), corners=(0, 0, R, R), margins=(14, 10, 14, 14))

    assets = write_assets(variant, pal, shape)

    T = []

    def add(key, value):
        T.append("%s = %s" % (key, value))

    def sb(key, bid):
        T.append('%s = SubResource("%s")' % (key, bid))

    def ex(key, rid):
        T.append('%s = ExtResource("%s")' % (key, rid))

    add("default_font_size", FONTS["body"])

    for key in sorted(pal):
        add("GoHud/colors/%s" % key, C(pal[key]))
    # 🔑 **넓은 면적에 칠하는 색**은 글자색과 요구가 반대다 — 글자는 배경에 묻히지 않게 어두워야 하고,
    #    막대 채움은 눈에 들어오게 밝아야 한다. 밝은 테마에서 한 색으로 버티면 경험치 막대가 갈색이 된다.
    #    `track`(막대 바탕) 위에서 3:1 을 넘는 선까지만 올린다 — 더 올리면 흰색으로 날아간다.
    track_solid = flatten(pal["track"], flatten(pal["background"], (0, 0, 0, 1.0)))
    for key in ("success", "warning", "danger", "info", "accent"):
        fill = fill_color(raw[key], track_solid, vivid=raw.get(key + "_vivid"))
        # 🛑 **조용히 나빠지는 자리다.** `*_vivid` 를 모르고 지나간 팔레트는 글자용으로 어두워진 색을
        #    그대로 채움에 쓰게 되고, 막대가 갈색이 된다. 눈에 띄게 알린다.
        if raw.get(key + "_vivid") is None and max(fill[:3]) < 0.70:
            moved.append((key + "_fill", raw[key], fill,
                          "막대가 칙칙하다 — 팔레트에 %s_vivid 를 더한다" % key))
        add("GoHud/colors/%s_fill" % key, C(fill))
    # 형태가 덮어쓴 값은 **토큰으로도** 나간다 — 위젯이 `GoUi.metric(RADIUS)` 로 읽는 값과 판의 반경이 같아야 한다.
    for key in sorted(consts):
        add("GoHud/constants/%s" % key, consts[key])
    for key, bid in [("panel", "panel"), ("card", "card"), ("hud", "hud"), ("notice", "notice"), ("popup", "popup"),
                     ("empty", "empty"), ("focus", "btn_focus"), ("focus_soft", "focus_soft")]:
        sb("GoHud/styles/%s" % key, bid)

    states = [("normal", "btn_normal"), ("hover", "btn_hover"), ("pressed", "btn_pressed"),
              ("hover_pressed", "btn_pressed"), ("disabled", "btn_disabled"), ("focus", "btn_focus")]

    add("Button/colors/font_color", C(pal["text"]))
    add("Button/colors/font_hover_color", C(pal["text"]))
    add("Button/colors/font_pressed_color", C(press_ink))
    add("Button/colors/font_focus_color", C(pal["text"]))
    add("Button/colors/font_disabled_color", C(pal["muted"]))
    add("Button/colors/icon_normal_color", C(pal["secondary"]))
    add("Button/colors/icon_hover_color", C(pal["text"]))
    add("Button/colors/icon_pressed_color", C(pal["accent"]))
    add("Button/colors/icon_disabled_color", C(alpha(pal["muted"], 0.5)))
    add("Button/constants/h_separation", CONST["gap_small"])
    add("Button/font_sizes/font_size", FONTS["button"])
    for state, bid in states:
        sb("Button/styles/%s" % state, bid)

    add("Label/colors/font_color", C(pal["text"]))
    add("Label/font_sizes/font_size", FONTS["body"])
    add("RichTextLabel/colors/default_color", C(pal["text"]))
    add("RichTextLabel/font_sizes/normal_font_size", FONTS["body"])

    add("LineEdit/colors/font_color", C(pal["text"]))
    add("LineEdit/colors/font_placeholder_color", C(pal["muted"]))
    add("LineEdit/colors/caret_color", C(pal["accent"]))
    add("LineEdit/colors/selection_color", C(alpha(pal["accent"], 0.35)))
    add("LineEdit/font_sizes/font_size", FONTS["body"])
    sb("LineEdit/styles/normal", "edit_normal")
    sb("LineEdit/styles/focus", "edit_focus")
    sb("LineEdit/styles/read_only", "btn_disabled")
    add("TextEdit/colors/font_color", C(pal["text"]))
    sb("TextEdit/styles/normal", "edit_normal")
    sb("TextEdit/styles/focus", "edit_focus")

    sb("Panel/styles/panel", "panel_solid")
    sb("PanelContainer/styles/panel", "panel_solid")
    sb("TooltipPanel/styles/panel", "tooltip")
    add("TooltipLabel/colors/font_color", C(pal["text"]))
    add("TooltipLabel/font_sizes/font_size", FONTS["caption"])

    add("PopupMenu/colors/font_color", C(pal["text"]))
    add("PopupMenu/colors/font_hover_color", C(pal["text"]))
    add("PopupMenu/colors/font_disabled_color", C(pal["muted"]))
    add("PopupMenu/colors/font_accelerator_color", C(pal["secondary"]))
    add("PopupMenu/colors/font_separator_color", C(pal["secondary"]))
    # 🛑 항목 높이는 글자 높이 + 이 값이다. 4 로 두면 27dp — 손가락으로 고를 수 없다(2026-09-13 실측).
    #    터치 하한 48 에 가깝도록 넉넉히 준다. 데스크톱에서도 성글어 보이지 않는 선이다.
    add("PopupMenu/constants/v_separation", CONST["gap_large"])
    add("PopupMenu/constants/h_separation", CONST["gap"])
    add("PopupMenu/constants/item_start_padding", CONST["gap_small"])
    add("PopupMenu/constants/item_end_padding", CONST["gap_small"])
    add("PopupMenu/constants/icon_max_width", CONST["icon_size"])
    add("PopupMenu/font_sizes/font_size", FONTS["body"])
    sb("PopupMenu/styles/panel", "popup")
    sb("PopupMenu/styles/hover", "menu_hover")
    sb("PopupMenu/styles/separator", "menu_separator")
    # 🛑 라디오·체크 표시를 엔진 기본(흐린 회색 원)에 맡기면 어느 항목이 골라졌는지 안 보인다 —
    #    체크박스가 쓰는 우리 그림을 그대로 쓴다. 테마가 바뀌면 이것도 따라 바뀐다.
    for key, rid in [("checked", "check_on"), ("unchecked", "check_off"),
                     ("checked_disabled", "check_on_disabled"), ("unchecked_disabled", "check_off_disabled"),
                     ("radio_checked", "radio_on"), ("radio_unchecked", "radio_off"),
                     ("radio_checked_disabled", "radio_on_disabled"), ("radio_unchecked_disabled", "radio_off_disabled")]:
        ex("PopupMenu/icons/%s" % key, rid)

    add("OptionButton/colors/font_color", C(pal["text"]))
    add("OptionButton/font_sizes/font_size", FONTS["body"])
    for state, bid in states:
        sb("OptionButton/styles/%s" % state, bid)
    ex("OptionButton/icons/arrow", "arrow_down")
    # 🛑 화살표를 오른쪽 끝에서 **버튼 여백만큼** 들여 놓는다. 엔진 기본(4)이면 옆에 놓인 `dropdown()`
    #    (MenuButton, 아이콘이 여백 안쪽) 과 화살표 x 가 12dp 어긋나 다른 부품처럼 보인다(2026-09-13 데모 실측).
    add("OptionButton/constants/arrow_margin", PAD[2])

    empty_states = ["normal", "hover", "pressed", "hover_pressed", "disabled"]
    add("CheckButton/colors/font_color", C(pal["text"]))
    add("CheckButton/colors/font_disabled_color", C(pal["muted"]))
    add("CheckButton/font_sizes/font_size", FONTS["body"])
    add("CheckButton/constants/h_separation", CONST["gap"])
    for state in empty_states:
        sb("CheckButton/styles/%s" % state, "empty")
    sb("CheckButton/styles/focus", "focus_soft")
    for key in ["checked", "unchecked", "checked_disabled", "unchecked_disabled",
                "checked_mirrored", "unchecked_mirrored", "checked_disabled_mirrored", "unchecked_disabled_mirrored"]:
        rid = key.replace("unchecked", "toggle_off").replace("checked", "toggle_on")
        ex("CheckButton/icons/%s" % key, rid)

    add("CheckBox/colors/font_color", C(pal["text"]))
    add("CheckBox/colors/font_disabled_color", C(pal["muted"]))
    add("CheckBox/font_sizes/font_size", FONTS["body"])
    add("CheckBox/constants/h_separation", CONST["gap_small"])
    for state in empty_states:
        sb("CheckBox/styles/%s" % state, "empty")
    sb("CheckBox/styles/focus", "focus_soft")
    for key, rid in [("checked", "check_on"), ("unchecked", "check_off"),
                     ("checked_disabled", "check_on_disabled"), ("unchecked_disabled", "check_off_disabled"),
                     ("radio_checked", "radio_on"), ("radio_unchecked", "radio_off"),
                     ("radio_checked_disabled", "radio_on_disabled"), ("radio_unchecked_disabled", "radio_off_disabled")]:
        ex("CheckBox/icons/%s" % key, rid)

    # 탭 줄 — 고른 탭은 강조색 밑줄, 나머지는 얇은 기준선. 위 모서리만 둥글다.
    tab_margins = (CONST["padding"], CONST["gap_small"], CONST["padding"], CONST["gap_small"])
    tab_radius = CONST.get("radius_small", 8)
    box("tab_selected", bg=pal["surface_high"], border=pal["accent"], borders=(0, 0, 0, 2),
        corners=(tab_radius, tab_radius, 0, 0), margins=tab_margins, glow=(alpha(pal["accent"], 0.35), 5))
    box("tab_unselected", draw_center=False, border=pal["border"], borders=(0, 0, 0, 1), margins=tab_margins)
    box("tab_hovered", bg=pal["surface_soft"], border=pal["border"], borders=(0, 0, 0, 1),
        corners=(tab_radius, tab_radius, 0, 0), margins=tab_margins)
    for key, bid in [("tab_selected", "tab_selected"), ("tab_unselected", "tab_unselected"),
                     ("tab_hovered", "tab_hovered"), ("tab_disabled", "tab_unselected"), ("tab_focus", "focus_soft")]:
        sb("TabBar/styles/%s" % key, bid)
    add("TabBar/colors/font_selected_color", C(pal["text"]))
    add("TabBar/colors/font_unselected_color", C(pal["secondary"]))
    add("TabBar/colors/font_hovered_color", C(pal["text"]))
    add("TabBar/colors/font_disabled_color", C(pal["muted"]))
    add("TabBar/font_sizes/font_size", FONTS["body"])
    add("TabBar/constants/h_separation", CONST["gap_small"])
    for key, bid in [("tab_selected", "tab_selected"), ("tab_unselected", "tab_unselected"),
                     ("tab_hovered", "tab_hovered"), ("tab_disabled", "tab_unselected"), ("tab_focus", "focus_soft"),
                     ("panel", "card")]:
        sb("TabContainer/styles/%s" % key, bid)
    add("TabContainer/colors/font_selected_color", C(pal["text"]))
    add("TabContainer/colors/font_unselected_color", C(pal["secondary"]))
    add("TabContainer/font_sizes/font_size", FONTS["body"])

    add("FoldableContainer/colors/font_color", C(pal["text"]))
    add("FoldableContainer/colors/hover_font_color", C(pal["text"]))
    add("FoldableContainer/colors/collapsed_font_color", C(pal["secondary"]))
    add("FoldableContainer/constants/h_separation", CONST["gap_small"])
    add("FoldableContainer/font_sizes/font_size", FONTS["body"])
    sb("FoldableContainer/styles/title_panel", "fold_title")
    sb("FoldableContainer/styles/title_hover_panel", "fold_title_hover")
    sb("FoldableContainer/styles/title_collapsed_panel", "fold_title_collapsed")
    sb("FoldableContainer/styles/title_collapsed_hover_panel", "fold_title_collapsed_hover")
    sb("FoldableContainer/styles/panel", "fold_panel")
    sb("FoldableContainer/styles/focus", "focus_soft")
    ex("FoldableContainer/icons/expanded_arrow", "arrow_down")
    ex("FoldableContainer/icons/expanded_arrow_mirrored", "arrow_down")
    ex("FoldableContainer/icons/folded_arrow", "arrow_right")
    ex("FoldableContainer/icons/folded_arrow_mirrored", "arrow_left")

    sb("ProgressBar/styles/background", "bar_bg")
    sb("ProgressBar/styles/fill", "bar_fill")
    add("ProgressBar/colors/font_color", C(pal["text"]))
    add("ProgressBar/font_sizes/font_size", FONTS["compact"])

    add("ScrollContainer/constants/scrollbar_h_separation", CONST["gap_small"])
    add("ScrollContainer/constants/scrollbar_v_separation", CONST["gap_small"])
    for bar in ("VScrollBar", "HScrollBar"):
        sb("%s/styles/scroll" % bar, "scroll_track")
        sb("%s/styles/scroll_focus" % bar, "scroll_track")
        sb("%s/styles/grabber" % bar, "scroll_grab")
        sb("%s/styles/grabber_highlight" % bar, "scroll_grab_hover")
        sb("%s/styles/grabber_pressed" % bar, "scroll_grab_hover")

    for slider in ("HSlider", "VSlider"):
        sb("%s/styles/slider" % slider, "slider_track")
        sb("%s/styles/grabber_area" % slider, "slider_grab")
        sb("%s/styles/grabber_area_highlight" % slider, "slider_grab_hover")
        ex("%s/icons/grabber" % slider, "grabber")
        ex("%s/icons/grabber_highlight" % slider, "grabber_highlight")
        ex("%s/icons/grabber_disabled" % slider, "grabber_disabled")

    sb("HSeparator/styles/separator", "separator")
    sb("VSeparator/styles/separator", "separator")
    for container in ("BoxContainer", "HBoxContainer", "VBoxContainer", "HFlowContainer", "VFlowContainer"):
        add("%s/constants/separation" % container, CONST["gap"])
    add("GridContainer/constants/h_separation", CONST["gap"])
    add("GridContainer/constants/v_separation", CONST["gap"])

    for role, size in [("Title", "title"), ("Subtitle", "subtitle"), ("Caption", "caption"),
                       ("Compact", "compact"), ("Micro", "micro")]:
        add("Go%sLabel/base_type" % role, '&"Label"')
        add("Go%sLabel/font_sizes/font_size" % role, FONTS[size])
    add("GoCaptionLabel/colors/font_color", C(pal["secondary"]))
    add("GoMicroLabel/colors/font_color", C(pal["muted"]))

    add("GoButton/base_type", '&"Button"')

    add("GoPrimaryButton/base_type", '&"Button"')
    for key in ("font_color", "font_hover_color", "font_pressed_color", "font_focus_color"):
        add("GoPrimaryButton/colors/%s" % key, C(pal["on_accent"]))
    add("GoPrimaryButton/colors/icon_normal_color", C(pal["on_accent"]))
    sb("GoPrimaryButton/styles/normal", "btn_primary")
    sb("GoPrimaryButton/styles/hover", "btn_primary_hover")
    sb("GoPrimaryButton/styles/pressed", "btn_primary_pressed")
    sb("GoPrimaryButton/styles/hover_pressed", "btn_primary_pressed")
    sb("GoPrimaryButton/styles/focus", "btn_focus_on_fill")

    # 채워진 위험 버튼 — 글자는 강조 버튼과 같은 `on_accent`(판이 진하므로 흰 글자가 읽힌다).
    # 🛑 **세 상태 전부에서** 읽혀야 한다. 눌린 판은 배경 쪽으로 섞여 밝아지므로, 보통 판에만 맞추면
    #    눌린 순간 3.87:1 까지 떨어진다(2026-09-13 측정).
    danger_solid_ink = readable_everywhere(pal["on_accent"], [
        flatten(pal["danger"], _bg),
        flatten(mix(pal["danger"], pal["text"], 0.18), _bg),
        flatten(danger_solid_press_bg, _bg),
    ], 4.6)
    add("GoDangerSolidButton/base_type", '&"Button"')
    for key in ("font_color", "font_hover_color", "font_pressed_color", "font_focus_color"):
        add("GoDangerSolidButton/colors/%s" % key, C(danger_solid_ink))
    add("GoDangerSolidButton/colors/icon_normal_color", C(danger_solid_ink))
    sb("GoDangerSolidButton/styles/normal", "btn_danger_solid")
    sb("GoDangerSolidButton/styles/hover", "btn_danger_solid_hover")
    sb("GoDangerSolidButton/styles/pressed", "btn_danger_solid_pressed")
    sb("GoDangerSolidButton/styles/hover_pressed", "btn_danger_solid_pressed")
    sb("GoDangerSolidButton/styles/focus", "btn_focus_on_fill")

    add("GoDangerButton/base_type", '&"Button"')
    add("GoDangerButton/colors/font_color", C(danger_ink))
    add("GoDangerButton/colors/font_hover_color", C(danger_ink_hover))
    add("GoDangerButton/colors/font_pressed_color", C(danger_ink_hover))
    sb("GoDangerButton/styles/normal", "btn_danger")
    sb("GoDangerButton/styles/hover", "btn_danger_hover")
    sb("GoDangerButton/styles/pressed", "btn_danger_hover")
    sb("GoDangerButton/styles/hover_pressed", "btn_danger_hover")

    add("GoBareButton/base_type", '&"Button"')
    for state in empty_states:
        sb("GoBareButton/styles/%s" % state, "empty")
    sb("GoBareButton/styles/focus", "focus_soft")

    add("GoCompactButton/base_type", '&"Button"')
    add("GoCompactButton/font_sizes/font_size", FONTS["caption"])
    sb("GoCompactButton/styles/normal", "compact_normal")
    sb("GoCompactButton/styles/hover", "compact_hover")
    sb("GoCompactButton/styles/pressed", "compact_hover")
    sb("GoCompactButton/styles/hover_pressed", "compact_hover")
    sb("GoCompactButton/styles/disabled", "compact_normal")
    sb("GoCompactButton/styles/focus", "focus_soft")

    add("GoIconButton/base_type", '&"Button"')
    add("GoIconButton/colors/icon_normal_color", C(pal["muted"]))
    add("GoIconButton/colors/icon_hover_color", C(pal["text"]))
    add("GoIconButton/colors/icon_pressed_color", C(pal["accent"]))
    add("GoIconButton/colors/icon_focus_color", C(pal["secondary"]))
    add("GoIconButton/colors/icon_disabled_color", C(alpha(pal["muted"], 0.4)))
    sb("GoIconButton/styles/normal", "empty")
    sb("GoIconButton/styles/hover", "icon_hover")
    sb("GoIconButton/styles/pressed", "icon_hover")
    sb("GoIconButton/styles/hover_pressed", "icon_hover")
    sb("GoIconButton/styles/disabled", "empty")
    sb("GoIconButton/styles/focus", "focus_soft")

    add("GoListButton/base_type", '&"Button"')
    sb("GoListButton/styles/normal", "list_normal")
    sb("GoListButton/styles/hover", "list_hover")
    add("GoListButton/colors/font_pressed_color", C(list_press_ink))
    sb("GoListButton/styles/pressed", "list_hover")
    sb("GoListButton/styles/hover_pressed", "list_hover")
    sb("GoListButton/styles/disabled", "list_normal")
    sb("GoListButton/styles/focus", "focus_soft")

    add("GoPanel/base_type", '&"PanelContainer"')
    sb("GoPanel/styles/panel", "panel")
    add("GoCard/base_type", '&"PanelContainer"')
    sb("GoCard/styles/panel", "card")

    # Optional role fonts are scoped to this theme; existing presets keep their exact output.
    fonts = shape.get("fonts", {})
    font_targets = {"title": "GoTitleLabel", "subtitle": "GoSubtitleLabel", "caption": "GoCaptionLabel",
                    "body": "Label", "button": "Button"}
    unknown_fonts = set(fonts) - set(font_targets)
    if unknown_fonts:
        raise SystemExit("Unknown font roles: %s" % sorted(unknown_fonts))
    for role in fonts:
        ex(font_targets[role] + "/fonts/font", "font_" + role)
        if role == "body": ex("default_font", "font_" + role)
    steps = len(boxes) + len(assets) + 1 + (2 if cutting else 0) + int(forging) + len(fonts)
    lines = ['[gd_resource type="Theme" load_steps=%d format=3]' % steps, ""]
    if cutting:
        lines.append('[ext_resource type="Script" path="%s" id="cut"]' % CUT_SCRIPT)
        lines.append('[ext_resource type="Script" path="%s" id="bracket"]' % BRACKET_SCRIPT)
    if forging:
        lines.append('[ext_resource type="Script" path="%s" id="medieval"]' % MEDIEVAL_SCRIPT)
    for role, path in fonts.items():
        if not path.startswith(RES + "/") or not os.path.isfile(os.path.join(ADDON, path[len(RES) + 1:])):
            raise SystemExit("Font must exist inside the addon: %s" % path)
        lines.append('[ext_resource type="FontFile" path="%s" id="font_%s"]' % (path, role))
    for name in assets:
        lines.append('[ext_resource type="Texture2D" path="%s/assets/%s/%s.svg" id="%s"]' % (RES, variant, name, name))
    lines.append("")
    for bid, (btype, body) in boxes.items():
        lines.append('[sub_resource type="%s" id="%s"]' % (btype, bid))
        lines += body
        lines.append("")
    lines.append("[resource]")
    lines += sorted(T, key=lambda s: s.split(" = ")[0])
    with open(out_path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    print("%s — 항목 %d · StyleBox %d · 그림 %d" % (os.path.relpath(out_path, ADDON), len(T), len(boxes), len(assets)))
    for key, before, after, why in moved:
        print("   ↳ %-10s %s → %s  (%s)" % (key, svg_hex(before), svg_hex(after), why))


# 🛑 새 그림(SVG)을 만들었으면 Godot 이 **실제 임포트**를 해야 읽힌다 — `.import` 파일만으로는 안 된다.
#    안 하면 새 테마를 preload 하는 스크립트가 로드에 실패해 헤드리스 검사가 소리 없이 매달린다(2026-09-12 실측).
IMPORT_HINT = "다음: 프로젝트에서 `godot --headless --path . --import` 를 한 번 돌린다(새 SVG 임포트). 그 전엔 검사·데모가 새 테마를 못 읽는다."

# ── 테마 레지스트리 ──────────────────────────────────────────────────────
#
# 🔑 **테마 하나 = 팔레트 + 형태.** 내장 넷은 여기 적혀 있고, 그 밖의 것은 `themes/palettes/*.json` 에서
#    온다 — 코드를 고치지 않고 파일 하나로 테마를 더한다(`tools/new_theme.py` 가 그 파일을 만든다).

BUILTIN_THEMES = {
    "dark": (DARK, SHAPE_DEFAULT),
    "light": (LIGHT, SHAPE_DEFAULT),
    "scifi_dark": (SCIFI_DARK, SHAPE_CUT),
    "scifi_light": (SCIFI_LIGHT, SHAPE_CUT),
}
SHAPES = {"flat": SHAPE_DEFAULT, "cut": SHAPE_CUT,
          "medieval": {"kind": "medieval", "controls": "rounded", "radius": 4, "radius_small": 3,
                       "radius_large": 6, "material": 1, "ornament_scale": 1.0,
                       "grain_alpha": 0.035, "bevel_strength": 0.18}}
PALETTES_DIR = os.path.join(ADDON, "themes", "palettes")
# 팔레트에 반드시 있어야 하는 키 — 없으면 생성 중간에 KeyError 로 죽는다. 미리 알려 준다.
PALETTE_KEYS = ("background", "surface", "surface_soft", "surface_high", "border", "text", "secondary",
                "muted", "accent", "on_accent", "success", "warning", "danger", "info", "scrim", "shadow", "track")


def parse_color(text):
    """`"#RRGGBB"` 또는 `"#RRGGBB@0.35"`(알파) → 색 튜플."""
    if isinstance(text, (list, tuple)):
        return tuple(float(v) for v in text) + ((1.0,) if len(text) == 3 else ())
    body, _, alpha = str(text).partition("@")
    return hexc(body.strip(), float(alpha) if alpha else 1.0)


def load_palette_file(path, ancestors=()):
    """JSON 테마 한 장 → (id, 팔레트, 형태, 메타). `from` 으로 내장 테마를 물려받고 적힌 것만 덮어쓴다."""
    import json
    path = os.path.abspath(path)
    if path in ancestors:
        raise SystemExit("Palette inheritance cycle: %s" % path)
    with open(path, encoding="utf-8") as fh:
        spec = json.load(fh)
    tid = spec.get("id") or os.path.splitext(os.path.basename(path))[0]
    base = spec.get("from", "dark")
    base_meta = None
    if base in BUILTIN_THEMES:
        base_pal, base_shape = BUILTIN_THEMES[base]
    else:
        base_path = os.path.join(PALETTES_DIR, base + ".json")
        if not os.path.isfile(base_path):
            raise SystemExit("Unknown parent palette: %s" % base)
        _, base_pal, base_shape, base_meta = load_palette_file(base_path, ancestors + (path,))
    pal = dict(base_pal)
    for key, value in spec.get("palette", {}).items():
        if key.startswith("_"): continue
        pal[key] = parse_color(value)
    missing = [k for k in PALETTE_KEYS if k not in pal]
    if missing:
        raise SystemExit("🛑 %s: 팔레트에 %s 가 없다" % (path, ", ".join(missing)))
    shape_spec = spec.get("shape", base_shape)
    if isinstance(shape_spec, str):
        shape = dict(SHAPES[shape_spec])
    else:
        kind = shape_spec.get("kind", base_shape["kind"])
        shape = dict(base_shape if kind == base_shape["kind"] else SHAPES[kind])
        if "fonts" in shape_spec:
            shape_spec = dict(shape_spec, fonts={**shape.get("fonts", {}), **shape_spec["fonts"]})
        shape.update({k: v for k, v in shape_spec.items() if not k.startswith("_")})
    inherited_skin = base_meta["skin"] if base_meta else "scifi" if base.startswith("scifi") else "default"
    skin = spec.get("skin", inherited_skin)
    if isinstance(skin, dict) and isinstance(inherited_skin, dict):
        if skin.get("base", inherited_skin.get("base")) == inherited_skin.get("base"):
            skin = {**inherited_skin, **skin, "dials": {**inherited_skin.get("dials", {}), **skin.get("dials", {})}}
    meta = {"title": spec.get("title", tid),
            "dark": spec.get("dark", base_meta["dark"] if base_meta else base in ("dark", "scifi_dark")),
            "skin": skin,
            "icons": spec.get("icons", base_meta.get("icons", "") if base_meta else ""), "from": base}
    return tid, pal, shape, meta


SKIN_SCRIPTS = {
    "default": ("GoSkin", RES + "/core/go_skin.gd"),
    "scifi": ("GoSkinSciFi", RES + "/themes/skins/go_skin_scifi.gd"),
    "medieval": ("GoSkinMedieval", RES + "/themes/skins/go_skin_medieval.gd"),
}
SKINS_DIR = os.path.join(ADDON, "themes", "skins")


SKIN_SOURCES = {
    "default": os.path.join(ADDON, "core", "go_skin.gd"),
    "scifi": os.path.join(ADDON, "themes", "skins", "go_skin_scifi.gd"),
    "medieval": os.path.join(ADDON, "themes", "skins", "go_skin_medieval.gd"),
}
DIALS_TABLE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "skin_dials.json")


def skin_dials():
    """스킨 다이얼 기본값 — **GDScript 가 유일한 원천**이다. `@export var 이름 := 값` 을 읽는다.

    🛑 표(`skin_dials.json`)를 손으로 관리하면 두 곳이 어긋난다(2026-09-13, I-63). 여기서 파싱하고,
       표는 검사가 볼 수 있게 남기는 **생성물**이다(`write_skin_dials_table`).
    """
    import re as _re
    out = {}
    pattern = _re.compile(r"^@export var (\w+) := (-?\d+(?:\.\d+)?)\s*$", _re.M)
    for name, path in SKIN_SOURCES.items():
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
        table = {}
        for key, raw in pattern.findall(text):
            if key == "skin_name": continue
            table[key] = float(raw) if "." in raw else int(raw)
        out[name] = table
    return out


def write_skin_dials_table():
    """파싱한 다이얼을 `tools/skin_dials.json` 에 남긴다 — GDScript 검사가 이것을 읽어 파서를 대조한다."""
    import json
    body = {"_help": "생성물 — 손으로 고치지 않는다. 원천은 core/go_skin.gd 와 themes/skins/go_skin_scifi.gd 의 "
                     "@export 기본값이고, make_theme.py 가 파싱해 여기 적는다. 검사(presets · skins)가 "
                     "GDScript 기본값과 대조해 파서를 지킨다."}
    body.update(skin_dials())
    with open(DIALS_TABLE, "w", encoding="utf-8") as fh:
        json.dump(body, fh, ensure_ascii=False, indent=2)
        fh.write("\n")


def write_skin_resource(tid, skin_spec):
    """JSON 의 `skin` 이 사전이면 **스킨 리소스 한 장**을 만든다 — `{"base": "scifi", "dials": {...}}`.

    🔑 스킨 코드를 안 만지고 숫자만 바꾸는 길이다. `base` 스킨의 스크립트에 다이얼 값을 얹은 `.tres` 다.
    """
    if not isinstance(skin_spec, dict):
        return None
    base = skin_spec.get("base", "default")
    if base not in SKIN_SCRIPTS:
        raise SystemExit("🛑 skin.base 는 %s 중 하나 (지금 %r)" % (sorted(SKIN_SCRIPTS), base))
    script_class, script_path = SKIN_SCRIPTS[base]
    known = dict(skin_dials()["default"])
    known.update(skin_dials()[base])
    dials = {k: v for k, v in skin_spec.get("dials", {}).items() if not k.startswith("_")}
    unknown = sorted(set(dials) - set(known))
    if unknown:
        raise SystemExit("🛑 %s: 모르는 스킨 다이얼 %s (있는 것: %s)" % (tid, ", ".join(unknown), ", ".join(sorted(known))))
    os.makedirs(SKINS_DIR, exist_ok=True)
    path = os.path.join(SKINS_DIR, "gohud_skin_%s.tres" % tid)
    lines = ['[gd_resource type="Resource" script_class="%s" load_steps=2 format=3]' % script_class, "",
             '[ext_resource type="Script" path="%s" id="script"]' % script_path, "",
             "[resource]", 'script = ExtResource("script")',
             'skin_name = "%s"' % skin_spec.get("name", tid)]
    for key in sorted(dials):
        value = dials[key]
        # 정수 다이얼은 정수로, 실수 다이얼은 실수로 — 타입이 어긋나면 엔진이 조용히 버린다.
        lines.append("%s = %s" % (key, int(value) if isinstance(known[key], int) and not isinstance(known[key], bool) else float(value)))
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    return path


def all_themes():
    """id → (팔레트, 형태, 메타). 내장 넷 뒤에 `themes/palettes/*.json` 이 이름순으로 온다."""
    out = {tid: (pal, shape, None) for tid, (pal, shape) in BUILTIN_THEMES.items()}
    if os.path.isdir(PALETTES_DIR):
        for name in sorted(os.listdir(PALETTES_DIR)):
            if name.endswith(".json"):
                tid, pal, shape, meta = load_palette_file(os.path.join(PALETTES_DIR, name))
                out[tid] = (pal, shape, meta)
    return out


if __name__ == "__main__":
    import sys
    wanted = set(sys.argv[1:])
    themes = os.path.join(ADDON, "themes")
    write_skin_dials_table()
    registry = all_themes()
    unknown = wanted - set(registry)
    if unknown:
        raise SystemExit("🛑 모르는 테마: %s (있는 것: %s)" % (", ".join(sorted(unknown)), ", ".join(registry)))
    for tid, (pal, shape, meta) in registry.items():
        if wanted and tid not in wanted: continue
        build(pal, shape, tid, os.path.join(themes, "gohud_%s.tres" % tid))
        if meta is not None:
            made = write_skin_resource(tid, meta.get("skin"))
            if made: print("   ↳ 스킨 리소스 %s" % os.path.relpath(made, ADDON))
    print(IMPORT_HINT)
