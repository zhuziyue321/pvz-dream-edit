extends HandComponentBase
class_name HandComponentGlove
## 手持物组件：手套
## 把场上已有的植物搬到另一个格子：不铲除、不重种，植物实例与状态（血量 / 成长 / 攻击 / 产阳光）全部保留。
## 交互：点手套 / 按 G → 点有植物的格子拿起（植物跟随鼠标）→ 点目标格子放下；右键或点空白取消并放回原位。
##
## ★ 关键实现：拿起时不把植物摘出场景树，只把 CanvasItem.top_level 打开做视觉位移 ——
##   一旦 remove_child 脱离场景树，Timer 与 _process 会停，攻击和产阳光都会中断。
## 事件来源：卡槽手套按钮 / 快捷键 G → EventBus "main_game_click_glove" → take_hand()

## 卡槽里的手套（本体是卡槽背景，Glove 图标由本组件控制显隐）
@onready var ui_glove: UIGlove = %UIGlove
## 跟随鼠标的真手套
@onready var real_glove: RealGlove = %RealGlove
## 手持美术的挂载点：用它取鼠标全局位置，保证与草坪同一坐标系（CanvasLayerTemp 开了 follow_viewport）
@onready var temporary_character: Node2D = %TemporaryCharacter

## 搬运中把植物抬到最上层的 z_index 增量（行层级间隔 50，取一个远大于全场行数的值）
const CARRY_Z_INDEX_UP: int = 1000

## 当前鼠标所在格子
var curr_plant_cell: PlantCell
## 当前被高亮（将被拿起）的植物
var plant_be_glove_look: Plant000Base
## 当前格子植物数量（>=2 时随鼠标切换高亮）
var curr_glove_look_plant_num: int = 0
## 当前手上搬着的植物
var curr_carry_plant: Plant000Base
## 拿起植物的来源格子（取消 / 强制退出时放回）
var carry_from_cell: PlantCell
## 植物原本的 z_index（放回时原样还原，不能按行重算：南瓜壳等自带偏移）
var carry_ori_z_index: int = 0
## 植物原点 → 图案中心的偏移，让搬运时图案中心对准鼠标
var carry_offset: Vector2 = Vector2.ZERO


func get_hand_component_type() -> E_HandComponentType:
	return E_HandComponentType.Glove


func _ready_component() -> void:
	change_is_enabling(is_can_has_glove(), E_IsEnableFactor.HandItem)
	## 总开关关闭时不订阅拿手套事件：即使有人绕过解锁判定强行启用组件，也收不到点击
	if not ConstFeatureSwitch.GLOVE_ENABLED:
		return
	EventBus.subscribe("main_game_click_glove", _on_click_glove)


## 本局是否可以持有手套：关卡允许操作草坪 + 全局解锁进度（通关冒险 4-5 后戴夫才把手套交给玩家）
## 与铲子同一套判定（见 ConstUnlockLevel.GLOVE_UNLOCK_ADVENTURE_LEVEL），关卡参数与解锁进度缺一不可
## ★ 当前 ConstFeatureSwitch.GLOVE_ENABLED = false：解锁判定恒为假，本组件整局禁用（手套功能隐藏）
func is_can_has_glove() -> bool:
	if not ConstFeatureSwitch.GLOVE_ENABLED:
		return false
	if not is_instance_valid(game_para):
		return false
	return game_para.is_shovel and Global.global_game_state.is_glove_unlocked()


## 点击卡槽手套：拿到手上
func _on_click_glove() -> void:
	if not ConstFeatureSwitch.GLOVE_ENABLED:
		return
	if not hand_manager.take_hand(get_hand_component_type()):
		## 组件被禁用（关卡没有草坪操作）时不发音效
		return
	SoundManager.play_other_SFX("shovel")


#region 手持态生命周期
func enter_hand(_payload: Variant = null) -> bool:
	_clear_carry_data()
	if is_instance_valid(real_glove):
		real_glove.change_is_using(true)
	return true


func exit_hand() -> void:
	_put_carry_plant_back()
	_clear_glove_look()
	curr_plant_cell = null
	curr_glove_look_plant_num = 0
	if is_instance_valid(real_glove):
		real_glove.change_is_using(false)


## 每帧：搬运中的植物跟随鼠标；未拿起且格子有多个植物时，随鼠标切换将被拿起的植物
func hand_process() -> void:
	if is_instance_valid(curr_carry_plant):
		curr_carry_plant.global_position = temporary_character.get_global_mouse_position() - carry_offset
		return
	## 手上的植物中途没了（被僵尸吃掉 / 关卡清理）：直接回空手，避免拿着已释放的对象
	if curr_carry_plant != null:
		curr_carry_plant = null
		carry_from_cell = null
		hand_manager.drop_hand()
		return
	if curr_glove_look_plant_num < 2 or not is_instance_valid(curr_plant_cell):
		return
	var new_plant_be_glove_look: Plant000Base = curr_plant_cell.return_plant_be_shovel_look()
	if new_plant_be_glove_look == plant_be_glove_look:
		return
	_clear_glove_look()
	plant_be_glove_look = new_plant_be_glove_look
	if is_instance_valid(plant_be_glove_look):
		plant_be_glove_look.be_shovel_look()
#endregion


#region 格子交互
func mouse_enter(plant_cell: PlantCell) -> void:
	curr_plant_cell = plant_cell
	## 手上已经拿着植物时不再高亮目标
	if is_instance_valid(curr_carry_plant):
		return
	## 进入新格子前先结束上一个高亮：漏发 mouse_exit（暂停 / 控件隐藏）时不会残留
	_clear_glove_look()
	curr_glove_look_plant_num = plant_cell.get_curr_plant_num()
	if curr_glove_look_plant_num >= 1:
		plant_be_glove_look = plant_cell.glove_get_carry_plant()
		if is_instance_valid(plant_be_glove_look):
			plant_be_glove_look.be_shovel_look()


func mouse_exit(_plant_cell: PlantCell) -> void:
	curr_plant_cell = null
	curr_glove_look_plant_num = 0
	_clear_glove_look()


## 点击格子：手上没植物就拿起（手套留在手上），手上有植物就放下（放好才回空手）
func click_cell(plant_cell: PlantCell) -> bool:
	if not is_instance_valid(curr_carry_plant):
		_take_plant(plant_cell)
		return false
	return _put_plant(plant_cell)


## 从格子拿起植物
func _take_plant(plant_cell: PlantCell) -> bool:
	var plant: Plant000Base = plant_cell.glove_get_carry_plant()
	if not is_instance_valid(plant) or not _can_take_plant(plant):
		SoundManager.play_other_SFX("buzzer")
		return false
	## ⚠️ 必须在格子摘除之前记录全局位置：摘除后节点成孤儿，global_position 会退化成局部坐标
	var plant_ori_global_pos: Vector2 = plant.global_position
	if not plant_cell.glove_take_plant(plant):
		SoundManager.play_other_SFX("buzzer")
		return false
	## 高亮已由 glove_take_plant 配对结束，这里只丢引用，不能重复 be_shovel_look_end()
	plant_be_glove_look = null
	curr_glove_look_plant_num = 0

	curr_carry_plant = plant
	carry_from_cell = plant_cell
	carry_ori_z_index = plant.z_index
	carry_offset = plant_cell.global_position + plant_cell.size * 0.5 - plant_ori_global_pos

	## ★ 不摘出场景树：只开 top_level 让位置脱离父级变换，Timer / _process 照常运行
	plant.top_level = true
	plant.z_index = carry_ori_z_index + CARRY_Z_INDEX_UP
	plant.global_position = temporary_character.get_global_mouse_position() - carry_offset
	## 抓住植物后收起手套图标（屏幕上只剩被搬着的植物）
	if is_instance_valid(real_glove):
		real_glove.change_is_using(false)
	SoundManager.play_other_SFX("seedlift")
	return true


## 把手上的植物放进格子，成功返回 true（回空手）
func _put_plant(plant_cell: PlantCell) -> bool:
	if not plant_cell.glove_judge_can_put(curr_carry_plant):
		SoundManager.play_other_SFX("buzzer")
		return false
	var place := plant_cell.glove_get_put_place(curr_carry_plant)
	if not plant_cell.glove_put_plant(curr_carry_plant, place):
		SoundManager.play_other_SFX("buzzer")
		return false
	var plant: Plant000Base = curr_carry_plant
	curr_carry_plant = null
	carry_from_cell = null
	## 幂等复位：格子侧已经关过，这里再关一次兜底
	plant.top_level = false
	plant.z_index = carry_ori_z_index
	SoundManager.play_other_SFX("plant2")
	return true


## 把搬运中的植物放回来源格子（取消 / 退出手持时调用，必须幂等）
func _put_carry_plant_back() -> void:
	var plant: Plant000Base = curr_carry_plant
	var from_cell: PlantCell = carry_from_cell
	curr_carry_plant = null
	carry_from_cell = null
	if not is_instance_valid(plant):
		return
	plant.top_level = false
	plant.z_index = carry_ori_z_index
	if is_instance_valid(from_cell) and from_cell.glove_put_plant(plant, from_cell.glove_get_put_place(plant)):
		return
	## 兜底：来源格子已经失效，植物不再属于任何格子，直接消失
	Log.warn("手套搬运：来源格子失效，植物 %s 放回失败" % str(plant.name))
	plant.character_death_disappear()


## 玉米加农炮占两个格子，只搬其中一株会破坏它的双格结构，禁止搬运
func _can_take_plant(plant: Plant000Base) -> bool:
	return plant.plant_type != CharacterRegistry.PlantType.P048CobCannon
#endregion


#region 界面与清理
## 刷新手套界面：卡槽本体（背景 + 按钮）在可操作草坪的阶段显示，手套图标只在手套不在手上时显示
func refresh_ui() -> void:
	if not is_instance_valid(ui_glove):
		return
	## 「可以操作草坪」= 主游戏阶段，或开场教程（1-5 铲子教学）正在跑
	var is_in_play := is_instance_valid(main_game) and main_game.is_lawn_playable()
	var is_slot_visible := is_enabling and is_in_play and ConstFeatureSwitch.GLOVE_ENABLED
	ui_glove.refresh_glove_ui(is_slot_visible, is_slot_visible and not is_curr_hand())


## 清空搬运数据（幂等）
func _clear_carry_data() -> void:
	curr_carry_plant = null
	carry_from_cell = null
	carry_ori_z_index = 0
	carry_offset = Vector2.ZERO


## 结束当前植物高亮并清空引用
func _clear_glove_look() -> void:
	if is_instance_valid(plant_be_glove_look):
		plant_be_glove_look.be_shovel_look_end()
	plant_be_glove_look = null
#endregion
