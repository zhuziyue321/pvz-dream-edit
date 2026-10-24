extends Plant000Base
## 柠檬榴弹（DLC Edition 的 Lemon-nade，由模组「DLC植物」提供）
##
## ★ 玩法就一句话：**樱桃炸弹的变体，一次性种下、连炸三次** —— 落地点燃引信，
##   在本格炸第一下，随后**随机弹到邻近区域**再炸第二、第三下（玩家无法控制弹向）。
##   每一发都是「中范围 3×3」的范围爆炸，炸死范围内的僵尸（灰烬即消），用完这株消失。
##
## ★ 数值（DLC Edition 的 wiki：Lemon-nade 页）：
##   200 阳光 / 冷却 50 秒（very slow）/ 每次爆炸 900 伤害（high）/ 范围 3×3 /
##   一次性、即时（single use, instant）。本体口径：樱桃炸弹的炸弹伤害 1800、3×3。
##   ⚠️ 「弹射」落点是随机的：本实现取「本格 ±(约 1.3 格 × 0.6 格)」随机偏移；
##      第一发固定落在本格（保证炸到种下时脚边的僵尸，也方便探针稳定断言）。
##
## ★ 为什么不走本体 `BombComponent` / 血橙那条 `Area2DBomb`：它们爆炸中心焊死在植物根上，
##   柠檬榴弹要**弹到别处再炸**、且一共三次；这里用 `PhysicsShapeQueryParameters2D.intersect_shape`
##   **即时**查一圈僵尸受击框（不用等物理帧，也不会因移动检测框丢帧），口径照抄本体
##   `BombComponentNorm._bomb_all_enemy`（`CanAttackStatusComponent.can_attack` 过滤 + `be_bomb`）。
##   也不给任何节点起名 `BombComponent` —— 免得基类 `death_language()` 误触「死亡引爆」。
##
## ★ 动画走 DLC 的 reanim → Godot 动画（`animation/character/plant/Lemonade/Lemonade.tscn`），
##   四段合成进同一条动画库 `AnimLib`：
##     · `Lemonade_idle`（1.25 秒，循环）：引信燃烧时的待机
##     · `Lemonade_explode` / `_explode2` / `_explode3`（各 1.0 秒）：三次爆炸各播一段
##   （爆炸间隔 0.28 秒 < 段长 1.0 秒，下一发用 `play()` 把该段从头重启，视觉就是「蹦一下炸一下」）
##
## ★ 数值都是**模组自己的取值**（对齐 wiki 的那几项已写在上面），别照 wiki 再改别的。
##
## ⚠️ 本文件可能跑在 `user://mods/dlc/` 下：`class_name` 不会注册成全局类，
##    所以这里不写 class_name，由同目录的 `plant_lemonade.tscn` 按路径引用。

#region 动画常量
const STATE_IDLE := &"Lemonade_idle"
## 三次爆炸各播一段（顺序播，视觉上是三下不同的爆）
const STATE_EXPLODES: Array[StringName] = [
	&"Lemonade_explode", &"Lemonade_explode2", &"Lemonade_explode3",
]
#endregion


#region 爆炸特效与音效
## 爆炸特效（`lemonade_blast.png`：横向 6 帧、单帧 128×128 的「柠檬炸开」全过程 ——
## 白闪 / 果皮碎片飞散 / 果汁环向外扩散 / 收尾淡出）。
## 原来三连炸在画面上只有一颗柠檬在原地缩放，连炸到哪儿去了完全看不出来
const FX_SCRIPT := preload("../dlc_sprite_fx.gd")
const BLAST_TEXTURE := preload("lemonade_blast.png")
const BLAST_FRAMES := 6
## 0.5 秒播完 6 帧：比 `explosion_gap`（0.28 秒）长一点，相邻两炸的特效会交叠，
## 正好是「连着炸开」的观感
const BLAST_FPS := 12.0
## 引信点燃音效（DLC 自己的两条引信声，种下时随机取一条）
const FUSE_SFX: Array[AudioStream] = [
	preload("../audio/fuse1.ogg"),
	preload("../audio/fuse2.ogg"),
]
#endregion

@onready var _anim_player: AnimationPlayer = $Body/LemonadeAnim/AnimLib
## 引信 + 三连炸的步进计时器（每一步重新装填 wait_time）
@onready var _action_timer: Timer = $ActionTimer
## 可攻击状态掩码：只炸僵尸（与本体炸弹同口径，僵尸全状态 63）
@onready var _can_attack: CanAttackStatusComponent = $CanAttackStatusComponent


#region 数值（模组的取值，对齐项写在文件头）
## 每次爆炸的伤害（wiki：900）
@export var bomb_damage := 900
## 引信时长（秒）：种下到第一炸
@export var fuse_time := 0.6
## 相邻两炸之间的间隔（秒）—— 必须**短于** explode 段长（1.0 秒），否则下一段会被打断重播
@export var explosion_gap := 0.28
## 第三炸到「用尽消失」之间的间隔（秒）= `Lemonade_explode3` 段长，让最后一爆播完再走
@export var finish_delay := 1.0
## 爆炸覆盖范围（宽 × 高，px）：3×3 ≈ 250×200，与本体樱桃炸弹同量级
@export var bomb_size := Vector2(250, 200)
## 爆炸中心相对植物原点的偏移（px）：与本体樱桃炸弹 `Area2DBomb` 的 (0,-25) 同思路
@export var bomb_center_offset := Vector2(0, -25)
## 弹射偏移幅度（px）：本格 ±(约 1.3 格 × 0.6 格)，只作用于第 2、3 发
@export var bounce_offset := Vector2(96, 48)
## 只炸本行 ±1 行（= 3 行，与 3×3 口径一致）
@export var bomb_lane_range := 1
#endregion

## 步进状态：0=引信，1/2=第 1/2 炸后的间隔，3=第 3 炸后的收尾
var _step := 0
## 种下时的落脚点（弹射以它为圆心）
var _home: Vector2 = Vector2.ZERO
## 全场变速（「僵尸快跑」）倍率，默认 1
var _speed := 1.0


#region 生命周期
## 初始化正常出战角色信号连接
func ready_norm_signal_connect() -> void:
	super()
	_action_timer.timeout.connect(_on_action_timer_timeout)
	## 被提前啃死就别再炸了（原版樱桃炸弹也会在被啃完前炸不出手）
	signal_character_death.connect(_on_self_death)
	## 关卡全场加速要连引信与动画一起加速
	signal_update_speed.connect(_on_update_speed)


## 初始化正常出战角色：种下即点燃引信
func ready_norm() -> void:
	super()
	_home = global_position
	_step = 0
	_play_idle()
	SoundManager.play_sfx_with_pool(FUSE_SFX.pick_random())
	## 计时时长以导出值为准（场景里的 wait_time 只是编辑器默认值）
	_action_timer.wait_time = fuse_time / _speed
	_action_timer.start()


## 初始化展示角色（图鉴 / 选卡界面里的形象）：只播待机，不点燃
func ready_show() -> void:
	super()
	_play_idle()


## 初始化花园角色
func ready_garden() -> void:
	super()
	_play_idle()
#endregion


#region 三连炸
func _on_action_timer_timeout() -> void:
	if is_death:
		return
	match _step:
		0:
			_explode(0)
		1:
			_explode(1)
		2:
			_explode(2)
		3:
			_finish()


## 炸第 index 发（0/1/2）：弹到落点 → 播爆炸段 → 范围伤害 → 装填下一步
func _explode(index: int) -> void:
	if is_death:
		return
	## 第一发固定在本格，后两发随机弹到邻近区域（弹射以本格为圆心）
	var offset := Vector2.ZERO
	if index > 0:
		offset = Vector2(randf_range(-bounce_offset.x, bounce_offset.x),
			randf_range(-bounce_offset.y, bounce_offset.y))
	global_position = _home + offset
	_anim_player.play(STATE_EXPLODES[index])
	_bomb_zombies()
	_spawn_blast()
	SoundManager.play_character_SFX(&"CherryBomb")
	_step = index + 1
	_action_timer.wait_time = (finish_delay if index >= 2 else explosion_gap) / _speed
	_action_timer.start()


## 炸开的那一下：在爆炸中心放一段「柠檬炸开」的特效（挂在自己身上，跟着弹射落点走）
func _spawn_blast() -> void:
	var fx := FX_SCRIPT.new()
	fx.position = bomb_center_offset
	add_child(fx)
	## 先入树再 setup：`play()` 离树跑不动（见 `dlc_sprite_fx.gd` 文件头）
	fx.setup(BLAST_TEXTURE, BLAST_FRAMES, BLAST_FPS)


## 用完即走：`HpComponentPlant.is_death_free` 默认 true，`character_death()` 会直接移除本株
func _finish() -> void:
	if is_death:
		return
	character_death()


## 范围伤害：以当前落脚点为中心，查一圈僵尸受击框，逐只 `be_bomb`
## （口径照抄本体 `BombComponentNorm._bomb_all_enemy`：`can_attack` 过滤 + 去重 + 行过滤）
func _bomb_zombies() -> void:
	var space := get_world_2d().direct_space_state
	var shape := RectangleShape2D.new()
	shape.size = bomb_size
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position + bomb_center_offset)
	## 只查僵尸受击检测框（`ZombieHurtBoxDetection` = 第 3 层 = 值 4）
	query.collision_mask = 4
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hits := space.intersect_shape(query, 64)
	var damaged: Array = []
	for hit in hits:
		var area := hit["collider"] as Area2D
		if area == null:
			continue
		var zombie := area.owner as Zombie000Base
		if zombie == null or not is_instance_valid(zombie) or zombie.is_death:
			continue
		## 同一只僵尸可能有两个受击框，去重
		if damaged.has(zombie):
			continue
		## 可攻击状态掩码（与本体炸弹同口径，跳过不可炸的僵尸）
		if not _can_attack.can_attack(zombie):
			continue
		## 行过滤：只炸本行上下各一行（3×3 的行口径）
		if absf(zombie.lane - lane) > bomb_lane_range:
			continue
		damaged.append(zombie)
		zombie.be_bomb(bomb_damage, true)


## 被啃死 / 其它原因死亡：停表，不再炸
func _on_self_death() -> void:
	_action_timer.stop()


## 全场加速：引信按倍率折算（与本体射手 `owner_update_speed` 同口径）
func _on_update_speed(speed_product: float) -> void:
	_speed = speed_product if speed_product > 0.0 else 1.0
	if speed_product == 0:
		_action_timer.paused = true
		_anim_player.speed_scale = 0.0
		return
	_action_timer.paused = false
	_anim_player.speed_scale = speed_product
	## 正在跑的那一步按剩余时间折算，别让一次变速把引信吞了
	if not _action_timer.is_stopped():
		_action_timer.start(_action_timer.time_left / speed_product)
#endregion


#region 动画
## 待机是循环的：已经在播就不打断（避免每帧重置动画）
func _play_idle() -> void:
	if _anim_player.current_animation == STATE_IDLE and _anim_player.is_playing():
		return
	_anim_player.play(STATE_IDLE)
#endregion
