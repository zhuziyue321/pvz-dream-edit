extends Zombie000Base
## 产脑光墓碑（DLC 对战墓碑 VSGravestone，由模组「玩家对战」提供）—— **僵尸单位**
##
## ★ 玩法一句话：**50 脑光**的僵尸方建筑型僵尸（只在「玩家对战」里发得出来）：
##   放下去后周期性给僵尸方银行入账脑子（见 `component_create_brains.gd`：
##   节奏全复用本体的产阳光组件，只把出阳光换成脑子入账）；站着不动、不啃植物。
##
## ★ 为什么是僵尸（2026-10-25 从植物改成僵尸）：
##   它本来就是**僵尸方**的单位，做成植物时得靠三处补丁才像僵尸
##   （`is_enemy_to_all_camps`、受击/检测层各补僵尸那两层、落位换一套自定义种植条件）。
##   改成本体 `zombie_base.tscn` 之后这些全都不需要：阵营判定、植物索敌与子弹、
##   僵尸放置链路（`can_common_zombie` + 红线）天然成立。照 `targetzombie/target_zombie.gd`
##   那套「静止僵尸」接法：
##     · `AnimComponent` 换成 `AnimComponentEmpty`，动画由本脚本直接播 `AnimLib`；
##     · `ready_norm()` 里把移动组件按上禁用因子（它不是进攻单位）；
##     · 死亡自己收尾（DLC 素材没有死亡段，淡出删除）。
##
## ★ **占格**（"用墓碑的逻辑"）：本体墓碑是「一块地记一个墓碑引用 + 植物侧特殊状态」，
##   这里照同一套做僵尸侧 —— 放下去时把所在 `PlantCell` 标成 `IsOccupied`
##   （`can_common_zombie = false`），放置判定（`hand_component_character.gd` 的僵尸分支）
##   自然拦住「同一格连放两块墓碑」；死亡 / 离场时放开。格子靠 lane + 生成坐标反查，
##   不需要本体为模组加任何生成钩子。
##   ⚠️ 植物侧不用管：对战红线已经把僵尸半场标成不能种植物（`can_common_plant = false`）。
##
## ★ 动画走 VSGravestone.reanim → Godot 动画（`animation/character/plant/VSGravestone/`），
##   七段装在同一个库 `AnimLib` 里：
##     · `VSGravestone_rise`（0.5 s）：出土
##     · `VSGravestone_idle`（0 长度静帧）：立定待机
##     · `VSGravestone_break1`~`break5`（1.1~1.35 s）：**受损五阶**，见下面一段
##   转换产物只留这七段（roof / night / water 各段本模组用不上）。
##
## ★ 受损动画怎么接的（2026-10-25）：原版 reanim 的 `anim_break1~5` 每一段都是
##   「**第 N 阶裂纹外观（Stone1~5 换掉 Stone）+ 这一下崩飞的碎块**」，碎块在段尾淡出，
##   所以**播一段就自洽**、播完停在最后一帧就是「被打裂了但还立着」的样子：
##     · 触发：`hp_component.signal_hp_loss` → 血量分 6 段（满血 + 5 阶），
##       每掉 1/6 血进一阶（300 血时 250 / 200 / 150 / 100 / 50 各换一次）；
##     · 只进不退：一阶一阶往上播，同一帧里挨十下也只播最高那阶；
##     · **播完不回待机**（回待机 = `Stone` 又出来，裂缝白挨）；
##     · 出土途中就被打：break 直接打断 rise，之后也不再补播 idle（见 `_on_animation_finished`）。
##   没走 `HpStageChangeComponent`：那个组件是给「换贴图 / 显隐精灵」的（还要把死亡血量设成
##   最后一档），而这里要的是「播一段动画再停住」，且死亡血量必须留在 0。
##
## ⚠️ 本文件可能跑在 `user://mods/player_battle/` 下：不写 `class_name`
##    （同 `target_zombie.gd` 口径，全局类型只引用本体的）。

## 动画播放器：动画场景里 root 下最后一个子节点（见场景内注释）；
## 动画整体套在出土裁剪板 `VSGravestoneMask` 里（见 `zombie_vsgravestone.tscn` 注释）
@onready var _anim_player: AnimationPlayer = $Body/VSGravestoneMask/VSGravestoneAnim/AnimLib
## 产脑子组件（节奏走本体产阳光组件，只换了产出物）
@onready var _create_sun_component: CreateSunComponent = $CreateSunComponent


#region 动画常量
const STATE_IDLE := &"VSGravestone_idle"
const STATE_RISE := &"VSGravestone_rise"

## 受损五阶（`break1` → `break5`，越往后裂得越厉害）；下标 0 = 第 1 阶
const STATE_BREAK_LIST: Array[StringName] = [
	&"VSGravestone_break1",
	&"VSGravestone_break2",
	&"VSGravestone_break3",
	&"VSGravestone_break4",
	&"VSGravestone_break5",
]

## 血量分段数 = 受损阶数 + 1（满血 + 五阶）：每掉 1/6 血进一阶
##
## ⚠️ 写死 6 而不是 `STATE_BREAK_LIST.size() + 1` —— 常量数组的 `.size()` 不是常量表达式，
##    那样写整个脚本会 Parse Error（2026-10-25 编译门禁抓到的）。改列表长度时同步改这里。
const HP_STAGE_COUNT := 6
#endregion


## 当前受损阶（0 = 满血；1~5 = `break1~5` 已播过、停在段尾姿态）
var _damage_stage := 0
## 正在死亡（播淡出到删除这一段）：防重入
var _is_dying := false
## 被本墓碑占住的格子（生成时反查；死亡 / 离场时放开）
var _occupied_cell: PlantCell = null


#region 生命周期
## 初始化正常出战角色信号连接
func ready_norm_signal_connect() -> void:
	super()
	_anim_player.animation_finished.connect(_on_animation_finished)
	## 掉血 → 受损动画（见文件头「受损动画怎么接的」）
	hp_component.signal_hp_loss.connect(_on_hp_loss)
	## 关卡全场加速（「僵尸快跑」/ 血月）要连动画与产脑节奏一起加速
	signal_update_speed.connect(_on_update_speed_anim)
	signal_update_speed.connect(_create_sun_component.owner_update_speed)
	## 被魅惑也别让它走起来（墓碑是建筑，不是进攻单位）——
	## 本基类先连了 `move_component._walking_start`，这里后连、后执行，禁得住
	signal_character_be_hypno.connect(_on_be_hypno)


## 初始化正常出战角色：**原地不动** + 占格 + 出土
func ready_norm() -> void:
	super()
	## 站着不动（靶子僵尸同一套：移动组件按禁用因子）
	move_component.update_move_factor(true, MoveComponent.E_MoveFactor.IsDisable)
	## 不啃植物 —— 它挡在僵尸半场，够不到植物；禁掉免得检测组件空转
	attack_component.disable_component(ComponentNormBase.E_IsEnableFactor.Character)
	## 产脑组件要 `BodyCharacter` 做发光表现：`%Body` 在嵌套场景里的解析不作保证，
	## 这里手工把宿主已经取到的那一份递过去（组件自己的 `%Body` 只在植物场景里验过）
	_create_sun_component.body = body
	_occupy_cell()
	_play(STATE_RISE)


## 初始化展示角色（图鉴 / 选卡界面里的形象）
func ready_show() -> void:
	super()
	_play(STATE_IDLE)


## 初始化花园角色
func ready_garden() -> void:
	super()
	_play(STATE_IDLE)


## 离场（正常死亡淡出 / 换关整批释放）：兜底放开占格
func _exit_tree() -> void:
	_release_cell()
#endregion


#region 占格（本体墓碑那套的僵尸侧版本）
## 生成后反查自己落在哪个格子，把它标成「已被僵尸单位占住」
##
## 反查方式：僵尸生成时位置已经在入树之前设好（`ZombieManager.create_norm_zombie`
## 用的是格子中心的 x + 该行出怪点的 y），所以这里按 lane 取整行格子、
## 用 x 落在哪一格的 [左边, 右边) 判断即可，不需要本体给模组加生成钩子。
func _occupy_cell() -> void:
	var main_game := get_main_game()
	if main_game == null or main_game.plant_cell_manager == null:
		Log.warn("产脑光墓碑：拿不到主游戏 / 格子管理器，占格判定未生效")
		return
	var rows: Array = main_game.plant_cell_manager.all_plant_cells
	if lane < 0 or lane >= rows.size():
		Log.warn("产脑光墓碑：行号 %d 越界（共 %d 行），占格判定未生效" % [lane, rows.size()])
		return
	## 优先按 x 落在哪一格判断；万一坐标系有偏差（斜面 / 相机层），退到「最近的格子」
	var nearest: PlantCell = null
	var nearest_distance := INF
	for cell in rows[lane]:
		var plant_cell := cell as PlantCell
		if plant_cell == null:
			continue
		var left := plant_cell.global_position.x
		var width := plant_cell.size.x
		if global_position.x >= left and global_position.x < left + width:
			_occupy(plant_cell)
			return
		var distance := absf(global_position.x - (left + width * 0.5))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = plant_cell
	if nearest != null:
		Log.warn("产脑光墓碑：x=%.1f 没落进任何格子（最近一格中心 %.1f，差 %.1f），按最近格子占位"
			% [global_position.x, nearest.global_position.x + nearest.size.x * 0.5, nearest_distance])
		_occupy(nearest)
		return
	Log.warn("产脑光墓碑：第 %d 行没有格子，占格判定未生效" % lane)


## 真正登记占格：格里记一个标记，放置判定读 `can_common_zombie` 时自然被拦住
func _occupy(plant_cell: PlantCell) -> void:
	_occupied_cell = plant_cell
	plant_cell.set_occupied_by_zombie(true)


## 放开占格（幂等；格子已随换关释放时什么都不做）
func _release_cell() -> void:
	if _occupied_cell != null and is_instance_valid(_occupied_cell):
		_occupied_cell.set_occupied_by_zombie(false)
	_occupied_cell = null
#endregion


#region 死亡
## 角色死亡：走本体那一套（禁受击框、发死亡信号给管理器）后放开占格 + 淡出删除
##
## DLC 素材没有死亡段（只有 idle / rise / break1~5），所以不做死亡动画，
## 直接走本体僵尸的淡出收尾（`_fade_and_remove`，1 秒后 queue_free）。
func character_death() -> void:
	if _is_dying:
		return
	super()
	_is_dying = true
	## 死亡即放开格子（与植物被啃死同一口径：格子马上能用，尸体只是还在淡出）
	_release_cell()
	_fade_and_remove()
#endregion


#region 受损动画
## 掉血：按血量比例进阶，进到哪一阶就播哪一段 `break`（只进不退）
##
## ⚠️ 一帧里连挨几下（霰弹 / 多颗豌豆同帧命中）时 `signal_hp_loss` 会连着来，
## 每次都只看**当前**血量算阶：跳级就只播跳上去那一段，不会把中间几段排队补播。
func _on_hp_loss(curr_hp: int, _is_drop: bool) -> void:
	if _is_dying or is_death:
		return
	var stage := _hp_to_damage_stage(curr_hp)
	if stage <= _damage_stage:
		return
	_damage_stage = stage
	_play(STATE_BREAK_LIST[stage - 1])


## 当前血量算受损阶：0 = 满血，1~5 = 第几阶（血量上限不是 300 时按比例走）
##
## ⚠️ 全程**整数除法**，别写成 `int(float(掉血) / 最大血 * 6)`：血量正好压在分界上
## （300 血掉到 200 = 2/6）时浮点会算出 1.9999999999999998，`int()` / `floori()`
## 都把它截成 1 —— 分界那一档白丢。
func _hp_to_damage_stage(curr_hp: int) -> int:
	var max_hp := hp_component.max_hp
	if max_hp <= 0:
		return 0
	@warning_ignore("integer_division")
	var stage := (max_hp - curr_hp) * HP_STAGE_COUNT / max_hp
	return clampi(stage, 0, STATE_BREAK_LIST.size())
#endregion


#region 动画回调
## 一段动画播完：出土播完回待机；受损段播完**停在最后一帧**（裂纹留下，碎块已淡出）
func _on_animation_finished(anim_name: StringName) -> void:
	if _is_dying or is_death:
		return
	if anim_name == STATE_RISE:
		## 出土途中就被打裂了：别补播待机把裂缝盖回去
		if _damage_stage == 0:
			_play(STATE_IDLE)


## 播一段动画；待机是静帧，显式 seek 一次确保第 0 帧姿态被应用
func _play(anim: StringName) -> void:
	if _is_dying:
		return
	if _anim_player.current_animation == anim and _anim_player.is_playing():
		return
	_anim_player.play(anim)
	_anim_player.seek(0.0, true)


## 全场加速：动画跟着折算（产脑计时器由上面的 signal 连接折算）
func _on_update_speed_anim(speed_product: float) -> void:
	_anim_player.speed_scale = speed_product
#endregion


## 被魅惑：不开攻击、不走路（见 `ready_norm_signal_connect` 的说明）
func _on_be_hypno() -> void:
	move_component.update_move_factor(true, MoveComponent.E_MoveFactor.IsDisable)
	attack_component.disable_component(ComponentNormBase.E_IsEnableFactor.Hypno)


#region 免疫（与靶子僵尸同一套待遇，2026-10-25）
## 免疫小推车**不在这里写**（2026-10-26 改）：小推车已改成一种**特殊伤害**
## （`E_DamageCause.Mower` + 秒杀，走 `DamageSystem`），由场景里的 `ImmuneMowerComponent`
## （`DamageModifierComponent` 子类）在修饰器链上整包取消 —— 见 `zombie_vsgravestone.tscn`。
## 墓碑立在僵尸半场，推车被触发后会一路开到屏幕外必然碾过它；建筑型单位被自己人的车推掉是纯亏。

## 被魅惑僵尸无视：魅惑僵尸索敌时不把墓碑当目标（DLC 原版里墓碑不算敌对目标）。[br]
## 只挡「僵尸打僵尸」这一条通道 —— 植物照样能啃 / 打它（300 血，被打烂一样放开占格）。
func is_targetable_by_hypno_zombie() -> bool:
	return false
#endregion
