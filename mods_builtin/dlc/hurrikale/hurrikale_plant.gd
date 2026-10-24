extends Plant000Base
## 飓衣甘蓝（DLC 的 Hurrikale，由模组「DLC植物」提供）
##
## ★ 玩法就一句话：**一次性飓风** —— 种下去，起手一小会儿，然后刮起一阵旋风：
##   · 把**全场**僵尸沿来路向后吹（`push_back_cells` 格，往右侧 = 僵尸涌来的方向）；
##   · 顺带把它们**冻住**一小会儿（复用本体的「全场冰冻」事件，寒冰菇同款，伤害 0 = 只冻不打）；
##   · 吹完这阵风，甘蓝自己也**消失**（一次性植物，腾出格子）。
##
## ★ 为什么不走本体的攻击组件：这一株不吐子弹，攻击方式是「一次性的全场控制效果」，
##   没有「检测到敌人→按冷却开火」这个循环。所以照 DLC 模组里那两株（环轨仙人掌 / 投掷蘑菇）
##   自己挂 `AnimationPlayer` + 计时器的路子来：这里更简单，只要一个起手计时器。
##   （`AttackComponent*` 那套靠 `AnimationTree` 驱动节奏，而 DLC 动画只有 `AnimationPlayer`。）
##
## ★ 冰冻复用现成链路：`ZombieManager.ice_all_zombie(time_ice, time_decelerate, damage)` ——
##   它就是寒冰菇 `BombComponentIce` 推的同一个事件，遍历 `all_zombies_2d` 给每只僵尸 `be_ice_freeze`。
##   这里 damage 传 0（飓衣甘蓝不造成伤害，只做控制）。
##
## ★ 击退怎么做：僵尸的 `position.x` 就是它的世界 x（移动组件两种模式都在改它），
##   所以把每只僵尸 `position.x += 距离`（+x = 往右 = 往僵尸涌来的方向吹）就是一次「往后推」。
##   僵王（`ZB000Base`）跳过 —— 它的 x 由自己的状态机 / 入场演出控制，别去平移它。
##
## ★ 动画走 DLC 的 reanim → Godot 动画（`animation/character/plant/Hurrikale/Hurrikale.tscn`），
##   三段合成进同一条动画库 `AnimLib`：
##     · `Hurrikale_idle`（3.4167 秒）：站着待机（起手阶段播它，播完由回调重播，循环）
##     · `Hurrikale_blow`（2.8333 秒）：吹风 —— 播它就出旋风
##     · `Hurrikale_loop`（0.8333 秒）：本株不用（预留；不挂进脚本也能取帧）
##
## ★ 数值都是**模组自己的取值**（PVZ2 的 Hurrikale：100 阳光 / 冷却约 30 秒 / 不造成伤害 / 冰冻 + 击退），
##   对齐哪一项见文件头；别照 wiki 再改别的。
##
## ⚠️ 本文件可能跑在 `user://mods/dlc/` 下：`class_name` 不会注册成全局类，
##    所以这里不写 class_name，由同目录的 `plant_hurrikale.tscn` 按路径引用。

@onready var _anim_player: AnimationPlayer = $Body/HurrikaleAnim/AnimLib
## 起手计时器：从种下到刮风之间的一小段（让玩家看清是哪株在吹风）
@onready var _windup_timer: Timer = $WindupTimer


#region 数值（模组的取值，不是照 wiki 抄的）
## 飓风刮起前的起手时长（秒）：≥ 0，给玩家一点反应时间看清旋风吹向
@export var windup_time := 0.4
## 完全冰冻时长（秒）：借本体「全场冰冻」口径（寒冰菇同款事件）
@export var freeze_time := 4.0
## 解冻后的减速时长（秒）
@export var decelerate_time := 6.0
## 每只僵尸被向后吹几格（正数 = 往右侧 / 来路吹）。本体一格 = 76 px。
@export var push_back_cells := 3.0
#endregion


#region 动画常量
const STATE_IDLE := &"Hurrikale_idle"
const STATE_BLOW := &"Hurrikale_blow"
#endregion

## 已经刮过风（进入吹风 / 演出阶段）：起手阶段之后就不再回到待机
var _is_blowing := false


#region 生命周期
## 初始化正常出战角色信号连接
func ready_norm_signal_connect() -> void:
	super()
	_anim_player.animation_finished.connect(_on_animation_finished)
	## 计时时长以导出值为准：场景里的 `wait_time` 只是编辑器默认值
	_windup_timer.wait_time = windup_time
	_windup_timer.timeout.connect(_on_windup_timeout)
	## 关卡全场加速（「僵尸快跑」）：起手计时与动画一起按倍率走
	signal_update_speed.connect(_on_update_speed)


## 初始化正常出战角色
func ready_norm() -> void:
	super()
	_play_idle()
	## 种下即进入起手（一次性植物：不需要等玩家再点什么）
	_windup_timer.start()


## 初始化展示角色（图鉴 / 选卡界面里的形象）：只站着待机，不刮风
func ready_show() -> void:
	super()
	_play_idle()


## 初始化花园角色：只站着待机，不刮风
func ready_garden() -> void:
	super()
	_play_idle()
#endregion


#region 飓风
func _on_windup_timeout() -> void:
	if is_death or _is_blowing:
		return
	_cast_hurricane()


## 刮一次风：结算全场效果 + 播吹风动画
func _cast_hurricane() -> void:
	_is_blowing = true
	_apply_freeze_and_push()
	_anim_player.play(STATE_BLOW)


## 冰冻 + 击退**本行**僵尸（wiki `range = 1x9`：只刮自己这一行，不是全场），
## 并顺手把本行的空中僵尸吹走（主场景不存在时安全跳过：探针 / 空场景里也要能把动画播完、把植物撤掉）
func _apply_freeze_and_push() -> void:
	var main_game := get_main_game()
	if not is_instance_valid(main_game):
		return
	var zombie_manager := main_game.zombie_manager
	if not is_instance_valid(zombie_manager):
		return
	## 只刮本行：`all_zombies_2d` 按行存，下标就是行号
	if lane < 0 or lane >= zombie_manager.all_zombies_2d.size():
		return
	var row: Array = zombie_manager.all_zombies_2d[lane]
	var push_px := push_back_cells * 76.0
	## 倒序遍历：吹飞会当场把僵尸从行表里摘掉
	for i in range(row.size() - 1, -1, -1):
		var zombie := row[i] as Zombie000Base
		if not is_instance_valid(zombie) or zombie is ZB000Base or zombie.is_death:
			continue
		## 空中僵尸（气球 / 乌鸦）**直接吹走**：wiki 说它像 Blover 一样瞬间摧毁飞行僵尸，
		## 但只在本行生效 —— 本体那个 `blover_blow_away_in_sky_zombie()` 是全场不分行的，
		## 所以这里自己按行筛一遍，判定一律看 `IsSky` 状态（将来热注册的飞行僵尸也认）
		if zombie.curr_be_attack_status == Zombie000Base.E_BeAttackStatusZombie.IsSky:
			zombie.be_blow_away()
			continue
		## 冰冻 + 击退：与寒冰菇同一条「冰冻」口径，伤害 0 = 只冻不打
		zombie.be_ice_freeze(freeze_time, decelerate_time, 0)
		zombie.position.x += push_px
#endregion


#region 全场加速
## 关卡全场加速（「僵尸快跑」）：起手计时按倍率折算，动画倍率一起改
func _on_update_speed(speed_product: float) -> void:
	if speed_product == 0:
		_windup_timer.paused = true
		_anim_player.speed_scale = 0.0
		return
	_windup_timer.paused = false
	_anim_player.speed_scale = speed_product
	if not _windup_timer.is_stopped():
		_windup_timer.start(_windup_timer.time_left / speed_product)
	_windup_timer.wait_time = windup_time / speed_product
#endregion


#region 动画回调
## 一段动画播完：待机重播（循环）；吹风播完 → 一次性植物撤掉自己
func _on_animation_finished(anim_name: StringName) -> void:
	if is_death:
		return
	if anim_name == STATE_IDLE:
		## 还没起风就继续站着（三段都是非循环，靠回调续上）
		if not _is_blowing:
			_play_idle()
	elif anim_name == STATE_BLOW:
		## 吹完这阵风，甘蓝消失、腾出格子（一次性植物）。
		## 走本体 `character_death()`（血橙即炸同款）：发死亡信号 → 格子 `one_plant_free` 清理，
		## `HpComponentPlant.is_death_free` 默认 true → 自动 queue_free
		character_death()


## 待机：已经在播就不打断（避免每帧重置动画）
func _play_idle() -> void:
	if _anim_player.current_animation == STATE_IDLE and _anim_player.is_playing():
		return
	_anim_player.play(STATE_IDLE)
#endregion
