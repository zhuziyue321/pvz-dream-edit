extends Plant000Base
## 光照蘑菇（DLC 的 Lume-shroom，美术资源名 GlowShroom，由模组「DLC植物」提供）
##
## ★ 玩法就一句话：**夜里的光源辅助菇** —— 白天和普通蘑菇一样睡觉，夜里醒来后散开一片光域，
##   光域里的僵尸**掉增益 + 死了掉小阳光**（wiki：their light clears zombie buffs and makes
##   them drop sun on defeat）。
##   · 掉阳光那一半见 `_on_tracked_zombie_died`；
##   · 清增益那一半见 `_clear_zombie_buffs` —— 清的是**血月事件**的加速与**血橙**炸剩下的
##     加速（wiki 说这两者是同一套 "Blood Moon effect"），靠 `is_illuminated` 让血月管理器
##     也不再给光域里的僵尸上加速（见 `blood_moon_manager.gd`）。
##     光域范围取 wiki 信息框的 `range = 5x5`（图鉴正文那句 "huge area" 是形容词，不当尺寸用）：
##     判定框 5 列 × 5 行 = 380×425 px，不再铺满全场 —— 一株只保护自己周围，不是全场免疫血月。
##
## ★ 为什么不挂 `CreateSunComponent`（向日葵 / 阳光菇那条周期自产的路）：
##   wiki 的阳光来源是「击杀掉落」而不是周期性自产，所以这里走**事件驱动** ——
##   监听光域里每只僵尸的死亡信号，死了就在原地掉一颗小阳光。
##
## ★ 数值（DLC Edition 的 wiki：Lume-shroom 页）：
##   阳光 50 / 冷却 30 秒（slow）/ 生命 300 / 范围 5x5 / 白天睡觉（Sleeps = Yes）。
##   生命 300 正好对上本体默认（plant_base 的 HpComponent.max_hp = 300，不必再改）。
##
## ★ 动画走 DLC 的 reanim → Godot 动画（animation/character/plant/GlowShroom/GlowShroom.tscn），
##   五段合成进同一条动画库 `AnimLib`：
##     · GlowShroom_idle：待机
##     · GlowShroom_sleep：白天睡觉的姿势
##     · GlowShroom_blink / GlowShroom_face：眨眼（交给 BlinkComponent / 姿态切换，本株脚本不手动播）
##     · GlowShroom_end：消亡（临时植物到点离场时由本株主动播，见 `_on_life_timer_timeout`）
##   注意：这株**没有攻击段**（不是射手 / 投手），所以库里没有 shooting 段。
##
## ⚠️ 本文件可能跑在 `user://mods/dlc/` 下：`class_name` 不会注册成全局类，
##    所以这里不写 class_name，由同目录的 plant_glowshroom.tscn 按路径引用。

@onready var _anim_player: AnimationPlayer = $Body/GlowShroomAnim/AnimLib
@onready var _detect_component: DetectComponent = $DetectComponent
## 看得见的那圈光（`LanternShine`，见场景注释）：路灯花同款 —— 星芒光带在照明区里
## 自转 + 闪烁。只在**夜里醒着**时亮（睡着 = 灯灭）
@onready var _light: GPUParticles2D = $LanternShine
## 光晕里升起的粒子（`GlowParticles`，见场景注释）：与灯同开同关。
## ⚠️ 蘑菇帽上那团小呼吸光是动画自带的 `GlowShroom_BigGlow`（待机亮 / 睡觉灭 / 离场淡出
## 全由动画自己的轨道管），脚本不碰它
@onready var _particles: GPUParticles2D = $GlowParticles


#region 数值（模组的取值；对齐 wiki 的那几项写在文件头）
## 光域里每只僵尸被击败时掉落的小阳光价值（原版小阳光 = 15）
@export var small_sun_value := 15
## 存活时长（秒）：wiki `Usage = single use` + 图鉴正文 "temporary plants" ——
## 它是一株**临时**植物：亮上一段时间就自己没了（与本体阳光菇那种长期驻场不同）。
## ⚠️ wiki **没给**具体时长，这里取**模组自定** 10 秒
@export var life_time := 10.0
#endregion


#region 动画常量
const STATE_IDLE := &"GlowShroom_idle"
const STATE_SLEEP := &"GlowShroom_sleep"
## 离场动画：reanim 里 `anim_end` 段（1.5 s），BigGlow / CapGlow 在其中淡出 ——
## 「光收掉、菇熄灭」就是这条，临时植物到点离场要播它
const STATE_END := &"GlowShroom_end"
#endregion


## 当前在光域里、且已连上死亡信号的僵尸（进去就连、离开就摘）
var _tracked_zombies: Array[Zombie000Base] = []
## 僵尸 -> 绑好的死亡回调（断开信号要用同一条 Callable，`.bind` 每次都是新的，得存下来）
var _death_conns: Dictionary = {}
## 已触发过多少次「击杀掉落」（探针 / 联机对齐用；真正生成阳光还要求场上有关卡场景）
var kill_drop_count := 0


#region 生命周期
## 初始化正常出战角色信号连接
func ready_norm_signal_connect() -> void:
	super()
	## 光域 = DetectComponent 的那块大矩形；除它自己的索敌外，再额外接一份「进 / 出」，
	## 用来维护「域内僵尸名单」，供「是不是在光域里死的」判断
	var aura_area := _detect_component.get_node_or_null("Area2D") as Area2D
	if aura_area != null:
		aura_area.area_entered.connect(_on_aura_area_entered)
		aura_area.area_exited.connect(_on_aura_area_exited)
	## 白天睡觉：进 / 出睡眠时换姿势（这株没有 AnimationTree，只能自己听信号）
	sleep_component.signal_is_sleep.connect(_on_sleep_start)
	sleep_component.signal_not_is_sleep.connect(_on_sleep_end)
	## 自己没了（被吃掉 / 临时植物到点自走 / 被铲 / 关卡退场）都要把光域摘干净：
	## 少摘一层，那只僵尸的 `illuminated_layers` 就永久 >0，从此免疫血月加速
	tree_exiting.connect(_on_self_exit)
	_anim_player.animation_finished.connect(_on_animation_finished)
	## 关卡全场加速（「僵尸快跑」）：动画一起加速
	signal_update_speed.connect(_on_update_speed)


## 初始化正常出战角色
func ready_norm() -> void:
	super()
	## `super()` 里可能已按白天进入睡眠并播了睡眠姿势 —— 别再用待机盖掉
	if not is_sleeping:
		_play_idle()
	## 灯与粒子只在出战状态亮（图鉴 / 选卡 / 花园里的形象保持关闭）
	_light.visible = not is_sleeping
	_particles.emitting = not is_sleeping
	## 临时植物：亮满 `life_time` 秒就自己走（wiki `Usage = single use`）
	_start_life_timer()


## 临时植物（wiki `Usage = single use` + 图鉴正文 "temporary plants"）：
## 出战满 `life_time` 秒后自行消失（时长 wiki 没给，取模组自定，见常量注释）。
## 计时器挂在自己身上：中途被铲 / 被吃时跟着一起没，不用额外摘。
func _start_life_timer() -> void:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = life_time
	add_child(timer)
	timer.timeout.connect(_on_life_timer_timeout)
	timer.start()


## 到点离场：先按「死亡但不消失」走完死亡流程（摘光域名单 / 停掉落 / 发死亡信号），
## 再播 DLC 的离场动画 `GlowShroom_end`（1.5 s，BigGlow / CapGlow 在里面淡出），
## 播完才真正释放 —— 见 `_on_animation_finished`。
## 睡着的时候没有光可收，硬播离场会把睡姿掰成醒姿，直接走「消失」那条。
func _on_life_timer_timeout() -> void:
	if is_death:
		return
	if is_sleeping:
		character_death_disappear()
		return
	hp_component_plant.is_death_free = false
	hp_component.hp_loss_to_death(false)
	## 灯跟着离场一起收：粒子停止补新、已有的自然飘完，灯本体淡出。
	## （蘑菇帽上那团小呼吸光不用管 —— `GlowShroom_end` 里它自己有 alpha 轨道淡出）
	_particles.emitting = false
	var fade := create_tween()
	fade.tween_property(_light, "modulate:a", 0.0, 0.6)
	_anim_player.play(STATE_END)


## 初始化展示角色（图鉴 / 选卡界面里的形象）
func ready_show() -> void:
	super()
	_play_idle()


## 初始化花园角色
func ready_garden() -> void:
	super()
	_play_idle()
#endregion


#region 光域（击杀掉落小阳光）
## 僵尸进入光域：记下它，并连上它的死亡信号（死了就掉阳光）
func _on_aura_area_entered(area: Area2D) -> void:
	var zombie := area.owner as Zombie000Base
	if zombie == null or _tracked_zombies.has(zombie):
		return
	_tracked_zombies.append(zombie)
	## 进光域：记一层光照（血月 / 血橙的加速从此不再落到它身上）+ 当场把已挂的增益清掉
	zombie.add_illuminated_layer()
	_clear_zombie_buffs(zombie)
	var cb := _on_tracked_zombie_died.bind(zombie)
	_death_conns[zombie] = cb
	if not zombie.signal_character_death.is_connected(cb):
		zombie.signal_character_death.connect(cb)


## 僵尸离开光域：摘掉名单与死亡监听
func _on_aura_area_exited(area: Area2D) -> void:
	var zombie := area.owner as Zombie000Base
	if zombie == null:
		return
	_untrack_zombie(zombie)


func _untrack_zombie(zombie: Zombie000Base) -> void:
	if not _tracked_zombies.has(zombie):
		return
	_tracked_zombies.erase(zombie)
	## 出光域 / 光域熄灭：摘掉那一层光照（血月加速重新能落到它身上）
	zombie.remove_illuminated_layer()
	var cb: Callable = _death_conns.get(zombie)
	if cb.is_valid() and zombie.signal_character_death.is_connected(cb):
		zombie.signal_character_death.disconnect(cb)
	_death_conns.erase(zombie)


## 光照清除增益（wiki："all zombies within their range lose all of their buffs"）。
## 清的两档 = 血月事件的加速 + 血橙炸剩下的加速（bloodorange_plant.gd），
## 这两者在 wiki 里是**同一套** Blood Moon effect，所以一起清。
## ⚠️ 只清"增益"：`LevelSpeed`（关卡自己的全场加速）与冰冻 / 黄油那类控制不是 buff，不动。
func _clear_zombie_buffs(zombie: Zombie000Base) -> void:
	zombie.clear_speed_factor(Character000Base.E_Influence_Speed_Factor.BloodMoon)
	zombie.clear_speed_factor(Character000Base.E_Influence_Speed_Factor.BloodOrange)


## 光域里的僵尸被击败：掉一颗小阳光（自己死了 / 正在睡觉就不掉）
func _on_tracked_zombie_died(zombie: Zombie000Base) -> void:
	if is_death or is_sleeping:
		return
	kill_drop_count += 1
	_spawn_small_sun(zombie.global_position)


## 在指定全局位置掉一颗小阳光（与 `CreateSunComponent._spawn_sun()` 同一条闸门 / 同一套 Sun 实例化）
func _spawn_small_sun(global_pos: Vector2) -> void:
	var main_game := get_main_game()
	if not is_instance_valid(main_game) or not is_instance_valid(main_game.suns):
		## 展示态（图鉴 / 卡片 / 花园）没有关卡场景，不下阳光
		return
	## 闸门被占住时（联机客户端）这一颗不产：与 `CreateSunComponent` / 天降共用同一个闸门
	if GlobalUtils.sun_spawn_gate.is_valid() and bool(GlobalUtils.sun_spawn_gate.call()):
		return
	## 与其它阳光生成点同口径：弹起来再落下 + 落点写进 Sun 之后再广播（见 `SunSpawner.pop_up`）
	SunSpawner.pop_up(main_game.suns, main_game.suns.to_local(global_pos), small_sun_value)
#endregion


#region 睡眠 / 动画回调
## 睡着：光域熄灭，掉阳光跟着停；清掉名单与监听（睡醒后重新按进入事件收集）
func _on_sleep_start() -> void:
	if is_death:
		return
	for zombie in _tracked_zombies.duplicate():
		_untrack_zombie(zombie)
	## 睡着 = 光域熄灭（画面上把光收掉，不掉阳光那半边本来就不工作）
	_light.visible = false
	_particles.emitting = false
	_play_sleep()


func _on_sleep_end() -> void:
	if is_death:
		return
	_light.visible = true
	_particles.emitting = true
	_play_idle()


## 自己退出场景树：把还记在名单里的僵尸全部摘掉（含那一层光照），见 `ready_norm_signal_connect`
func _on_self_exit() -> void:
	for zombie in _tracked_zombies.duplicate():
		_untrack_zombie(zombie)


## 一段动画播完：离场动画播完才释放；待机 / 睡眠都续上（睡着时回睡眠姿势）
func _on_animation_finished(anim_name: StringName) -> void:
	## 离场动画（1.5 s）是这株在场上最后一段：播完才真正消失
	if anim_name == STATE_END:
		queue_free()
		return
	if is_death:
		return
	if anim_name == STATE_IDLE or anim_name == STATE_SLEEP:
		if is_sleeping:
			_play_sleep()
		else:
			_play_idle()


## 待机是循环的：已经在播就不打断（避免每帧重置动画）
func _play_idle() -> void:
	if _anim_player.current_animation == STATE_IDLE and _anim_player.is_playing():
		return
	_anim_player.play(STATE_IDLE)


## 睡眠段也是循环的
func _play_sleep() -> void:
	if _anim_player.current_animation == STATE_SLEEP and _anim_player.is_playing():
		return
	_anim_player.play(STATE_SLEEP)


## 全场加速：只影响动画播放速度（这株没有攻击节奏）
func _on_update_speed(speed_product: float) -> void:
	_anim_player.speed_scale = 0.0 if speed_product == 0.0 else speed_product
#endregion
