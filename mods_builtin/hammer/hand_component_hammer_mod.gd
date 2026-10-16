extends HandComponentBase
## 手持物组件：锤子（「锤子」模组）
## 点一下草坪，对以点击点为中心、半径可调范围内的僵尸按设置造成伤害（固定数值，或一键秒杀）。
## 交互：点锤子 / 按 H → 拿到手上（真锤子跟着鼠标走）→ 点草坪 → 挥一锤（挥完自动回空手）；
## 右键或点空白取消（由 HandManager 统一处理）。
##
## ★ 与迷你游戏的锤子互不相干：那边是 `src/items/mini_game/hammer.gd` + 手持物类型 `Hammer`
##   （单锤 1800、只打最左边一只、是那两关的空闲手持物）；本组件用独立的类型槽位 `HammerMod`，
##   只在「锤子」模组开着时由 `HeadHammerMod.install_to_main_game()` 现场 new 出来挂到
##   `HandManager` 下（硬约束 §1-8 的反面：这不是一关专属，是玩家开关的模组）。
##   所以可视化节点用 `set_visual_nodes()` 注入，不能写 `@onready %Xxx`
##   —— 场景唯一名只对场景里本来就有的节点生效。
##
## 命中判定与迷你游戏锤子同一套路：真锤子身上的 Area2D（监测僵尸受击框层）
## 在挥锤那一刻 `get_overlapping_areas()`，锤子一直在跟鼠标所以重叠数据是新鲜的。
## 真正的命中名单由 `RealHammerMod.swing()` 返回，伤害结算在本组件里做（它才知道设置）。
##
## **解锁**（默认要通关冒险 2-4）：`HammerSettings.UNLOCK_ADVENTURE_LEVEL` = 14 ——
## 装着还不够，通关 2-4 之后锤子才归玩家，2-5 起卡槽里有它；没解锁时整块不出现（含 H 键）。
##
## **冷却**（默认关）：挥完一锤之后等几秒才能再挥，开关与时长在模组页面里设
## （`HammerSettings.is_cooldown_enabled()` / `HammerSettings.get_cooldown_time()`，
## 值落在**模组存档文件** `[hammer]` 段，见 `HeadHammerMod` 的类注释）。
## 冷却中锤子拿不起来（点它只有一声"不行"），卡槽图标上盖一层遮罩随剩余时间往回收。

## 跨文件引用：`user://` 下脚本的 class_name **不会注册成全局类**（实测 Godot 4.6.2），
## 所以同目录的文件一律 preload 成常量再引用，不能写 `var x: Xxx`
## 秒杀 / 伤害 / 范围 / 冷却的读值口走 `hammer_settings.gd`
## （与 `hammer_mod.gd` 共用，两边互相 preload 会成环）
const HammerSettings := preload("hammer_settings.gd")

## 卡槽里的锤子（本体是卡槽背景，Icon 由本组件控制显隐）
var ui_hammer
## 跟随鼠标的真锤子
var real_hammer
## 手持美术的挂载点：用它取鼠标全局位置，保证与草坪同一坐标系（CanvasLayerTemp 开了 follow_viewport）
var temporary_character: Node2D

## 冷却还剩几秒（`> 0` = 正在冷却，这段时间不能再拿锤子）
var cool_remain: float = 0.0
## 本次冷却的总时长（秒）：给卡槽遮罩算「还剩几分之几」用；0 = 没在冷却
var cool_total: float = 0.0


## 由 `HeadHammerMod` 在把本组件加进场景树之前调用：模组自己建的节点没法用 `%同名` 取
func set_visual_nodes(
		p_ui_hammer, p_real_hammer, p_temporary_character: Node2D) -> void:
	ui_hammer = p_ui_hammer
	real_hammer = p_real_hammer
	temporary_character = p_temporary_character


func get_hand_component_type() -> E_HandComponentType:
	return E_HandComponentType.HammerMod


func _ready_component() -> void:
	change_is_enabling(is_can_has_hammer(), E_IsEnableFactor.HandItem)


## 本局是否可以持有锤子：关卡允许操作草坪 + 全局解锁进度（通关冒险 2-4 之后才有锤子）
## 与铲子同一套判定，关卡参数与解锁进度缺一不可；
## 解锁口径属于模组自己（`HammerSettings.UNLOCK_ADVENTURE_LEVEL`），本体不认识"锤子解锁"这回事
func is_can_has_hammer() -> bool:
	if not is_instance_valid(game_para):
		return false
	return game_para.is_shovel and is_unlocked()


## 玩家的通关进度是否已够拿到锤子（与铲子的 1-4 同一套口径，由通关记录推导，不落库存档）
func is_unlocked() -> bool:
	return HammerSettings.is_unlocked(Global.global_game_state.get_max_success_adventure_level())


## 点卡槽锤子 / 按 H：拿到手上（由 `HeadHammerMod` 接到卡槽按钮的 signal 上）
func on_click_hammer() -> void:
	## 冷却中：给一声"不行"，不放行（遮罩已经画在卡槽上，玩家看得到为什么按不动）
	if is_cooling():
		SoundManager.play_other_SFX("buzzer")
		return
	if not hand_manager.take_hand(get_hand_component_type()):
		## 组件被禁用（关卡没有草坪操作）时不发音效
		return
	SoundManager.play_other_SFX("shovel")


func enter_hand(_payload: Variant = null) -> bool:
	if is_instance_valid(real_hammer):
		real_hammer.change_is_using(true)
	return true


## 必须幂等：拿卡片 / 铲子时会先走这里，阶段切换收起时也可能被连调
func exit_hand() -> void:
	if is_instance_valid(real_hammer):
		real_hammer.change_is_using(false)


## 点草坪格子 = 挥一锤，挥完这次点击就算用完了手持物（回空手）
## 锤子跟着鼠标走，点格子与点空白对它没有区别；点空白那条路由 HandManager 统一取消
func click_cell(_plant_cell: PlantCell) -> bool:
	_swing_once()
	return true


## 挥一锤：真锤子出动画并圈出命中名单，这里按设置结算伤害；不管打没打中都开始冷却
func _swing_once() -> void:
	if not is_instance_valid(real_hammer) or not is_instance_valid(temporary_character):
		return
	var zombies: Array[Zombie000Base] = real_hammer.swing(HammerSettings.get_radius())
	for zombie in zombies:
		if not is_instance_valid(zombie):
			continue
		if HammerSettings.is_kill_mode():
			zombie.be_attack_to_death()
		else:
			var info := DamageInfo.create(zombie, HammerSettings.get_damage_value(),
					ConstDamage.E_DamageMode.Norm, ConstDamage.E_DamageCause.Hammer)
			zombie.apply_damage(info)
	_start_cooldown()


#region 界面
## 刷新锤子界面：卡槽本体（背景 + 按钮）在可操作草坪的阶段显示，锤子图标只在锤子不在手上时显示
func refresh_ui() -> void:
	if not is_instance_valid(ui_hammer):
		return
	## 「可以操作草坪」= 主游戏阶段，或开场教程（1-5 铲子教学）正在跑
	var is_in_play := is_instance_valid(main_game) and main_game.is_lawn_playable()
	var is_slot_visible := is_enabling and is_in_play
	ui_hammer.refresh_hammer_ui(is_slot_visible, is_slot_visible and not is_curr_hand())
	_refresh_cool_ui()
#endregion


#region 冷却
## 当前是否正在冷却（这段时间锤子拿不起来）
func is_cooling() -> bool:
	return cool_remain > 0.0


## 冷却倒计时：用自己的 `_process`，**不是** `hand_process()`
## —— 后者只在「锤子拿在手上」时才被 `HandManager` 调到，
##    而冷却恰恰发生在**挥完之后**、手上没东西的时候。
func _process(delta: float) -> void:
	if cool_remain <= 0.0:
		return
	## 运行期把开关关掉了：立刻结束冷却，别让人干等一个已经不存在的限制
	if not HammerSettings.is_cooldown_enabled():
		_end_cooldown()
		return
	cool_remain -= delta
	if cool_remain > 0.0:
		_refresh_cool_ui()
		return
	_end_cooldown()


## 开始冷却：**挥出一锤**才开始（不管有没有打中 —— 那一下都用掉了一次机会）
func _start_cooldown() -> void:
	if not HammerSettings.is_cooldown_enabled():
		return
	var cool_time := HammerSettings.get_cooldown_time()
	if cool_time <= 0.0:
		return
	cool_total = cool_time
	cool_remain = cool_time
	_refresh_cool_ui()


## 结束冷却（正常走完 / 开关被关掉，都要把遮罩收掉）
func _end_cooldown() -> void:
	cool_remain = 0.0
	cool_total = 0.0
	_refresh_cool_ui()


## 卡槽遮罩：按「还剩几分之几」盖住锤子图标（0 = 没在冷却 → 收起遮罩）
func _refresh_cool_ui() -> void:
	if not is_instance_valid(ui_hammer):
		return
	var cool_ratio := 0.0
	if cool_total > 0.0 and cool_remain > 0.0:
		cool_ratio = clampf(cool_remain / cool_total, 0.0, 1.0)
	ui_hammer.refresh_hammer_cool(cool_ratio)
#endregion
