extends Node
class_name CardSlotController
## 常规卡槽控制器（出战卡槽 + 待选卡槽）
##
## 只管「玩家选出来的那一套卡」：建卡槽、选卡阶段出现 / 收起、主游戏阶段挪进 HUD 容器、
## 多轮换一轮时归位、卡槽扩充补一格、阳光存档。
##
## 传送带归 `ConveyorBeltController` 管，两者可以同时存在（卡槽在上、传送带在下），
## 谁都不直接碰对方的节点 —— 见 docs/参考存档/卡槽与传送带.md

## 出战卡槽在场景里写死的高度（offset_top = -100 / offset_bottom = -10）：
## 还没布局过（size 为 0）时用它把传送带压到卡槽下面
const DEFAULT_SLOT_HEIGHT := 90.0

## 所属卡片管理器（卡槽根节点 / HUD 容器 / 关卡数据都从它取）
var card_manager: CardManager
## 卡槽根节点：快捷键从这里取当前卡片
var card_slot_root: CardSlotRoot
## 主游戏阶段的卡槽容器
var card_slot_container: PanelContainer

## 常规卡槽（出战卡槽 + 待选卡槽都在这上面）
var card_slot_norm: CardSlotNorm
## 出战卡槽
var card_slot_battle: CardSlotBattle
## 出战卡槽是否已经出现过（选卡阶段出现过就不用再播一次入场）
var is_norm_appeared := false


## 由 CardManager 在 init_manager() 里调用，先于 create()
func setup(manager: CardManager) -> void:
	card_manager = manager
	card_slot_root = manager.card_slot_root
	card_slot_container = manager.card_slot_container


## 建卡槽；关卡数据里没有常规卡槽时直接返回 false（调用方据此跳过卡槽相关流程）
func create() -> bool:
	if card_manager == null or not card_manager.game_para.has_norm_card_slot():
		return false
	card_slot_norm = load("res://src/ui/card/card_slot/card_slot_norm.tscn").instantiate()
	card_slot_root.add_child(card_slot_norm)
	card_slot_norm.init_card_slot_norm(card_manager.game_para)
	card_slot_battle = card_slot_norm.card_slot_battle
	card_slot_root.curr_cards = card_slot_battle.curr_cards
	return true


## 本关有没有常规卡槽
func has_card_slot() -> bool:
	return card_slot_norm != null


## 出战卡槽上的卡（选卡结果 / 系统预选卡）
func get_cards() -> Array[Card]:
	if card_slot_battle == null:
		return []
	return card_slot_battle.curr_cards


## 出战卡槽的高度：同时有传送带时用它把传送带压到卡槽下面（卡槽在上、传送带在下）
func get_slot_height() -> float:
	if not has_card_slot():
		return 0.0
	var height := card_slot_battle.size.y
	return height if height > 0.0 else DEFAULT_SLOT_HEIGHT


#region 阶段切换
## 选卡阶段：出战卡槽与待选区一起出现
func appear_choose() -> void:
	if not has_card_slot():
		return
	is_norm_appeared = true
	card_slot_norm.move_card_slot_battle(true)
	card_slot_norm.move_card_slot_candidate(true)


## 选卡结束：收起待选区（传送带这类没有常规卡槽的关卡直接空转）
func disappear_choose() -> void:
	if not has_card_slot():
		return
	await card_slot_norm.move_card_slot_candidate(false)


## 主游戏阶段：出战卡槽挪进 HUD 容器并按关卡刷新（测试关卡片无冷却）
func update_main_game() -> void:
	if not has_card_slot():
		return
	if not is_norm_appeared:
		await card_slot_norm.move_card_slot_battle(true)
	card_slot_battle.reparent(card_slot_container)
	card_slot_battle.main_game_refresh_card()
	if card_manager.main_game.is_test:
		for card in card_slot_battle.curr_cards:
			card.card_change_cool_time(0)


## 多轮游戏切新一轮：出战卡槽回到卡槽根节点上重新选卡
func start_next_game_update() -> void:
	if not has_card_slot():
		return
	card_slot_battle.reparent(card_slot_norm)
	card_slot_battle.start_next_game_card_slot_battle_update()
#endregion


## 出战卡槽补一格（夜晚开场戴夫卖出卡槽扩充后当场 +1）
func add_one_battle_card_placeholder() -> void:
	if has_card_slot():
		card_slot_battle.add_one_card_placeholder()


#region 阳光存档
func get_sun_value() -> int:
	return card_slot_battle.sun_value if has_card_slot() else 0


func set_sun_value(value: int) -> void:
	if has_card_slot():
		card_slot_battle.sun_value = value
#endregion
