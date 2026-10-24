extends RefCounted
## 探针：波次战力参数（出怪倍率 / 基础点数公式 / 固定出场）
##
## 为什么有这个探针：
##   `zombie_multy`（出怪倍率）是每关自定的旋钮，历史上被当成「加料」随手调 ——
##   植物僵尸两关曾因此每波出怪数是原版的 10 倍（2026-10-24 用户反馈「植物僵尸明显过多」），
##   迷你 04 / 07 / 13 / 14 / 10 / 12 也各有一份无依据的倍率。本探针把全仓关卡的
##   「倍率 + 点数公式」按**原版模式倍率表**锁死，并直接验
##   `ZombieWaveCreateManager.calculate_base_wave_points()` 的算术与排山倒海的固定出场。
##
## 原版依据（../PvZ-Portable-main/src/Lawn/Board.cpp:633-686，两份本机 C++ 参照交叉验证一致）：
##   · 基础点数四条分支：LAST_STAND `(阶段*10+波+10)*2/5+1`、生存第 2 轮起
##     `(阶段*每阶段波数+波)*2/5+1`、二周目冒险 `波*2/5+1`、默认 `波/3+1`
##   · 模式倍率：COLUMN ×6；LittleTrouble / WallnutBowling ×4；MiniBoss（冒险 1-10/2-10/3-10）
##     / StormyNight（冒险 4-10）×3；Shovel / BungeeBlitz（冒险 5-5）/ PortalCombat / Invisighoul ×2；其余 ×1
##   · COLUMN 固定出场：第 6 波扶梯×10、第 9 波玩偶匣×10、第 20 波巨人×3、第 30 波巨人×5
##
## 只做静态检查（不进关卡，不 add_child）。
## 机器可读汇总：最后一行 [WAVEPOINTS] result=PASS|FAIL failed=<n>
## 跑：godot --headless --path <项目> -- --scenario=res://test/scenarios/probe_wave_points.gd --autopilot-max-seconds=60

## 原版模式倍率表：关卡脚本路径 → 期望 zombie_multy
## 只列**非 1** 的关；没列到的关卡一律期望 1（`_check_all_levels` 的兜底扫描会查）
const C_EXPECT_MULTY: Dictionary[String, int] = {
	## ×4：Little Trouble / Wall-Nut Bowling（Board.cpp:671-674）
	"res://src/levels/mode_minigame/minigame_02_bowling.gd": 4,
	"res://src/levels/mode_minigame/minigame_10_mini_zombie.gd": 4,
	"res://src/levels/mode_minigame/minigame_18_bowling_2.gd": 4,
	"res://src/levels/mode_adventure/adventure_01_05.gd": 4,
	"res://src/levels/mode_adventure/adventure_01_05_round2.gd": 4,
	"res://src/levels/mode_adventure/adventure_03_05.gd": 4,
	"res://src/levels/mode_adventure/adventure_03_05_round2.gd": 4,
	## ×4：蹦蹦舞会是**刻意值**（蹦僵战力 4 → 非旗帜波预算整除，见关卡脚本注释），原版实际 ×1
	"res://src/levels/mode_minigame/minigame_19_pogo_party.gd": 4,
	## ×6：Column（Board.cpp:667-670）
	"res://src/levels/mode_minigame/minigame_12_column.gd": 6,
	## ×3：MiniBoss（冒险 1-10/2-10/3-10）与 StormyNight（冒险 4-10）
	"res://src/levels/mode_adventure/adventure_01_10.gd": 3,
	"res://src/levels/mode_adventure/adventure_01_10_round2.gd": 3,
	"res://src/levels/mode_adventure/adventure_02_10.gd": 3,
	"res://src/levels/mode_adventure/adventure_02_10_round2.gd": 3,
	"res://src/levels/mode_adventure/adventure_03_10.gd": 3,
	"res://src/levels/mode_adventure/adventure_03_10_round2.gd": 3,
	"res://src/levels/mode_adventure/adventure_04_10.gd": 3,
	"res://src/levels/mode_adventure/adventure_04_10_round2.gd": 3,
	## ×2：Invisighoul / PortalCombat / BungeeBlitz（Board.cpp:683-686）
	"res://src/levels/mode_minigame/minigame_06_invisi_ghoul.gd": 2,
	"res://src/levels/mode_minigame/minigame_11_portal_combat.gd": 2,
	"res://src/levels/mode_adventure/adventure_05_05.gd": 2,
	"res://src/levels/mode_adventure/adventure_05_05_round2.gd": 2,
}

## 原版基础点数公式表：关卡脚本路径 → 期望 wave_points_formula
## 只列**非 Norm** 的关：坚不可摧（LAST_STAND 分支）+ 生存 11 关（生存分支）
const C_EXPECT_FORMULA: Dictionary[String, int] = {
	"res://src/levels/mode_minigame/minigame_16_last_stand.gd":
		ConstLevelData.E_WavePointsFormula.LastStand,
	"res://src/levels/mode_survival/survival_flag_01_day.gd":
		ConstLevelData.E_WavePointsFormula.Survival,
	"res://src/levels/mode_survival/survival_flag_02_night.gd":
		ConstLevelData.E_WavePointsFormula.Survival,
	"res://src/levels/mode_survival/survival_flag_03_pool.gd":
		ConstLevelData.E_WavePointsFormula.Survival,
	"res://src/levels/mode_survival/survival_flag_04_fog.gd":
		ConstLevelData.E_WavePointsFormula.Survival,
	"res://src/levels/mode_survival/survival_flag_05_roof.gd":
		ConstLevelData.E_WavePointsFormula.Survival,
	"res://src/levels/mode_survival/survival_flag_06_day.gd":
		ConstLevelData.E_WavePointsFormula.Survival,
	"res://src/levels/mode_survival/survival_flag_07_night.gd":
		ConstLevelData.E_WavePointsFormula.Survival,
	"res://src/levels/mode_survival/survival_flag_08_pool.gd":
		ConstLevelData.E_WavePointsFormula.Survival,
	"res://src/levels/mode_survival/survival_flag_09_fog.gd":
		ConstLevelData.E_WavePointsFormula.Survival,
	"res://src/levels/mode_survival/survival_flag_10_roof.gd":
		ConstLevelData.E_WavePointsFormula.Survival,
	"res://src/levels/mode_survival/survival_flag_11_pool_endless.gd":
		ConstLevelData.E_WavePointsFormula.Survival,
}

## 排山倒海的固定出场（原版 COLUMN 分支，Board.cpp:727-759）
const COLUMN_LEVEL := "res://src/levels/mode_minigame/minigame_12_column.gd"

var _failed := 0


func run(a) -> void:
	a.log("PROBE 波次战力参数（倍率 / 点数公式 / 固定出场） 启动")
	_check_expect_tables(a)
	_check_all_levels(a)
	_check_manager_math(a)
	_check_column_fixed_zombies(a)
	a.log("")
	a.log("[WAVEPOINTS] result=%s failed=%d" % [("PASS" if _failed == 0 else "FAIL"), _failed])
	a.quit_game()


## 表里每一关都能实例化，且倍率 / 公式与期望一致
func _check_expect_tables(a) -> void:
	for path: String in C_EXPECT_MULTY:
		var para: Resource = (load(path) as GDScript).new()
		if para == null:
			_fail(a, path.get_file() + " 可实例化", path)
			continue
		_expect(a, path.get_file() + " 出怪倍率", para.zombie_multy, C_EXPECT_MULTY[path])
	for path: String in C_EXPECT_FORMULA:
		var para: Resource = (load(path) as GDScript).new()
		if para == null:
			_fail(a, path.get_file() + " 可实例化", path)
			continue
		_expect(a, path.get_file() + " 点数公式", para.wave_points_formula, C_EXPECT_FORMULA[path])


## 兜底扫描：没列进表里的关卡必须保持默认值（倍率 1 / 公式 Norm）
## 这条防的是「往某一关随手加个倍率」—— 历史上植物僵尸两关的 10 就是这么来的
func _check_all_levels(a) -> void:
	var checked := 0
	var all_paths := _find("res://src/levels")
	for path: String in all_paths:
		var para: Resource = (load(path) as GDScript).new()
		if para == null:
			continue
		checked += 1
		var want_multy: int = C_EXPECT_MULTY.get(path, 1)
		var want_formula: int = C_EXPECT_FORMULA.get(path, ConstLevelData.E_WavePointsFormula.Norm)
		if para.zombie_multy != want_multy:
			_expect(a, path.get_file() + " 出怪倍率", para.zombie_multy, want_multy)
		if para.wave_points_formula != want_formula:
			_expect(a, path.get_file() + " 点数公式", para.wave_points_formula, want_formula)
	a.log("兜底扫描覆盖 %d 个关卡脚本，倍率 / 公式全部与上表一致" % checked)
	## 扫描量下限：_find 失灵（返回空数组）时这里会 FAIL，而不是静悄悄地「全过」
	## ⚠️ _expect 两边必须同类型：GDScript 的 `bool == String` 是**运行期错误**（不是 false），
	## 而 autopilot 用 Object.call() 驱动场景脚本 —— 运行期错误只中断当前函数、还被 call 吞掉，
	## 报告照样打 PASS。这里就踩过：拿 `checked > 200`（bool）比 `str(checked)`（String）直接炸穿。
	_expect(a, "兜底扫描覆盖的关卡数（≥ 100）", checked >= 100, true)


## 管理器算术：基础点数公式三条可静态验证的分支
## （生存第 2 轮起的 `波*2/5+1` 与二周目冒险同式，但依赖 main_game.curr_game_round，
##   运行期由 probe_progress_chain / 实机覆盖，这里只验字段）
func _check_manager_math(a) -> void:
	var last_stand: Resource = (load(
		"res://src/levels/mode_minigame/minigame_16_last_stand.gd") as GDScript).new()
	var norm: Resource = ResourceLevelData.new()
	var wcm := ZombieWaveCreateManager.new()
	var zm := ZombieManager.new()
	## game_para 由关卡脚本给（ZombieManager 的成员，见 MainGameSubManager）
	zm.game_para = last_stand
	wcm.zombie_manager = zm
	## 坚不可摧：`(波+10)*2/5+1` —— 第 1 波 5 点、第 10 波 8 点、第 50 波 24 点
	_expect(a, "坚不可摧 第 1 波点数", wcm.calculate_base_wave_points(0), 5)
	_expect(a, "坚不可摧 第 10 波点数", wcm.calculate_base_wave_points(9), 8)
	_expect(a, "坚不可摧 第 50 波点数", wcm.calculate_base_wave_points(49), 24)
	## 默认（Norm）：`波/3+1` —— 第 1 波 1 点、第 10 波 4 点、第 50 波 17 点
	zm.game_para = norm
	_expect(a, "默认公式 第 1 波点数", wcm.calculate_base_wave_points(0), 1)
	_expect(a, "默认公式 第 10 波点数", wcm.calculate_base_wave_points(9), 4)
	_expect(a, "默认公式 第 50 波点数", wcm.calculate_base_wave_points(49), 17)
	## 生存第 1 轮（curr_game_round = 1）：落默认分支，与上面相同
	var survival: Resource = (load(
		"res://src/levels/mode_survival/survival_flag_01_day.gd") as GDScript).new()
	zm.game_para = survival
	_expect(a, "生存第 1 轮第 1 波走默认公式", wcm.calculate_base_wave_points(0), 1)


## 排山倒海的固定出场：第 6 波扶梯×10、第 9 波玩偶匣×10、第 20 波巨人×3、第 30 波巨人×5，其余波空
func _check_column_fixed_zombies(a) -> void:
	var level = (load(COLUMN_LEVEL) as GDScript).new()
	if level == null:
		_fail(a, "排山倒海脚本可实例化", COLUMN_LEVEL)
		return
	_expect(a, "第 6 波固定出场 = 扶梯×10",
		level.get_fixed_wave_zombies(5, false), _repeat(ZombieIds.LADDER, 10))
	_expect(a, "第 9 波固定出场 = 玩偶匣×10",
		level.get_fixed_wave_zombies(8, false), _repeat(ZombieIds.JACKBOX, 10))
	_expect(a, "第 20 波固定出场 = 巨人×3",
		level.get_fixed_wave_zombies(19, false), _repeat(ZombieIds.GARGANTUAR, 3))
	_expect(a, "第 30 波固定出场 = 巨人×5",
		level.get_fixed_wave_zombies(29, false), _repeat(ZombieIds.GARGANTUAR, 5))
	_expect(a, "第 1 波没有固定出场", level.get_fixed_wave_zombies(0, false), [])
	_expect(a, "第 10 波（旗帜波）没有固定出场", level.get_fixed_wave_zombies(9, true), [])


## GDScript 没有 `Array * int`，固定出场的期望清单在这里拼
func _repeat(zombie_type: StringName, num: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for _i in range(num):
		out.append(zombie_type)
	return out


## 无条件记一条 FAIL（用于「能不能加载」这类没有期望值的断言）
## 别拿 `_expect(a, name, false, "xxx")` 代替：GDScript 的 `bool == String` 是运行期错误
func _fail(a, name: String, detail: String = "") -> void:
	_failed += 1
	a.log("  FAIL " + name + ("  " + detail if detail != "" else ""))


func _expect(a, name: String, got, want) -> void:
	if got == want:
		a.log("  OK   " + name + " = " + str(got))
	else:
		_failed += 1
		a.log("  FAIL " + name + " = " + str(got) + "（期望 " + str(want) + "）")


## 递归找关卡脚本（判据同 LevelRegistry._scan_dir 与 probe_levels._find）
func _find(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var n := dir.get_next()
	while n != "":
		if dir.current_is_dir():
			if n == "core" or n == "script":
				n = dir.get_next()
				continue
			out.append_array(_find(dir_path + "/" + n))
		elif n.ends_with(".gd"):
			if not LevelRegistry.is_level_script(dir_path + "/" + n):
				n = dir.get_next()
				continue
			out.append(dir_path + "/" + n)
		n = dir.get_next()
	dir.list_dir_end()
	return out
