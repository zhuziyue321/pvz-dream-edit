extends HandComponentBase
class_name HandComponentShovel
## 手持物组件：铲子
## 负责铲子跟随鼠标、悬停高亮将要被铲除的植物、点击铲除。
## 卡槽里的铲子图标也由本组件收敛显隐规则（只有本组件被启用、处于可操作草坪的阶段、
## 且铲子不在手上时才显示），避免「在手上时卡槽里也显示一把」的双铲子问题。
## 「可操作草坪的阶段」= 主游戏阶段或开场教程（1-5 铲子教学）运行中，见 MainGameManager.is_lawn_playable()。
## 事件来源：卡槽铲子按钮/快捷键 → EventBus "main_game_click_shovel" → take_hand()

## 卡槽里的铲子（本体是卡槽背景，Shovel 图标由本组件控制显隐）
@onready var ui_shovel: UIShovel = %UIShovel
## 跟随鼠标的真铲子
@onready var real_shovel: RealShovel = %RealShovel

## 当前鼠标所在格子
var curr_plant_cell: PlantCell
## 当前铲子选中的植物
var plant_be_shovel_look: Plant000Base
## 当前铲子所在格子植物数量
var curr_shovel_look_plant_num: int = 0


func get_hand_component_type() -> E_HandComponentType:
	return E_HandComponentType.Shovel


func _ready_component() -> void:
	## 关卡参数决定本关允不允许有铲子，已通关 1-4 决定玩家手上有没铲子（两者都要满足）
	change_is_enabling(is_can_has_shovel(), E_IsEnableFactor.HandItem)
	EventBus.subscribe("main_game_click_shovel", _on_click_shovel)


## 本局是否可以持有铲子：关卡没禁用铲子 + 玩家已通关 1-4 拿到铲子
func is_can_has_shovel() -> bool:
	if not is_instance_valid(game_para):
		return false
	return game_para.is_shovel and Global.global_game_state.is_shovel_unlocked()


## 点击卡槽铲子：拿到手上
func _on_click_shovel() -> void:
	if not hand_manager.take_hand(get_hand_component_type()):
		## 组件被禁用（关卡没有铲子）时不发音效
		return
	SoundManager.play_other_SFX("shovel")


#region 手持态生命周期
func enter_hand(_payload: Variant = null) -> bool:
	if is_instance_valid(real_shovel):
		real_shovel.change_is_using(true)
	return true


func exit_hand() -> void:
	_clear_shovel_look()
	if is_instance_valid(real_shovel):
		real_shovel.change_is_using(false)


## 每帧：格子内有多个植物时，随鼠标位置切换将被铲除的植物
func hand_process() -> void:
	if not is_valid_shovel_look() or curr_shovel_look_plant_num < 2:
		return
	if not is_instance_valid(curr_plant_cell):
		return
	var new_plant_be_shovel_look: Plant000Base = curr_plant_cell.return_plant_be_shovel_look()
	if new_plant_be_shovel_look == plant_be_shovel_look:
		return
	plant_be_shovel_look.be_shovel_look_end()
	plant_be_shovel_look = new_plant_be_shovel_look
	if is_instance_valid(plant_be_shovel_look):
		plant_be_shovel_look.be_shovel_look()
#endregion


#region 格子交互
func mouse_enter(plant_cell: PlantCell) -> void:
	curr_plant_cell = plant_cell
	## 进入新格子前先结束上一个高亮：漏发 mouse_exit（隐藏/移除控件、暂停）时不会残留
	_clear_shovel_look()
	curr_shovel_look_plant_num = plant_cell.get_curr_plant_num()
	if curr_shovel_look_plant_num >= 1:
		plant_be_shovel_look = plant_cell.return_plant_be_shovel_look()
		if is_instance_valid(plant_be_shovel_look):
			plant_be_shovel_look.be_shovel_look()


func mouse_exit(_plant_cell: PlantCell) -> void:
	curr_plant_cell = null
	_clear_shovel_look()


## 点击格子铲除植物
## 铲到东西才返回 true（用完铲子），点空格子时铲子留在手上
func click_cell(_plant_cell: PlantCell) -> bool:
	if not is_valid_shovel_look():
		return false
	SoundManager.play_other_SFX("plant2")
	plant_be_shovel_look.be_shovel_kill()
	plant_be_shovel_look = null
	curr_shovel_look_plant_num = 0
	return true
#endregion


#region 界面
## 刷新增铲子界面：卡槽本体（背景+按钮）在游玩阶段显示，铲子图标只在铲子不在手上时显示
func refresh_ui() -> void:
	if not is_instance_valid(ui_shovel):
		return
	## 「可以操作草坪」= 主游戏阶段，或开场教程（1-5 铲子教学）正在跑
	var is_in_play := is_instance_valid(main_game) and main_game.is_lawn_playable()
	var is_slot_visible := is_enabling and is_in_play
	ui_shovel.refresh_shovel_ui(is_slot_visible, is_slot_visible and not is_curr_hand())
#endregion


## 当前是否有被铲子选中的植物
func is_valid_shovel_look() -> bool:
	return is_instance_valid(plant_be_shovel_look)


## 结束当前植物高亮并清空选中数据
func _clear_shovel_look() -> void:
	if is_instance_valid(plant_be_shovel_look):
		plant_be_shovel_look.be_shovel_look_end()
	plant_be_shovel_look = null
	curr_shovel_look_plant_num = 0
