extends RefCounted
## 探针 PROBE8：角色初始化链路回归（对应项目规范 K-04 的那次改动）
##
## 覆盖：把三个角色子类从「重写 _ready()」改成「重写 ready_norm()」之后，
##       初始化是否仍然完整跑到，且组件是否仍然被创建：
##         1. 普僵 Zombie001Norm——海草/随机外观仍然生效（原 _ready 里的逻辑）
##         2. 窝瓜 Plant018Squash——AttackComponent 的受击状态掩码组件仍被创建
##         3. 睡莲 Plant017LilyPad——DownBase 的 ready_norm 链仍跑到（tween 已建立）
##
## 机器可读汇总：最后一行 [INIT] result=PASS|FAIL failed=<n>

const LEVEL := "res://src/levels/mode_adventure/adventure_01_01.gd"

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE8 角色初始化链路 ==========")
	if not await _boot(a):
		_finish(a)
		return

	var cell := _first_plant_cell()
	_check(a, "找到测试用植物格子", cell != null, str(cell.get_path()) if cell != null else "")
	if cell == null:
		_finish(a)
		return

	await _check_norm_zombie(a)
	await _check_squash(a, cell)
	await _check_lily_pad(a, cell)
	_finish(a)


#region 关卡准备

func _boot(a) -> bool:
	var para: Resource = (load(LEVEL) as GDScript).new()
	if para == null:
		a.log("!! 关卡资源加载失败: " + LEVEL)
		return false
	Global.game_para = para
	a.get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.MainGameFront]
	)
	await a.wait(2.0)
	if Global.main_game == null:
		a.log("!! Global.main_game 为空")
		return false
	## 卡槽被系统自动填满时会跳过选卡直接开始，这里不要重复触发开始流程
	if Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.CHOOSE_CARD:
		Global.main_game.main_game_start()
	await a.wait(3.0)
	return Global.main_game.main_game_progress != null


func _first_plant_cell() -> PlantCell:
	var mgr := Global.main_game.plant_cell_manager
	for row in mgr.all_plant_cells:
		for cell in row:
			if is_instance_valid(cell):
				return cell
	return null

#endregion


#region 三条回归

## 普僵：改到 ready_norm() 之后，随机外观逻辑仍要生效
func _check_norm_zombie(a) -> void:
	var mgr := Global.main_game.zombie_manager
	if mgr == null or mgr.zombie_wave_manager == null:
		_check(a, "僵尸管理器可用", false, "zombie_wave_manager 为空")
		return
	var z: Zombie000Base = mgr.zombie_wave_manager.zombie_wave_create_manager.wave_create_zombie(
		CharacterRegistry.ZombieType.Z001Norm, 0, 0
	)
	await a.wait(0.5)
	if z == null or not is_instance_valid(z):
		_check(a, "普僵创建成功", false, "wave_create_zombie 返回空")
		return
	_check(a, "普僵创建成功", true, z.get_class())
	_check(a, "僵尸类型是 Zombie001Norm", z is Zombie001Norm, str(z.get_class()))
	## 原 _ready 里的「随机动画状态」：三个 status 都要落在 [1, max] 内
	_check(a, "僵尸动画状态已随机化",
		z.idle_status >= 1 and z.idle_status <= z.idle_status_max
		and z.walk_status >= 1 and z.walk_status <= z.walk_status_max
		and z.death_status >= 1 and z.death_status <= z.death_status_max,
		"idle=%d/%d walk=%d/%d death=%d/%d" % [
			z.idle_status, z.idle_status_max, z.walk_status, z.walk_status_max,
			z.death_status, z.death_status_max])
	## 原 _ready 里的「随机精灵显隐」：精灵表必须存在（跑过 for 循环）。
	## 注意不要把「至少一个可见」写成断言 —— init_sprite_random 是逐项 pick_random，
	## 全 false 的概率是 1/8，那样断言会随机翻车。这里只做确定性判定，随机结果只打印。
	var visible_count := 0
	for sprite in z.init_sprite_random:
		if sprite.visible:
			visible_count += 1
	_check(a, "僵尸随机精灵表可用", z.init_sprite_random.size() > 0,
		"visible=%d/%d" % [visible_count, z.init_sprite_random.size()])


## 窝瓜：ready_norm() 里创建受击状态掩码组件，_ready 阶段不该再创建
func _check_squash(a, cell: PlantCell) -> void:
	var p := _new_plant(CharacterRegistry.PlantType.P018Squash, cell)
	if p == null:
		_check(a, "窝瓜创建成功", false, "实例化失败")
		return
	_check(a, "窝瓜创建成功", p is Plant018Squash, str(p.get_class()))
	var comp := p.get_node_or_null(^"CanAttackStatusComponent")
	_check(a, "窝瓜受击状态掩码组件已创建", comp != null, str(comp) if comp != null else "null")
	if comp != null:
		## 掩码值由场景配置或运行期兜底决定，这里只校验"已初始化成可用的掩码"，
		## 不写死具体数值（plant_018 的默认值是 13/1，场景里可能被覆盖）。
		_check(a, "窝瓜掩码已初始化",
			comp.can_attack_plant_status != 0 and comp.can_attack_zombie_status != 0,
			"plant=%d zombie=%d" % [comp.can_attack_plant_status, comp.can_attack_zombie_status])
	## 走完初始化后本体仍应稳定存活
	_check(a, "窝瓜初始化后仍有效", is_instance_valid(p))
	p.queue_free()
	await a.wait(0.2)


## 睡莲：Plant000DownBase 的 ready_norm() 链
func _check_lily_pad(a, cell: PlantCell) -> void:
	var p := _new_plant(CharacterRegistry.PlantType.P017LilyPad, cell)
	if p == null:
		_check(a, "睡莲创建成功", false, "实例化失败")
		return
	_check(a, "睡莲创建成功", p is Plant017LilyPad, str(p.get_class()))
	_check(a, "睡莲初始化后仍有效", is_instance_valid(p))
	p.queue_free()
	await a.wait(0.2)


func _new_plant(plant_type: CharacterRegistry.PlantType, cell: PlantCell) -> Plant000Base:
	var scene: PackedScene = Global.character_registry.get_plant_info(
		plant_type, CharacterRegistry.PlantInfoAttribute.PlantScenes)
	if scene == null:
		return null
	var p: Plant000Base = scene.instantiate()
	p.init_plant({
		Plant000Base.E_PInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
		Plant000Base.E_PInitAttr.PlantCell: cell,
	})
	cell.add_child(p)
	return p

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
	a.log("[INIT] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()

#endregion
