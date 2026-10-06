extends RefCounted
## 探针：僵王博士的蹦极技能只在血量低于阈值后才可用（默认 <80% 才能开始蹦极）
## 覆盖：5-10 进关 → 等博士出场 → 摆一行花盆当偷取目标 → 逐档改血量断言 can_start()：
##      满血 false、恰好等于阈值 false、刚跌破阈值 true、深残血 true、恢复满血 false。
## 机器可读汇总：最后一行 [ZOMBOSSBUNGEE] result=PASS|FAIL failed=<n>

const LEVEL_05_10 := "res://src/levels/mode_adventure/adventure_05_10.gd"
## 体检视的可用血量阈值，与 ZB001DoctorSkillBungee.bungee_hp_ratio 的默认值一致
const RATIO := 0.8

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE 僵王蹦极血量门槛 ==========")
	if not await _boot(a):
		_finish(a)
		return

	var boss = null
	var mg := Global.main_game
	for _i in 40:
		var bosses := mg.zombie_manager.get_living_bosses()
		if not bosses.is_empty():
			boss = bosses[0]
			break
		await a.wait(0.5)
	_check(a, "博士已出场", boss != null, "20 秒内没有僵王实例")
	if boss == null:
		_finish(a)
		return
	await a.wait(1.0)

	var skill = boss.get_node_or_null("Skills/BungeeSkill")
	_check(a, "取到蹦极效果组件", skill != null, "Skills/BungeeSkill 缺失")
	if skill == null:
		_finish(a)
		return
	a.log("  bungee_hp_ratio=%s" % str(skill.get("bungee_hp_ratio")))
	_check(a, "可用血量阈值配置位 0.8", is_equal_approx(float(skill.get("bungee_hp_ratio")), RATIO),
		str(skill.get("bungee_hp_ratio")))

	## 摆一行花盆：既给蹦极提供偷取目标，又不依赖关卡自带的植物
	await _plant_targets(a)
	var hp = boss.get("hp_component")
	var max_hp: int = hp.max_hp

	## 低于阈值前一定不可用
	hp.curr_hp = max_hp
	_check(a, "满血（100%）不开启蹦极", not skill.can_start(), "can_start=true")
	hp.curr_hp = int(roundi(max_hp * RATIO))
	_check(a, "恰好剩 %.0f%% 仍不开启蹦极" % (RATIO * 100.0), not skill.can_start(), "can_start=true")

	## 跌破阈值后允许使用（目标已摆好，这里同时证明「假阴性」是血量导致的、不是没目标）
	hp.curr_hp = int(roundi(max_hp * RATIO)) - 1
	_check(a, "刚跌破 %.0f%% 可以开启蹦极" % (RATIO * 100.0), skill.can_start(), "can_start=false")
	hp.curr_hp = maxi(1, int(roundi(max_hp * 0.5)))
	_check(a, "残血 50% 可以开启蹦极", skill.can_start(), "can_start=false")

	hp.curr_hp = max_hp
	_check(a, "血量回到满血后重新关闭蹦极", not skill.can_start(), "can_start=true")
	_check(a, "改血量没有把博士打死", not boss.get("is_death"), "博士已死亡")
	_finish(a)


## 进入 5-10 并跳过选卡，返回主游戏是否可用。
func _boot(a) -> bool:
	var para: Resource = (load(LEVEL_05_10) as GDScript).new()
	if para == null:
		a.log("!! 关卡资源加载失败: " + LEVEL_05_10)
		return false
	Global.game_para = para
	a.get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.MainGameRoof]
	)
	await a.wait(3.0)
	var mg := Global.main_game
	_check(a, "已进入主游戏", mg != null, "Global.main_game 为空")
	if mg == null:
		return false
	if mg.main_game_progress == MainGameManager.E_MainGameProgress.CHOOSE_CARD:
		mg.main_game_start()
	await a.wait(2.0)
	return Global.main_game != null


## 在最上一行摆满花盆，作为蹦极的偷取目标。
func _plant_targets(a) -> void:
	var mg := Global.main_game
	var grid: Array = mg.plant_cell_manager.all_plant_cells
	if grid.is_empty():
		_check(a, "取到草坪格子", false, "all_plant_cells 为空")
		return
	var planted := 0
	for cell in grid[0]:
		var plant = cell.create_plant(CharacterRegistry.PlantType.P034FlowerPot)
		if is_instance_valid(plant):
			planted += 1
	await a.wait(1.0)
	var targets := 0
	for cell in grid[0]:
		if cell.get_bungi_target() != null:
			targets += 1
	a.log("  第一行摆了花盆=%d 可作为偷取目标的格子=%d" % [planted, targets])
	_check(a, "草坪上摆出了可被偷取的植物", targets > 0, "可偷格子=%d" % targets)


#region 断言
func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label)
	else:
		_failed += 1
		a.log("  [NG] " + label + "  " + detail)


func _finish(a) -> void:
	a.log("")
	a.log("[ZOMBOSSBUNGEE] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
