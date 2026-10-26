extends Node
## 玩家对战模组的「植物卡对战口径」接线：**阳光花费 + 冷却**
##
## DLC Edition 的对战模式里，一部分植物与冒险模式的**阳光 / 冷却不同**（见
## `player_battle_settings.gd` 的 `PLAYER_BATTLE_PLANT_COSTS` / `PLAYER_BATTLE_PLANT_COOLDOWNS`，
## 口径 = 白天前院，逐株抄自 DLC wiki 植物词条）。本接线把这张表落到**植物那半槽**上：
##
##   - 选卡界面：待选区里每张候选卡的容器（显示用的数字）+ 内层那张卡（选中后原样搬进卡槽，
##     是**同一个节点**，不是副本）两处都换 —— 玩家在选卡界面看到的就是对战价；
##   - 出战卡槽：选卡收尾（`signal_choose_card_finished`）整槽同步一遍兜底
##     （「重选上次卡片」/ 预选卡这类绕过待选区点击的路径也走这里）。
##
## ⚠️ **只改卡自己的 `sun_cost` / `cool_time`**：角色注册表（`plant_info_data.gd`）与 DLC 模组
##    的配方常量一个都不动 ⇒ 冒险模式 / 图鉴 / 商店仍是原口径。
## ⚠️ **不动容器的 `source_sun_cost` / `source_cool_time`**：那是「还池时恢复成什么」的底账
##    （见 `CardCandidateContainer` 与 `SceneRegistry._reset_candidate_container()`），
##    改它会把对战价写回整个卡池，下一关（冒险模式）就跟着变。
## ⚠️ 模仿者卡（`is_imitater`）不在此处理：它的价格跟随被模仿的株，由 `AllCards` 那边算。
## ⚠️ 只在玩家对战关卡里装（入口脚本按 `game_mode` 判断），别的关卡一行代码都不走。

const Settings := preload("player_battle_settings.gd")

## 本局主游戏（选卡收尾时还要回头找卡槽）
var _main_game: MainGameManager = null


## 装到这一局上（由入口脚本 `install_to_main_game()` 调用）
func setup(main_game: MainGameManager) -> void:
	_main_game = main_game
	if main_game == null or main_game.card_manager == null:
		Log.error("玩家对战模组（植物对战口径）：拿不到卡片管理器，本局装不上")
		return
	sync_all(main_game)
	## 选卡收尾再整槽同步一遍：玩家可能走「重选上次卡片」/ 预选卡进来，那些卡没经过待选区点击
	if not main_game.signal_choose_card_finished.is_connected(_on_choose_card_finished):
		main_game.signal_choose_card_finished.connect(_on_choose_card_finished)


func _on_choose_card_finished() -> void:
	if _main_game == null or not is_instance_valid(_main_game):
		return
	sync_all(_main_game)


#region 对战口径（阳光 / 冷却）
## 这张植物卡在对战里花多少阳光；不是植物卡 / 表里没登记时返回 -1
static func versus_cost_of(card: Card) -> int:
	var plant_type := plant_type_of(card)
	if plant_type == PlantIds.NULL:
		return -1
	return int(Settings.PLAYER_BATTLE_PLANT_COSTS.get(plant_type, -1))


## 这张植物卡在对战里冷却多少秒；不是植物卡 / 表里没登记时返回 -1
static func versus_cooldown_of(card: Card) -> float:
	var plant_type := plant_type_of(card)
	if plant_type == PlantIds.NULL:
		return -1.0
	return float(Settings.PLAYER_BATTLE_PLANT_COOLDOWNS.get(plant_type, -1.0))


## 这张卡算哪一株（模仿者 / 非植物卡返回 `PlantIds.NULL` ⇒ 不进对战口径）
static func plant_type_of(card: Card) -> StringName:
	if card == null or card.card_type != ResourceCardReference.CardType.Plant:
		return PlantIds.NULL
	if card.is_imitater:
		return PlantIds.NULL
	return card.card_plant_type


## 把一张卡换成对战阳光（表里没登记就保持原值）
static func apply_versus_cost(card: Card) -> void:
	var cost := versus_cost_of(card)
	if cost >= 0:
		card.sun_cost = cost


## 把一张卡换成对战冷却（表里没登记就保持原值）
##
## ⚠️ 必须在**用卡之前**改：`Card.card_cool()` 是按当时的 `cool_time` 起表的，
##    用卡后再改只会影响下一次。
static func apply_versus_cooldown(card: Card) -> void:
	var cool := versus_cooldown_of(card)
	if cool >= 0.0:
		card.cool_time = cool


## 一张卡两样都换
static func apply_versus_stats(card: Card) -> void:
	apply_versus_cost(card)
	apply_versus_cooldown(card)


## 候选容器也换：面板上显示的数字是**容器自己**的 `sun_cost`，
## 内层那张卡带着另一份（选中后原样搬进卡槽）—— 两份都要改
static func apply_versus_stats_to_container(container: CardCandidateContainer) -> void:
	if container == null or container.card == null:
		return
	var cost := versus_cost_of(container.card)
	if cost >= 0:
		container.sun_cost = cost
	apply_versus_stats(container.card)
#endregion


#region 批量同步
## 待选区（选卡界面）+ 出战卡槽各同步一遍
static func sync_all(main_game: MainGameManager) -> void:
	if main_game == null or main_game.card_manager == null:
		return
	if main_game.card_manager.card_slot_norm != null:
		sync_candidates(main_game.card_manager.card_slot_norm.card_slot_candidate)
	sync_slot(main_game.card_manager.card_slot_battle)


## 待选区里所有植物候选卡换成对战口径（植物页 + 模仿者页；模仿者页那批会被
## `plant_type_of()` 判成 NULL，实际不会动）
static func sync_candidates(candidate_slot: CardSlotCandidate) -> void:
	if candidate_slot == null:
		return
	for container in candidate_slot.all_card_candidate_containers_plant.values():
		apply_versus_stats_to_container(container as CardCandidateContainer)
	for container in candidate_slot.all_card_candidate_containers_plant_imitater.values():
		apply_versus_stats_to_container(container as CardCandidateContainer)


## 出战卡槽里所有植物卡换成对战口径（僵尸 / 僵王卡由僵尸卡模组自己那套管）
static func sync_slot(slot: CardSlotBattle) -> void:
	if slot == null:
		return
	for card in slot.curr_cards:
		apply_versus_stats(card)
#endregion


## 只给探针 / 调试看：本接线挂上了没
func is_installed() -> bool:
	return _main_game != null and is_instance_valid(_main_game)
