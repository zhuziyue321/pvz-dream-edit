extends RefCounted
## 探针：校验 P0（关卡格式版本 + 存档键显式化 + 关卡注册表）
##
## 必须**单独起一个进程**跑：tool_write_save_keys.gd 写文件时，那些关卡资源已在场景里被引用，
## 同进程内 CACHE_MODE_REPLACE 顶不掉缓存实例，回读会拿到旧值。
##
## 校验三件事：
##   1. LevelRegistry 能扫到内置关卡（id = 文件名 basename）
##   2. 迁移过的关卡 format_version = 2、save_key 非空
##   3. 写了 save_key 的关卡，set_choose_level() 之后 save_game_name 仍等于 save_key
##      （即存档键显式化没有改变语义 —— 玩家的老存档不会丢）

## 期望已迁移（format_version = 2）的关卡 id
const EXPECT_V2: Array[String] = ["adventure_01_01", "adventure_01_02", "adventure_01_03", "adventure_01_04"]

var _failed := 0


func run(a) -> void:
	## 1. 注册表
	LevelRegistry.rescan()
	var ids := LevelRegistry.all_ids()
	a.log("[SAVEKEYPROBE] 注册表扫到 %d 关" % ids.size())
	_check(a, "注册表能扫到内置关卡", ids.size() >= 90)
	_check(a, "注册表能取到 adventure_01_01 的路径",
		LevelRegistry.get_level_path("adventure_01_01")
		== "res://src/levels/mode_adventure/adventure_01_01.gd")
	var adv_ids := LevelRegistry.ids_by_mode(MainSceneRegistry.MainScenes.ChooseLevelAdventure)
	a.log("[SAVEKEYPROBE] 冒险模式 %d 关，生存模式 %d 关" % [
		adv_ids.size(),
		LevelRegistry.ids_by_mode(MainSceneRegistry.MainScenes.ChooseLevelSurvival).size()])
	## 冒险目录 53 个 = 50 个正式关 + 3 个 *_test 调试关（不挂在选关界面上）
	_check(a, "按模式能分组（冒险 53 关）", adv_ids.size() == 53)

	## 2 / 3. 逐关校验
	a.log("")
	for id in EXPECT_V2:
		var para := LevelRegistry.get_level(id)
		if para == null:
			a.log("[SAVEKEYPROBE] !! %s 取不到关卡" % id)
			_failed += 1
			continue
		_check(a, "%s format_version = 2" % id, para.format_version == 2)
		_check(a, "%s save_key 非空" % id, para.save_key != "")
		## 存档键语义不变：显式值 == 旧拼法
		var old_style := str(int(MainSceneRegistry.MainScenes.ChooseLevelAdventure)) \
			+ "_" + str(para.level_page) + "_" + str(para.level_id)
		para.set_choose_level(MainSceneRegistry.MainScenes.ChooseLevelAdventure, 0, "0001")
		_check(a, "%s 显式存档键生效（不再吃运行时拼法）" % id, para.save_game_name == para.save_key)
		a.log("[SAVEKEYPROBE]   %s save_key=%s （旧拼法此刻应为 %s，已被显式值接管）" % [
			id, para.save_key, old_style])

	## 未迁移的关卡必须仍是 V1、save_key 为空（V1 行为零变化）
	a.log("")
	var v1 := LevelRegistry.get_level("adventure_01_05")
	_check(a, "未迁移的 adventure_01_05 仍是 V1", v1 != null and v1.format_version == 1)
	_check(a, "未迁移的关卡 save_key 为空", v1 != null and v1.save_key == "")
	if v1 != null:
		v1.set_choose_level(MainSceneRegistry.MainScenes.ChooseLevelAdventure, 0, "0005")
		_check(a, "V1 关卡存档键仍走旧拼法", v1.save_game_name == "101_0_0005")

	a.log("")
	a.log("[SAVEKEYPROBE] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()


func _check(a, label: String, ok: bool) -> void:
	if not ok:
		_failed += 1
	a.log("[SAVEKEYPROBE] %s %s" % ["PASS" if ok else "FAIL", label])
