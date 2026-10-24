extends RefCounted
## 探针：多场战斗拼接进度条
##
## 覆盖 `LevelProgressChainedBattleProvider`：
##   ① 多轮关卡（生存 5 轮）自动装上拼接数据源，不用关卡写代码
##   ② 总进度 = (已完成场次 + 本场进度/100) / 总场次 × 100（切轮连着走，不从 0 重来）
##   ③ 旗帜总数 = 每场旗数 × 场次数
##   ④ 底层「收起全部旗帜」请求被吞掉（切轮时前面几场的旗留着）
##   ⑤ 单轮关卡不受影响（段数 = 1 时与默认数据源等价）
##
## 机器可读汇总：最后一行 [PROGRESS_CHAIN] result=PASS|FAIL failed=<n>

const LEVEL := "res://src/levels/mode_survival/survival_flag_01_day.gd"

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针 多场战斗拼接进度条 ==========")

	var para = (load(LEVEL) as GDScript).new()
	if para == null:
		_check(a, "关卡脚本可实例化", false, LEVEL)
		_finish(a)
		return
	_check(a, "这是 5 轮的多场战斗关卡", para.game_round == 5, str(para.game_round))
	Global.game_para = para
	GlobalUtils.change_scene(Global.main_scene_registry.get_scene_path(para.game_sences))
	await a.wait(3.0)

	var mg = GameContext.curr_main_game
	if mg == null:
		_check(a, "已进入主游戏", false, "GameContext.curr_main_game 为空")
		_finish(a)
		return

	var controller = mg.level_progress_controller
	var provider = controller.provider if controller != null else null
	_check(a, "进度条装了拼接数据源", provider is LevelProgressChainedBattleProvider, str(provider))
	if not provider is LevelProgressChainedBattleProvider:
		_finish(a)
		return

	var zm = mg.zombie_manager
	var count: int = provider.get_battle_count()
	_check(a, "场次数 = 关卡轮数（5）", count == 5, str(count))

	var per_flags: int = zm.get_battle_flag_num()
	_check(a, "旗帜总数 = 每场旗数 × 5", provider.get_flag_num() == per_flags * 5,
		"%d × 5 = %d（每场 %d）" % [per_flags, provider.get_flag_num(), per_flags])

	## 第 1 场：总进度 = 本场进度 / 5
	mg.curr_game_round = 1
	await a.wait(0.1)
	var local: float = zm.get_battle_progress()
	var expect_1: float = local / 5.0
	_check(a, "第 1 场进度 = 本场 / 5", absf(provider.get_progress() - expect_1) < 0.05,
		"实测 %.2f 期望 %.2f（本场 %.1f）" % [provider.get_progress(), expect_1, local])

	## 第 3 场：前 2 场已完，总进度 = (2 + 本场/100) / 5
	mg.curr_game_round = 3
	await a.wait(0.1)
	local = zm.get_battle_progress()
	var expect_3: float = (2.0 + local * 0.01) / 5.0 * 100.0
	_check(a, "第 3 场进度 = (2 + 本场/100) / 5", absf(provider.get_progress() - expect_3) < 0.05,
		"实测 %.2f 期望 %.2f" % [provider.get_progress(), expect_3])
	_check(a, "切场后进度不回退到 0", provider.get_progress() >= 40.0 - 0.05,
		"实测 %.2f" % provider.get_progress())

	## 切轮时底层请求「收起全部旗帜」：拼接模式必须吞掉（前面的旗要留着）
	_check(a, "收起全部旗帜的请求被吞掉", not provider.take_flag_reset())

	## 打完最后一场 = 100%（本场进度按满算）
	mg.curr_game_round = 5
	await a.wait(0.1)
	var expected_last_max: float = (4.0 + zm.get_battle_progress() * 0.01) / 5.0 * 100.0
	_check(a, "最后一场的最大值仍按 5 等分（不会超过 100）",
		provider.get_progress() <= 100.0 + 0.01 and provider.get_progress() >= expected_last_max - 0.05,
		"实测 %.2f 期望 ≥ %.2f" % [provider.get_progress(), expected_last_max])

	## 单轮关卡：段数 = 1，与默认数据源等价
	var single := LevelProgressChainedBattleProvider.new(1)
	single.controller = controller
	mg.curr_game_round = 1
	await a.wait(0.1)
	var single_progress: float = single.get_progress()
	var local_now: float = zm.get_battle_progress()
	_check(a, "段数 = 1 时与默认口径等价", absf(single_progress - local_now) < 0.05,
		"实测 %.2f 本场 %.2f" % [single_progress, local_now])

	## 手动分段：一场战斗内部分 3 段，自己推进场次
	var manual := LevelProgressChainedBattleProvider.new(3)
	manual.controller = controller
	manual.set_curr_battle_index(1)
	var manual_progress: float = manual.get_progress()
	var expect_manual: float = (1.0 + local_now * 0.01) / 3.0 * 100.0
	_check(a, "手动分段可自己推进场次", absf(manual_progress - expect_manual) < 0.05,
		"实测 %.2f 期望 %.2f" % [manual_progress, expect_manual])
	_finish(a)


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[PROGRESS_CHAIN] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
