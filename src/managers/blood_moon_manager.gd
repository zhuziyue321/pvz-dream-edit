extends MainGameSubManager
class_name BloodMoonManager
## 血月（Blood Moon）—— DLC 版第 6 章「月夜屋顶（Moon）」的旗间事件。
##
## 机制口径（DLC 官方维基 https://pvz-dlc-edition.fandom.com/wiki/Moon）：
##   "Between or during each flag, the Blood Moon event occurs, giving zombies a
##    significant boost in speed" —— 旗与旗之间 / 大波期间触发，全场僵尸大幅加速。
## 落地取舍（维基没给数值，以下为本仓库自定，改常量即可调）：
##   · 触发：**旗帜波**（每 10 波的最后一波，含最终波）开起来时触发一次；
##   · 时长 15 秒；移速 ×2（与「僵尸快跑」关的 speed_factor_zombie 同一档）；
##   · 表现：全屏红屏渐入渐出 + 血月音效 + 血月期间换环境曲。
##
## 开关：`ResourceLevelData.is_blood_moon`，由**场景**带出来（月夜屋顶场景给 true，
## 见 scene_moon_roof.gd）；关卡想单独关掉就自己写 `is_blood_moon = false`。
## 开关关着的时候本管理器一行订阅都不做（其它场景零开销）。
##
## 为什么做成主游戏子管理器而不是关卡脚本里的协程：
## 它要跨波次长期活着、要读波次信号与新生成的僵尸（zombie_created），
## 挂在主游戏下随场景一起生灭，比塞进某一关的 run_flow() 干净 —— 见 docs/参考存档/场景设置.md

## 血月期间全场僵尸的移速倍率（"significant boost"，与「僵尸快跑」关的 2 倍同档）
const SPEED_FACTOR := 2.0
## 一次血月持续多少秒
const DURATION := 15.0
## 红屏渐入 / 渐出的秒数
const FADE_TIME := 1.5
## 红屏最浓时的 alpha（再高就看不见场面了）
const MAX_ALPHA := 0.3

## 血月是否正在生效（读它就能判断「现在是不是血月」，调试窗口 / 探针都查这个）
var is_active := false

var _wave_manager: ZombieWaveManager
## 血月期间的计时器（重开一局 / 提前结束时 kill 掉，避免旧的计时器回调把新一局搞乱）
var _timer: SceneTreeTimer


func init_manager() -> void:
	if game_para == null or not game_para.is_blood_moon:
		return
	_wave_manager = main_game.zombie_manager.zombie_wave_manager
	_wave_manager.wave_started.connect(_on_wave_started)
	## 血月期间才进场的僵尸也要吃到加速（在场的那批由 start_blood_moon() 当场刷一遍）
	main_game.zombie_manager.zombie_created.connect(_on_zombie_created)


#region 触发与结束

## 旗帜波开起来 → 血月升起。波次口径见 ZombieWaveManager：每 10 波的最后一波（下标 %10==9）
## 是旗帜波，其中最后一波是最终波。
func _on_wave_started(wave: int) -> void:
	if wave % 10 != 9:
		return
	start_blood_moon()


## 开始一次血月（外部也能手动触发：调试窗口 / 探针走这里）
func start_blood_moon() -> void:
	if is_active:
		return
	is_active = true
	Log.info("血月升起（全场僵尸 ×%.1f，持续 %.0f 秒）" % [SPEED_FACTOR, DURATION])
	## 血月升起：红屏渐入 + 升起音
	EventBus.push_event(ConstEventName.CANVAS_LAYER_EFFECT_FADE, [
		CanvasLayerEffect.E_CanvasLayerEffectType.BloodMoon, MAX_ALPHA, FADE_TIME,
	])
	SoundManager.play_other_SFX(&"bloodmoon_rise")
	_apply_speed_to_all()
	## 环境曲换成血月那一条（循环），事件结束再换回本关的曲子
	_play_blood_moon_bgm()
	SoundManager.play_other_SFX(&"bloodmoon_tension")

	## process_always = false：暂停时血月跟着一起停，不让它偷偷走完
	_timer = get_tree().create_timer(DURATION, false)
	_timer.timeout.connect(end_blood_moon)


## 结束一次血月（到点自动走，也可以被重开 / 调试窗口提前叫停）
func end_blood_moon() -> void:
	if not is_active:
		return
	is_active = false
	if is_instance_valid(_timer):
		_timer.timeout.disconnect(end_blood_moon)
	_timer = null
	Log.info("血月落下")
	_restore_speed_to_all()
	EventBus.push_event(ConstEventName.CANVAS_LAYER_EFFECT_FADE, [
		CanvasLayerEffect.E_CanvasLayerEffectType.BloodMoon, 0.0, FADE_TIME,
	])
	SoundManager.play_other_SFX(&"bloodmoon_fall")
	SoundManager.play_bgm(main_game.bgm_main_game)
#endregion


#region 全场加速

## 血月期间进场的僵尸：当场补上加速（不然只有老僵尸快、新僵尸照旧走）
func _on_zombie_created(zombie: Zombie000Base) -> void:
	if not is_active:
		return
	_apply_speed(zombie)


func _apply_speed_to_all() -> void:
	for zombie: Zombie000Base in main_game.zombie_manager.all_zombies_1d:
		if is_instance_valid(zombie):
			_apply_speed(zombie)


## 走 `update_speed_factor()` 的乘积通道：只写 `BloodMoon` 这一档，
## 不碰冰冻 / 黄油 / 关卡加速那些档（与 DLC 模组血橙同一条路子，见 bloodorange_plant.gd）。
## 这一档同时驱动移动 / 啃食 / 动画（signal_update_speed），所以僵尸是整体"变急"。
func _apply_speed(zombie: Zombie000Base) -> void:
	zombie.update_speed_factor(SPEED_FACTOR, Character000Base.E_Influence_Speed_Factor.BloodMoon)


func _restore_speed_to_all() -> void:
	for zombie: Zombie000Base in main_game.zombie_manager.all_zombies_1d:
		if is_instance_valid(zombie):
			zombie.update_speed_factor(1.0, Character000Base.E_Influence_Speed_Factor.BloodMoon)
#endregion


#region 血月环境曲

## 血月期间的环境曲（bloodmoon.ogg 10.7 秒，设成循环才撑得住整个事件）
func _play_blood_moon_bgm() -> void:
	var stream := SoundManager.SFXOtherMap.get(&"bloodmoon") as AudioStreamOggVorbis
	if stream == null:
		return
	stream.loop = true
	SoundManager.play_bgm(stream)
#endregion
