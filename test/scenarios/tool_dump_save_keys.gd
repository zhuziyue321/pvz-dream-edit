extends RefCounted
## 工具（只读）：把每个内置关卡**当前真实的存档键 save_game_name** dump 出来。
##
## 为什么是「dump」而不是「推算」：
##   关卡 V2 要把存档键显式化成 ResourceLevelData.save_key，写进去的值必须和现在运行时
##   拼出来的**一模一样**，否则玩家的老存档会找不到。而现在的拼法是
##   `str(game_mode)_str(level_page)_str(level_id)`，其中 level_page / level_id 来自
##   选关场景**遍历节点的顺序**（见 choose_level.gd:31 generate_level_id）—— 推算容易算错。
##   所以这里真跑一遍 4 个选关场景，从按钮上读权威值。
##
## 只读：不写任何 .tres。写回由 tool_write_save_keys.gd 做。

const MODES := [
	MainSceneRegistry.MainScenes.ChooseLevelAdventure,
	MainSceneRegistry.MainScenes.ChooseLevelMiniGame,
	MainSceneRegistry.MainScenes.ChooseLevelPuzzle,
	MainSceneRegistry.MainScenes.ChooseLevelSurvival,
]


func run(a) -> void:
	var total := 0
	for mode in MODES:
		var path: String = Global.main_scene_registry.MainScenesMap[mode]
		a.log("[SAVEKEY] === mode=%s scene=%s" % [str(mode), path])
		a.get_tree().change_scene_to_file(path)
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
				## 格式: 资源路径|存档键
				a.log("[SAVEKEY]   %s|%s" % [para.resource_path, para.save_game_name])
				total += 1
		a.log("[SAVEKEY]   按钮数=%d" % btn_count)
		a.log("")
	a.log("[SAVEKEY] 合计 %d 关" % total)
	a.log("[SAVEKEY] result=DONE")
	a.quit_game()


func _walk(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for c in node.get_children():
		out.append_array(_walk(c))
	return out
