# -*- coding: utf-8 -*-
"""테마의 **명도 대비비**를 재서 읽기 어려운 색 짝을 찾아낸다.

    python3 addons/gohud/tools/check_contrast.py           # 모든 테마를 잰다
    python3 addons/gohud/tools/check_contrast.py --strict   # 경고도 실패로 센다(CI용)

## 왜 재는가
"예쁘다" 는 취향이지만 **"읽힌다" 는 측정할 수 있다.** 밝은 테마에서 흐린 회색 글자는 디자이너의
좋은 모니터에서는 멀쩡해 보이고 햇빛 아래 폰에서는 사라진다. 눈으로 고르면 반드시 그렇게 된다.

## 기준 — WCAG 2.2 대비 최소값
| 글자 | 필요한 비 |
|---|---|
| 본문(24px 미만, 또는 19px 미만 굵게) | **4.5 : 1** |
| 큰 글자(24px 이상) | **3 : 1** |
| UI 부품의 경계·아이콘 | **3 : 1** |

🛑 알파가 있는 색은 **깔린 배경 위에 합성한 뒤** 잰다 — 반투명 테두리를 그대로 재면 실제보다
   좋게 나온다. 배경이 불투명하지 않으면 그 아래 `background` 까지 차례로 합성한다.
"""
import argparse
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.normpath(os.path.join(HERE, ".."))
THEMES = os.path.join(ADDON, "themes")

# 본문 4.5 · 큰 글자 3 · 부품 경계 3
BODY, LARGE, UI = 4.5, 3.0, 3.0

# 🛑 장식 테두리는 WCAG 의 3:1 대상이 **아니다.** 1.4.11 은 "그것을 못 보면 기능을 쓸 수 없는"
#    경계에만 적용되는데, gohud 의 카드는 배경색 차이로 이미 구분된다 — 테두리는 그 위의 장식이다.
#    그래도 아예 안 보이면 카드가 배경에 녹으므로, 경계가 눈에 드는 최소선을 따로 둔다.
DECOR = 2.0


def parse_theme(path):
    """`GoHud/colors/*` 토큰만 뽑는다 — 그것이 위젯이 실제로 쓰는 색이다."""
    colors = {}
    for line in open(path, encoding="utf-8"):
        match = re.match(r"^GoHud/colors/([a-z_]+)\s*=\s*Color\(([^)]+)\)", line.strip())
        if match:
            parts = [float(value) for value in match.group(2).split(",")]
            while len(parts) < 4:
                parts.append(1.0)
            colors[match.group(1)] = tuple(parts[:4])
    return colors


def over(top, bottom):
    """알파 합성 — `top` 을 `bottom` 위에 얹은 실제 색."""
    alpha = top[3]
    return tuple(top[i] * alpha + bottom[i] * (1.0 - alpha) for i in range(3)) + (1.0,)


def luminance(color):
    def channel(value):
        value = max(0.0, min(1.0, value))
        return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4
    r, g, b = (channel(color[i]) for i in range(3))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def ratio(front, back):
    a, b = luminance(front), luminance(back)
    high, low = max(a, b), min(a, b)
    return (high + 0.05) / (low + 0.05)


def solid(colors, name, under="background"):
    """토큰 하나를 **불투명한 실제 화면 색**으로 만든다."""
    base = colors.get(under, (0, 0, 0, 1))
    if base[3] < 1.0:
        base = over(base, (0, 0, 0, 1.0))
    value = colors.get(name)
    if value is None:
        return None
    return over(value, base) if value[3] < 1.0 else value


# (앞색, 뒷배경, 필요한 비, 어디에 쓰이나)
def pairs(colors):
    surfaces = ["surface", "surface_soft", "surface_high"]
    out = []
    for back in ["background"] + surfaces:
        out.append(("text", back, BODY, "본문 글자"))
        out.append(("secondary", back, BODY, "보조 글자(캡션)"))
        out.append(("muted", back, BODY, "흐린 글자(마이크로 라벨·비활성)"))
    out.append(("on_accent", "accent", BODY, "강조 버튼의 글자"))
    for tone in ["success", "warning", "danger", "info"]:
        out.append((tone, "surface", BODY, "%s 상태 글자" % tone))
        out.append((tone, "background", BODY, "%s 상태 글자(바탕 위)" % tone))
    out.append(("accent", "surface", UI, "강조 테두리·아이콘"))
    out.append(("accent", "background", UI, "강조 테두리·아이콘(바탕 위)"))
    out.append(("border", "surface", DECOR, "카드 테두리(장식 — WCAG 3:1 대상 아님)"))
    out.append(("border", "background", DECOR, "카드 테두리(바탕 위)"))
    return out


# 🛑 **면끼리도 구분되어야 한다.** 글자 대비만 재면 "카드가 배경에 녹아 어디까지가 카드인지 모르겠다" 를
#    놓친다. WCAG 는 이 짝에 기준을 주지 않는다(장식도 글자도 아니므로). 눈이 경계를 알아보는 최소선을
#    경험으로 잡는다 — Material 의 표면 단계도 대략 이 정도 차이를 둔다.
LAYER = 1.12

# (위 면, 아래 면, 무엇이 구분되는가)
LAYER_PAIRS = [
    ("surface", "background", "패널이 화면 바탕에서"),
    ("surface_soft", "surface", "카드가 패널에서"),
    ("surface_high", "surface_soft", "도드라진 칸이 카드에서"),
    # 🛑 **카드는 바탕 위에도 놓인다.** 이 쌍을 빠뜨렸다가 밝은 테마에서 카드가 바탕과 1.00:1 이 되어
    #    목록 줄의 판이 통째로 사라진 것을 스크린샷에서야 발견했다(2026-09-13).
    ("surface_soft", "background", "카드가 화면 바탕에서"),
    ("surface_high", "background", "도드라진 칸이 화면 바탕에서"),
]


def layer_rows(colors):
    rows = []
    for top, bottom, note in LAYER_PAIRS:
        a = solid(colors, top, "background")
        b = solid(colors, bottom, "background")
        if a is None or b is None:
            continue
        rows.append({
            "front": top, "back": bottom, "need": LAYER, "note": note + " 구분된다",
            "ratio": ratio(a, b),
        })
    return rows


def parse_boxes(path):
    """`[sub_resource ...] id="x"` 블록마다 `bg_color` 를 모은다.

    🛑 커스텀 StyleBox(`type="StyleBox"` + script)도 `bg_color` 칸을 쓴다 — 타입 이름으로 거르지 않는다.
    """
    boxes = {}
    current = None
    for line in open(path, encoding="utf-8"):
        line = line.strip()
        head = re.match(r'^\[sub_resource type="[^"]+" id="([^"]+)"\]', line)
        if head:
            current = head.group(1)
            continue
        if line.startswith("["):
            current = None
            continue
        if current:
            match = re.match(r"^bg_color\s*=\s*Color\(([^)]+)\)", line)
            if match:
                parts = [float(v) for v in match.group(1).split(",")]
                while len(parts) < 4:
                    parts.append(1.0)
                boxes[current] = tuple(parts[:4])
            elif re.match(r"^draw_center\s*=\s*false", line):
                boxes[current] = None      # 배경을 안 그린다 — 아래 판이 그대로 보인다
    return boxes


def parse_theme_map(path):
    """`Type/styles/state = SubResource("id")` 와 `Type/colors/name = Color(...)`, 그리고 `base_type`."""
    styles, fonts, bases = {}, {}, {}
    for line in open(path, encoding="utf-8"):
        line = line.strip()
        match = re.match(r'^([A-Za-z0-9_]+)/styles/([a-z_]+)\s*=\s*SubResource\("([^"]+)"\)', line)
        if match:
            styles.setdefault(match.group(1), {})[match.group(2)] = match.group(3)
            continue
        match = re.match(r"^([A-Za-z0-9_]+)/colors/([a-z_]+)\s*=\s*Color\(([^)]+)\)", line)
        if match:
            parts = [float(v) for v in match.group(3).split(",")]
            while len(parts) < 4:
                parts.append(1.0)
            fonts.setdefault(match.group(1), {})[match.group(2)] = tuple(parts[:4])
            continue
        match = re.match(r'^([A-Za-z0-9_]+)/base_type\s*=\s*&"([^"]+)"', line)
        if match:
            bases[match.group(1)] = match.group(2)
    return styles, fonts, bases


# 상태 → 그 상태에서 쓰이는 글자색 칸(없으면 앞의 것으로 떨어진다)
STATE_FONTS = {
    "normal": ["font_color"],
    "hover": ["font_hover_color", "font_color"],
    "pressed": ["font_pressed_color", "font_color"],
    "disabled": ["font_disabled_color", "font_color"],
}

# 검사할 타입 — 글자를 담는 것만. 스크롤바·슬라이더는 글자가 없다.
TEXT_TYPES = [
    "Button", "OptionButton", "GoButton", "GoPrimaryButton", "GoDangerButton", "GoDangerSolidButton",
    "GoCompactButton", "GoListButton", "LineEdit", "TextEdit", "PopupMenu", "TabBar",
    "FoldableContainer",
]


def font_for(fonts, bases, type_name, keys):
    """타입에 그 색이 없으면 `base_type` 을 따라 올라간다 — 엔진이 실제로 그렇게 찾는다."""
    seen = 0
    current = type_name
    while current and seen < 8:
        table = fonts.get(current, {})
        for key in keys:
            if key in table:
                return table[key]
        current = bases.get(current)
        seen += 1
    return None


# 🛑 **떠 있는 판은 뒤에 무엇이 올지 모른다.** HUD·팝업·알림은 게임 화면 위에 얹힌다 — 눈밭일 수도,
#    동굴일 수도 있다. 판이 반투명이면 뒤가 비쳐 판 색 자체가 달라지고, 그 위 글자 대비가 따라 무너진다.
#    갤러리에서도 스크롤 본문이 HUD 뒤를 지나가며 같은 일이 벌어졌다(2026-09-13 실측).
#    그래서 **순백과 순흑**을 깔아 보고도 본문 기준을 지키는지 잰다 — 게임 화면의 최악이 그 둘이다.
FLOATING_STYLES = ["hud", "popup", "notice", "panel", "card", "empty"]
FLOATING_INKS = [("text", BODY), ("secondary", BODY), ("muted", BODY)]
WORST_BACKDROPS = [((1.0, 1.0, 1.0, 1.0), "순백"), ((0.0, 0.0, 0.0, 1.0), "순흑")]


def parse_box_field(path, *fields):
    """`sub_resource` 블록마다 주어진 색 칸 중 **먼저 나오는 것**을 모은다.

    커스텀 StyleBox 는 칸 이름이 다르다 — 챔퍼 판은 `border_color`, 조준 표식은 `color` 다.
    """
    found = {}
    current = None
    for line in open(path, encoding="utf-8"):
        line = line.strip()
        head = re.match(r'^\[sub_resource type="[^"]+" id="([^"]+)"\]', line)
        if head:
            current = head.group(1)
            continue
        if line.startswith("["):
            current = None
            continue
        if current is None or current in found:
            continue
        for field in fields:
            match = re.match(r"^%s\s*=\s*Color\(([^)]+)\)" % re.escape(field), line)
            if match:
                parts = [float(v) for v in match.group(1).split(",")]
                while len(parts) < 4:
                    parts.append(1.0)
                found[current] = tuple(parts[:4])
                break
    return found


# 🛑 **포커스 표시는 그것이 얹히는 판 위에서 보여야 한다.** 강조 버튼의 판이 바로 강조색이라,
#    강조색 링을 그리면 같은 색이 겹쳐 **사라진다** — 키보드로 옮겨 다닐 때 "지금 어디" 가 없어진다
#    (2026-09-13 데스크톱 실측: 호버와 포커스가 구별되지 않았다). WCAG 2.4.11 은 포커스 표시에
#    3:1 을 요구한다.
FOCUS_TYPES = ["Button", "GoPrimaryButton", "GoDangerButton", "GoDangerSolidButton"]


# 🛑 **툴팁은 타입이 둘로 나뉜다** — 판은 `TooltipPanel`, 글자는 `TooltipLabel` 이다. 한 타입 안에서
#    판과 글자를 짝지어 보는 검사로는 **절대 걸리지 않는다.** 그리고 아이콘 버튼은 글자가 없어,
#    마우스 사용자에게 툴팁이 그 버튼의 **유일한 설명**이다.
def tooltip_rows(path, colors):
    boxes = parse_boxes(path)
    styles, fonts, _bases = parse_theme_map(path)
    panel_id = styles.get("TooltipPanel", {}).get("panel")
    ink = fonts.get("TooltipLabel", {}).get("font_color")
    if panel_id is None or ink is None or panel_id not in boxes:
        return []
    panel = boxes[panel_id]
    base = solid(colors, "background", "background")
    back = base if panel is None else (over(panel, base) if panel[3] < 1.0 else panel)
    front = over(ink, back) if ink[3] < 1.0 else ink
    return [{
        "front": "툴팁 글자", "back": "툴팁 판", "need": BODY, "ratio": ratio(front, back),
        "note": "아이콘 버튼의 유일한 설명",
    }]


def focus_rows(path, colors):
    boxes = parse_boxes(path)
    edges = parse_box_field(path, "border_color", "color")
    styles, _fonts, _bases = parse_theme_map(path)
    rows = []
    base = solid(colors, "background", "background")
    for type_name in FOCUS_TYPES:
        table = styles.get(type_name)
        if not table:
            continue
        focus_id = table.get("focus")
        normal_id = table.get("normal")
        if focus_id is None or focus_id not in edges:
            continue
        ring = edges[focus_id]
        under = base
        if normal_id is not None and boxes.get(normal_id) is not None:
            panel = boxes[normal_id]
            under = over(panel, base) if panel[3] < 1.0 else panel
        front = over(ring, under) if ring[3] < 1.0 else ring
        rows.append({
            "front": "%s 포커스 링" % type_name, "back": "자기 판 위",
            "need": UI, "ratio": ratio(front, under),
            "note": "키보드로 옮겼을 때 어디인지 보인다",
        })
    return rows


def floating_rows(path, colors):
    """반투명한 떠 있는 판 — 뒤가 무엇이든 판 위 글자가 읽히는가."""
    boxes = parse_boxes(path)
    styles, _fonts, _bases = parse_theme_map(path)
    hud_styles = styles.get("GoHud", {})
    rows = []
    for style_name in FLOATING_STYLES:
        box_id = hud_styles.get(style_name)
        if box_id is None or box_id not in boxes:
            continue
        box_bg = boxes[box_id]
        if box_bg is None or box_bg[3] >= 1.0:
            continue                      # 배경을 안 그리거나 불투명하면 뒤가 비칠 일이 없다
        for ink_name, need in FLOATING_INKS:
            raw = colors.get(ink_name)
            if raw is None:
                continue
            worst, worst_name = None, ""
            for backdrop, backdrop_name in WORST_BACKDROPS:
                back = over(box_bg, backdrop)
                front = over(raw, back) if raw[3] < 1.0 else raw
                value = ratio(front, back)
                if worst is None or value < worst:
                    worst, worst_name = value, backdrop_name
            rows.append({
                "front": ink_name, "back": "%s 판/%s" % (style_name, worst_name),
                "need": need, "ratio": worst,
                "note": "떠 있는 판 뒤가 비쳐도 읽힌다",
            })
    return rows


def surface_rows(path, colors):
    """**StyleBox 배경 위의 글자** — 눈에 실제로 보이는 조합을 잰다."""
    boxes = parse_boxes(path)
    styles, fonts, bases = parse_theme_map(path)
    under_names = ["background", "surface_soft"]      # 버튼은 바탕 위에도, 카드 안에도 놓인다
    rows = []
    for type_name in TEXT_TYPES:
        table = styles.get(type_name)
        if not table:
            continue
        for state, keys in STATE_FONTS.items():
            box_id = table.get(state)
            if box_id is None or box_id not in boxes:
                continue
            box_bg = boxes[box_id]
            ink = font_for(fonts, bases, type_name, keys)
            if ink is None:
                continue
            worst, worst_under = None, ""
            for under in under_names:
                base = solid(colors, under)
                if base is None:
                    continue
                back = base if box_bg is None else (over(box_bg, base) if box_bg[3] < 1.0 else box_bg)
                front = over(ink, back) if ink[3] < 1.0 else ink
                value = ratio(front, back)
                if worst is None or value < worst:
                    worst, worst_under = value, under
                if box_bg is not None and box_bg[3] >= 1.0:
                    break        # 불투명한 판이면 아래가 무엇이든 같다
            if worst is None:
                continue
            rows.append({
                "front": "%s.%s" % (type_name, state), "back": "판 위 (%s)" % worst_under,
                "need": BODY, "ratio": worst, "note": "버튼·입력칸 글자",
            })
    return rows


def measure(path):
    colors = parse_theme(path)
    if not colors:
        return None, []
    rows = []
    for front, back, need, note in pairs(colors):
        back_solid = solid(colors, back) if back != "background" else solid(colors, "background", "background")
        if back_solid is None:
            continue
        raw = colors.get(front)
        if raw is None:
            continue
        front_solid = over(raw, back_solid) if raw[3] < 1.0 else raw
        rows.append({
            "front": front, "back": back, "need": need, "note": note,
            "ratio": ratio(front_solid, back_solid),
        })
    rows += surface_rows(path, colors)
    rows += floating_rows(path, colors)
    rows += focus_rows(path, colors)
    rows += tooltip_rows(path, colors)
    rows += layer_rows(colors)
    return colors, rows


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--strict", action="store_true", help="아깝게 넘긴 것(기준의 1.1배 미만)도 실패로 센다")
    parser.add_argument("--quiet", action="store_true", help="통과한 줄은 감춘다")
    args = parser.parse_args()

    files = sorted(name for name in os.listdir(THEMES) if name.endswith(".tres"))
    failures = 0
    for name in files:
        path = os.path.join(THEMES, name)
        colors, rows = measure(path)
        if not rows:
            continue
        bad = [row for row in rows if row["ratio"] < row["need"]]
        thin = [row for row in rows if row["need"] <= row["ratio"] < row["need"] * 1.1]
        mark = "🛑" if bad else ("⚠️ " if thin else "✅")
        print("\n%s %s — 짝 %d개 · 미달 %d · 아슬아슬 %d" % (mark, name, len(rows), len(bad), len(thin)))
        for row in sorted(rows, key=lambda r: r["ratio"]):
            failed = row["ratio"] < row["need"]
            close = not failed and row["ratio"] < row["need"] * 1.1
            if args.quiet and not failed and not close:
                continue
            flag = "🛑" if failed else ("⚠️ " if close else "  ")
            print("   %s %-24s on %-20s %5.2f:1  (필요 %.1f)  %s"
                  % (flag, row["front"], row["back"], row["ratio"], row["need"], row["note"]))
        failures += len(bad) + (len(thin) if args.strict else 0)

    print("\n%s 미달 합계 %d" % ("🛑" if failures else "✅", failures))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
