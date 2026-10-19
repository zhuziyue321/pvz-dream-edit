extends RefCounted
## 探针：血月（Blood Moon）—— DLC 版月夜屋顶（Moon）章的旗间事件
## 用法：powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Scenario probe_blood_moon
## 覆盖：
##   1. 静态：月夜屋顶场景开血月（SceneSetting.is_blood_moon）→ 关卡参数跟着开；
##      白天屋顶场景不开；四条血月音源都已登记
##   2. 实机：月夜屋顶合成关卡里手动起一次血月，核对
##      在场僵尸吃到 ×2 / 血月期间**新生成**的僵尸也吃到 / 红屏 alpha 抬起来 /
##      结束后速度还原 + 红屏淡回 0
## 机器可读汇总：最后一行 [BLOODMOON] result=PASS|FAIL failed=<n>

const MAP_MOON := "res://data/map/map_moonroof.tres"

## 血月期间全场僵尸的移速倍率（与 BloodMoonManager.SPEED_FACTOR 对齐）
const EXPECT_SPEED_FACTOR := 2.0

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针 血月（Blood Moon） ==========")
	_check_scene_switch(a)
	_check_sfx(a)
	await _check_runtime(a)
	_finish(a)


#region 静态：场景开关与音源

func _check_scene_switch(a) -> void:
	a.log("")
	a.log("STEP1 血月开关")
	var moon := SceneSettingRegistry.get_scene(SceneSettingRegistry.SCENE_MOON_ROOF)
	_check(a, "月夜屋顶场景已登记", moon != null, str(moon))
	if moon != null:
		_check(a, "月夜屋顶场景开血月", moon.is_blood_moon, str(moon.is_blood_moon))
	var roof := SceneSettingRegistry.get_scene(SceneSettingRegistry.SCENE_ROOF)
	_check(a, "白天屋顶场景不开血月", roof != null and not roof.is_blood_moon,
		str(roof.is_blood_moon if roof != null else null))

	## 场景开关要跟着 scene_name 落到关卡参数上（ResourceLevelData.apply_scene_setting）
	var para := ResourceLevelData.new()
	_check(a, "ResourceLevelData 可实例化", para != null, str(para))
	if para == null:
		return
	_check(a, "默认关卡不开血月", not para.is_blood_moon, str(para.is_blood_moon))
	para.scene_name = SceneSettingRegistry.SCENE_MOON_ROOF
	_check(a, "套用月夜屋顶场景后关卡开血月", para.is_blood_moon, str(para.is_blood_moon))


func _check_sfx(a) -> void:
	a.log("")
	a.log("STEP2 血月音源")
	for key in [&"bloodmoon_rise", &"bloodmoon_tension", &"bloodmoon_fall", &"bloodmoon"]:
		var stream: AudioStream = SoundManager.SFXOtherMap.get(key)
		_check(a, "音源 %s 已登记" % key, stream != null, str(stream))
#endregion


#region 实机：起一次血月

## 没有为血月单开关卡：合成一份 ResourceLevelData（月夜屋顶地图 + 场景名）进主游戏，
## 手动起一次血月，核对「速度因子 / 新僵尸也吃到 / 红屏 / 还原」四件事。
func _check_runtime(a) -> void:
	a.log("")
	a.log("STEP3 实机：起一次血月")
	var para := ResourceLevelData.new()
	if para == null:
		_check(a, "ResourceLevelData 可实例化", false)
		return
	para.map_data = load(MAP_MOON)
	para.scene_name = SceneSettingRegistry.SCENE_MOON_ROOF
	Global.game_para = para
	await a.wait(1.0)
	GlobalUtils.change_scene(
		Global.main_scene_registry.get_scene_path(para.game_sences)
	)
	var waited := 0.0
	while waited < 30.0 and GameContext.curr_main_game == null:
		await a.wait(0.5)
		waited += 0.5
	var mg = GameContext.curr_main_game
	if mg == null:
		_check(a, "进入主游戏场景", false, "超时")
		return
	_check(a, "进入主游戏场景", true)
	await a.wait(1.0)

	var manager: BloodMoonManager = mg.blood_moon_manager
	_check(a, "血月管理器已装配", manager != null, str(manager))
	if manager == null:
		return
	_check(a, "开局没在血月里", not manager.is_active, str(manager.is_active))

	## 血月前先来一只僵尸，用来验证「在场的那批」会被刷到
	var zm: ZombieManager = mg.zombie_manager
	var old_zombie := _create_zombie(zm)
	_check(a, "创建了一只普通僵尸", is_instance_valid(old_zombie), str(old_zombie))
	if not is_instance_valid(old_zombie):
		return
	_check(a, "血月前僵尸没有血月加速", _factor_of(old_zombie) == 1.0, str(_factor_of(old_zombie)))

	manager.start_blood_moon()
	await a.wait(0.5)
	_check(a, "血月已生效", manager.is_active, str(manager.is_active))
	_check(a, "在场僵尸吃到血月加速", _factor_of(old_zombie) == EXPECT_SPEED_FACTOR,
		str(_factor_of(old_zombie)))
	## 血月期间**新进场**的僵尸也要吃到（靠 ZombieManager.zombie_created 补）
	var new_zombie := _create_zombie(zm)
	_check(a, "血月期间新生成的僵尸也吃到加速",
		is_instance_valid(new_zombie) and _factor_of(new_zombie) == EXPECT_SPEED_FACTOR,
		str(_factor_of(new_zombie) if is_instance_valid(new_zombie) else null))
	var panel := _blood_moon_panel(mg)
	_check(a, "红屏节点在（Panel_BloodMoon）", panel != null, str(panel))
	if panel != null:
		_check(a, "红屏已染色（alpha > 0）", panel.modulate.a > 0.0, str(panel.modulate.a))

	manager.end_blood_moon()
	await a.wait(0.5)
	_check(a, "血月已结束", not manager.is_active, str(manager.is_active))
	_check(a, "在场僵尸速度已还原", _factor_of(old_zombie) == 1.0, str(_factor_of(old_zombie)))
	if panel != null:
		## 红屏是 1.5 秒淡出，等它走完再看
		await a.wait(2.0)
		_check(a, "红屏已淡回 0", panel.modulate.a <= 0.01, str(panel.modulate.a))
#endregion


#region 小工具

func _create_zombie(zm: ZombieManager) -> Zombie000Base:
	var row_node: Node = zm.all_zombie_rows[0]
	var init_para := {
		Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
		Zombie000Base.E_ZInitAttr.Lane: 0,
		Zombie000Base.E_ZInitAttr.CurrZombieRowType: CharacterRegistry.ZombieRowType.Land,
	}
	return zm.create_norm_zombie(ZombieIds.NORM, row_node, init_para, Vector2(900, 100))


## 读一只僵尸身上「血月」那一档速度因子（没写过就是 1.0）
func _factor_of(zombie: Zombie000Base) -> float:
	var value: float = zombie.influence_speed_factors.get(
		Character000Base.E_Influence_Speed_Factor.BloodMoon, 1.0)
	return value


func _blood_moon_panel(mg) -> Panel:
	var layer: Node = mg.get_node_or_null("CanvasLayerEffect")
	if layer == null:
		return null
	return layer.get_node_or_null("Panel_BloodMoon") as Panel
#endregion


#region 断言

func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[BLOODMOON] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
