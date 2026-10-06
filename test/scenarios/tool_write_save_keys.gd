extends RefCounted
## 工具（**会改文件**）：把关卡的存档键写死进 .tres（`save_key`），并把关卡标记为 V2。
##
## 存档键不能靠推算 —— 现在它来自选关场景**遍历节点的顺序**
## （`choose_level.gd:31 generate_level_id()`），推算错了玩家的老存档就找不回来。
## 所以本工具跟 tool_dump_save_keys.gd 一样：**真跑一遍选关场景**，从按钮上读权威值再写回。
##
## 写入两个字段（都在 .tres 的 [resource] 段）：
##   save_key       = "<mode>_<page>_<序号>"  —— 与运行时拼出来的值完全一致，玩家存档不丢
##   format_version = 2                        —— 标记本关已迁到 V2
##
## ⚠️ 文本级改写，不经过 Godot 的 ResourceSaver：
##   关卡 .tres 里有大量 `;` 开头的原版考据注释（台词出处 / 罐子配比理由），
##   用 Godot 重新保存会全部冲掉（见 docs/参考存档/关卡时间轴.md）。
##
## 用法：改下面的 TARGET_IDS（留空 = 全部关卡），然后
##   powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Scenario tool_write_save_keys

## 只迁移这几个关卡 id（文件名 basename）；留空数组 = 迁移全部
const TARGET_IDS: Array[String] = ["adventure_01_01", "adventure_01_02", "adventure_01_03", "adventure_01_04"]

const MODES := [
	MainSceneRegistry.MainScenes.ChooseLevelAdventure,
	MainSceneRegistry.MainScenes.ChooseLevelMiniGame,
	MainSceneRegistry.MainScenes.ChooseLevelPuzzle,
	MainSceneRegistry.MainScenes.ChooseLevelSurvival,
]

var _written := 0
var _skipped := 0
var _failed := 0


func run(a) -> void:
	a.log("[WRITESAVEKEY] 目标=%s" % ("全部" if TARGET_IDS.is_empty() else str(TARGET_IDS)))
	for mode in MODES:
		var path: String = Global.main_scene_registry.MainScenesMap[mode]
		a.get_tree().change_scene_to_file(path)
		await a.wait(2.0)
		var root: Node = a.get_tree().current_scene
		if root == null:
			a.log("[WRITESAVEKEY] 场景没起来 " + path)
			continue
		for node in _walk(root):
			if node is ChooseLevelButton:
				_handle(a, node.curr_level_data_game_para)
	a.log("")
	a.log("[WRITESAVEKEY] 写入=%d 跳过=%d 失败=%d" % [_written, _skipped, _failed])
	a.log("")
	a.log("[WRITESAVEKEY] 回读要**另起一个进程**跑 probe_save_key：")
	a.log("[WRITESAVEKEY] 本进程里关卡资源正被选关场景引用，CACHE_MODE_REPLACE 顶不掉缓存实例")
	a.log("[WRITESAVEKEY] result=DONE")
	a.quit_game()


func _handle(a, para: ResourceLevelData) -> void:
	if para == null:
		return
	var res_path: String = para.resource_path
	var id := res_path.get_file().get_basename()
	if not TARGET_IDS.is_empty() and not TARGET_IDS.has(id):
		return
	var save_key: String = para.save_game_name
	if save_key == "":
		a.log("[WRITESAVEKEY] !! %s 存档键为空，跳过" % id)
		_failed += 1
		return
	var err := _write_fields(res_path, {"format_version": "2", "save_key": '"%s"' % save_key})
	if err != "":
		a.log("[WRITESAVEKEY] !! %s 写入失败: %s" % [id, err])
		_failed += 1
		return
	_written += 1
	a.log("[WRITESAVEKEY] %s -> save_key=%s" % [id, save_key])


## 文本级改写：字段已存在就替换，不存在就插到 [resource] 段首
func _write_fields(res_path: String, fields: Dictionary) -> String:
	var abs_path := ProjectSettings.globalize_path(res_path)
	var text := FileAccess.get_file_as_string(abs_path)
	if text == "":
		return "读不到文件"
	var eol := "\r\n" if text.contains("\r\n") else "\n"
	var lines := text.split("\n")

	var res_idx := -1
	for i in lines.size():
		if lines[i].strip_edges().begins_with("[resource]"):
			res_idx = i
			break
	if res_idx < 0:
		return "找不到 [resource] 段"

	var pending := fields.duplicate()
	for i in lines.size():
		var body: String = lines[i]
		if body.ends_with("\r"):
			body = body.substr(0, body.length() - 1)
		var key := body.split("=", true, 1)[0].strip_edges()
		if pending.has(key):
			lines[i] = "%s = %s" % [key, str(pending[key])]
			pending.erase(key)

	## 没命中的字段插在 [resource] 段里 **script = 那一行之后**
	## ⚠️ 不能插在 [resource] 之后就完事：.tres 的属性是**按顺序**设置的，
	##    写在 script = 之前时资源还没挂上脚本，format_version / save_key 会被当成
	##    未知属性静默忽略（表现：文件里明明有，加载回来却是默认值）
	var insert_at := res_idx + 1
	for i in range(res_idx + 1, lines.size()):
		if lines[i].rstrip("\r").strip_edges().begins_with("script ="):
			insert_at = i + 1
			break
	for k in pending.keys():
		lines.insert(insert_at, "%s = %s" % [k, str(pending[k])])
		insert_at += 1

	var out := eol.join(lines)
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		return "写文件失败 err=%d" % FileAccess.get_open_error()
	f.store_string(out)
	f.close()
	return ""


func _walk(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for c in node.get_children():
		out.append_array(_walk(c))
	return out


## 关卡 id -> 所在目录（目录名即模式，与 LevelRegistry.MODE_BY_DIR 同款约定）
func _dir_of(id: String) -> String:
	for d in ["mode_adventure", "mode_minigame", "mode_puzzle", "mode_survival"]:
		if id.begins_with(d.substr(5)):
			return d
	return ""


func _all_level_ids() -> Array[String]:
	var ids: Array[String] = []
	for d in ["mode_adventure", "mode_minigame", "mode_puzzle", "mode_survival"]:
		var dir := DirAccess.open("res://src/levels/" + d)
		if dir == null:
			continue
		dir.list_dir_begin()
		var n := dir.get_next()
		while n != "":
			if n.ends_with(".tres"):
				ids.append(n.get_basename())
			n = dir.get_next()
		dir.list_dir_end()
	ids.sort()
	return ids
