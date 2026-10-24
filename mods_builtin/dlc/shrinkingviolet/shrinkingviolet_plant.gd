extends Plant000Base
## 缩小紫罗兰（DLC 的 Shrinking Violet，由模组「DLC植物」提供）
##
## ★ 玩法就一句话：**一次性「绽放 → 缩小全场僵尸 → 自身消失」** —— 种下后立刻绽放，
##   把场上所有僵尸缩小（视觉变小 + 啃咬伤害降低），持续若干秒后僵尸自行恢复，
##   而紫罗兰自己绽放完就被消耗掉（与寒冰菇 / 樱桃炸弹同一类「一次即走」的植物）。
##
## ★ 为什么不用 `AttackComponentBulletBase` / `BombComponent` 那一套：
##   本株没有子弹、也没有「范围爆炸」，它的效果是「对所有僵尸挂一个控制状态」。
##   本体已有现成的同类机制 —— 寒冰菇的 `ZombieManager.ice_all_zombie()`：
##   遍历 `all_zombies_2d` 对每只僵尸调一个 `be_xxx()`。这里照它写一个
##   `ZombieManager.shrink_all_zombie()`，本脚本在绽放那一刻直接调它。
##   （缩小状态挂在**僵尸**身上，紫罗兰自身随即消失也不影响效果，与寒冰菇同理。）
##
## ★ 动画走 DLC 的 reanim → Godot 动画（`animation/character/plant/ShrinkingViolet/ShrinkingViolet.tscn`），
##   本株只用两段，合成进同一条动画库 `AnimLib`：
##     · `ShrinkingViolet_idle`（1.667 秒）：展示态（图鉴 / 选卡）的待机
##     · `ShrinkingViolet_bloom`（4.083 秒）：种下后的一次性绽放，播完即消耗
##   （`idle_almanac` 段本株不用，交给图鉴自己的待机口径）
##
## ★ 数值都是**模组自己的取值**（对齐项写在常量注释里），别照 wiki 再改别的。
##
## ⚠️ 本文件可能跑在 `user://mods/dlc/` 下：`class_name` 不会注册成全局类，
##    所以这里不写 class_name，由同目录的 `plant_shrinkingviolet.tscn` 按路径引用。

@onready var _anim_player: AnimationPlayer = $Body/ShrinkingVioletAnim/AnimLib


#region 数值（对齐 DLC Edition wiki 的 Shrinking Violet 页：100 阳光 / 冷却 30 秒 slow /
## 射程 3×3 / 一次性；「缩小持续多久、缩到多小」wiki 没给，取模组自定）
## 缩小持续时长（秒）：僵尸缩小多久后自行恢复
@export var shrink_duration := 5.0
## 缩小比例（<1）：0.5 = 僵尸缩到原来一半大
@export var shrink_scale := 0.5
## 缩小期间啃咬伤害倍率（<1）：0.5 = 啃咬伤害减半
@export var shrink_damage_factor := 0.5
## 射程（wiki `range = 3x3`）：只影响**本行与上下各一行**、左右各约一格半 ——
## 一格 ≈ 76 px，故横向半宽取 114 px
const SHRINK_LANE_RANGE := 1
const SHRINK_HALF_WIDTH := 114.0
#endregion


#region 动画常量
const STATE_IDLE := &"ShrinkingViolet_idle"
const STATE_BLOOM := &"ShrinkingViolet_bloom"
#endregion


#region 施法波与音效
## 绽放音效：DLC 自己的 `shrinkingviolet.ogg`（这株原本一个音效都没有）
const BLOOM_SFX: AudioStream = preload("../audio/shrinkingviolet.ogg")
## 施法波（`shrinkingviolet_wave.png`：横向 6 帧、单帧 128×128，由小到大扩散淡出）。
## 原来只有自己绽放，僵尸是缩小了、但场上没有「波」铺过去的过程
const FX_SCRIPT := preload("../dlc_sprite_fx.gd")
const WAVE_TEXTURE := preload("shrinkingviolet_wave.png")
const WAVE_FRAMES := 6
const WAVE_FPS := 12.0
## 单帧 128×128，放大 6 倍 ≈ 768 px —— 与「向全场铺开」的观感同量级
const WAVE_SCALE := 6.0
## 波心落在植物胸口（植物本地坐标）
const WAVE_POSITION := Vector2(0, -25)
#endregion


#region 生命周期
## 初始化正常出战角色信号连接
func ready_norm_signal_connect() -> void:
	super()
	_anim_player.animation_finished.connect(_on_animation_finished)


## 初始化正常出战角色：**种下即绽放**，绽放那一刻缩小全场僵尸
func ready_norm() -> void:
	super()
	_start_bloom()


## 初始化展示角色（图鉴 / 选卡界面里的形象）：只待机，不绽放
func ready_show() -> void:
	super()
	_play_idle()


## 初始化花园角色：只待机
func ready_garden() -> void:
	super()
	_play_idle()
#endregion


#region 绽放 / 缩小
## 绽放一次：播 `bloom`（单次），同一刻把全场僵尸缩小，并从身上铺开一圈施法波
func _start_bloom() -> void:
	if is_death:
		return
	_anim_player.play(STATE_BLOOM)
	SoundManager.play_sfx_with_pool(BLOOM_SFX)
	## 施法期间无敌（wiki：`She is also completely invulnerable while using this ability`）
	_make_invulnerable()
	_spawn_wave()
	_shrink_zombies_in_range()


## 铺开施法波（挂在自己身上：这株绽放完就消失，波正好跟着一起走）
func _spawn_wave() -> void:
	var fx := FX_SCRIPT.new()
	fx.position = WAVE_POSITION
	fx.scale = Vector2(WAVE_SCALE, WAVE_SCALE)
	add_child(fx)
	## 先入树再 setup：`play()` 离树跑不动（见 `dlc_sprite_fx.gd` 文件头）
	fx.setup(WAVE_TEXTURE, WAVE_FRAMES, WAVE_FPS)


## 缩小 3×3 范围内的僵尸（wiki `range = 3x3`）。
##
## 本体只有「全场缩小」那条 `shrink_all_zombie()`，够不上 3×3，所以这里自己筛一遍：
## 行差 ≤ `SHRINK_LANE_RANGE`、横向距离 ≤ `SHRINK_HALF_WIDTH`，命中的逐个 `be_shrink()`
## （与全场那条路子最终调的是同一个方法，参数语义也一致）。
func _shrink_zombies_in_range() -> void:
	var main_game := get_main_game()
	if not is_instance_valid(main_game) or not is_instance_valid(main_game.zombie_manager):
		return
	for zombie in main_game.zombie_manager.all_zombies_1d:
		if not is_instance_valid(zombie) or zombie.is_death:
			continue
		if absi(zombie.lane - lane) > SHRINK_LANE_RANGE:
			continue
		if absf(zombie.global_position.x - global_position.x) > SHRINK_HALF_WIDTH:
			continue
		zombie.be_shrink(shrink_duration, shrink_scale, shrink_damage_factor)


## 施法期间**无敌**：wiki 写明「绽放时完全无敌」，本体没有 `is_invincible` 这类标记，
## 这里照组件化的通用做法 —— 把受击框按 `Character` 因子禁用，僵尸就啃不到它。
## 绽放完这株直接消失，所以不用再启用回来。
func _make_invulnerable() -> void:
	if is_instance_valid(hurt_box_component):
		hurt_box_component.disable_component(ComponentNormBase.E_IsEnableFactor.Character)
#endregion


#region 动画回调
## 一段动画播完：`bloom` 播完 → 自身被消耗掉（一次即走，与寒冰菇 / 樱桃同类）
func _on_animation_finished(anim_name: StringName) -> void:
	if is_death:
		return
	if anim_name == STATE_BLOOM:
		## 直接消失（不走死亡演出）；缩小状态已挂在僵尸身上，紫罗兰自身消失不影响效果。
		## `character_death_disappear()` 内部经 `hp_loss_to_death()` → `signal_character_death`
		## 让格子正常释放，不需要在这里再单独清理种植格。
		character_death_disappear()


## 待机是循环的：已经在播就不打断（避免每帧重置动画）
func _play_idle() -> void:
	if _anim_player.current_animation == STATE_IDLE and _anim_player.is_playing():
		return
	_anim_player.play(STATE_IDLE)
#endregion
