extends RefCounted
## 探针：僵王的踩踏与砸车只在血量低于 50% 后才可用
## 覆盖：5-10 进关 → 等博士出场 → 全场摆花盆当踩踏目标 → 逐档改血量断言 can_start()：
##      满血 false、恰好等于阈值 false、刚跌破阈值 true、深残血 true、恢复满血 false。
## 机器可读汇总：最后一行 [ZOMBOSSLOWHP] result=PASS|FAIL failed=<n>

const LEVEL_05_10 := "res://src/levels/mode_adventure/adventure_05_10.gd"
## 踩踏 / 砸车的可用血量阈值，与 StompSkill.stomp_hp_ratio、ThrowRVSkill.throw_rv_hp_ratio 一致
const RATIO := 0.5

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE 僵王残血技能（踩踏 / 砸车） ==========")
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

	var stomp = boss.get_node_or_null("Skills/StompSkill")
	var throw_rv = boss.get_node_or_null("Skills/ThrowRVSkill")
	_check(a, "取到踩踏效果组件", stomp != null, "Skills/StompSkill 缺失")
	_check(a, "取到砸车效果组件", throw_rv != null, "Skills/ThrowRVSkill 缺失")
	if stomp == null or throw_rv == null:
		_finish(a)
		return

	a.log("  stomp_hp_ratio=%s  throw_rv_hp_ratio=%s"
		% [str(stomp.get("stomp_hp_ratio")), str(throw_rv.get("throw_rv_hp_ratio"))])
	_check(a, "踩踏阈值配置为 0.5", is_equal_approx(float(stomp.get("stomp_hp_ratio")), RATIO),
		str(stomp.get("stomp_hp_ratio")))
	_check(a, "砸车阈值配置为 0.5", is_equal_approx(float(throw_rv.get("throw_rv_hp_ratio")), RATIO),
		str(throw_rv.get("throw_rv_hp_ratio")))

	## 全场摆花盆：踩踏要求区域内有植物，先摆满才测得出「是血量不给用、不是没目标」
	await _plant_targets(a)
	var hp = boss.get("hp_component")
	var max_hp: int = hp.max_hp

	## 50% 及以上：两招都不开
	hp.curr_hp = max_hp
	_check(a, "满血（100%）不踩踏", not stomp.can_start(), "can_start=true")
	_check(a, "满血（100%）不砸车", not throw_rv.can_start(), "can_start=true")
	hp.curr_hp = int(roundi(max_hp * RATIO))
	_check(a, "恰好剩 %.0f%% 仍不踩踏" % (RATIO * 100.0), not stomp.can_start(), "can_start=true")
	_check(a, "恰好剩 %.0f%% 仍不砸车" % (RATIO * 100.0), not throw_rv.can_start(), "can_start=true")

	## 跌破阈值：两招都开
	hp.curr_hp = int(roundi(max_hp * RATIO)) - 1
	_check(a, "刚跌破 %.0f%% 可以踩踏" % (RATIO * 100.0), stomp.can_start(), "can_start=false")
	_check(a, "刚跌破 %.0f%% 可以砸车" % (RATIO * 100.0), throw_rv.can_start(), "can_start=false")
	hp.curr_hp = maxi(1, int(roundi(max_hp * 0.25)))
	_check(a, "残血 25% 可以踩踏", stomp.can_start(), "can_start=false")
	_check(a, "残血 25% 可以砸车", throw_rv.can_start(), "can_start=false")

	## 血量回满后重新关闭（血量是每轮实时读的，不会锁死）
	hp.curr_hp = max_hp
	_check(a, "回到满血后重新关闭踩踏", not stomp.can_start(), "can_start=true")
	_check(a, "回到满血后重新关闭砸车", not throw_rv.can_start(), "can_start=true")
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


## 全场摆花盆，保证任一条踩踏区域里都有植物（踩踏候选要求区域内有存活植物）。
func _plant_targets(a) -> void:
	var mg := Global.main_game
	var grid: Array = mg.plant_cell_manager.all_plant_cells
	if grid.is_empty():
		_check(a, "取到草坪格子", false, "all_plant_cells 为空")
		return
	var planted := 0
	for row: Array in grid:
		for cell in row:
			var plant = cell.create_plant(CharacterRegistry.PlantType.P034FlowerPot)
			if is_instance_valid(plant):
				planted += 1
	await a.wait(1.0)
	a.log("  全场摆花盆=%d" % planted)
	_check(a, "草坪上摆出了可被踩踏的植物", planted > 0, "花盆=%d" % planted)


#region 断言
func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label)
	else:
		_failed += 1
		a.log("  [NG] " + label + "  " + detail)


func _finish(a) -> void:
	a.log("")
	a.log("[ZOMBOSSLOWHP] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
