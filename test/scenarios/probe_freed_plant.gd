extends RefCounted
## 临时回归探针：验证 PlantCell.get_plant() 不会把「已释放实例」交出去。
## 复现路径与历史线上报错完全一致：
##   种植 → 植物死亡消失（槽位残留已释放引用）→ 再次点同一格 create_plant()
## 修复前会在 create_plant -> get_plant 报 "Trying to return a previously freed instance"。
##
## 注意：同一个槽位有活植物时 create_plant() 会直接返回 null（不会顶替），
## 所以每次复种前必须先让上一株真正消失。

func run(a) -> void:
	await a.wait(1.0)
	var para: Resource = (load("res://src/levels/mode_adventure/adventure_01_01.gd") as GDScript).new()
	if para == null:
		a.log("[FREED] 关卡资源加载失败")
		a.finish()
		return
	Global.game_para = para
	a.get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.MainGameFront]
	)
	await a.wait(3.0)
	if Global.main_game == null:
		a.log("[FREED] !! main_game 为空")
		a.finish()
		return
	if Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.CHOOSE_CARD:
		Global.main_game.main_game_start()
	await a.wait(2.0)

	var place = CharacterRegistry.PlacePlantInCell.Norm
	var p_type = CharacterRegistry.PlantType.P001PeaShooterSingle
	var cell: PlantCell = Global.main_game.plant_cell_manager.all_plant_cells[0][0]

	## STEP1 第一次种植
	var p1 = cell.create_plant(p_type)
	a.log("[FREED] STEP1 首次种植 ok=%s" % str(is_instance_valid(p1)))
	await a.wait(0.5)

	## STEP2 让植物死亡并真正消失，槽位里留下已释放引用
	p1.character_death_disappear()
	await a.wait(0.5)
	a.log("[FREED] STEP2 已释放, 槽位内容=%s" % str(cell.plant_in_cell.get(place)))

	## STEP3 修复前：这一行在 create_plant 内部读槽位时报 previously freed instance
	var p2 = cell.create_plant(p_type)
	a.log("[FREED] STEP3 再次种植 ok=%s" % str(is_instance_valid(p2)))
	await a.wait(0.5)

	var got2 = cell.get_plant(place)
	var ok_step3 := is_instance_valid(p2) and is_instance_valid(got2) and got2 == p2
	a.log("[FREED] STEP4 get_plant valid=%s is_p2=%s" % [str(is_instance_valid(got2)), str(got2 == p2)])

	## STEP5 直接验证兜底：槽位放的是已释放对象时，get_plant 必须返回 null 并清空槽位
	p2.character_death_disappear()
	await a.wait(0.5)
	var got_freed = cell.get_plant(place)
	var ok_step5 := got_freed == null and cell.plant_in_cell.get(place) == null
	a.log("[FREED] STEP5 读已释放槽位 null=%s 槽位已清空=%s" % [
		str(got_freed == null), str(cell.plant_in_cell.get(place) == null)
	])

	## STEP6 清空后槽位必须能正常复用
	var p3 = cell.create_plant(p_type)
	await a.wait(0.5)
	var got3 = cell.get_plant(place)
	var ok_step6 := is_instance_valid(p3) and is_instance_valid(got3) and got3 == p3
	a.log("[FREED] STEP6 清空后复种 ok=%s" % str(ok_step6))

	a.log("[FREED] result=%s" % ("PASS" if (ok_step3 and ok_step5 and ok_step6) else "FAIL"))
	a.finish()
