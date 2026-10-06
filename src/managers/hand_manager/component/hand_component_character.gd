extends HandComponentBase
class_name HandComponentCharacter
## 手持物组件：手持角色（植物卡片、僵尸卡片）
## 负责手持卡片的美术、格子虚影、种植/放置，以及紫卡预种植提示。
##
## **只做通用校验**：能不能种一律问格子（种植条件资源 / 僵尸行条件），本组件不认识任何具体玩法
## （「点一格种一整列」这类一关专属机制写在关卡脚本里，见硬约束 §1-8）。
## 事件来源：卡片按钮 → EventBus "main_game_click_card" → take_hand()

## 手持角色美术的挂载节点（在 CanvasLayerTemp 下，保证渲染层次与坐标系）
@onready var temporary_character: Node2D = %TemporaryCharacter

## 当前卡片
var curr_card: Card = null
## 手持静态角色
var characte_static: Node2D
## 格子静态角色虚影
var characte_static_shadow: Node2D
## 植物种植条件
var plant_condition: ResourcePlantCondition
## 僵尸放置行条件
var zombie_row_type: CharacterRegistry.ZombieRowType
## 虚影在格子中，即可以种植
var is_shadow_in_cell := false
## 当前手持的是僵王卡：任意战场格子都能确认召唤
var _is_boss_card := false

## 紫卡植物可以的预种植植物，点击卡片时明暗交替
var curr_all_preplant_purple: Array[Plant000Base] = []


func get_hand_component_type() -> E_HandComponentType:
	return E_HandComponentType.Character


func _ready_component() -> void:
	EventBus.subscribe("main_game_click_card", _on_click_card)


## 点击卡片：拿到手上
func _on_click_card(card: Card) -> void:
	if not hand_manager.take_hand(get_hand_component_type(), card):
		## 卡片被禁用（例如关卡没有该卡片）时不发音效
		return
	SoundManager.play_other_SFX("seedlift")


#region 手持态生命周期
func enter_hand(payload: Variant = null) -> bool:
	var card := payload as Card
	if not is_instance_valid(card):
		Log.error("HandComponentCharacter: 手持卡片无效 " + str(payload))
		return false
	## 清理上一次的手持数据（同一组件重复持卡 = 换一张卡）
	_clear_curr_data()

	curr_card = card
	EventBus.push_event("hand_card_take", [curr_card])

	## 僵王：召唤不检查格子占用、水陆或行号，虚影落在格子的普通植物位置
	if curr_card.card_type == ResourceCardReference.CardType.ZombieBoss:
		_is_boss_card = true
		if not _create_hand_static():
			_clear_curr_data()
			return false
		return true
	## 植物
	if curr_card.card_plant_type != CharacterRegistry.PlantType.Null:
		plant_condition = Global.character_registry.get_plant_info(
			curr_card.card_plant_type, CharacterRegistry.PlantInfoAttribute.PlantConditionResource
		)
		if not _create_hand_static():
			_clear_curr_data()
			return false
		## 如果是紫卡植物，让所有可预种植的前置植物明暗闪烁
		if plant_condition.is_purple_card:
			start_preplant_purple_light(plant_condition, curr_card.card_plant_type)
	## 僵尸
	else:
		zombie_row_type = Global.character_registry.get_zombie_info(
			curr_card.card_zombie_type, CharacterRegistry.ZombieInfoAttribute.ZombieRowType
		)
		if not _create_hand_static():
			_clear_curr_data()
			return false

	return true


func exit_hand() -> void:
	_clear_curr_data()


## 每帧：手持美术跟随鼠标
func hand_process() -> void:
	if not is_instance_valid(characte_static):
		return
	## CanvasItem 方法获取位置（含画布变换，CanvasLayerTemp 开了 follow_viewport）
	characte_static.global_position = temporary_character.get_global_mouse_position()
#endregion


#region 手持美术
## 创建手持静态角色与格子虚影
func _create_hand_static() -> bool:
	if not is_instance_valid(curr_card.character_static) or curr_card.character_static.get_child_count() == 0:
		Log.error("HandComponentCharacter: 卡片静态角色为空 " + str(curr_card.name))
		return false
	characte_static = curr_card.character_static.duplicate()
	## 卡片里的角色是缩小过的，手持时还原成实际大小
	characte_static.get_child(0).scale = Vector2.ONE
	characte_static_shadow = characte_static.get_child(0).duplicate()
	characte_static_shadow.modulate.a = 0
	characte_static.z_index = 1

	temporary_character.add_child(characte_static)
	temporary_character.add_child(characte_static_shadow)
	return true


## 清除手持数据（幂等）
func _clear_curr_data() -> void:
	## 如果是紫卡植物
	if plant_condition != null and plant_condition.is_purple_card:
		end_preplant_purple_light()

	is_shadow_in_cell = false
	_is_boss_card = false
	## 若当前存在卡片，事件总线推清除当前卡片数据，种子雨卡槽接受判断
	if is_instance_valid(curr_card):
		EventBus.push_event("hand_card_release", [curr_card])
	curr_card = null

	if is_instance_valid(characte_static):
		characte_static.queue_free()
	characte_static = null
	if is_instance_valid(characte_static_shadow):
		characte_static_shadow.queue_free()
	characte_static_shadow = null

	plant_condition = null
	zombie_row_type = CharacterRegistry.ZombieRowType.Land
#endregion


#region 紫卡预种植提示
## 紫卡预种植植物身体明暗发光开始
func start_preplant_purple_light(curr_plant_condition: ResourcePlantCondition, plant_type: CharacterRegistry.PlantType) -> void:
	curr_all_preplant_purple = curr_plant_condition.get_all_preplant_purple(
		main_game.plant_cell_manager.all_plant_cells, plant_type
	)
	for preplant_purple in curr_all_preplant_purple:
		preplant_purple.preplant_purple_body_light_and_dark()


## 紫卡预种植植物身体明暗发光结束
func end_preplant_purple_light() -> void:
	for preplant_purple in curr_all_preplant_purple:
		if is_instance_valid(preplant_purple):
			preplant_purple.preplant_purple_body_light_and_dark_end()
	curr_all_preplant_purple.clear()
#endregion


#region 格子交互
## 鼠标进入格子：更新虚影
func mouse_enter(plant_cell: PlantCell) -> void:
	if not is_instance_valid(characte_static_shadow):
		return
	is_shadow_in_cell = _update_cell_shadow(plant_cell, characte_static_shadow)


## 鼠标移出格子：藏掉虚影
func mouse_exit(_plant_cell: PlantCell) -> void:
	if is_instance_valid(characte_static_shadow):
		characte_static_shadow.modulate.a = 0


## 点击格子：种植 / 放置
## 种不下去时返回 false，手持物留在手上（原来的实现会把卡片直接丢掉）
func click_cell(plant_cell: PlantCell) -> bool:
	if not is_instance_valid(curr_card):
		return false
	if not is_shadow_in_cell:
		SoundManager.play_other_SFX("buzzer")
		return false

	if _is_boss_card:
		var boss: ZB000Base = main_game.zombie_manager.try_create_boss_from_card(curr_card.card_zombie_boss_type)
		if boss == null:
			SoundManager.play_other_SFX("buzzer")
			return false
		curr_card.signal_card_use_end.emit()
		return true

	if curr_card.card_plant_type != CharacterRegistry.PlantType.Null:
		## 坚果包扎术：手持坚果类卡片点在掉手 / 裂开的同种坚果上 = 补种修复，
		## 不铲除旧植物也不腾格子，照样扣一张卡的钱与冷却
		var first_aid_plant := plant_cell.get_first_aid_plant(curr_card.card_plant_type)
		if first_aid_plant != null:
			first_aid_plant.be_first_aid_heal()
		else:
			plant_cell.create_plant(curr_card.card_plant_type, curr_card.is_imitater)
	else:
		var zombie_init_para: Dictionary = {
			Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
			Zombie000Base.E_ZInitAttr.Lane: plant_cell.row_col.x,
		}

		main_game.zombie_manager.create_norm_zombie(
			curr_card.card_zombie_type,
			main_game.zombie_manager.all_zombie_rows[plant_cell.row_col.x],
			zombie_init_para,
			Vector2(
				plant_cell.global_position.x + plant_cell.size.x / 2,
				main_game.zombie_manager.all_zombie_rows[plant_cell.row_col.x].zombie_create_position.global_position.y
			),
			GlobalUtils.get_special_zombie_callable(curr_card.card_zombie_type, plant_cell)
		)

	## 卡片种植完成发射信号（扣阳光、卡片冷却、传送带移除卡片都由卡槽接这个信号）
	curr_card.signal_card_use_end.emit()
	return true


## 更新植物格子虚影，返回是否能种
func _update_cell_shadow(plant_cell: PlantCell, curr_characte_static_shadow: Node2D) -> bool:
	## 僵王：不检查占用、水陆或行号，虚影落在格子的普通植物位置
	if _is_boss_card:
		curr_characte_static_shadow.global_position = plant_cell.get_new_plant_static_shadow_global_position(
			CharacterRegistry.PlacePlantInCell.Norm
		)
		curr_characte_static_shadow.modulate.a = 0.5
		return true
	## 植物
	if curr_card.card_plant_type != CharacterRegistry.PlantType.Null:
		## 判定是否可以种植植物
		if plant_condition.judge_is_can_plant(plant_cell, curr_card.card_plant_type):
			curr_characte_static_shadow.global_position = plant_cell.get_new_plant_static_shadow_global_position(plant_condition.place_plant_in_cell)
			curr_characte_static_shadow.modulate.a = 0.5
			return true
		## 种不下去时再看能不能"补种修复"（坚果包扎术）：可以修的格子同样给虚影
		elif plant_cell.get_first_aid_plant(curr_card.card_plant_type) != null:
			curr_characte_static_shadow.global_position = plant_cell.get_new_plant_static_shadow_global_position(plant_condition.place_plant_in_cell)
			curr_characte_static_shadow.modulate.a = 0.5
			return true
		else:
			curr_characte_static_shadow.modulate.a = 0
			return false

	## 僵尸
	else:
		## 如果当前格子不能放置普通僵尸（蹦极除外）
		if not plant_cell.can_common_zombie and curr_card.card_zombie_type != CharacterRegistry.ZombieType.Z021Bungi:
			return false
		## 如果不是双地形
		if zombie_row_type != CharacterRegistry.ZombieRowType.Both:
			if zombie_row_type == main_game.zombie_manager.all_zombie_rows[plant_cell.row_col.x].zombie_row_type:
				curr_characte_static_shadow.global_position = get_zombie_static_shadow_global_position(plant_cell)
				curr_characte_static_shadow.modulate.a = 0.5
				return true
			else:
				curr_characte_static_shadow.modulate.a = 0
				return false
		else:
			curr_characte_static_shadow.global_position = get_zombie_static_shadow_global_position(plant_cell)
			curr_characte_static_shadow.modulate.a = 0.5
			return true


## 获取放置僵尸的虚影位置
func get_zombie_static_shadow_global_position(plant_cell: PlantCell) -> Vector2:
	var global_pos := Vector2(
		plant_cell.global_position.x + plant_cell.size.x / 2,
		main_game.zombie_manager.all_zombie_rows[plant_cell.row_col.x].zombie_create_position.global_position.y
	)

	## 如果有斜面
	if is_instance_valid(main_game.main_game_slope):
		global_pos += Vector2(0, main_game.main_game_slope.get_all_slope_y(global_pos.x))

	return global_pos
#endregion

