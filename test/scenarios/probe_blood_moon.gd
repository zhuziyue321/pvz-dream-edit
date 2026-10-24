extends RefCounted
## 探针：血月（Blood Moon）—— DLC 版月夜屋顶（Moon）章的旗间事件
## 用法：powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Scenario probe_blood_moon
## 覆盖：
##   1. 静态：月夜屋顶场景开血月（SceneSetting.is_blood_moon）→ 关卡参数跟着开；
##      白天屋顶场景不开；四条血月音源都已登记；**波次表**每 5 波一次（4/9/14/19…）
##   2. 实机：月夜屋顶合成关卡里手动起一次血月，核对
##      在场僵尸吃到 ×2 / 血月期间**新生成**的僵尸也吃到 / 红屏 alpha 抬起来 /
##      结束后速度还原 + 红屏淡回 0 / 底图与房门遮罩换成血月那套并换回
##   3. 光照清增益：被光照笼罩的僵尸不吃血月加速，已挂上的可被 `clear_speed_factor` 清掉
##      （DLC 的 Lume-shroom："Removes the Blood Moon and other buffs"）
##   4. 常驻形态：开 `is_blood_moon_permanent` 后开战即挂上、且**不**起自动落下的计时器
##   5. 无专属底图的场景（把 gimmick 借用到 Night 那类）退化为**底图染红**，结束还原
## 机器可读汇总：最后一行 [BLOODMOON] result=PASS|FAIL failed=<n>

const MAP_MOON := "res://data/map/map_moonroof.tres"

## 月夜屋顶的两幅底图：平时月夜、血月时才换血月那张（id 见 DLC resources.xml）
const TEX_BG_NIGHT := "res://pak/images/background6boss.jpg"
const TEX_BG_BLOOD := "res://pak/images/background6moon.png"
const TEX_MASK_NIGHT := "res://pak/images/background6_gameover_mask.png"
const TEX_MASK_BLOOD := "res://pak/images/background6moon_gameover_mask.png"

## 血月期间全场僵尸的移速倍率（与 BloodMoonManager.SPEED_FACTOR 对齐）
const EXPECT_SPEED_FACTOR := 2.0

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针 血月（Blood Moon） ==========")
	_check_scene_switch(a)
	_check_wave_table(a)
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
	## 常驻形态默认关（Moon 章是周期性的，只有 DLC 活动关 Hemophilia 才常驻）
	_check(a, "月夜屋顶不是常驻血月", not para.is_blood_moon_permanent,
		str(para.is_blood_moon_permanent))
	## 只有月夜屋顶有 DLC 的血月那幅底图，别的场景（Night 那类）走染红
	_check(a, "月夜屋顶有专属血月底图", para.is_blood_moon_bg_art, str(para.is_blood_moon_bg_art))
	if roof != null:
		_check(a, "白天屋顶没有专属血月底图", not roof.is_blood_moon_bg_art,
			str(roof.is_blood_moon_bg_art))


## 波次表：旗帜波（%10==9）与两旗正中间（%10==4）交替 = **每 5 波一次**
func _check_wave_table(a) -> void:
	a.log("")
	a.log("STEP2 血月波次表（每 5 波一次）")
	var hits: Array[int] = []
	for w in 20:
		if BloodMoonManager.is_blood_moon_wave(w):
			hits.append(w)
	_check(a, "20 波里血月落在 4/9/14/19", hits == [4, 9, 14, 19], str(hits))
	_check(a, "第 9 波（旗帜波）起血月", BloodMoonManager.is_blood_moon_wave(9))
	_check(a, "第 4 波（两旗正中间）起血月", BloodMoonManager.is_blood_moon_wave(4))
	_check(a, "第 3 波不起血月", not BloodMoonManager.is_blood_moon_wave(3))


func _check_sfx(a) -> void:
	a.log("")
	a.log("STEP3 血月音源")
	for key in [&"bloodmoon_rise", &"bloodmoon_tension", &"bloodmoon_fall", &"bloodmoon"]:
		var stream: AudioStream = SoundManager.SFXOtherMap.get(key)
		_check(a, "音源 %s 已登记" % key, stream != null, str(stream))
#endregion


#region 实机：起一次血月

## 没有为血月单开关卡：合成一份 ResourceLevelData（月夜屋顶地图 + 场景名）进主游戏，
## 手动起一次血月，核对「速度因子 / 新僵尸也吃到 / 红屏 / 还原」四件事。
func _check_runtime(a) -> void:
	a.log("")
	a.log("STEP4 实机：起一次血月")
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

	## 进关瞬间必须**看不出**血月：红屏 alpha 必须是 0、效果层必须是藏着的，
	## 否则玩家一进关就满屏红（视觉上像是血月已经在生效）
	var init_panel := _blood_moon_panel(mg)
	var init_layer := mg.get_node_or_null("CanvasLayerEffect")
	_check(a, "红屏节点在（Panel_BloodMoon）", init_panel != null, str(init_panel))
	if init_panel != null:
		_check(a, "进关时红屏是透明的（alpha=0）", init_panel.modulate.a == 0.0,
			str(init_panel.modulate.a))
	if init_layer != null:
		_check(a, "进关时效果层是藏着的", not init_layer.visible, str(init_layer.visible))
	## 进关必须是**月夜**那幅：血月那幅紫红底图要是常驻，玩家一进关就以为血月已经开了
	_check(a, "进关时底图是月夜那幅", _bg_texture_path(mg) == TEX_BG_NIGHT, _bg_texture_path(mg))
	_check(a, "进关时房门遮罩是普通那张", _mask_texture_path(mg) == TEX_MASK_NIGHT,
		_mask_texture_path(mg))

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
	## 血月一起，场景就该换成血月那套（底图 + 房门遮罩）
	_check(a, "血月时底图换成血月那幅", _bg_texture_path(mg) == TEX_BG_BLOOD, _bg_texture_path(mg))
	_check(a, "血月时房门遮罩换成血月那张", _mask_texture_path(mg) == TEX_MASK_BLOOD,
		_mask_texture_path(mg))

	manager.end_blood_moon()
	await a.wait(0.5)
	_check(a, "血月已结束", not manager.is_active, str(manager.is_active))
	_check(a, "在场僵尸速度已还原", _factor_of(old_zombie) == 1.0, str(_factor_of(old_zombie)))
	if panel != null:
		## 红屏是 1.5 秒淡出，等它走完再看
		await a.wait(2.0)
		_check(a, "红屏已淡回 0", panel.modulate.a <= 0.01, str(panel.modulate.a))
	_check(a, "血月结束后底图换回月夜那幅", _bg_texture_path(mg) == TEX_BG_NIGHT,
		_bg_texture_path(mg))
	_check(a, "血月结束后房门遮罩换回普通那张", _mask_texture_path(mg) == TEX_MASK_NIGHT,
		_mask_texture_path(mg))

	await _check_illuminated(a, mg, zm, manager)
	await _check_permanent(a, mg, manager)
	await _check_bg_tint(a, mg, manager)


## 光照清增益（DLC 的 Lume-shroom："Removes the Blood Moon and other buffs"）：
## 光域里的僵尸不吃血月加速，已经挂上的加速会被清掉，出光域后恢复正常。
func _check_illuminated(a, mg, zm: ZombieManager, manager: BloodMoonManager) -> void:
	a.log("")
	a.log("STEP5 光照清除血月增益")
	var lit := _create_zombie(zm)
	if not is_instance_valid(lit):
		_check(a, "创建了一只僵尸（光照用例）", false)
		return
	manager.start_blood_moon()
	await a.wait(0.3)
	_check(a, "血月起后僵尸吃到加速", _factor_of(lit) == EXPECT_SPEED_FACTOR, str(_factor_of(lit)))
	## 进光域 = 光照蘑菇干的两件事：记一层光照 + 把已挂的这一档清掉
	lit.add_illuminated_layer()
	lit.clear_speed_factor(Character000Base.E_Influence_Speed_Factor.BloodMoon)
	_check(a, "清增益后速度回到 1.0", _factor_of(lit) == 1.0, str(_factor_of(lit)))
	## 还在光域里：血月再起一次也不该给它加速（血月管理器跳过被照到的僵尸）
	manager.end_blood_moon()
	manager.start_blood_moon()
	await a.wait(0.3)
	_check(a, "光域里的僵尸不再吃血月加速", _factor_of(lit) == 1.0, str(_factor_of(lit)))
	## 出光域：豁免消失，重新吃到加速
	lit.remove_illuminated_layer()
	manager.end_blood_moon()
	manager.start_blood_moon()
	await a.wait(0.3)
	_check(a, "离开光域后重新吃到加速", _factor_of(lit) == EXPECT_SPEED_FACTOR, str(_factor_of(lit)))
	manager.end_blood_moon()
	await a.wait(0.3)
	_check(a, "血月已结束（光照用例收尾）", not manager.is_active, str(manager.is_active))


## 常驻形态（DLC 活动关 Hemophilia："permanent Blood Moon effect"）：开战即挂上、不自动落
func _check_permanent(a, mg, manager: BloodMoonManager) -> void:
	a.log("")
	a.log("STEP6 常驻血月")
	var para = mg.game_para
	if para == null:
		_check(a, "拿得到关卡参数", false)
		return
	para.is_blood_moon_permanent = true
	## 合成关没有流程在跑：直接发「开了一波」模拟开战（常驻形态 = 开战即挂上）
	var wm: ZombieWaveManager = mg.zombie_manager.zombie_wave_manager
	wm.wave_started.emit(0)
	await a.wait(0.3)
	_check(a, "常驻血月：开战即挂上", manager.is_active, str(manager.is_active))
	## 常驻不起计时器（周期性那 15 秒的定时器）：读私有字段只为断言，玩法不依赖它
	_check(a, "常驻血月不自动落（没有计时器）", manager._timer == null, str(manager._timer))
	manager.end_blood_moon()
	await a.wait(0.3)
	para.is_blood_moon_permanent = false
	_check(a, "常驻开关已还原", not para.is_blood_moon_permanent,
		str(para.is_blood_moon_permanent))


## 没有专属血月底图的场景（把 gimmick 借用到 Night 那类）退化为**底图染红**，结束还原
func _check_bg_tint(a, mg, manager: BloodMoonManager) -> void:
	a.log("")
	a.log("STEP7 无专属底图的场景：底图染红")
	var para = mg.game_para
	if para == null:
		_check(a, "拿得到关卡参数", false)
		return
	## 假装本关没有 DLC 的血月那幅底图（月夜屋顶是有专属图的，这里借它的场景验退化分支）
	para.is_blood_moon_bg_art = false
	manager.start_blood_moon()
	await a.wait(2.0)
	var bg: Sprite2D = mg.background_manager.background
	if not is_instance_valid(bg):
		_check(a, "拿得到底图节点", false)
		return
	_check(a, "底图已染红（绿蓝被压下去）", bg.modulate.g < 1.0 and bg.modulate.r > bg.modulate.g,
		str(bg.modulate))
	manager.end_blood_moon()
	await a.wait(2.0)
	_check(a, "底图还原成白色", bg.modulate.is_equal_approx(Color.WHITE), str(bg.modulate))
	para.is_blood_moon_bg_art = true
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


func _bg_texture_path(mg) -> String:
	var bg: Sprite2D = mg.background_manager.background
	if bg == null or bg.texture == null:
		return ""
	return bg.texture.resource_path


## 房门遮罩走 Home 的数组（MoonRoof 那一格），跟游戏里读的是同一个对象
func _mask_texture_path(mg) -> String:
	var masks: Array = mg.background_manager.home.door_masks
	var idx: int = ConstLevelData.GameBg.MoonRoof
	if idx >= masks.size():
		return ""
	var mask: Sprite2D = masks[idx]
	if mask == null or mask.texture == null:
		return ""
	return mask.texture.resource_path
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
