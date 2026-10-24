extends RefCounted
## 探针：校验关卡存档键显式化（P0：关卡注册表 + save_key 写死）
##
## 必须**单独起一个进程**跑：tool_write_save_keys.gd 写文件时，那些关卡资源已在场景里被引用，
## 同进程内 CACHE_MODE_REPLACE 顶不掉缓存实例，回读会拿到旧值。
##
## 校验三件事：
##   1. LevelRegistry 能扫到内置关卡（id = 文件名 basename）
##   2. 每关都写死了 save_key（不再依赖选关场景的遍历顺序）
##   3. **写死的值 == 运行时原本拼出来的值**（存档键显式化没有改变语义 —— 玩家的老存档不会丢）：
##      · 冒险模式：与权威式子 `GlobalGameState.get_adventure_save_game_name(序号)` 比对；
##      · 有选关界面的 3 个模式：**真跑一遍选关场景**，拿按钮上的 page / level_id 重走一次「旧拼法」再比对
##        （见 _check_scene_modes：拿一个干净副本、清掉 save_key 逼它走旧拼法）。
##
## ⚠️ **「写死值 == 当前遍历顺序拼出来的值」只对部分模式成立，别 generalize**：
##   迷你 / 解密两模式的存档键是**早就写死的**，而选关场景的按钮遍历顺序后来变过
##   （2026-10 的几轮改动），于是「现在拼出来的值」与「写死的值」对不上 ——
##   **对不上时写死值才是权威**：它固化的是玩家存档文件里真正在用的那个键，
##   拿当前拼法去「纠正」它等于把玩家的通关进度整体挪位（U-22 担心的正是这件事）。
##   所以这两个模式只校验「save_key 非空」，差异记 INFO；**只有生存模式**做严格比对
##   （它的键是本工具按当前拼法刚写死的，二者必须相等）。
##
## ⚠️ **只校验 save_key，不管 format_version** —— 后者是「字段怎么读」的开关，属行为变更，
##    要单独评测（见 docs/TODO清单.md 的 U-22 第 ④ 条）。

const ADVENTURE := MainSceneRegistry.MainScenes.ChooseLevelAdventure

## 有选关界面的 3 个模式；冒险模式没有选关界面，走 _check_adventure()
const SCENE_MODES := [
	MainSceneRegistry.MainScenes.ChooseLevelMiniGame,
	MainSceneRegistry.MainScenes.ChooseLevelPuzzle,
	MainSceneRegistry.MainScenes.ChooseLevelSurvival,
]

## 这几个模式做「写死值 == 当前拼法」的严格比对（理由见文件头）
const STRICT_COMPARE_MODES := [
	MainSceneRegistry.MainScenes.ChooseLevelSurvival,
]

var _failed := 0
## 全部写死的存档键：用来查「两关撞了同一个键」（撞了就是进度互相覆盖）
var _seen_keys: Dictionary = {}
## 「写死值 != 当前遍历顺序拼法」的关数（迷你 / 解密的既有差异，只统计不判失败）
var _diff_count := 0


func run(a) -> void:
	## 1. 注册表
	LevelRegistry.rescan()
	var ids := LevelRegistry.all_ids()
	a.log("[SAVEKEYPROBE] 注册表扫到 %d 关" % ids.size())
	_check(a, "注册表能扫到内置关卡", ids.size() >= 90)
	_check(a, "注册表能取到 adventure_01_01 的路径",
		LevelRegistry.get_level_path("adventure_01_01")
		== "res://src/levels/mode_adventure/adventure_01_01.gd")
	var adv_ids := LevelRegistry.ids_by_mode(ADVENTURE)
	a.log("[SAVEKEYPROBE] 冒险模式 %d 关，生存模式 %d 关" % [
		adv_ids.size(),
		LevelRegistry.ids_by_mode(MainSceneRegistry.MainScenes.ChooseLevelSurvival).size()])
	## 冒险目录 53 个 = 50 个正式关 + 3 个 *_test 调试关（不挂在选关界面上）
	_check(a, "按模式能分组（冒险 53 关）", adv_ids.size() == 53)

	## 2 / 3a. 冒险模式：与权威式子比对
	a.log("")
	_check_adventure(a)

	## 3b. 有选关界面的模式：真跑一遍选关场景，按按钮上的 page / level_id 重拼一次旧拼法
	for mode in SCENE_MODES:
		await _check_scene_mode(a, mode)

	## 4. 唯一性：任何两关不能撞同一个存档键
	a.log("")
	for key in _seen_keys.keys():
		var owners: Array = _seen_keys[key]
		if owners.size() > 1:
			_check(a, "存档键唯一（%s 被 %s 共用）" % [key, str(owners)], false)
	a.log("[SAVEKEYPROBE] 共收集 %d 个存档键" % _seen_keys.size())
	if _diff_count > 0:
		a.log("[SAVEKEYPROBE] INFO %d 关的写死存档键与「当前遍历顺序拼出的值」不一致 —— 属既有事实，" % _diff_count)
		a.log("[SAVEKEYPROBE] INFO 写死值才是权威（玩家存档用的就是它），**不要**拿当前拼法去纠正它")

	## format_version 只打印不判定（单独评测，见文件头）
	var v2_count := 0
	for id in LevelRegistry.all_ids():
		var para := LevelRegistry.get_level(id)
		if para != null and para.format_version == 2:
			v2_count += 1
	a.log("[SAVEKEYPROBE] format_version=2 的关卡 %d 关（本探针不判定）" % v2_count)

	a.log("")
	a.log("[SAVEKEYPROBE] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()


## 冒险模式：存档键 = 关卡序号的那条式子（与运行时同源，见 GlobalGameState.get_adventure_save_game_name）
func _check_adventure(a) -> void:
	for id in LevelRegistry.ids_by_mode(ADVENTURE):
		var adventure_level := LevelRegistry._parse_adventure_level(id)
		if adventure_level <= 0:
			## 不是 adventure_<大关>_<小关>（*_test 调试关 / 辅助关），不参与存档
			continue
		var want := Global.global_game_state.get_adventure_save_game_name(adventure_level)
		_check_one(a, id, want)
		## 二周目变体只是换个脚本，存档键与正本同一份（见 LevelRegistry.ROUND_VARIANT_SUFFIX）
		## ⚠️ 因此**不参与下面的唯一性查重**（二周目靠记录里的 "Round" 区分，键本来就该相同）
		var variant_id := id + LevelRegistry.ROUND_VARIANT_SUFFIX
		if LevelRegistry.get_level_path(variant_id) != "":
			var v := LevelRegistry.get_level(variant_id)
			_check(a, "%s save_key == %s" % [variant_id, want], v != null and v.save_key == want)


func _check_one(a, id: String, want: String) -> void:
	var para := LevelRegistry.get_level(id)
	_check(a, "%s save_key == %s" % [id, want], para != null and para.save_key == want)
	_remember(id, para.save_key if para != null else "")


## 记一个存档键的归属（查重）
func _remember(id: String, key: String) -> void:
	if key == "":
		return
	if not _seen_keys.has(key):
		_seen_keys[key] = []
	_seen_keys[key].append(id)


## 有选关界面的模式：写死值必须等于「没有 save_key 时运行时拼出来的那个值」
func _check_scene_mode(a, mode) -> void:
	var path: String = Global.main_scene_registry.get_scene_path(mode)
	GlobalUtils.change_scene(path)
	await a.wait(2.0)
	var root: Node = a.get_tree().current_scene
	if root == null:
		_check(a, "选关场景能起来 " + path, false)
		return
	var n := 0
	for node in _walk(root):
		if not (node is ChooseLevelButton):
			continue
		var btn := node as ChooseLevelButton
		var para: ResourceLevelData = btn.curr_level_data_game_para
		if para == null or btn.level_script == null:
			continue
		n += 1
		var id := btn.level_script.resource_path.get_file().get_basename()
		## 旧拼法：拿一个干净副本、把 save_key 清空逼它走 set_choose_level 的自动拼法，
		## 用的还是按钮上的 game_mode / level_page / level_id（就是运行时拼的那个值）
		var fresh := (btn.level_script as Script).new() as ResourceLevelData
		if fresh == null:
			_check(a, "%s 能 new 出关卡实例" % id, false)
			continue
		fresh.save_key = ""
		fresh.set_choose_level(para.game_mode, para.level_page, para.level_id)
		_remember(id, para.save_key)
		if STRICT_COMPARE_MODES.has(mode):
			_check(a, "%s 写死的存档键 == 旧拼法 %s" % [id, fresh.save_game_name],
				para.save_key == fresh.save_game_name)
		else:
			## 宽松：只要求非空。**写死值与当前拼法不一致是既有事实，且写死值才是权威**（见文件头）
			_check(a, "%s save_key 非空（%s）" % [id, para.save_key], para.save_key != "")
			if para.save_key != "" and para.save_key != fresh.save_game_name:
				_diff_count += 1
	a.log("[SAVEKEYPROBE]   mode=%d 按钮 %d 个" % [int(mode), n])


func _check(a, label: String, ok: bool) -> void:
	if not ok:
		_failed += 1
	a.log("[SAVEKEYPROBE] %s %s" % ["PASS" if ok else "FAIL", label])


func _walk(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for c in node.get_children():
		out.append_array(_walk(c))
	return out
