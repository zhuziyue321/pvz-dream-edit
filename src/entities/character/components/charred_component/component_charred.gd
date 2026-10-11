extends ComponentNormBase
class_name CharredComponent
## 灰烬组件
##
## 2026-10-11 接入组件体系（U-06）：原先 `extends Node2D`，自己在 components/ 下却不是组件，
## 于是拿不到基类的宿主访问器，只能各自定义 `owner_character`。接入后统一走
## `ComponentNormBase.owner_character`。（它本来就是 Node2D，场景里的节点类型不用改。）

## 播放灰烬动画,将灰烬组件从角色本体中移动到角色父节点
func play_charred_anim():
	#GlobalUtils.child_node_change_parent(self, owner_character.get_sibling_layer())
	reparent(owner_character.get_sibling_layer())
	visible = true
