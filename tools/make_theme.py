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


DARK = dict(
    background=hexc("0E1117"), surface=hexc("1A1F29"), surface_soft=hexc("222834"),
    surface_high=hexc("2B3342"), border=hexc("3A4557", 0.70), text=hexc("F2F5F9"),
    secondary=hexc("A8B3C2"), muted=hexc("7A869A"), accent=hexc("56CCF2"),
    on_accent=hexc("0B1016"), success=hexc("5FD9A6"), warning=hexc("F5C563"),
    danger=hexc("F27272"), info=hexc("7EA6FF"), scrim=hexc("000000", 0.32),
    shadow=hexc("000000", 0.80), track=hexc("070B11", 0.90),
)

LIGHT = dict(
    background=hexc("F5F7FA"), surface=hexc("FFFFFF"), surface_soft=hexc("EEF1F6"),
    surface_high=hexc("E3E8F0"), border=hexc("9AA6B8", 0.70), text=hexc("121721"),
    secondary=hexc("47536A"), muted=hexc("6B7891"), accent=hexc("0E86C0"),
    on_accent=hexc("FFFFFF"), success=hexc("18845C"), warning=hexc("9A6B06"),
    danger=hexc("C02F2F"), info=hexc("2A5BD7"), scrim=hexc("1B2432", 0.28),
    shadow=hexc("10161F", 0.30), track=hexc("D3DAE5", 0.95),
)

CONST = dict(
    touch=48, button_height=52,
    gap_tiny=4, gap_small=8, gap=12, gap_large=20,
    padding=20, padding_compact=12,
    radius=12, radius_small=8, radius_large=18,
    screen_margin=16,
    scroll_deadzone=18, scroll_edge=4, scrollbar_width=6,
    list_glyph=18, icon_size=20,
    notice_duration_ms=3000,
)

FONTS = dict(micro=10, compact=12, caption=13, body=16, button=16, subtitle=22, title=28)


# ── 테마별 컨트롤 그림 ───────────────────────────────────────────────────

def control_svgs(pal):
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

    def arrow(path):
        return ('<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16" fill="none" '
                'stroke="%s" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="%s"/></svg>') % (sec, path)

    out = {}
    for state_on in (True, False):
        for disabled in (False, True):
            for mirrored in (False, True):
                name = "toggle_%s%s%s" % ("on" if state_on else "off", "_disabled" if disabled else "", "_mirrored" if mirrored else "")
                out[name] = toggle(state_on, disabled, mirrored)
        for disabled in (False, True):
            out["check_%s%s" % ("on" if state_on else "off", "_disabled" if disabled else "")] = check(state_on, disabled)
    out["grabber"] = wrap(20, 20, '<circle cx="10" cy="10" r="8" fill="%s"/>' % acc)
    out["grabber_highlight"] = wrap(20, 20, '<circle cx="10" cy="10" r="10" fill="%s" fill-opacity=".22"/><circle cx="10" cy="10" r="8" fill="%s"/>' % (acc, acc))
    out["grabber_disabled"] = wrap(20, 20, '<circle cx="10" cy="10" r="7" fill="%s"/>' % mut)
    out["arrow_down"] = arrow("M4 6l4 4 4-4")
    out["arrow_right"] = arrow("M6 4l4 4-4 4")
    out["arrow_left"] = arrow("M10 4 6 8l4 4")
    return out


IMPORT_TEMPLATE = ('[remap]\n\nimporter="svg"\ntype="DPITexture"\n\n[deps]\n\nsource_file="%s"\n\n[params]\n\n'
                   'base_scale=1.0\nsaturation=1.0\ncolor_map={}\nfix_alpha_border=false\npremult_alpha=false\ncompress=true\n')


def write_assets(variant, pal):
    folder = os.path.join(ADDON, "assets", variant)
    os.makedirs(folder, exist_ok=True)
    names = []
    for name, svg in control_svgs(pal).items():
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


def build(pal, variant, out_path):
    R, G = CONST["radius"], CONST["radius_small"]
    PAD = (16, 10, 16, 10)
    boxes = {}

    def box(bid, **kw):
        boxes[bid] = ("StyleBoxFlat", flat(**kw))

    hover_bg = mix(pal["surface"], pal["text"], 0.10)
    press_bg = mix(pal["surface"], pal["accent"], 0.22)

    # 버튼
    box("btn_normal", bg=pal["surface"], border=pal["border"], bw=1, radius=R, margins=PAD)
    box("btn_hover", bg=hover_bg, border=alpha(pal["text"], 0.42), bw=1, radius=R, margins=PAD)
    box("btn_pressed", bg=press_bg, border=alpha(pal["accent"], 0.75), bw=1, radius=R, margins=PAD)
    box("btn_disabled", bg=alpha(pal["surface"], 0.55), border=alpha(pal["border"], 0.35), bw=1, radius=R, margins=PAD)
    box("btn_focus", draw_center=False, border=pal["accent"], bw=2, radius=R, margins=PAD)
    box("btn_primary", bg=pal["accent"], border=pal["accent"], bw=1, radius=R, margins=PAD)
    box("btn_primary_hover", bg=mix(pal["accent"], pal["text"], 0.18), border=pal["accent"], bw=1, radius=R, margins=PAD)
    box("btn_primary_pressed", bg=mix(pal["accent"], pal["background"], 0.18), border=pal["accent"], bw=1, radius=R, margins=PAD)
    box("btn_danger", bg=alpha(pal["danger"], 0.14), border=alpha(pal["danger"], 0.8), bw=1, radius=R, margins=PAD)
    box("btn_danger_hover", bg=alpha(pal["danger"], 0.26), border=pal["danger"], bw=1, radius=R, margins=PAD)

    # 얇은 버튼 · 아이콘 버튼 · 목록 항목
    box("compact_normal", bg=alpha(pal["surface_soft"], 0.85), border=alpha(pal["border"], 0.55), bw=1, radius=G, margins=(10, 5, 10, 5))
    box("compact_hover", bg=hover_bg, border=alpha(pal["text"], 0.36), bw=1, radius=G, margins=(10, 5, 10, 5))
    box("icon_hover", bg=alpha(pal["text"], 0.10), radius=G)
    box("list_normal", bg=alpha(pal["surface_soft"], 0.55), radius=G, margins=(0, 0, 0, 0))
    box("list_hover", bg=alpha(pal["text"], 0.09), border=alpha(pal["border"], 0.5), bw=1, radius=G, margins=(0, 0, 0, 0))
    box("focus_soft", draw_center=False, border=alpha(pal["accent"], 0.7), bw=1, radius=G)

    # 표면
    box("panel", bg=pal["surface"], border=pal["border"], bw=1, radius=CONST["radius_large"],
        margins=(0, 0, 0, 0), shadow=(alpha(pal["shadow"], pal["shadow"][3] * 0.55), 18), shadow_offset=(0, 6))
    box("panel_solid", bg=pal["surface"], border=pal["border"], bw=1, radius=R, margins=(0, 0, 0, 0))
    gap = CONST["gap"]
    box("card", bg=pal["surface_soft"], border=alpha(pal["border"], 0.6), bw=1, radius=R, margins=(gap, gap, gap, gap))
    box("popup", bg=mix(pal["surface"], pal["background"], 0.25), border=pal["border"], bw=1, radius=R, margins=(gap, gap, gap, gap))
    small = CONST["gap_small"]
    box("hud", bg=alpha(pal["surface"], 0.82), border=alpha(pal["border"], 0.8), bw=1, radius=R, margins=(small, small, small, small))
    box("notice", bg=mix(pal["surface"], pal["background"], 0.15), border=pal["border"], bw=1, radius=R, margins=(gap, gap, gap, gap))
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
    box("bar_bg", bg=alpha(pal["track"], 0.85), radius=G)
    box("bar_fill", bg=pal["accent"], radius=G)
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

    assets = write_assets(variant, pal)

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
    for key in sorted(CONST):
        add("GoHud/constants/%s" % key, CONST[key])
    for key, bid in [("panel", "panel"), ("card", "card"), ("hud", "hud"), ("notice", "notice"), ("popup", "popup"),
                     ("empty", "empty"), ("focus", "btn_focus"), ("focus_soft", "focus_soft")]:
        sb("GoHud/styles/%s" % key, bid)

    states = [("normal", "btn_normal"), ("hover", "btn_hover"), ("pressed", "btn_pressed"),
              ("hover_pressed", "btn_pressed"), ("disabled", "btn_disabled"), ("focus", "btn_focus")]

    add("Button/colors/font_color", C(pal["text"]))
    add("Button/colors/font_hover_color", C(pal["text"]))
    add("Button/colors/font_pressed_color", C(pal["accent"]))
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
    add("PopupMenu/constants/v_separation", CONST["gap_small"])
    add("PopupMenu/font_sizes/font_size", FONTS["body"])
    sb("PopupMenu/styles/panel", "popup")
    sb("PopupMenu/styles/hover", "btn_hover")

    add("OptionButton/colors/font_color", C(pal["text"]))
    add("OptionButton/font_sizes/font_size", FONTS["body"])
    for state, bid in states:
        sb("OptionButton/styles/%s" % state, bid)
    ex("OptionButton/icons/arrow", "arrow_down")

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
                     ("checked_disabled", "check_on_disabled"), ("unchecked_disabled", "check_off_disabled")]:
        ex("CheckBox/icons/%s" % key, rid)

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

    add("GoDangerButton/base_type", '&"Button"')
    add("GoDangerButton/colors/font_color", C(pal["danger"]))
    add("GoDangerButton/colors/font_hover_color", C(pal["danger"]))
    add("GoDangerButton/colors/font_pressed_color", C(pal["danger"]))
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
    sb("GoListButton/styles/pressed", "list_hover")
    sb("GoListButton/styles/hover_pressed", "list_hover")
    sb("GoListButton/styles/disabled", "list_normal")
    sb("GoListButton/styles/focus", "focus_soft")

    add("GoPanel/base_type", '&"PanelContainer"')
    sb("GoPanel/styles/panel", "panel")
    add("GoCard/base_type", '&"PanelContainer"')
    sb("GoCard/styles/panel", "card")

    lines = ['[gd_resource type="Theme" load_steps=%d format=3]' % (len(boxes) + len(assets) + 1), ""]
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


if __name__ == "__main__":
    themes = os.path.join(ADDON, "themes")
    build(DARK, "dark", os.path.join(themes, "gohud_dark.tres"))
    build(LIGHT, "light", os.path.join(themes, "gohud_light.tres"))
