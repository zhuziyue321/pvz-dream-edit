extends MainGameSubManager
class_name BloodMoonManager
## 血月（Blood Moon）—— DLC 版 Moon 章的关卡级 gimmick（Halloween 活动关把同一套借用到 Night 上）。
##
## 机制口径（DLC 官方维基 https://pvz-dlc-edition.fandom.com/wiki/Moon）：
##   "Between or during each flag, the Blood Moon event occurs, giving zombies a
##    significant boost in speed" —— 旗与旗之间 / 大波期间触发，全场僵尸大幅加速。
##   落到波次上（波次口径见 ZombieWaveManager：每 10 波一面旗，旗帜波下标 %10==9）：
##     · "during  each flag" = 旗帜波本身           → wave % 10 == 9
##     · "between each flag" = 两面旗的正中间       → wave % 10 == 4
##   两者交替，合起来就是**每 5 波一次**（`(wave + 1) % 5 == 0`：4 / 9 / 14 / 19 …）。
## 另有**常驻**形态：DLC 活动关 Hemophilia "permanent Blood Moon effect"
##   （<https://pvz-dlc-edition.fandom.com/wiki/Hemophilia>）—— `is_blood_moon_permanent`。
##
## 落地取舍（维基没给数值，以下为本仓库自定，改常量即可调）：
##   · 时长 15 秒；移速 ×2（与「僵尸快跑」关的 speed_factor_zombie 同一档）；
##   · 表现：全屏红屏渐入渐出 + 血月音效 + 血月期间换环境曲。
##
## 影响范围：走 `update_speed_factor()` 的**乘积**通道，`signal_update_speed` 同时驱动
##   移动（MoveComponent）/ 啃食（AttackComponent）/ 动画（AnimComponent），
##   所以僵尸是**整体变急**而不只是走得快 —— 与 wiki 的 "boost in speed" 一致。
##
## 开关：`ResourceLevelData.is_blood_moon`，由**场景**带出来（月夜屋顶场景给 true，
## 见 scene_moon_roof.gd）；关卡想单独开 / 关就自己写这两个字段。
## 开关关着的时候本管理器一行订阅都不做（其它场景零开销）。
##
## 为什么做成主游戏子管理器而不是关卡脚本里的协程：
## 它要跨波次长期活着、要读波次信号与新生成的僵尸（zombie_created），
## 挂在主游戏下随场景一起生灭，比塞进某一关的 run_flow() 干净 —— 见 docs/参考存档/场景设置.md

## 血月期间全场僵尸的移速倍率（"significant boost"，与「僵尸快跑」关的 2 倍同档）
const SPEED_FACTOR := 2.0
## 一次血月持续多少秒（**常驻模式不走这个计时器**）
const DURATION := 15.0
## 红屏渐入 / 渐出的秒数
const FADE_TIME := 1.5
## 红屏最浓时的 alpha（再高就看不见场面了）
const MAX_ALPHA := 0.3
## 旗间隔：每 10 波一面旗（与 ZombieWaveManager 的 `% 10 == 9` 同一口径）
const FLAG_INTERVAL := 10
## 血月触发节奏：**每 5 波一次** —— 旗帜波（%10==9）与两旗正中间（%10==4）交替，
## 就是旗间隔的一半；波次号从 0 起算，故判据写成 `(wave + 1) % WAVE_INTERVAL == 0`
@warning_ignore("integer_division")
const WAVE_INTERVAL := FLAG_INTERVAL / 2
## 没有专属血月底图的场景（Night 那类）的退化表现：底图染红（压绿蓝 = 泛红，乘色）
const BG_TINT := Color(1.0, 0.72, 0.72)

## 血月是否正在生效（读它就能判断「现在是不是血月」，调试窗口 / 探针都查这个）
var is_active := false

var _wave_manager: ZombieWaveManager
## 血月期间的计时器（重开一局 / 提前结束时 kill 掉，避免旧的计时器回调把新一局搞乱）
var _timer: SceneTreeTimer
## 底图染色的渐变（无专属底图的场景才有；起落反复时要先杀掉上一条）
var _bg_tween: Tween


func init_manager() -> void:
	if game_para == null or not game_para.is_blood_moon:
		return
	_wave_manager = main_game.zombie_manager.zombie_wave_manager
	_wave_manager.wave_started.connect(_on_wave_started)
	## 血月期间才进场的僵尸也要吃到加速（在场的那批由 start_blood_moon() 当场刷一遍）
	main_game.zombie_manager.zombie_created.connect(_on_zombie_created)


#region 触发与结束

## 这一波是不是血月波：**每 5 波一次**（旗帜波 + 两旗正中间交替，见类注释）。
## 做成静态是为了让探针不必起一整关就能验算波次表。
static func is_blood_moon_wave(wave: int) -> bool:
	return (wave + 1) % WAVE_INTERVAL == 0


func _on_wave_started(wave: int) -> void:
	## 常驻：开战（第一波）就挂上，之后每波再确认一次（被调试窗口提前结束也能自己补回来）
	if game_para != null and game_para.is_blood_moon_permanent:
		start_blood_moon()
		return
	if is_blood_moon_wave(wave):
		start_blood_moon()


## 开始一次血月（外部也能手动触发：调试窗口 / 探针走这里）
func start_blood_moon() -> void:
	if is_active:
		return
	is_active = true
	Log.info("血月升起（全场僵尸 ×%.1f，%s）" % [
		SPEED_FACTOR, "常驻" if _is_permanent() else "持续 %.0f 秒" % DURATION,
	])
	## 血月升起：红屏渐入 + 升起音
	EventBus.push_event(ConstEventName.CANVAS_LAYER_EFFECT_FADE, [
		CanvasLayerEffect.E_CanvasLayerEffectType.BloodMoon, MAX_ALPHA, FADE_TIME,
	])
	_set_visual(true)
	SoundManager.play_other_SFX(&"bloodmoon_rise")
	_apply_speed_to_all()
	## 环境曲换成血月那一条（循环），事件结束再换回本关的曲子
	_play_blood_moon_bgm()
	SoundManager.play_other_SFX(&"bloodmoon_tension")

	## 常驻形态不落（没有"落下"这一说），自然也就不起计时器
	if _is_permanent():
		return
	## process_always = false：暂停时血月跟着一起停，不让它偷偷走完
	_timer = get_tree().create_timer(DURATION, false)
	_timer.timeout.connect(end_blood_moon)


## 结束一次血月（到点自动走，也可以被重开 / 调试窗口提前叫停）
## ⚠️ 常驻形态下这只是**临时**落下：下一波开起来会被重新挂上（见 _on_wave_started）。
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
	_set_visual(false)
	SoundManager.play_other_SFX(&"bloodmoon_fall")
	SoundManager.play_bgm(main_game.bgm_main_game)


## 本关是不是常驻血月
func _is_permanent() -> bool:
	return game_para != null and game_para.is_blood_moon_permanent
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
##
## ⚠️ **光域里的僵尸不吃这一档**：DLC 的 Lume-shroom 会清掉它（wiki "Removes the Blood Moon
## and other buffs"），本仓的等价做法是被光照笼罩的僵尸（`is_illuminated`）压根不上加速，
## 已经上了的由光照蘑菇自己调 `clear_speed_factor()` 清掉 —— 两边合起来才是"清除"。
func _apply_speed(zombie: Zombie000Base) -> void:
	if zombie.is_illuminated:
		return
	zombie.update_speed_factor(SPEED_FACTOR, Character000Base.E_Influence_Speed_Factor.BloodMoon)


func _restore_speed_to_all() -> void:
	for zombie: Zombie000Base in main_game.zombie_manager.all_zombies_1d:
		if is_instance_valid(zombie):
			zombie.update_speed_factor(1.0, Character000Base.E_Influence_Speed_Factor.BloodMoon)
#endregion


#region 表现（换图 / 染红）

## 血月的视觉切换：① 广播 `BLOOD_MOON_VISUAL`（有专属底图的场景自己换图，现在只有月夜屋顶）；
## ② 没有专属底图的场景（如把 gimmick 借用到 Night 上）退而求其次把底图染红。
func _set_visual(is_on: bool) -> void:
	EventBus.push_event(ConstEventName.BLOOD_MOON_VISUAL, [is_on])
	_tint_background(is_on)


## 底图染红（无专属血月底图的场景用）：只是把底图乘一层红，结束还原成白色。
## 全屏红屏（`Panel_BloodMoon`）是**所有场景**都有的那一层，不在这里管。
func _tint_background(is_on: bool) -> void:
	## 月夜屋顶有 DLC 的血月那幅底图，换图已经够红了，再叠一层染色会红到看不见场面
	if game_para != null and game_para.is_blood_moon_bg_art:
		return
	var bg: Sprite2D = main_game.background_manager.background
	if not is_instance_valid(bg):
		return
	## 上一次的渐变可能还没走完（血月被反复起落 / 提前结束）：先杀掉再起新的，
	## 否则两条 tween 抢同一个 `modulate`，底图会停在中间某个颜色上
	if is_instance_valid(_bg_tween):
		_bg_tween.kill()
	_bg_tween = bg.create_tween()
	_bg_tween.tween_property(bg, "modulate", BG_TINT if is_on else Color.WHITE, FADE_TIME)
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
