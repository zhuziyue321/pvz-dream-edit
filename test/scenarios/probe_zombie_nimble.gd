extends RefCounted
## 探针：迷你游戏第 14 关「僵尸快跑」的**全场加速**
## 覆盖：
##   ① 关卡字段 speed_factor_zombie / speed_factor_plant 真的写进关卡脚本
##   ② 僵尸进场后带上 LevelSpeed 因子（移动 / 动画一起加速），并实测 2 秒位移
##   ③ 豌豆射手进场后攻击 CD 按倍率缩短（attack_cd / 倍率，再乘植物 0.9~1.1 的随机速度）
##   ④ 对照组 adventure_01_01：倍率 1.0，攻击 CD 不缩水 —— 证明默认关卡没被改坏
## 机器可读汇总：最后一行 [NIMBLE] result=PASS|FAIL failed=<n>

const LEVEL_NIMBLE := "res://src/levels/mode_minigame/minigame_14_zombie_nimble.gd"
const LEVEL_1_1 := "res://src/levels/mode_adventure/adventure_01_01.gd"

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE 僵尸快跑（全场加速） ==========")
	await _run_one(a, "僵尸快跑", LEVEL_NIMBLE, 2.0)
	await _run_one(a, "1-1对照", LEVEL_1_1, 1.0)
	_finish(a)


func _run_one(a, title: String, level_path: String, expect: float) -> void:
	a.log("---- " + title + " (" + level_path.get_file() + ") 期望倍率=" + str(expect))
	var para: Resource = (load(level_path) as GDScript).new()
	if para == null:
		_check(a, title + ": 关卡脚本可实例化", false, level_path)
		return
	Global.game_para = para
	## 让上一关的收尾（僵尸移除、节点增删）走完再切场景，否则 remove_child 会撞上 busy
	await a.frames(3)
	a.get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[para.game_sences])
	await a.wait(3.0)

	var mg := Global.main_game
	_check(a, title + ": 已进入主游戏", mg != null, "Global.main_game 为空")
	if mg == null:
		return
	## 卡槽被系统自动填满时关卡已自己开了，重复触发会跑两遍开始流程
	if mg.main_game_progress == MainGameManager.E_MainGameProgress.CHOOSE_CARD:
		mg.choosed_card_start_game()
	await a.wait(1.5)

	## ① 关卡字段
	_check(a, title + ": speed_factor_zombie=" + str(para.speed_factor_zombie),
		is_equal_approx(para.speed_factor_zombie, expect), "实际=" + str(para.speed_factor_zombie))
	_check(a, title + ": speed_factor_plant=" + str(para.speed_factor_plant),
		is_equal_approx(para.speed_factor_plant, expect), "实际=" + str(para.speed_factor_plant))

	## ② 僵尸：LevelSpeed 因子 + 2 秒实测位移
	await _check_zombie(a, title, mg, expect)

	## ③ 植物：攻击 CD
	await _check_plant(a, title, mg, expect)


func _check_zombie(a, title: String, mg, expect: float) -> void:
	var zm: ZombieManager = mg.zombie_manager
	if zm.zombies_root.get_child_count() == 0:
		_check(a, title + ": 有僵尸行", false, "zombies_root 没有子节点")
		return
	var row_node: Node = zm.zombies_root.get_child(0)
	var init_para := {
		Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
		Zombie000Base.E_ZInitAttr.Lane: 0,
		Zombie000Base.E_ZInitAttr.CurrZombieRowType: CharacterRegistry.ZombieRowType.Land,
	}
	var z: Zombie000Base = zm.create_norm_zombie(
		CharacterRegistry.ZombieType.Z001Norm, row_node, init_para, Vector2(900, 100))
	await a.wait(0.5)
	if not is_instance_valid(z):
		_check(a, title + ": 僵尸创建成功", false, "实例无效")
		return

	var got: float = z.influence_speed_factors.get(
		Character000Base.E_Influence_Speed_Factor.LevelSpeed, 1.0)
	_check(a, title + ": 僵尸 LevelSpeed 因子=" + str(snappedf(got, 0.01)),
		is_equal_approx(got, expect), "期望=" + str(expect))

	## 移动组件接到的倍率（普僵是 Ground 模式，位置由动画驱动，curr_speed 是同一份乘积算出来的）
	var mc := z.move_component
	var ratio: float = mc.curr_speed / maxf(mc.ori_speed, 0.001)
	a.log("  [INFO] 移动组件 curr_speed=" + str(snappedf(mc.curr_speed, 0.1)) \
		+ " ori_speed=" + str(mc.ori_speed) + " 比值=" + str(snappedf(ratio, 0.01)))
	## 角色还有 0.9~1.1 的随机速度，倍率再乘它
	_check(a, title + ": 移动速度 ≈ 倍率×随机(0.9~1.1)",
		ratio >= expect * 0.88 and ratio <= expect * 1.12, "比值=" + str(snappedf(ratio, 0.01)))

	## 实测位移：僵尸往左走，2 秒内的位移量（只打印，动画驱动的值不给硬断言）
	var x0: float = z.position.x
	await a.wait(2.0)
	var moved: float = x0 - z.position.x
	a.log("  [INFO] 2 秒向左位移 = " + str(snappedf(moved, 0.1)) + " px")
	_check(a, title + ": 僵尸确实在往左走", moved > 0.0, "位移=" + str(snappedf(moved, 0.1)))
	z.character_death_disappear()


func _check_plant(a, title: String, mg, expect: float) -> void:
	var cells: Array = mg.plant_cell_manager.all_plant_cells
	if cells.is_empty() or (cells[0] as Array).is_empty():
		_check(a, title + ": 有草坪格子", false, "all_plant_cells 为空")
		return
	var cell: PlantCell = cells[0][0]
	var plant: Plant000Base = cell.create_plant(CharacterRegistry.PlantType.P001PeaShooterSingle)
	await a.wait(0.5)
	if not is_instance_valid(plant):
		_check(a, title + ": 豌豆射手种下", false, "实例无效")
		return

	var atk = plant.get_node_or_null(^"AttackComponent")
	if atk == null:
		_check(a, title + ": 攻击组件存在", false, "AttackComponent 缺失")
		return
	var cd: float = atk.attack_cd
	var wait_time: float = atk.bullet_attack_cd_timer.wait_time
	var ratio: float = cd / maxf(wait_time, 0.001)
	a.log("  [INFO] 攻击 attack_cd=" + str(cd) + " 实际 wait_time=" + str(snappedf(wait_time, 0.01)) \
		+ " 缩短到 1/" + str(snappedf(ratio, 0.01)))
	_check(a, title + ": 攻击间隔 ≈ 倍率×随机(0.9~1.1)",
		ratio >= expect * 0.88 and ratio <= expect * 1.12, "比值=" + str(snappedf(ratio, 0.01)))


#region 断言
func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label)
	else:
		_failed += 1
		a.log("  [NG] " + label + "  " + detail)


func _finish(a) -> void:
	a.log("")
	a.log("[NIMBLE] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
