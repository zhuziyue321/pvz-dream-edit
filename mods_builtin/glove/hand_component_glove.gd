extends HandComponentBase
## 手持物组件：手套（「手套」模组）
## 把场上已有的植物搬到另一个格子：不铲除、不重种，植物实例与状态（血量 / 成长 / 攻击 / 产阳光）全部保留。
##
## ★ 交互是**两段式**（2026-10-24 调整）：
##   1. 点手套 / 按 G 拿到手套 → 点有植物的格子 = **选中**它：
##      植物**留在原格子里**（照常攻击、照常产阳光，不摘、不改层级），
##      屏幕上只多一份**半透明虚影**（像选卡时那种虚影）跟着手套走，指明"要搬的是这一株"。
##   2. **再点一次**目标格子 = 真的把它搬过去（这时才动场上状态）；
##      点回原格子 = 取消选中；右键 / 点空白 = 整个手持取消。
##
## ★ 关键实现：搬运全程植物都**留在场景树里**（`move_take_plant` / `move_put_plant` 只换格子归属），
##   所以 Timer 与 _process 不会停，攻击和产阳光都不会中断。
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

## 当前鼠标所在格子
var curr_plant_cell: PlantCell
## 当前被高亮（将被选中）的植物
var plant_be_glove_look: Plant000Base
## 当前格子植物数量（>=2 时随鼠标切换高亮）
var curr_glove_look_plant_num: int = 0
## 当前被**选中**的植物（第一次点击选中的那株）：它还在原格子里，只有一份虚影跟着手套走
var selected_plant: Plant000Base
## 选中植物所在的格子（第二次点击时从这里摘走）
var selected_from_cell: PlantCell
## 跟着手套走的半透明虚影（选中植物身体的复制）
var carry_ghost: Node2D
## 植物原点 → 格子中心的偏移：虚影摆位用（沿用"搬起来时图案中心对准鼠标"的口径）
var carry_offset: Vector2 = Vector2.ZERO
## 植物原点 → 身体节点的偏移：虚影摆位用
var carry_body_offset: Vector2 = Vector2.ZERO

## 虚影的透明度（与选卡虚影同一档 0.5）
const GHOST_ALPHA := 0.5
## 虚影在临时层里的层级（临时层已在卡槽之上；与手持卡片美术同档）
const GHOST_Z_INDEX := 1

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
	## 取消时植物**留在原格子里**（它从头到尾就没被摘走过），只需要收掉虚影
	_cancel_select()
	_clear_glove_look()
	curr_plant_cell = null
	curr_glove_look_plant_num = 0
	if is_instance_valid(real_glove):
		real_glove.change_is_using(false)


## 每帧：虚影跟着鼠标走；未选中植物且格子有多个植物时，随鼠标切换将被选中的植物
func hand_process() -> void:
	## 选中的植物中途没了（被僵尸吃掉 / 关卡清理）：直接取消选中，别抱着已释放的对象
	if selected_plant != null and not is_instance_valid(selected_plant):
		_cancel_select()
		return
	if is_instance_valid(carry_ghost):
		_update_ghost_position()
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
	## 已经选中了一株：不再切换高亮（选中的那株保持高亮，等第二次点击）
	if is_instance_valid(selected_plant):
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
	## 选中状态下移出格子只是把光标移开：选中的那株仍然高亮，别把它的高亮撤掉
	if is_instance_valid(selected_plant):
		return
	curr_glove_look_plant_num = 0
	_clear_glove_look()


## 点击格子：**第一次**点 = 选中植物（植物留在原地，只出虚影）；
## **第二次**点 = 真的把它搬到这格（成功才回空手）
func click_cell(plant_cell: PlantCell) -> bool:
	if not is_instance_valid(selected_plant):
		_select_plant(plant_cell)
		return false
	return _move_selected_plant(plant_cell)


## 第一次点击：选中这株植物
## ★ 它**留在原格子里**：不摘、不改层级、不改归属 —— 照常攻击与产阳光；
##   屏幕上只多一份半透明虚影跟着手套走
func _select_plant(plant_cell: PlantCell) -> bool:
	var plant: Plant000Base = plant_cell.move_get_carry_plant()
	if not is_instance_valid(plant) or not _can_take_plant(plant):
		SoundManager.play_other_SFX("buzzer")
		return false
	selected_plant = plant
	selected_from_cell = plant_cell
	## 摆位用的两个偏移：植物原点相对格子中心、身体相对植物原点
	carry_offset = plant_cell.global_position + plant_cell.size * 0.5 - plant.global_position
	carry_body_offset = Vector2.ZERO
	if is_instance_valid(plant.body):
		carry_body_offset = plant.body.global_position - plant.global_position
	_create_carry_ghost(plant)
	## 选中期间固定高亮这一株：不再随鼠标切换
	_clear_glove_look()
	plant_be_glove_look = plant
	plant.be_shovel_look()
	curr_glove_look_plant_num = 0
	SoundManager.play_other_SFX("seedlift")
	return true


## 第二次点击：把选中的植物真的搬到目标格子（这才动到场上状态）
func _move_selected_plant(plant_cell: PlantCell) -> bool:
	var plant: Plant000Base = selected_plant
	var from_cell: PlantCell = selected_from_cell
	## 点回原格子 = 取消选中（植物本来就没离开过原位，不用放回）
	if plant_cell == from_cell:
		_cancel_select()
		SoundManager.play_other_SFX("tap2")
		return false
	if not is_instance_valid(plant) or not is_instance_valid(from_cell):
		_cancel_select()
		return false
	if not plant_cell.move_judge_can_put(plant):
		SoundManager.play_other_SFX("buzzer")
		return false
	var place := plant_cell.move_get_put_place(plant)
	## 先从来源格子摘掉（只换归属，不销毁实例），再放进目标格子
	if not from_cell.move_take_plant(plant):
		SoundManager.play_other_SFX("buzzer")
		_cancel_select()
		return false
	if not plant_cell.move_put_plant(plant, place):
		## 目标格子放不下：放回来源格子（兜底，别让植物凭空消失）
		from_cell.move_put_plant(plant, from_cell.move_get_put_place(plant))
		SoundManager.play_other_SFX("buzzer")
		_cancel_select()
		return false
	## 搬完了：虚影收掉，手套回卡槽（返回 true = 这次点击用完了手持物）
	_clear_carry_ghost()
	selected_plant = null
	selected_from_cell = null
	plant_be_glove_look = null
	curr_glove_look_plant_num = 0
	SoundManager.play_other_SFX("plant2")
	_start_cooldown()
	return true


## 取消选中：虚影收掉，植物**留在原格子里**（它从头到尾就没被摘走过）
func _cancel_select() -> void:
	_clear_carry_ghost()
	selected_plant = null
	selected_from_cell = null
	carry_offset = Vector2.ZERO
	carry_body_offset = Vector2.ZERO
	## 恢复"随鼠标切换高亮"：取消之后光标可能还停在某个格子上
	curr_glove_look_plant_num = 0
	if is_instance_valid(curr_plant_cell):
		curr_glove_look_plant_num = curr_plant_cell.get_curr_plant_num()


## 玉米加农炮占两个格子，只搬其中一株会破坏它的双格结构，禁止搬运
func _can_take_plant(plant: Plant000Base) -> bool:
	return plant.plant_type != PlantIds.COB_CANNON
#endregion


#region 虚影
## 造一份跟着手套走的半透明虚影（复制选中植物的身体）
##
## ★ 用 `body.duplicate()` 而不是另取一帧：复制的是**眼前这株植物的样子**
##   （受损的坚果、带壳的南瓜都如实照搬），而取帧只能拿到"标准形态"。
##   `BodyCharacter` 没有 `_ready` / `_process`，复制出来不会跑任何行为
##   （同款用法见 `Plant000Base.be_bungi()`：蹦极僵尸偷走的就是身体的一份复制）。
func _create_carry_ghost(plant: Plant000Base) -> void:
	_clear_carry_ghost()
	if not is_instance_valid(plant.body) or not is_instance_valid(temporary_character):
		return
	var ghost := plant.body.duplicate() as Node2D
	if ghost == null:
		return
	## 虚影只用来"示意这是哪一株"：统一半透明，不继承高亮 / 冰冻之类的染色
	ghost.modulate = Color(1.0, 1.0, 1.0, GHOST_ALPHA)
	ghost.z_index = GHOST_Z_INDEX
	temporary_character.add_child(ghost)
	carry_ghost = ghost
	## 立刻摆到鼠标上（否则要等下一帧 `hand_process` 才动，会在左上角闪一下）
	_update_ghost_position()


## 释放虚影（幂等）
func _clear_carry_ghost() -> void:
	if is_instance_valid(carry_ghost):
		carry_ghost.queue_free()
	carry_ghost = null


## 把虚影摆到鼠标上：格子中心对准鼠标，植物相对格子的位置原样保留
## （与旧实现"搬起来时图案中心对准鼠标"是同一个观感）
func _update_ghost_position() -> void:
	if not is_instance_valid(carry_ghost) or not is_instance_valid(temporary_character):
		return
	carry_ghost.global_position = temporary_character.get_global_mouse_position() \
		- carry_offset + carry_body_offset
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
	_cancel_select()
	_clear_glove_look()
	curr_glove_look_plant_num = 0


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


## 开始冷却：**搬完一株**才开始（选中又取消不算 —— 那一下没有真的改动布局）
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
