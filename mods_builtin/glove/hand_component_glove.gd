extends HandComponentBase
## 手持物组件：手套（「手套」模组）
## 把场上已有的植物搬到另一个格子：不铲除、不重种，植物实例与状态（血量 / 成长 / 攻击 / 产阳光）全部保留。
## 交互：点手套 / 按 G → 点有植物的格子拿起（植物跟随鼠标）→ 点目标格子放下；右键或点空白取消并放回原位。
##
## ★ 关键实现：拿起时不把植物摘出场景树，只把 CanvasItem.top_level 打开做视觉位移 ——
##   一旦 remove_child 脱离场景树，Timer 与 _process 会停，攻击和产阳光都会中断。
##
## ★ 本组件不在本体场景里：它由 `GloveMod.install_to_main_game()` 现场 new 出来挂到
##   `HandManager` 下，随后被 `HandManager.init_manager()` 登记进 `all_hand_components`
##   （手持物类型 `E_HandComponentType.Glove` 是本体留给模组的槽位）。
##   所以可视化节点用 `set_visual_nodes()` 注入，不能写 `@onready %Xxx`
##   —— 场景唯一名只对场景里本来就有的节点生效。
##
## 原版没有这个玩法（原版手套是禅境花园工具），所以整条链路（本组件 + 卡槽按钮 + 真手套）
## 都在模组里；关掉模组 = 本组件根本不会被创建。
##
## **冷却**（原版也没有，默认关）：搬完一株之后才能再用，两种口径二选一 ——
## **按秒数**（`GloveSettings.get_cooldown_time()`，`_process` 自己倒数）或
## **按波数**（`GloveSettings.get_cooldown_wave()`，连波次管理器的 `wave_started`，每开一波减 1）。
## 开关 / 方式 / 时长 / 波数都在模组页面里设（`GloveSettings.is_cooldown_enabled()` /
## `is_cooldown_by_wave()`，值落在**模组存档文件** `[glove]` 段，与模组开关同一份，
## 见 `GloveMod` 的类注释）。
## 冷却中手套拿不起来（点它只有一声"不行"），卡槽图标上盖一层遮罩随剩余时间 / 剩余波数往回收。

## 跨文件引用：`user://` 下脚本的 class_name **不会注册成全局类**（实测 Godot 4.6.2），
## 所以同目录的文件一律 preload 成常量再引用，不能写 `var x: Xxx`
## 解锁 / 冷却的读值口走 `glove_settings.gd`（与 `glove_mod.gd` 共用，两边互相 preload 会成环）
const GloveSettings := preload("glove_settings.gd")

## 卡槽里的手套（本体是卡槽背景，Glove 图标由本组件控制显隐）
var ui_glove
## 跟随鼠标的真手套
var real_glove
## 手持美术的挂载点：用它取鼠标全局位置，保证与草坪同一坐标系（CanvasLayerTemp 开了 follow_viewport）
var temporary_character: Node2D

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

## 当前冷却是不是「按波数」那一档（true = 按波数，false = 按秒数）
var cool_is_by_wave: bool = false
## 按秒冷却还剩几秒（`> 0` = 正在冷却，这段时间不能再拿手套）
var cool_remain: float = 0.0
## 本次按秒冷却的总时长（秒）：给卡槽遮罩算「还剩几分之几」用；0 = 没在冷却
var cool_total: float = 0.0
## 按波冷却还剩几波（`> 0` = 正在冷却；每开一波减 1，减到 0 冷却好）
var cool_wave_remain: int = 0
## 本次按波冷却的总波数：给卡槽遮罩算「还剩几分之几」用
var cool_wave_total: int = 0
## 波数冷却要观察的波次管理器：连上它的 `wave_started`，每开一波扣 1
var wave_manager: ZombieWaveManager


## 由 `GloveMod` 在把本组件加进场景树之前调用：模组自己建的节点没法用 `%同名` 取
func set_visual_nodes(p_ui_glove, p_real_glove, p_temporary_character: Node2D) -> void:
	ui_glove = p_ui_glove
	real_glove = p_real_glove
	temporary_character = p_temporary_character


func get_hand_component_type() -> E_HandComponentType:
	return E_HandComponentType.Glove


func _ready_component() -> void:
	change_is_enabling(is_can_has_glove(), E_IsEnableFactor.HandItem)
	_connect_wave_signal()


## 连上波次管理器的「开了一波」信号（按波数冷却要用）
## 关卡没有波次（`E_MonsterMode.Null` 之类）时 `wave_manager` 保持 null，波数冷却会自己让开
func _connect_wave_signal() -> void:
	if not is_instance_valid(main_game) or not is_instance_valid(main_game.zombie_manager):
		return
	wave_manager = main_game.zombie_manager.zombie_wave_manager
	if not is_instance_valid(wave_manager) or wave_manager.wave_started.is_connected(_on_wave_started):
		return
	wave_manager.wave_started.connect(_on_wave_started)


## 本局是否可以持有手套：关卡允许操作草坪 + 全局解锁（商店里买下园艺手套之后才到手）
## 与铲子同一套判定，关卡参数与解锁缺一不可；
## 解锁口径属于模组自己（`GloveSettings.is_unlocked()`），本体不认识"关卡内手套解锁"这回事
func is_can_has_glove() -> bool:
	if not is_instance_valid(game_para):
		return false
	return game_para.is_shovel and is_unlocked()


## 关卡内手套是否已到手：**与商店里的园艺手套同时获取** —— 存档里买断了园艺手套就有
func is_unlocked() -> bool:
	return GloveSettings.is_unlocked()


## 点卡槽手套 / 按 G：拿到手上（由 `GloveMod` 接到卡槽按钮的 signal 上）
func on_click_glove() -> void:
	## 冷却中：给一声"不行"，不放行（遮罩已经画在卡槽上，玩家看得到为什么按不动）
	if is_cooling():
		SoundManager.play_other_SFX("buzzer")
		return
	if not hand_manager.take_hand(get_hand_component_type()):
		## 组件被禁用（关卡没有草坪操作、没解锁）时不发音效
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
		plant_be_glove_look = plant_cell.move_get_carry_plant()
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
	var plant: Plant000Base = plant_cell.move_get_carry_plant()
	if not is_instance_valid(plant) or not _can_take_plant(plant):
		SoundManager.play_other_SFX("buzzer")
		return false
	## ⚠️ 必须在格子摘除之前记录全局位置：摘除后节点成孤儿，global_position 会退化成局部坐标
	var plant_ori_global_pos: Vector2 = plant.global_position
	if not plant_cell.move_take_plant(plant):
		SoundManager.play_other_SFX("buzzer")
		return false
	## 高亮已由 move_take_plant 配对结束，这里只丢引用，不能重复 be_shovel_look_end()
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
	if not plant_cell.move_judge_can_put(curr_carry_plant):
		SoundManager.play_other_SFX("buzzer")
		return false
	var place := plant_cell.move_get_put_place(curr_carry_plant)
	if not plant_cell.move_put_plant(curr_carry_plant, place):
		SoundManager.play_other_SFX("buzzer")
		return false
	var plant: Plant000Base = curr_carry_plant
	curr_carry_plant = null
	carry_from_cell = null
	## 幂等复位：格子侧已经关过，这里再关一次兜底
	plant.top_level = false
	plant.z_index = carry_ori_z_index
	SoundManager.play_other_SFX("plant2")
	_start_cooldown()
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
	if is_instance_valid(from_cell) and from_cell.move_put_plant(plant, from_cell.move_get_put_place(plant)):
		return
	## 兜底：来源格子已经失效，植物不再属于任何格子，直接消失
	Log.warn("手套搬运：来源格子失效，植物 %s 放回失败" % str(plant.name))
	plant.character_death_disappear()


## 玉米加农炮占两个格子，只搬其中一株会破坏它的双格结构，禁止搬运
func _can_take_plant(plant: Plant000Base) -> bool:
	return plant.plant_type != PlantIds.COB_CANNON
#endregion


#region 界面与清理
## 刷新手套界面：卡槽本体（背景 + 按钮）在可操作草坪的阶段显示，手套图标只在手套不在手上时显示
func refresh_ui() -> void:
	if not is_instance_valid(ui_glove):
		return
	## 「可以操作草坪」= 主游戏阶段，或开场教程（1-5 铲子教学）正在跑
	var is_in_play := is_instance_valid(main_game) and main_game.is_lawn_playable()
	var is_slot_visible := is_enabling and is_in_play
	ui_glove.refresh_glove_ui(is_slot_visible, is_slot_visible and not is_curr_hand())
	_refresh_cool_ui()


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


#region 冷却
## 当前是否正在冷却（这段时间手套拿不起来）
func is_cooling() -> bool:
	return cool_wave_remain > 0 or cool_remain > 0.0


## 冷却倒计时：用自己的 `_process`，**不是** `hand_process()`
## —— 后者只在「手套拿在手上」时才被 `HandManager` 调到（见 `HandManager._process`），
##    而冷却恰恰发生在**放下之后**、手上没东西的时候。
## 按波数冷却时这里不倒数（等 `_on_wave_started` 来扣），只做「开关被关掉 / 关卡没有波次」的兜底收尾。
func _process(delta: float) -> void:
	if not is_cooling():
		return
	## 运行期把开关关掉了：立刻结束冷却，别让人干等一个已经不存在的限制
	if not GloveSettings.is_cooldown_enabled():
		_end_cooldown()
		return
	if cool_is_by_wave:
		## 关卡没有波次可数：波数永远等不到，直接放行（否则玩家会被永久锁住）
		if not is_instance_valid(wave_manager):
			_end_cooldown()
		return
	cool_remain -= delta
	if cool_remain > 0.0:
		_refresh_cool_ui()
		return
	_end_cooldown()


## 开始冷却：**搬完一株**才开始（拿起又放回 / 取消不算 —— 那一下没有真的改动布局）
## 方式看设置：按秒数倒数（`cooldown_time`）或按波数扣（`cooldown_wave`，每开一波减 1）
func _start_cooldown() -> void:
	if not GloveSettings.is_cooldown_enabled():
		return
	if GloveSettings.is_cooldown_by_wave():
		## 关卡没有波次管理器时别进冷却，否则玩家会被永久锁住（`_process` 里还有一层同样的兜底）
		if not is_instance_valid(wave_manager):
			return
		var wave_num := GloveSettings.get_cooldown_wave()
		if wave_num <= 0:
			return
		cool_is_by_wave = true
		cool_wave_total = wave_num
		cool_wave_remain = wave_num
		_refresh_cool_ui()
		return
	var cool_time := GloveSettings.get_cooldown_time()
	if cool_time <= 0.0:
		return
	cool_is_by_wave = false
	cool_total = cool_time
	cool_remain = cool_time
	_refresh_cool_ui()


## 新的一波开起来：按波数冷却的手套扣 1 波，扣到 0 就冷却好
func _on_wave_started(_wave: int) -> void:
	if not is_cooling() or not cool_is_by_wave:
		return
	if not GloveSettings.is_cooldown_enabled():
		_end_cooldown()
		return
	cool_wave_remain -= 1
	if cool_wave_remain > 0:
		_refresh_cool_ui()
		return
	_end_cooldown()


## 结束冷却（正常走完 / 开关被关掉，都要把遮罩收掉）
func _end_cooldown() -> void:
	cool_remain = 0.0
	cool_total = 0.0
	cool_wave_remain = 0
	cool_wave_total = 0
	_refresh_cool_ui()


## 卡槽遮罩：按「还剩几分之几」盖住手套图标（0 = 没在冷却 → 收起遮罩）
## 按波数时用「还剩几波 / 共几波」，逐波往下掉一档
func _refresh_cool_ui() -> void:
	if not is_instance_valid(ui_glove):
		return
	var cool_ratio := 0.0
	if cool_is_by_wave and cool_wave_total > 0 and cool_wave_remain > 0:
		cool_ratio = clampf(float(cool_wave_remain) / float(cool_wave_total), 0.0, 1.0)
	elif cool_total > 0.0 and cool_remain > 0.0:
		cool_ratio = clampf(cool_remain / cool_total, 0.0, 1.0)
	ui_glove.refresh_glove_cool(cool_ratio)
#endregion
