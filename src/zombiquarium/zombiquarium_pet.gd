extends Node2D
class_name ZombiquariumPet
## 僵尸水族馆里养着的潜水僵尸（原版的「宠物」）
##
## 行为照搬原版 `Zombie::UpdateZombiquarium` + `Zombie::ZombiquariumFindClosestBrain`
## （A 级参照工程 `../PvZ-Portable-main/src/Lawn/Zombie.cpp`）：
##   · 原版一 tick = 1/60 秒，本脚本也按固定步长跑 tick（`ConstZombiquarium.TICK_SECONDS`）
##   · 状态机四态：DRIFT / ACCEL / BACK_AND_FORTH / BITE（`E_PetPhase`）
##   · 速度每 tick +0.01，上限随状态不同（0.5 / 0.3 / 0.05），出界时按当前速度的 0.3 倍减速
##   · 方向角 vel_z：换阶段时随机取，锁定脑子时对准脑子
##   · 血量：初始 200、上限 300、每 100 tick 掉 10；血量 ≤150 才找脑子，吃一个 +200
##   · 吐阳光：开局 200~400 tick 一次，之后 1000~1500 tick 一次，25 阳光，从嘴部冒出
##   · 血量 <100 身上发绿；血量归零播死亡动画，动画放完离场
##
## **坐标口径**：本节点的 `position` 就是原版的 `mPos`（水族馆局部坐标 = 原版棋盘坐标），
## 精灵挂在子节点上，偏移见 `PET_SPRITE_OFFSET`。
## 组件只通过信号与宿主通信（硬约束 §1-2）：本脚本不读组件内部字段，只发信号给管理器。

## 动画名（见 zombie_snorkle.tscn 的 AnimationPlayer 动画库）
const ANIM_SWIM := &"Zombie_snorkle_aquarium_swim"
const ANIM_BITE := &"Zombie_snorkle_aquarium_bite"
const ANIM_DEATH := &"Zombie_snorkle_aquarium_death"

## 精灵根节点相对 mPos 的偏移 —— 推导只用**原版自己的几何**，不靠量图：
##   · 原版潜水僵尸的受击框是 mPos + Rect(12, 0, 62, 115)（原版 Zombie.cpp:488）
##   · 原版的嘴部锚点是 mPos + (50, 40)（原版 Zombie.cpp:3092 判吃脑子、3246 吐阳光，同一个点）
##   · 仓库这条水族馆动画里，头贴图（`Body/BodyCorrect/Anim_head1`）在 BodyCorrect 空间的
##     x 21.6~66.3、y -1.3~49.0，躯干（body1）在 x 39.4~76.9、y 44.6~81.2，腿脚一直到 y 122
##   · 于是把 **BodyCorrect 原点摆到 mPos 上**，原版的受击框与嘴部锚点正好落在头与躯干上
##     （腿脚到 122，与受击框底 115 只差 7px）
##   · BodyCorrect 在仓库场景里的位置是 (-62, -122)（src/entities/character/zombie/zombie_snorkle.tscn），
##     所以精灵根节点摆在 mPos + (62, 122)
const PET_SPRITE_OFFSET := Vector2(62.0, 122.0)

## 宠物状态（原版 ZombiePhase 的四个水族馆阶段）
enum E_PetPhase {
	Drift,		## 原版 PHASE_ZOMBIQUARIUM_DRIFT：慢慢飘
	Accel,		## 原版 PHASE_ZOMBIQUARIUM_ACCEL：朝一个方向加速游
	BackAndForth,	## 原版 PHASE_ZOMBIQUARIUM_BACK_AND_FORTH：在 x 200~550 之间来回
	Bite,		## 原版 PHASE_ZOMBIQUARIUM_BITE：正在吃脑子
}

## 僵尸死透了（死亡动画放完，管理器据此判负）
signal signal_pet_death(pet: ZombiquariumPet)
## 该吐一颗阳光了（阳光由管理器统一生成，本脚本不碰阳光经济）
signal signal_produce_sun(pet: ZombiquariumPet, global_pos: Vector2)

## 脑子列表的取法（**由管理器注入的 Callable**）：原版每只僵尸自己去板子上找最近的脑子，
## 所以找脑子这件事留在宠物这边，管理器不派活（硬约束 §1-2：不跨节点抓字段）
var brains_getter: Callable = Callable()

## 当前状态
var phase: E_PetPhase = E_PetPhase.Drift
## 当前血量（原版 mBodyHealth）
var health: int = ConstZombiquarium.PET_HEALTH_INIT
## 奖杯已经掉下来（原版 `HasLevelAwardDropped()`）：原版这时宠物不再找脑子、不吐阳光、不掉血
var is_award_dropped := false

var _zombie: Zombie012Snorkle
var _anim_player: AnimationPlayer
## 原版 mZombieAge：每 tick +1，满 100 的整数倍掉 10 血
var _age := 0
## 原版 mPhaseCounter：阶段计时（tick）
var _phase_counter := 0
## 原版 mVelZ：速度方向角（弧度）
var _vel_z := 0.0
## 原版 mVelX（水族馆里当「速度大小」用）：每 tick +0.01
var _speed := 0.0
## 原版 mSummonCounter：吐阳光的倒计时（tick）
var _summon_counter := 0
var _tick_accumulator := 0.0
var _is_dead := false


#region 初始化
## 初始化宠物：造出展示态的潜水僵尸（必须在 add_child 到场景树之前调用）
## [param new_brains_getter] 取脑子列表的 Callable（管理器注入）
func init_pet(new_brains_getter: Callable) -> void:
	brains_getter = new_brains_getter
	_create_zombie()
	## 原版 Zombie.cpp:865-868：进关就是 DRIFT 阶段、阶段计时 200 tick、血量 200、
	## 第一次吐阳光的倒计时 200~400 tick
	phase = E_PetPhase.Drift
	_phase_counter = ConstZombiquarium.PHASE_TICKS_DRIFT_INIT
	health = ConstZombiquarium.PET_HEALTH_INIT
	_summon_counter = randi_range(
		ConstZombiquarium.PET_SUMMON_INIT_RANGE.x,
		ConstZombiquarium.PET_SUMMON_INIT_RANGE.y
	)
	_refresh_tint()


## 造一只展示态的潜水僵尸挂在本节点下
func _create_zombie() -> void:
	## 展示态：受击框 / 攻击 / 移动组件都不启用（见 character_base.ready_show / zombie_base.ready_show）
	_zombie = CharacterShowFactory.create_show_zombie(
		ConstZombiquarium.get_pet_zombie_type(), self, PET_SPRITE_OFFSET) as Zombie012Snorkle
	if _zombie == null:
		return
	## 水里的僵尸没有影子（原版 Zombie.cpp:9373「shadows look really dumb in Zombiquarium」）
	_zombie.shadow.visible = false
	## 动画树在展示态会一直播 idle，交给动画播放器直接播水族馆那三条动画
	_zombie.anim_component.stop_anim()
	_anim_player = _zombie.get_node("AnimationPlayer")
	_play_swim_anim()
#endregion


#region 每帧 / 每 tick
func _process(delta: float) -> void:
	if _is_dead:
		_update_dead()
		return
	_tick_accumulator += delta
	## 一帧最多补 15 tick：防止卡顿后一次性狂跑（原版不会这样，这里只防卡死）
	_tick_accumulator = minf(_tick_accumulator, ConstZombiquarium.TICK_SECONDS * 15.0)
	while _tick_accumulator >= ConstZombiquarium.TICK_SECONDS:
		_tick_accumulator -= ConstZombiquarium.TICK_SECONDS
		_tick()


## 一个 tick：对应原版 `Zombie::Update` 里的一帧（60 帧/秒）
func _tick() -> void:
	_age += 1
	## 原版 Zombie.cpp:4340：阶段计时每 tick 减 1
	if _phase_counter > 0:
		_phase_counter -= 1

	if phase == E_PetPhase.Bite:
		## 原版 Zombie.cpp:3139-3148：咬的动画放完就回到漂游
		if _is_anim_finished(ANIM_BITE):
			_play_swim_anim()
			phase = E_PetPhase.Drift
			_phase_counter = ConstZombiquarium.PHASE_TICKS_DRIFT_AFTER_BITE
	elif not _find_closest_brain() and _phase_counter == 0:
		## 原版 Zombie.cpp:3150-3181：阶段计时归零且附近没脑子 → 随机换一个漂游方式
		_pick_random_phase()

	_move()
	_summon_sun()
	_take_age_damage()
#endregion


#region 原版行为对照
## 原版 `Zombie::ZombiquariumFindClosestBrain`：找最近的脑子（落地 15 tick 之后的才算）；
## 够近就吃掉（回血 + 播咬的动画），否则把方向角对准它、进入加速阶段
func _find_closest_brain() -> bool:
	## 原版 Zombie.cpp:3081：奖杯掉了、血还够多 → 都不找脑子
	if is_award_dropped or health > ConstZombiquarium.PET_SEEK_HEALTH:
		return false
	var closest: ZombiquariumBrain = null
	var closest_distance := 0.0
	for brain in _get_brains():
		if not is_instance_valid(brain) or brain.is_eaten:
			continue
		## 原版 Zombie.cpp:3090：脑子落地 15 tick 之后才吃得掉
		if brain.get_alive_tick() < ConstZombiquarium.BRAIN_EAT_DELAY_TICK:
			continue
		var distance: float = brain.get_center().distance_to(get_mouth_pos())
		if closest == null or distance < closest_distance:
			closest_distance = distance
			closest = brain
	if closest == null:
		return false
	## 原版 Zombie.cpp:3103：够近就吃掉
	if closest_distance < ConstZombiquarium.BRAIN_EAT_DISTANCE:
		_eat_brain(closest)
		return false
	## 原版 Zombie.cpp:3117-3125：方向角对准脑子，进入加速阶段
	var to_brain: Vector2 = closest.get_center() - get_mouth_pos()
	_vel_z = atan2(to_brain.y, to_brain.x)
	if _vel_z < 0.0:
		_vel_z += TAU
	phase = E_PetPhase.Accel
	return true


## 吃掉一个脑子：原版 Zombie.cpp:3105-3114（脑子死、回 200 血、播咬的动画、进 BITE 阶段）
func _eat_brain(brain: ZombiquariumBrain) -> void:
	brain.be_eaten()
	health = mini(health + ConstZombiquarium.PET_EAT_HEAL, ConstZombiquarium.PET_HEALTH_MAX)
	_refresh_tint()
	_play_anim(ANIM_BITE, ConstZombiquarium.ANIM_RATE_BITE)
	phase = E_PetPhase.Bite
	_phase_counter = ConstZombiquarium.PHASE_TICKS_BITE
	## 原版 Zombie.cpp:3106 吃脑子是 slurp 音效
	SoundManager.play_other_SFX("slurp")


## 随机换一个漂游方式：原版 Zombie.cpp:3152-3180
func _pick_random_phase() -> void:
	## 原版 `Rand(7)` → 0~6
	var hit := randi() % 7
	_phase_counter = randi_range(
		ConstZombiquarium.PHASE_TICKS_RANDOM.x,
		ConstZombiquarium.PHASE_TICKS_RANDOM.y
	)
	if hit <= 4:
		## 原版 Zombie.cpp:3155-3158：随便找个方向加速游
		phase = E_PetPhase.Accel
		_vel_z = randf() * TAU
		_set_swim_rate(ConstZombiquarium.ANIM_RATE_FAST)
	elif hit == 5:
		## 原版 Zombie.cpp:3167-3172：来回游，先往右
		phase = E_PetPhase.BackAndForth
		_vel_z = 0.0
		_set_swim_rate(ConstZombiquarium.ANIM_RATE_FAST)
	else:
		## 原版 Zombie.cpp:3175-3179：来回游，先往左
		phase = E_PetPhase.BackAndForth
		_vel_z = PI
		_set_swim_rate(ConstZombiquarium.ANIM_RATE_FAST)


## 移动：原版 Zombie.cpp:3183-3236
func _move() -> void:
	var dir_x := cos(_vel_z)
	var dir_y := sin(_vel_z)
	## 原版 Zombie.cpp:3186-3201：出界判定
	var is_out_of_bounds := false
	if position.x < ConstZombiquarium.PET_AREA_X.x and dir_x < 0.0:
		is_out_of_bounds = true
	elif position.x > ConstZombiquarium.PET_AREA_X.y and dir_x > 0.0:
		is_out_of_bounds = true
	elif position.y < ConstZombiquarium.PET_AREA_Y.x and dir_y < 0.0:
		is_out_of_bounds = true
	elif position.y > ConstZombiquarium.PET_AREA_Y.y and dir_y > 0.0:
		is_out_of_bounds = true

	var max_speed := ConstZombiquarium.SPEED_ACCEL
	if is_out_of_bounds:
		## 原版 Zombie.cpp:3204-3208：出界减速，阶段计时也压到 100 以内
		max_speed = _speed * ConstZombiquarium.SPEED_OUT_OF_BOUNDS_SCALE
		_phase_counter = mini(100, _phase_counter)
	elif phase == E_PetPhase.Accel:
		max_speed = ConstZombiquarium.SPEED_ACCEL
	elif phase == E_PetPhase.BackAndForth:
		## 原版 Zombie.cpp:3215-3223：到折返点就折向
		if position.x < ConstZombiquarium.PET_TURN_X.x and dir_x < 0.0:
			_vel_z = 0.0
		if position.x > ConstZombiquarium.PET_TURN_X.y and dir_x > 0.0:
			_vel_z = PI
		max_speed = ConstZombiquarium.SPEED_BACK_AND_FORTH
	elif phase == E_PetPhase.Drift or phase == E_PetPhase.Bite:
		max_speed = ConstZombiquarium.SPEED_DRIFT

	## 原版 Zombie.cpp:3232-3236：加速 + 位移
	_speed = minf(max_speed, _speed + ConstZombiquarium.SPEED_STEP)
	dir_x *= _speed
	dir_y *= _speed
	position += Vector2(dir_x, dir_y)
	_update_facing()


## 吐阳光：原版 Zombie.cpp:3238-3249
func _summon_sun() -> void:
	if is_award_dropped:
		return
	if _summon_counter <= 0:
		return
	_summon_counter -= 1
	if _summon_counter != 0:
		return
	## 原版 Zombie.cpp:3245-3247：吐一颗阳光，然后重排下一次的时间
	## （吐阳光那声由阳光自己的弹出音效负责，见 SunSpawner.pop_up）
	signal_produce_sun.emit(self, global_position + ConstZombiquarium.PET_MOUTH_OFFSET)
	_summon_counter = randi_range(
		ConstZombiquarium.PET_SUMMON_RANGE.x,
		ConstZombiquarium.PET_SUMMON_RANGE.y
	)


## 掉血：原版 Zombie.cpp:3251-3258（每 100 tick 掉 10 血，掉到 0 就死）
func _take_age_damage() -> void:
	if is_award_dropped:
		return
	if _age % ConstZombiquarium.PET_DAMAGE_INTERVAL_TICK != 0:
		return
	health -= ConstZombiquarium.PET_DAMAGE_VALUE
	_refresh_tint()
	if health <= 0:
		die()
#endregion


#region 对外接口
## 嘴部锚点（原版 mPos + (50, 40)）：吃脑子、吐阳光都用它
func get_mouth_pos() -> Vector2:
	return position + ConstZombiquarium.PET_MOUTH_OFFSET


## 当前在播的动画名（调试 / 探针用，用来确认水族馆那三条动画真的播上了）
func get_curr_anim_name() -> StringName:
	if not is_instance_valid(_anim_player):
		return &""
	return _anim_player.current_animation


## 血量（调试 / 探针用）
func get_health() -> int:
	return health


## 已经活了多少 tick（调试 / 探针用）
func get_alive_tick() -> int:
	return _age


## 死了（血量归零，或外部强制处决）：播死亡动画，动画放完才离场
func die() -> void:
	if _is_dead:
		return
	_is_dead = true
	health = 0
	_refresh_tint()
	_play_anim(ANIM_DEATH, ConstZombiquarium.ANIM_RATE_DEATH)
	## 原版 Zombie.cpp:3256 死亡音效（仓库没有原素材，先用水花音顶上）
	SoundManager.play_other_SFX("zombie_entering_water")
#endregion


#region 内部
## 死亡动画放完 → 通知管理器 → 离场
func _update_dead() -> void:
	if not _is_anim_finished(ANIM_DEATH):
		return
	signal_pet_death.emit(self)
	queue_free()


## 血量低于 100 就发绿（原版 Zombie.cpp:5712-5714）
func _refresh_tint() -> void:
	if not is_instance_valid(_zombie):
		return
	if health < ConstZombiquarium.PET_GREEN_HEALTH:
		_zombie.body.modulate = ConstZombiquarium.PET_GREEN_COLOR
	else:
		_zombie.body.modulate = Color.WHITE


## 翻面：原版 Zombie.cpp:5079-5085，往右游（速度角不在 [π/2, 3π/2]）时把僵尸翻过来
func _update_facing() -> void:
	if not is_instance_valid(_zombie):
		return
	var is_backwards := _vel_z < PI / 2.0 or _vel_z > PI * 1.5
	## 仓库口径：direction_x = 1 朝左（默认朝向）、-1 镜像朝右
	_zombie.update_direction_x_root(-1 if is_backwards else 1)


## 脑子列表（管理器注入的 Callable）
func _get_brains() -> Array:
	if not brains_getter.is_valid():
		return []
	var result: Variant = brains_getter.call()
	if result is Array:
		return result
	return []


## 播游泳动画：原版 Zombie.cpp:861 / 3143 `RandRangeFloat(8.0, 10.0)`
func _play_swim_anim() -> void:
	_play_anim(ANIM_SWIM, randf_range(
		ConstZombiquarium.ANIM_RATE_SWIM.x,
		ConstZombiquarium.ANIM_RATE_SWIM.y
	))


## 只改播放速率、不重播：原版 `aBodyReanim->mAnimRate = RandRangeFloat(15.0, 20.0)`
func _set_swim_rate(rate: Vector2) -> void:
	if not is_instance_valid(_anim_player):
		return
	_anim_player.speed_scale = randf_range(rate.x, rate.y) / ConstZombiquarium.REANIM_BASE_FPS


## 播一段动画：原版 `PlayZombieReanim(名字, 模式, 混合时间, 速率)`
## 速率换算：仓库的 .tres 是 12fps 基准，原版速率 R → speed_scale = R / 12
func _play_anim(anim_name: StringName, rate: float) -> void:
	if not is_instance_valid(_anim_player) or not _anim_player.has_animation(anim_name):
		Log.error("僵尸水族馆：动画不存在 " + str(anim_name))
		return
	_anim_player.speed_scale = rate / ConstZombiquarium.REANIM_BASE_FPS
	_anim_player.play(anim_name)


## 动画是否已经放完（原版：reanim 播完 mLoopCount > 0）
func _is_anim_finished(anim_name: StringName) -> bool:
	if not is_instance_valid(_anim_player):
		return true
	if _anim_player.current_animation != anim_name:
		return true
	return not _anim_player.is_playing()
#endregion
