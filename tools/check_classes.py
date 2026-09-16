# -*- coding: utf-8 -*-
"""같은 `class_name` 이 저장소 안에 **둘 이상** 있는지 본다.

    python3 addons/gohud/tools/check_classes.py

## 🛑 왜 필요한가 (2026-09-16 실측)

`examples/usage/` 에는 "게임 프로젝트에 설치한 모습" 을 보이려고 **애드온 사본이 한 벌 더** 들어
있었고, 거기에 `.gdignore` 가 없었다. 그래서 `GoUi`·`GoConfig`·`GoStyle` 을 비롯한 **35 개 클래스가
두 번 선언**됐다.

같은 `class_name` 이 둘이면 Godot 은 하나만 고르고, **어느 쪽인지는 사람이 정하지 못한다.** 고른
결과는 스캔 순서와 `.godot` 캐시에 달려 있어 기계마다 달라질 수 있다.

🛑 **틀려도 오류가 나지 않는다.** 옛 사본의 클래스도 그 자체로는 멀쩡히 동작하므로, 고른 쪽이 옛
것이어도 화면은 조용히 옛 동작을 한다. 단위 검사도 전부 통과한다 — 검사는 **고른 그 클래스**를
보기 때문이다. 그래서 이 겹침은 사람이 알아채기 전에는 드러나지 않고, 검사로만 막을 수 있다.

🔑 배포 ZIP 에는 `examples/usage/` 가 들어가지 않는다(`tools/check_package.py`). 위험한 것은 저장소를
통째로 쓰는 쪽 — README 가 안내하는 **git 서브모듈** 방식이다.

🔑 `.gdignore` 가 있는 폴더는 Godot 이 통째로 건너뛰므로 여기서도 건너뛴다 — 사본을 두는 것 자체는
문제가 아니고, **스캔되게 두는 것**이 문제다.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.normpath(os.path.join(HERE, ".."))
SKIP = {".git", ".godot", "builds", "__pycache__", ".cowork", "node_modules"}
CLASS = re.compile(r"^class_name\s+([A-Za-z_][A-Za-z0-9_]*)", re.M)


def scan():
	"""`class_name` → 그것을 선언한 파일들. `.gdignore` 가 있는 폴더는 통째로 건너뛴다."""
	found = {}
	for root, dirs, files in os.walk(ADDON):
		if ".gdignore" in files:
			dirs[:] = []            # Godot 과 같은 규칙 — 이 아래로는 내려가지 않는다
			continue
		dirs[:] = [name for name in dirs if name not in SKIP]
		for name in sorted(files):
			if not name.endswith(".gd"):
				continue
			path = os.path.join(root, name)
			try:
				text = open(path, encoding="utf-8").read()
			except (UnicodeDecodeError, OSError):
				continue
			for match in CLASS.finditer(text):
				found.setdefault(match.group(1), []).append(os.path.relpath(path, ADDON))
	return found


def main():
	found = scan()
	clashes = {name: paths for name, paths in found.items() if len(paths) > 1}
	print("스크립트가 선언하는 클래스 %d개" % len(found))
	if not clashes:
		print("\n✅ 같은 이름을 두 번 선언하는 곳이 없다")
		return 0
	for name in sorted(clashes):
		print("   🛑 %s — %s" % (name, " · ".join(clashes[name])))
	print("\n🛑 같은 class_name 이 둘 이상이다 — %d개" % len(clashes))
	print("   사본을 둔 폴더라면 그 폴더에 빈 `.gdignore` 를 둔다(Godot 이 통째로 건너뛴다).")
	return 1


if __name__ == "__main__":
	raise SystemExit(main())
