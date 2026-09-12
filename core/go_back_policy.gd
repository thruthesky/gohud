## ⬅️ Android **뒤로가기 소유권**. 열려 있는 창이 하나라도 있으면 뒤로가기가 앱을 끄지 않게 한다.
##
## ## 왜 세어야 하나
## `SceneTree.quit_on_go_back` 은 전역 스위치 하나다. 창 A 가 끄고 창 B 가 켜면 A 가 아직
## 열려 있는데도 뒤로가기가 앱을 종료한다. 그래서 **연 개수를 세고**, 마지막 하나가 닫힐 때
## 원래 값으로 되돌린다.
##
## ```gdscript
## GoBackPolicy.acquire(get_tree())   # 창이 뜰 때
## GoBackPolicy.release(get_tree())   # 창이 닫힐 때 — `_exit_tree` 에서도 반드시
## ```
##
## 🛑 `acquire` 한 창은 **무슨 일이 있어도** `release` 해야 한다. 노드가 `queue_free` 로 사라지는
##    경로까지 포함해서다(그래서 `GoSurface` 는 `_exit_tree` 에서도 놓는다). 빠뜨리면 창을 다
##    닫았는데 뒤로가기가 영영 죽는다.
class_name GoBackPolicy
extends RefCounted

static var _owners := 0
static var _previous := true


## 지금 뒤로가기를 붙잡고 있는 창의 수.
static func owners() -> int:
	return _owners


static func acquire(tree: SceneTree) -> void:
	if tree == null: return
	if _owners == 0: _previous = tree.quit_on_go_back
	_owners += 1
	tree.quit_on_go_back = false


static func release(tree: SceneTree) -> void:
	if tree == null or _owners == 0: return
	_owners -= 1
	if _owners == 0: tree.quit_on_go_back = _previous


## 🛑 검사 사이의 초기화용. 제품 코드에서 부르지 않는다.
static func reset(tree: SceneTree = null) -> void:
	_owners = 0
	if tree != null: tree.quit_on_go_back = _previous
