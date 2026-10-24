extends Plant000Base
## 血橙（DLC 的 BloodOrange，由模组「DLC植物」提供）
##
## ★ 玩法就一句话：**即炸植物** —— 种下后短暂待机，随后原地引爆，
##   对周围 3×3 范围内的僵尸造成一次性大伤害（1800，灰烬炸弹口径），
##   然后这株植物结束（被移除）。
##
## ★ 动画走 DLC 的 reanim → Godot 动画（`animation/character/plant/BloodOrange/BloodOrange.tscn`），
##   两段合成进同一条动画库 `AnimLib`：
##     · `BloodOrange_idle`（0.667 秒）：站着待机
##     · `BloodOrange_explode`（1.0 秒）：胀大 + 泡沫飞溅后炸开
##
## ★ 爆炸 = 自己挂的 `Area2DBomb` 检测重叠的僵尸受击框，逐个 `be_bomb()` —— 不再走本体
##   `BombComponent`（那条路靠 AnimationTree 的方法轨在爆炸动画里回调 `bomb_once()`，
##   而 DLC 动画只有 `AnimationPlayer`、没有 `AnimationTree`，场景加载就会报「Node not found」）。
##   数值都是**模组自己的取值**（对齐「樱桃炸弹」那一档：1800 伤害 / 3 行范围）。
##
## ⚠️ 本文件可能跑在 `user://mods/dlc/` 下：`class_name` 不会注册成全局类，
##    所以这里不写 class_name，由同目录的 `plant_bloodorange.tscn` 按路径引用。

## 两段动画名
const STATE_IDLE := &"BloodOrange_idle"
const STATE_EXPLODE := &"BloodOrange_explode"

## 引爆音效：DLC 自己的 `bloodexplosion.ogg`（血橙专属），比借本体的 `CherryBomb` 准
const EXPLOSION_SFX: AudioStream = preload("../audio/bloodexplosion.ogg")
## 引信点燃音效（DLC 自己的两条引信声，种下时随机取一条）
const FUSE_SFX: Array[AudioStream] = [
	preload("../audio/fuse1.ogg"),
	preload("../audio/fuse2.ogg"),
]

## 一棵僵尸受到的爆炸伤害（wiki `damage = 900`：正好是樱桃炸弹 1800 的一半，
## wiki 正文也明说它是「半价、半伤的樱桃炸弹」）
@export var bomb_value := 900
## 引信时长（秒）：种下后多久引爆；长于 idle（0.667 秒），让待机先播完
@export var fuse_time := 1.0
## Blood Moon（wiki `special = inflicts the Blood Moon effect to zombies`）：
## **没被这一炸炸死的**僵尸会被血月加速 —— 这是「半价樱桃」的代价（原版是纯负面副作用）。
## wiki 没给倍率与持续时长，取**模组自定**：加速 1.5 倍 / 10 秒
@export var blood_moon_factor := 1.5
@export var blood_moon_duration := 10.0

@onready var _anim_player: AnimationPlayer = $Body/BloodOrangeAnim/AnimLib
@onready var _area_bomb: Area2D = $Area2DBomb
@onready var _can_attack: CanAttackStatusComponent = $CanAttackStatusComponent
@onready var _fuse_timer: Timer = $FuseTimer


#region 生命周期
## 初始化正常出战角色信号连接
func ready_norm_signal_connect() -> void:
	super()
	_fuse_timer.wait_time = fuse_time
	_fuse_timer.timeout.connect(_on_fuse_timeout)
	_anim_player.animation_finished.connect(_on_animation_finished)
	## 关卡全场加速（「僵尸快跑」）要连引信与动画一起加速
	signal_update_speed.connect(_on_update_speed)


## 初始化正常出战角色：播待机 + 点引信
func ready_norm() -> void:
	super()
	_play_idle()
	SoundManager.play_sfx_with_pool(FUSE_SFX.pick_random())
	_fuse_timer.start()


## 初始化展示角色（图鉴 / 选卡界面里的形象）：只播待机，不点引信
func ready_show() -> void:
	super()
	_play_idle()


## 初始化花园角色
func ready_garden() -> void:
	super()
	_play_idle()
#endregion


#region 爆炸
## 引信到点 → 引爆
func _on_fuse_timeout() -> void:
	_explode()


## 引爆：播爆炸动画 + 音效，等一物理帧让爆炸框与僵尸受击框重叠生效，再派发伤害
func _explode() -> void:
	if is_death:
		return
	_anim_player.play(STATE_EXPLODE)
	SoundManager.play_sfx_with_pool(EXPLOSION_SFX)
	## 同本体 `BombComponent` 的口径：爆炸框是刚随场景建出来的 Area2D，
	## `get_overlapping_areas()` 在它过完一个物理帧之前是空的。
	await get_tree().create_timer(0.12).timeout
	_bomb_all_enemy()


## 炸范围内的僵尸（口径照抄本体 `BombComponentNorm._bomb_all_enemy`）
func _bomb_all_enemy() -> void:
	if is_death:
		return
	var areas := _area_bomb.get_overlapping_areas()
	for area in areas:
		var owner_char = area.owner
		if owner_char is Zombie000Base and _can_attack.can_attack(owner_char):
			var zombie := owner_char as Zombie000Base
			zombie.be_bomb(bomb_value, true)
			## 炸完还活着 → 上血月（`be_bomb` 是同步结算，这里能直接看 `is_death`）
			if not zombie.is_death:
				_apply_blood_moon(zombie)


## 给一只僵尸挂上血月：按 `blood_moon_factor` 加速，`blood_moon_duration` 秒后还原。
##
## 走 `update_speed_factor()` 的**乘积**通道（与增幅鹅河菊同一条路子）：只写自己那 `BloodOrange`
## 一档，不碰冰冻 / 黄油 / 关卡加速那些档 —— 恢复时把这一档设回 1.0 即可。
## ⚠️ 这一档**不能**跟月夜屋顶章的血月事件共用 `BloodMoon`：共用时血橙计时一到就把那一档
## 设回 1.0，会顺手把正在进行的血月加速也清掉（反过来血月结束也会提前结束血橙加速）。
## 计时器挂在这只僵尸身上：它先被清掉的话计时器跟着一起没，不用额外摘。
func _apply_blood_moon(zombie: Zombie000Base) -> void:
	zombie.update_speed_factor(blood_moon_factor, Character000Base.E_Influence_Speed_Factor.BloodOrange)
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = blood_moon_duration
	zombie.add_child(timer)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(zombie):
			zombie.update_speed_factor(1.0, Character000Base.E_Influence_Speed_Factor.BloodOrange)
		timer.queue_free()
	)
	timer.start()


## 爆炸动画播完 → 这株植物结束（灰烬炸弹，当场移除）
func _on_animation_finished(anim_name: StringName) -> void:
	if is_death:
		return
	if anim_name == STATE_EXPLODE:
		character_death()
#endregion


#region 动画
## 待机是循环的：已经在播就不打断（避免每帧重置动画）
func _play_idle() -> void:
	if _anim_player.current_animation == STATE_IDLE and _anim_player.is_playing():
		return
	_anim_player.play(STATE_IDLE)
#endregion


#region 全场加速
func _on_update_speed(speed_product: float) -> void:
	if speed_product == 0:
		_fuse_timer.paused = true
		_anim_player.speed_scale = 0.0
		return
	_fuse_timer.paused = false
	_anim_player.speed_scale = speed_product
	if not _fuse_timer.is_stopped():
		_fuse_timer.start(_fuse_timer.time_left / speed_product)
	_fuse_timer.wait_time = fuse_time / speed_product
#endregion
