extends RefCounted
## 工具（只读）：把每个内置关卡**当前真实的存档键 save_game_name** dump 出来。
##
## 为什么是「dump」而不是「推算」：
##   关卡 V2 要把存档键显式化成 ResourceLevelData.save_key，写进去的值必须和现在运行时
##   拼出来的**一模一样**，否则玩家的老存档会找不到。而现在的拼法是
##   `str(game_mode)_str(level_page)_str(level_id)`，其中 level_page / level_id 来自
##   选关场景**遍历节点的顺序**（见 choose_level.gd:31 generate_level_id）—— 推算容易算错。
##   所以这里真跑一遍 3 个选关场景，从按钮上读权威值。
##
## ⚠️ **冒险模式是唯一的例外：它不走选关场景**。冒险模式没有选关界面
##   （见 docs/参考存档/选关界面与解锁.md），进关方是 `GlobalGameState.build_adventure_level_para()`，
##   `level_id` 就是关卡序号本身（`%04d`），所以它的存档键**不依赖遍历顺序**，
##   由 `GlobalGameState.get_adventure_save_game_name()` 直接给出 —— 那正是运行时拼的那条式子。
##
## ⚠️ **2026-10-22 修路径来源**：原来读 `para.resource_path`，而按钮上的关卡数据是
##   `level_script.new()` 出来的**实例**，实例的 resource_path 恒为空串 ——
##   关卡从 .tres 改成 .gd 之后这条就断了（实测 dump 出来的路径列全是空的）。
##   现在改成读 `ChooseLevelButton.level_script.resource_path`（Script 才带 .gd 路径）。
##
## 只读：不写任何 .gd。写回由 tool_write_save_keys.gd 做。

## 有选关场景的 3 个模式；冒险模式没有选关界面，走 _dump_adventure()
const MODES := [
	MainSceneRegistry.MainScenes.ChooseLevelMiniGame,
	MainSceneRegistry.MainScenes.ChooseLevelPuzzle,
	MainSceneRegistry.MainScenes.ChooseLevelSurvival,
]

const ADVENTURE := MainSceneRegistry.MainScenes.ChooseLevelAdventure


func run(a) -> void:
	var total := _dump_adventure(a)
	for mode in MODES:
		var path: String = Global.main_scene_registry.get_scene_path(mode)
		a.log("[SAVEKEY] === mode=%d scene=%s" % [int(mode), path])
		GlobalUtils.change_scene(path)
		await a.wait(2.0)
		var root: Node = a.get_tree().current_scene
		if root == null:
			a.log("[SAVEKEY]   场景没起来")
			continue
		var btn_count := 0
		for node in _walk(root):
			if node is ChooseLevelButton:
				btn_count += 1
				var para: ResourceLevelData = node.curr_level_data_game_para
				if para == null:
					a.log("[SAVEKEY]   <按钮没挂关卡资源>")
					continue
				## 格式: 关卡 .gd 路径|存档键
				a.log("[SAVEKEY]   %s|%s" % [_script_path_of(node), para.save_game_name])
				total += 1
		a.log("[SAVEKEY]   按钮数=%d" % btn_count)
		a.log("")
	a.log("[SAVEKEY] 合计 %d 关" % total)
	a.log("[SAVEKEY] result=DONE")
	a.quit_game()


## 冒险模式：没有选关界面，存档键由「关卡序号」直接给出（不依赖遍历顺序）
func _dump_adventure(a) -> int:
	a.log("[SAVEKEY] === mode=%d 冒险模式（无选关界面，走 GlobalGameState 的序号式子）" % int(ADVENTURE))
	var n := 0
	for id in LevelRegistry.ids_by_mode(ADVENTURE):
		var adventure_level := LevelRegistry._parse_adventure_level(id)
		if adventure_level <= 0:
			a.log("[SAVEKEY]   %s 不是 adventure_<大关>_<小关>（测试关 / 辅助关），跳过" % id)
			continue
		var key := Global.global_game_state.get_adventure_save_game_name(adventure_level)
		a.log("[SAVEKEY]   %s|%s" % [LevelRegistry.get_level_path(id), key])
		n += 1
		## 二周目变体只是换个脚本，存档键与正本同一份（见 LevelRegistry.ROUND_VARIANT_SUFFIX）
		var variant_id := id + LevelRegistry.ROUND_VARIANT_SUFFIX
		var variant_path := LevelRegistry.get_level_path(variant_id)
		if variant_path != "":
			a.log("[SAVEKEY]   %s|%s" % [variant_path, key])
			n += 1
	a.log("")
	return n


## 按钮 -> 关卡 .gd 路径：走按钮上挂的 Script，不是 new() 出来的实例（实例的 resource_path 是空的）
func _script_path_of(btn: ChooseLevelButton) -> String:
	if btn.level_script == null:
		return ""
	return btn.level_script.resource_path


func _walk(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for c in node.get_children():
		out.append_array(_walk(c))
	return out
