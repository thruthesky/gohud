# gohud 데모

애드온 하나로 만든 화면 전체 — HUD·버튼·대화상자·알림·터치 컨트롤·테마를 카드 6장에 담았고,
전부 실제로 동작한다(슬라이더를 끌면 숫자가 바뀌고, 조이스틱과 버튼이 눌린다).

```bash
godot                          # 이 폴더에서 — 보통의 Godot 프로젝트다(에디터로 열어도 된다)
bash run.sh --shot out.png     # 화면을 파일로 저장하고 끝낸다
bash run.sh --setup            # ZIP 으로 받아 링크가 없을 때 한 번
```

> 🛑 **`addons/gohud` 는 복사본이 아니라 애드온 루트로 가는 심볼릭 링크(`../../..`)다.** 이 데모가 애드온
> **안**에 있어서 복사하면 원본과 어긋나고, 그냥 두면 자기 자신을 품는 순환이 된다. 링크를 타고 다시
> 들어오는 자리는 이 폴더의 `.gdignore` 가 막는다(루트의 `.gdignore` 는 자기 자신을 막지 않는다 — 실측).

## 무엇을 보나

| 카드 | 쓰인 것 |
|---|---|
| 01 HUD & quick slots | `GoBar` · `GoSlot`(수량·선택 강조·터치 영역 분배) |
| 02 Buttons & inputs | `GoStyle.button`(Primary/Secondary) · `line_edit` · `toggle` · `slider` |
| 03 Dialogs & sheets | `GoStyle.card` · `list_button` · 시트 손잡이 |
| 04 Notices & prompts | `GoNotice` · 확인 카드 |
| 05 Touch controls | `GoJoystick` · `GoStyle.icon_button` + `disc` |
| 06 Themes & icons | 같은 위젯을 **테마만 바꿔** 나란히 · 아이콘 세트 |

색은 `GoConfig.color_overrides` 한 줄로 정한다 — 강조색 하나가 화면 전체를 물들인다.
