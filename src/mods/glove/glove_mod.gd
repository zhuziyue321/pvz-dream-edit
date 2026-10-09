extends ModBase
class_name GloveMod
## 模组「手套」：把场上已种下的植物搬到另一个格子（不铲除、不重种，实例与状态全保留）
##
## ★ 为什么是模组：原版没有这个玩法 —— 原版的手套是禅境花园工具（商店买断、用来搬花园植物），
##   关卡内"拎起植物换个地方放下"是同人加的。所以它整条链路都在本模组里，
##   本体（`main_game_base.tscn` / `HandManager` / 卡槽）**不认识手套**，
##   关掉模组时主游戏里不会多出任何一个手套节点。
##
## 装了什么（三件，都在 `install_to_main_game()` 里现场造）：
##   1. `HM_Glove`   —— 手持物组件 `HandComponentGlove`，挂到 `HandManager` 下
##                      （随后被 `HandManager.init_manager()` 登记，类型槽位 `E_HandComponentType.Glove`）
##   2. `UIGlove`    —— 卡槽里的手套按钮，插到 `ShovelContainer`（铲子右边，不占卡牌槽）
##   3. `RealGlove`  —— 跟随鼠标的真手套，挂到 `CanvasLayerTemp`
##
## 还管一件本体做不到的事：**解锁进度**（`UNLOCK_ADVENTURE_LEVEL`）。
## 原本它写在 `ConstUnlockLevel`（本体）里，现在跟着模组走，本体不再有"手套解锁"这个概念。
##
## 唯一留在本体里的东西：`adventure_04_06.gd` 开场那段"戴夫送手套"的赠礼对话 ——
## 它是 4-6 的关卡内容（台词与戴夫手上举的手套是关卡演出资源），
## 由关卡脚本按 `ModManager.is_mod_enabled(ModIds.GLOVE)` 决定是否播。

## 卡槽手套按钮插在哪：以铲子槽为锚点（UIShovel 是本体场景的唯一名节点），
## 这样卡槽布局改了也不用改这里
const SHOVEL_SLOT_NODE := "%UIShovel"
## 跟随鼠标的手套挂这一层（layer 20，跟随画布变换，与真铲子 / 真锤子同层）
const TEMP_LAYER_NODE := "%CanvasLayerTemp"
## 取鼠标全局位置的锚点（与草坪同一坐标系）
const TEMP_CHARACTER_NODE := "%TemporaryCharacter"

const GLOVE_SLOT_SCENE := preload("res://src/mods/glove/glove_slot.tscn")
const GLOVE_TEXTURE := preload("res://assets/image/garden/Zen_GardenGlove.png")
## 真手套在屏幕上的初始位置（与真铲子同排，进手持后才跟着鼠标走）
const REAL_GLOVE_POSITION := Vector2(687, 67)

## 解锁：通关冒险 4-5（关卡序号 35）后戴夫把手套交给玩家，4-6 起卡槽才出现手套。
## 选点理由同旧实现：4-6 是矿工僵尸首次登场的关卡，矿工从后排钻出，
## 玩家第一次需要挪动已种下的植物，赠送即教学；更早给会削弱"种下即定"的布局压力。
const UNLOCK_ADVENTURE_LEVEL := 35


## 通关进度是否已够拿到手套（静态：解锁口径属于模组，本体不需要知道）
static func is_unlocked(max_success_adventure_level: int) -> bool:
	return max_success_adventure_level >= UNLOCK_ADVENTURE_LEVEL


func get_mod_id() -> StringName:
	return ModIds.GLOVE


func get_mod_name() -> String:
	return "手套"


func get_mod_description() -> String:
	return "关卡内把已种下的植物搬到另一个格子（原版没有，原版手套只用于禅境花园）"


## 每局安装：造出三件套并接好线（本体场景里没有手套节点，全靠这里现场装）
func install_to_main_game(main_game: MainGameManager) -> void:
	var hand_manager: HandManager = main_game.hand_manager
	var shovel_slot: Node = main_game.get_node_or_null(SHOVEL_SLOT_NODE)
	var temp_layer: Node = main_game.get_node_or_null(TEMP_LAYER_NODE)
	var temp_character: Node = main_game.get_node_or_null(TEMP_CHARACTER_NODE)
	if hand_manager == null or shovel_slot == null or temp_layer == null or temp_character == null:
		Log.error("手套模组：主游戏缺少挂载点，本局不安装（HandManager=%s 卡槽=%s 临时层=%s 锚点=%s）" % [
			str(hand_manager != null), str(shovel_slot != null),
			str(temp_layer != null), str(temp_character != null)
		])
		return

	## 1. 跟随鼠标的真手套
	var real_glove := RealGlove.new()
	real_glove.name = "RealGlove"
	real_glove.texture = GLOVE_TEXTURE
	real_glove.position = REAL_GLOVE_POSITION
	real_glove.visible = false
	temp_layer.add_child(real_glove)

	## 2. 卡槽里的手套按钮（与铲子同一排，紧贴铲子右侧）
	var glove_slot: UIGlove = GLOVE_SLOT_SCENE.instantiate()
	glove_slot.name = "UIGlove"
	shovel_slot.get_parent().add_child(glove_slot)

	## 3. 手持物组件（HandManager.init_manager() 紧接着就会把它登记进去）
	var glove_component := HandComponentGlove.new()
	glove_component.name = "HM_Glove"
	glove_component.set_visual_nodes(glove_slot, real_glove, temp_character)
	hand_manager.add_child(glove_component)

	## 4. 卡槽按钮 → 组件（模组内部的连线，不走 EventBus）
	glove_slot.glove_clicked.connect(glove_component.on_click_glove)
