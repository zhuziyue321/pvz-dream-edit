extends RefCounted
## 探针：僵尸表现层三块抽成 util 之后的行为回归（见 重构拆分方案.md 的 B5）
##
## 覆盖：
##   1. 黄油定身：be_butter → 黄油节点挂上 + 可见 + 速度因子归零
##   2. 黄油到点：计时结束后自动收起黄油并恢复速度
##   3. 黄油叠加：定身期间再被打一次不炸，仍然处于定身
##   4. 黄油解除：death_stop_butter 立刻恢复速度（死亡链路用）
##   5. 大蒜换行：update_lane 换到相邻的同类型行，并发出 signal_lane_update
##   6. 大蒜无处可换：相邻行都不是同类行时安全返回，不改 lane、不崩
##   7. 小推车碾压：be_mowered_run 走完"压扁 + 逐个掉落"后节点被回收
##
## 无头可跑：这三块都不依赖渲染，Tween / 计时器 / 节点回收在无头下一样生效。
##
## 机器可读汇总：最后一行 [ZDFX] result=PASS|FAIL failed=<n>

const LEVEL_PATH := "res://src/levels/mode_adventure/adventure_01_01.gd"
const ProbeUtil := preload("res://test/scenarios/probe_util.gd")

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE 僵尸表现层（黄油 / 大蒜换行 / 碾压） ==========")

	var para: Resource = (load(LEVEL_PATH) as GDScript).new()
	if para == null:
		a.log("!! 关卡资源加载失败: " + LEVEL_PATH)
		_finish(a)
		return
	Global.game_para = para
	a.get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.MainGameFront]
	)
	await a.wait(3.0)
	if Global.main_game == null:
		a.log("!! 主游戏未创建")
		_finish(a)
		return
	## 替玩家点「开始游戏」：小推车要在「准备-安放-植物」之前才登场，
	## 提前开战流程就停在选卡那一步了，碾压那段永远拿不到车
	await ProbeUtil.click_start(a)
	await ProbeUtil.wait_lawn_mowers(a, 20.0)
	var zm = Global.main_game.zombie_manager
	if zm == null or zm.zombie_wave_manager == null:
		a.log("!! 波次管理器不可用")
		_finish(a)
		return

	## 1-1 是教程关，第一波要等教程推进才启动，这里直接摆僵尸上场
	var creator = zm.zombie_wave_manager.zombie_wave_create_manager
	creator.wave_create_zombie(CharacterRegistry.ZombieType.Z001Norm, 0, 1)
	creator.wave_create_zombie(CharacterRegistry.ZombieType.Z001Norm, 1, 1)
	creator.wave_create_zombie(CharacterRegistry.ZombieType.Z001Norm, 2, 1)
	await a.wait(1.0)

	var all_zombie := _pick_zombies()
	a.log("场上僵尸=%d" % all_zombie.size())
	if all_zombie.size() < 3:
		_check(a, "至少摆出 3 只僵尸用于分项验证", false, "实际=%d" % all_zombie.size())
		_finish(a)
		return

	await _check_butter(a, all_zombie[0])
	await _check_garlic_lane(a, all_zombie[1])
	await _check_mower_run(a, all_zombie[2])

	_finish(a)


#region 僵尸准备

## 取当前存活的僵尸，带上行号；过滤掉列表里已释放的残留引用
func _pick_zombies() -> Array[Zombie000Base]:
	var list: Array[Zombie000Base] = []
	for z in Global.main_game.zombie_manager.all_zombies_1d:
		if is_instance_valid(z):
			list.append(z)
	return list

#endregion


#region 黄油

func _check_butter(a, z: Zombie000Base) -> void:
	a.log("-- 黄油定身 --")
	var butter_key = Character000Base.E_Influence_Speed_Factor.Butter

	z.be_butter(0.5)
	await a.frames(2)

	_check(a, "黄油节点已挂到僵尸身上", is_instance_valid(z.butter_splat))
	if not is_instance_valid(z.butter_splat):
		return
	_check(a, "黄油可见", z.butter_splat.visible)
	_check(a, "定身时速度因子为 0", z.influence_speed_factors.get(butter_key) == 0.0,
		"Butter=%s" % str(z.influence_speed_factors.get(butter_key)))

	## 定身期间再补一次黄油：计时器重置，不炸
	z.be_butter(0.5)
	await a.frames(2)
	_check(a, "叠加黄油后仍处于定身", z.influence_speed_factors.get(butter_key) == 0.0)

	await a.wait(1.2)
	_check(a, "到点后黄油自动收起", not z.butter_splat.visible)
	_check(a, "到点后速度恢复 1.0", z.influence_speed_factors.get(butter_key) == 1.0,
		"Butter=%s" % str(z.influence_speed_factors.get(butter_key)))

	## 死亡链路用的解除接口
	z.be_butter(5.0)
	await a.frames(2)
	_check(a, "再次上路后重新进入定身", z.influence_speed_factors.get(butter_key) == 0.0)
	z.death_stop_butter()
	await a.frames(2)
	_check(a, "death_stop_butter 立刻解除定身", z.influence_speed_factors.get(butter_key) == 1.0,
		"Butter=%s" % str(z.influence_speed_factors.get(butter_key)))

#endregion


#region 吃大蒜换行

func _check_garlic_lane(a, z: Zombie000Base) -> void:
	a.log("-- 大蒜换行 --")
	var rows = Global.main_game.zombie_manager.all_zombie_rows
	var lane_before: int = z.lane
	## 注意别用 func(): lane_updated = true 这种写法：GDScript 的 lambda 对外部局部变量是值捕获，
	## 改不到外面的 bool，探针会假失败。用字典当盒子才能回传
	var box := {"updated": false}
	z.signal_lane_update.connect(func(): box.updated = true)

	z.update_lane()
	await a.frames(3)
	_check(a, "换行发出 signal_lane_update", box.updated)
	_check(a, "换到相邻行", z.lane == lane_before - 1 or z.lane == lane_before + 1,
		"%d -> %d" % [lane_before, z.lane])
	_check(a, "新行类型与自身一致", rows[z.lane].zombie_row_type == z.curr_zombie_row_type)
	_check(a, "僵尸仍有效（换行没搞坏节点）", is_instance_valid(z))

	## 换到偶数 / 奇数都可能出现，位移补间跑完再验一次
	await a.wait(1.5)
	_check(a, "位移结束后僵尸仍挂在新的行节点下",
		is_instance_valid(z) and z.get_parent() == rows[z.lane],
		"parent=%s" % (str(z.get_parent().name) if is_instance_valid(z) else "已释放"))

	## 相邻行都不是同类行时：安全返回，不改 lane
	a.log("-- 大蒜无路可换 --")
	var lane_now: int = z.lane
	z.curr_zombie_row_type = CharacterRegistry.ZombieRowType.Pool
	z.update_lane()
	await a.frames(2)
	_check(a, "相邻行都不是水行时不换行", z.lane == lane_now, "%d -> %d" % [lane_now, z.lane])
	z.curr_zombie_row_type = CharacterRegistry.ZombieRowType.Land

#endregion


#region 被小推车碾压

func _check_mower_run(a, z: Zombie000Base) -> void:
	a.log("-- 小推车碾压 --")
	var gim = Global.main_game.game_item_manager.gim_lawn_mover
	if gim == null or gim.all_lawn_movers.is_empty():
		_check(a, "拿到一辆小推车", false, "gim_lawn_mover 为空")
		return
	var mower: LawnMover = null
	for m in gim.all_lawn_movers:
		if is_instance_valid(m):
			mower = m
			break
	if mower == null:
		_check(a, "拿到一辆可用的小推车", false, "列表里全是已释放对象")
		return

	z.be_mowered_run(mower)
	await a.frames(2)
	_check(a, "碾压后立刻进入死亡结算", z.is_death or not is_instance_valid(z),
		"is_death=%s" % str(z.is_death if is_instance_valid(z) else "已释放"))

	## 没有自爆节点的普通僵尸走通用表现：压扁 + 逐个掉落，播完回收节点
	await a.wait(2.5)
	_check(a, "表现播完后节点被回收", not is_instance_valid(z))

#endregion


#region 工具

func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[ZDFX] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()

#endregion
