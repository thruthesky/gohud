# -*- coding: utf-8 -*-
"""🎨 **테마 한 장을 새로 만든다** — 팔레트 JSON 과 프리셋 리소스를 놓아 주면 나머지는 생성기가 한다.

    python3 addons/gohud/tools/new_theme.py neon --from scifi_dark --title "Neon"
    python3 addons/gohud/tools/make_theme.py neon          # 테마 .tres + 컨트롤 그림
    godot --headless --path . --import                      # 새 SVG 임포트
    GoUi.use_preset(&"neon")                                # 끝

    python3 addons/gohud/tools/new_theme.py --remove neon   # 만든 파일 전부 되돌린다

## 왜 이렇게 하는가
테마 하나를 더하려면 원래 네 군데를 손으로 만져야 했다 — 생성기의 팔레트 dict, 형태 dict, 스킨,
프리셋 리소스. 곧 테마가 더 들어온다(2026-09-13 요청). 그래서 **파일 하나**(`themes/palettes/<id>.json`)
로 줄였다: 내장 테마를 `from` 으로 물려받고 바꿀 것만 적는다. 이 도구는 그 파일을 **부모 값을 전부
풀어 적은 채로** 만들어, 무엇을 바꿀 수 있는지가 한눈에 보이게 한다.

🛑 `id` 는 파일 이름이 된다 — 소문자·숫자·밑줄만.
"""
import argparse
import json
import os
import re
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_theme as mt  # noqa: E402

ADDON = mt.ADDON
THEMES = os.path.join(ADDON, "themes")
PRESETS = os.path.join(THEMES, "presets")
PALETTES = mt.PALETTES_DIR
SKINS = mt.SKIN_SCRIPTS


def color_text(c):
    """색 튜플 → `"#RRGGBB"` 또는 `"#RRGGBB@알파"` — 사람이 고치기 쉬운 꼴."""
    body = mt.svg_hex(c).upper()
    return body if abs(c[3] - 1.0) < 1e-6 else "%s@%s" % (body, ("%.2f" % c[3]).rstrip("0").rstrip("."))


def scaffold(tid, base, title, dark, skin, shape_kind, new_skin=False):
    if not re.fullmatch(r"[a-z][a-z0-9_]*", tid):
        raise SystemExit("🛑 id 는 소문자로 시작하고 소문자·숫자·밑줄만 쓴다: %r" % tid)
    registry = mt.all_themes()
    if tid in registry:
        raise SystemExit("🛑 %r 테마는 이미 있다" % tid)
    if base not in registry:
        raise SystemExit("🛑 --from 은 %s 중 하나" % ", ".join(registry))
    pal, shape, meta = registry[base]
    if dark is None: dark = meta["dark"] if meta else base in ("dark", "scifi_dark")
    if skin is None:
        inherited = meta["skin"] if meta else "scifi" if base.startswith("scifi") else "default"
        skin = inherited.get("base", "default") if isinstance(inherited, dict) else inherited
    if shape_kind is None: shape_kind = shape["kind"]

    os.makedirs(PALETTES, exist_ok=True)
    palette_path = os.path.join(PALETTES, tid + ".json")
    preset_path = os.path.join(PRESETS, tid + ".tres")
    for path in (palette_path, preset_path):
        if os.path.exists(path):
            raise SystemExit("🛑 이미 있다: %s (지우려면 --remove %s)" % (os.path.relpath(path, ADDON), tid))

    # 🔑 부모 팔레트를 **전부 풀어 적는다** — 바꿀 수 있는 칸이 그대로 목록이 된다.
    spec = {
        "_help": "색은 \"#RRGGBB\" 또는 \"#RRGGBB@알파\". 지우면 `from` 테마의 값이 쓰인다. "
                 "*_vivid 는 막대 채움 전용 원색(밝은 테마에서 글자색이 어두워져도 막대는 선명하게).",
        "id": tid,
        "title": title or tid.replace("_", " ").title(),
        "dark": bool(dark),
        "from": base,
        "skin": {
            "_help": "base: default | scifi | medieval. dials 는 스킨 코드를 안 만지고 바꾸는 숫자 — 값을 지우면 부모 값이다. "
                     "그림 자체를 바꾸려면 --new-skin 으로 GoSkin 을 상속한 스크립트 껍데기를 만든다.",
            "base": skin,
            "dials": {**mt.skin_dials()["default"], **mt.skin_dials()[skin],
                      **(meta["skin"].get("dials", {}) if meta and isinstance(meta["skin"], dict)
                         and meta["skin"].get("base") == skin else {})},
        },
        "shape": {
            "_help": "kind: flat(둥근 모서리) | cut(사선 모서리) | medieval(금속 프레임). 아래 숫자를 더하면 CONST 를 덮어쓴다 — "
                     "radius, radius_small, radius_large, gap, gap_small, gap_large, padding, button_height, "
                     "button_padding[4]. cut 전용: cut_ratio, cut_max, corners(diagonal|all), glow, edge.",
            "kind": shape_kind,
            **{k: v for k, v in (shape if shape_kind == shape["kind"] else mt.SHAPES[shape_kind]).items()
               if k not in ("kind", "controls")},
        },
        "palette": {key: color_text(pal[key]) for key in pal},
    }
    if meta and meta.get("icons"):
        spec["icons"] = meta["icons"]
    with open(palette_path, "w", encoding="utf-8") as fh:
        json.dump(spec, fh, ensure_ascii=False, indent=2)
        fh.write("\n")

    with open(preset_path, "w", encoding="utf-8") as fh:
        fh.write('[gd_resource type="Resource" script_class="GoThemePreset" load_steps=%d format=3]\n\n' % (5 if spec.get("icons") else 4))
        fh.write('[ext_resource type="Script" path="res://addons/gohud/core/go_theme_preset.gd" id="script"]\n')
        fh.write('[ext_resource type="Theme" path="res://addons/gohud/themes/gohud_%s.tres" id="theme"]\n' % tid)
        # 🔑 스킨은 이 테마 전용 리소스(`gohud_skin_<id>.tres`)를 가리킨다 — `make_theme.py` 가 JSON 의
        #    `skin.dials` 로 그 파일을 만든다. 그래서 다이얼을 고치고 생성기만 다시 돌리면 된다.
        fh.write('[ext_resource type="Resource" path="res://addons/gohud/themes/skins/gohud_skin_%s.tres" id="skin"]\n\n' % tid)
        if spec.get("icons"):
            fh.write('[ext_resource type="Resource" path="%s" id="icons"]\n\n' % spec["icons"])
        fh.write('[resource]\nscript = ExtResource("script")\nid = &"%s"\ntitle = "%s"\ndark = %s\n'
                 'theme = ExtResource("theme")\nskin = ExtResource("skin")\n'
                 % (tid, spec["title"].replace('"', '\\"'), "true" if dark else "false"))
        if spec.get("icons"):
            fh.write('icons = ExtResource("icons")\n')

    if new_skin:
        write_skin_script(tid, skin)
    print("✅ %s\n   %s  ← 색·모양·스킨 다이얼을 여기서 고친다\n   %s  ← 고르개에 뜨는 묶음"
          % (tid, os.path.relpath(palette_path, ADDON), os.path.relpath(preset_path, ADDON)))
    print("다음:\n   python3 %s %s\n   godot --headless --path . --import\n   GoUi.use_preset(&\"%s\")"
          % (os.path.relpath(os.path.join(HERE, "make_theme.py"), ADDON), tid, tid))


def write_skin_script(tid, base):
    """`GoSkin` 을 상속한 **스크립트 껍데기** — 그림 자체(조이스틱·링·배지)를 바꿀 때만 필요하다."""
    parent = mt.SKIN_SCRIPTS[base][0]
    path = os.path.join(THEMES, "skins", "go_skin_%s.gd" % tid)
    if os.path.exists(path):
        raise SystemExit("🛑 이미 있다: %s" % os.path.relpath(path, ADDON))
    body = f"""## 🎨 `{tid}` 테마의 스킨 — `{parent}` 을 물려받아 바꿀 자리만 덮어쓴다.
##
## 테마(.tres)와 형태가 닿지 못하는 자리만 여기다: 코드가 직접 그리는 조이스틱·퀵슬롯 판·배지·
## 코치마크 링·칩·구분선. 숫자만 바꿀 거라면 이 파일은 필요 없다 — `themes/palettes/{tid}.json` 의
## `skin.dials` 로 충분하다. 덮어쓰지 않은 것은 부모 모양이 남는다.
##
## 덮어쓸 수 있는 것(전부 `GoSkin` 참조):
##   surface_box · floating_box · disc_box · chip_box · chip_ink · slot_box · slot_ink · badge_box
##   skeleton_box · alert_box · segment_box · progress_fill_box · notice_box · tint_notice
##   coach_ring_box · divider_color · divider_thickness · section_box · draw_joystick · draw_coach_pointer
class_name GoSkin{tid.title().replace("_", "")}
extends {parent}


## 예: 퀵슬롯 판만 다르게.
# func slot_box(accent: Color, lit: bool) -> StyleBox:
# \tvar box := super(accent, lit)
# \treturn box
"""
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(body)
    print("   %s  ← 그림을 바꾸려면 여기 메서드를 덮어쓴다" % os.path.relpath(path, ADDON))
    # 스킨 리소스가 이 스크립트를 가리키게 팔레트 JSON 의 base 는 그대로 두되, 생성기가 만드는
    # `gohud_skin_<id>.tres` 는 부모 스크립트를 가리킨다 — 이 껍데기를 쓰려면 아래 한 줄로 바꾼다.
    print("   → gohud_skin_%s.tres 의 script 를 이 파일로 바꾸면 적용된다(생성기가 다시 만들 때 덮이지 않게 JSON 의 skin 을 문자열 \"%s\" 로 두는 편이 낫다)" % (tid, tid))


def remove(tid):
    """만든 파일을 전부 지운다 — 팔레트·프리셋·생성된 테마·스킨·그림 폴더."""
    gone = []
    for path in (os.path.join(PALETTES, tid + ".json"), os.path.join(PRESETS, tid + ".tres"),
                 os.path.join(THEMES, "gohud_%s.tres" % tid),
                 os.path.join(THEMES, "skins", "gohud_skin_%s.tres" % tid),
                 os.path.join(THEMES, "skins", "go_skin_%s.gd" % tid),
                 os.path.join(THEMES, "skins", "go_skin_%s.gd.uid" % tid)):
        if os.path.exists(path):
            os.remove(path); gone.append(path)
    assets = os.path.join(ADDON, "assets", tid)
    if os.path.isdir(assets):
        shutil.rmtree(assets); gone.append(assets)
    for path in gone:
        print("🗑  %s" % os.path.relpath(path, ADDON))
    if not gone:
        print("(지울 것이 없다: %s)" % tid)


def main():
    parser = argparse.ArgumentParser(description="gohud 테마 스캐폴딩")
    parser.add_argument("id", nargs="?", help="새 테마 이름(소문자·숫자·밑줄)")
    parser.add_argument("--from", dest="base", default="dark", help="물려받을 테마: dark | light | scifi_dark | medieval_dark | ...")
    parser.add_argument("--title", default="", help="고르개에 보일 이름")
    parser.add_argument("--dark", dest="dark", action="store_true", default=None)
    parser.add_argument("--light", dest="dark", action="store_false")
    parser.add_argument("--skin", choices=sorted(SKINS), default=None, help="코드가 직접 그리는 자리의 모양")
    parser.add_argument("--shape", choices=sorted(mt.SHAPES), default=None, help="판의 모양 계열")
    parser.add_argument("--new-skin", action="store_true", help="GoSkin 을 상속한 스크립트 껍데기도 만든다(그림 자체를 바꿀 때)")
    parser.add_argument("--remove", metavar="ID", help="만든 파일을 전부 지운다")
    args = parser.parse_args()
    if args.remove:
        remove(args.remove); return
    if not args.id:
        parser.error("id 를 준다 (예: neon)")
    scaffold(args.id, args.base, args.title, args.dark, args.skin, args.shape, args.new_skin)


if __name__ == "__main__":
    main()
