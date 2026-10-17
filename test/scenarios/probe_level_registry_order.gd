extends RefCounted
## 探针：LevelRegistry 的冒险模式关卡顺序（存档语义的护栏）
##
## 为什么必须有这个探针：选关页的关卡按钮**硬挂在 .tscn 上**，而每关的 `level_id`
## 是按按钮在场景树里的**先后顺序**发的（choose_level.gd 的 generate_level_id），
## `save_game_name` 又由 level_id 拼出来 —— 也就是说**玩家 n 年的通关进度挂在按钮顺序上**。
## 一旦将来把选关页改成由 LevelRegistry 动态生成，只要注册表排序与现在的场景顺序差一位，
## 所有人的进度就会整体错位一格，而且**不报错、不崩溃**，只是「咦我怎么通关了没打过的关」。
##
## 所以这里把「注册表第 n 个 id 必须等于 adventure_<大关>_<小关>（n = (area-1)*10 + small）」
## 钉死：它是动态生成能落地的前提，也是存档不错位的唯一保障。
##
## 机器可读汇总：最后一行 [LVREG] result=PASS|FAIL failed=<n>

const ADVENTURE_LEVEL_TOTAL := 50
const LEVEL_PER_PAGE := 10

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针 关卡注册表顺序 ==========")
	await a.wait(2.0)

	var all_ids := LevelRegistry.ids_by_mode(MainSceneRegistry.MainScenes.ChooseLevelAdventure)
	## 测试关（*_day_test / *_pool_test / *_roof_test）也是 LevelScriptBase 子类，
	## 会被注册表一并扫进来，但它们**故意不挂选关按钮**（靠调试入口进），
	## 所以校验正式关顺序时要先剔掉，否则这里和选关页的护栏都会天天误报。
	var test_ids := all_ids.filter(func(id): return id.ends_with("_test"))
	var ids := all_ids.filter(func(id): return not id.ends_with("_test"))
	a.log("  登记总数 %d = 正式 %d + 测试 %d（测试关：%s）"
		% [all_ids.size(), ids.size(), test_ids.size(), ", ".join(test_ids)])
	_check(a, "测试关确实被登记但不进选关页（期望 3 个）", test_ids.size() == 3, str(test_ids.size()))
	_check(a, "正式冒险关 %d 关" % ADVENTURE_LEVEL_TOTAL,
		ids.size() == ADVENTURE_LEVEL_TOTAL, str(ids.size()))

	if ids.size() == ADVENTURE_LEVEL_TOTAL:
		_check(a, "第 1 个是 adventure_01_01", ids[0] == "adventure_01_01", str(ids[0]))
		_check(a, "最后一个是 adventure_05_10",
			ids[ADVENTURE_LEVEL_TOTAL - 1] == "adventure_05_10", str(ids[ADVENTURE_LEVEL_TOTAL - 1]))

		## 关键断言：第 n 关必须落在它该在的位置上（顺序 == 关卡序号）
		var mismatched: Array[String] = []
		for n in range(1, ADVENTURE_LEVEL_TOTAL + 1):
			var area := (n - 1) / LEVEL_PER_PAGE + 1
			var small := (n - 1) % LEVEL_PER_PAGE + 1
			var expected := "adventure_%02d_%02d" % [area, small]
			if ids[n - 1] != expected:
				mismatched.append("第%d位 期望%s 实际%s" % [n, expected, ids[n - 1]])
		_check(a, "第 n 个 id 严格等于 adventure_<大关>_<小关>（顺序 == 关卡序号）",
			mismatched.is_empty(), "；".join(mismatched.slice(0, 3)))

	## 每一关都要能取出实例（取不出来 = 登记了废路径）
	var broken: Array[String] = []
	for level_id in ids:
		if LevelRegistry.get_level(level_id) == null:
			broken.append(level_id)
	_check(a, "登记的关卡都能 get_level() 取出实例", broken.is_empty(), "，".join(broken.slice(0, 3)))

	## 二周目变体护栏（见 LevelRegistry.ROUND_VARIANT_SUFFIX / docs/参考存档/二周目.md）：
	## 变体只是「同一关的另一套脚本」，必须**不进** ids_by_mode ——
	## 混进来的话上面的「正式冒险关恰好 50 关」与「第 n 位 == 第 n 关」会立刻炸。
	var missing_variant: Array[String] = []
	for n in range(1, ADVENTURE_LEVEL_TOTAL + 1):
		var base_id := LevelRegistry.get_adventure_level_id(n)
		if not LevelRegistry.has_level(base_id + LevelRegistry.ROUND_VARIANT_SUFFIX):
			missing_variant.append(base_id)
	_check(a, "50 关都有自己的二周目变体脚本（adventure_XX_YY_round2）",
		missing_variant.is_empty(), "，".join(missing_variant.slice(0, 3)))
	var variant_ok: bool = (LevelRegistry.get_adventure_level_id(1, 2) == "adventure_01_01_round2"
		and LevelRegistry.get_adventure_level_id(1, 1) == "adventure_01_01")
	_check(a, "按周目取脚本：周目 2 拿变体、周目 1 拿正本", variant_ok,
		LevelRegistry.get_adventure_level_id(1, 2))
	var variant_leaked := ids.filter(func(id: String) -> bool:
		return id.ends_with(LevelRegistry.ROUND_VARIANT_SUFFIX))
	_check(a, "变体不进 ids_by_mode（不算「一关」，不占选关顺序）",
		variant_leaked.is_empty(), "，".join(variant_leaked.slice(0, 3)))

	## 序号反查：1..50 每关都要能取到「查声明用的副本」
	var no_data: Array[int] = []
	for n in range(1, ADVENTURE_LEVEL_TOTAL + 1):
		if LevelRegistry.get_adventure_level_data(n) == null:
			no_data.append(n)
	_check(a, "冒险序号 1..%d 都能反查到关卡数据" % ADVENTURE_LEVEL_TOTAL,
		no_data.is_empty(), str(no_data.slice(0, 5)))

	_finish(a)


#region 工具与断言

func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[LVREG] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()

#endregion
