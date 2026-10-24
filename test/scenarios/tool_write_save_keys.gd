extends RefCounted
## 工具（**会改文件**）：把关卡的存档键写死进关卡 `.gd`（`_init()` 里的 `save_key = "..."`）。
##
## 存档键不能靠推算 —— 它来自选关场景**遍历节点的顺序**
## （`choose_level.gd:31 generate_level_id()`），推算错了玩家的老存档就找不回来。
## 所以本工具跟 tool_dump_save_keys.gd 一样：**真跑一遍选关场景**，从按钮上读权威值再写回。
##
## ⚠️ **冒险模式是例外**：它没有选关界面（见 docs/参考存档/选关界面与解锁.md），
##   存档键由关卡序号直接给出（`GlobalGameState.get_adventure_save_game_name()`，即运行时那条式子），
##   所以这一段不切场景，按序号算 —— 详见 _write_adventure()。
##
## 写入位置 = 关卡 `.gd` 里 `_init()` 中的那一行 `save_key = "..."`：
##   已有该行 → 整行替换；有 `_init()` 但没有 → 插到 `func _init()` 之后；连 `_init()` 都没有 → 新建一个。
## ⚠️ **只写 save_key，不动 format_version** —— 后者是「字段怎么读」的开关，属行为变更，要单独评测
##   （见 docs/TODO清单.md 的 U-22 第 ④ 条）。
##
## ⚠️ **2026-10-22 两处修正**（原工具对现在的关卡库**完全不工作**）：
##   ① 写入目标从 `.tres` 的 `[resource]` 段改成 `.gd` 的 `save_key` 行 —— 关卡 V2 已是
##      「一个 .gd = 属性 + 流程」，`src/levels/` 下实测 `.tres` = 0，旧写法每关都会报「找不到 [resource] 段」；
##   ② 路径来源从 `para.resource_path` 改成 `ChooseLevelButton.level_script.resource_path` ——
##      按钮上的关卡数据是 `level_script.new()` 出来的实例，实例的 resource_path 恒为空串。
##   仍然是**文本级改写**（不经过 Godot 的 ResourceSaver）—— 关卡文件里有大量原版考据注释
##   （台词出处 / 罐子配比理由），重新保存会全部冲掉（见 docs/参考存档/关卡时间轴.md）。
##
## 用法：改下面的 TARGET_IDS（留空 = 全部关卡），然后
##   powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Scenario tool_write_save_keys

## 只迁移这几个关卡 id（文件名 basename）；留空数组 = 迁移全部
const TARGET_IDS: Array[String] = []

## 有选关场景的 3 个模式；冒险模式没有选关界面，走 _write_adventure()
const MODES := [
	MainSceneRegistry.MainScenes.ChooseLevelMiniGame,
	MainSceneRegistry.MainScenes.ChooseLevelPuzzle,
	MainSceneRegistry.MainScenes.ChooseLevelSurvival,
]

const ADVENTURE := MainSceneRegistry.MainScenes.ChooseLevelAdventure

var _written := 0
var _skipped := 0
var _failed := 0


func run(a) -> void:
	a.log("[WRITESAVEKEY] 目标=%s" % ("全部" if TARGET_IDS.is_empty() else str(TARGET_IDS)))
	_write_adventure(a)
	for mode in MODES:
		var path: String = Global.main_scene_registry.get_scene_path(mode)
		GlobalUtils.change_scene(path)
		await a.wait(2.0)
		var root: Node = a.get_tree().current_scene
		if root == null:
			a.log("[WRITESAVEKEY] 场景没起来 " + path)
			continue
		for node in _walk(root):
			if node is ChooseLevelButton:
				var para: ResourceLevelData = node.curr_level_data_game_para
				if para == null:
					continue
				_handle(a, para, para.save_game_name, _script_path_of(node))
	a.log("")
	a.log("[WRITESAVEKEY] 写入=%d 跳过=%d 失败=%d" % [_written, _skipped, _failed])
	a.log("")
	a.log("[WRITESAVEKEY] 回读要**另起一个进程**跑 probe_save_key：")
	a.log("[WRITESAVEKEY] 本进程里关卡资源正被选关场景引用，CACHE_MODE_REPLACE 顶不掉缓存实例")
	a.log("[WRITESAVEKEY] result=DONE")
	a.quit_game()


## 冒险模式：没有选关界面可跑，存档键 = 关卡序号的那条式子（与运行时同源）
func _write_adventure(a) -> void:
	a.log("[WRITESAVEKEY] === mode=%d 冒险模式（无选关界面，走 GlobalGameState 的序号式子）" % int(ADVENTURE))
	for id in LevelRegistry.ids_by_mode(ADVENTURE):
		var adventure_level := LevelRegistry._parse_adventure_level(id)
		if adventure_level <= 0:
			continue
		var key := Global.global_game_state.get_adventure_save_game_name(adventure_level)
		_handle(a, LevelRegistry.get_level(id), key, LevelRegistry.get_level_path(id))
		## 二周目变体只是换个脚本，存档键与正本同一份（见 LevelRegistry.ROUND_VARIANT_SUFFIX）
		var variant_id := id + LevelRegistry.ROUND_VARIANT_SUFFIX
		var variant_path := LevelRegistry.get_level_path(variant_id)
		if variant_path != "":
			_handle(a, LevelRegistry.get_level(variant_id), key, variant_path)


## [para] 关卡实例（new() 出来的，用来读当前已写死的 save_key 做幂等判断；null 也能写）
## [save_key] 权威存档键  [res_path] 关卡 .gd 路径
func _handle(a, para: ResourceLevelData, save_key: String, res_path: String) -> void:
	if res_path == "":
		a.log("[WRITESAVEKEY] !! 拿不到关卡脚本路径，跳过")
		_failed += 1
		return
	var id := res_path.get_file().get_basename()
	if not TARGET_IDS.is_empty() and not TARGET_IDS.has(id):
		return
	if not res_path.ends_with(".gd"):
		a.log("[WRITESAVEKEY] !! %s 不是 .gd（%s），关卡已全改 .gd，跳过" % [id, res_path])
		_failed += 1
		return
	if save_key == "":
		a.log("[WRITESAVEKEY] !! %s 存档键为空，跳过" % id)
		_failed += 1
		return
	## 幂等：已经写死且和权威值一致就别再动文件（也避免同一进程内重复写）
	if para != null and para.save_key == save_key:
		_skipped += 1
		return
	var err := _write_save_key_gd(res_path, save_key)
	if err != "":
		a.log("[WRITESAVEKEY] !! %s 写入失败: %s" % [id, err])
		_failed += 1
		return
	_written += 1
	a.log("[WRITESAVEKEY] %s -> save_key=%s" % [id, save_key])


## 文本级改写 `save_key = "..."` 那一行：有就替换，没有就插进 `_init()`，连 `_init()` 都没有就新建
func _write_save_key_gd(res_path: String, save_key: String) -> String:
	var abs_path := ProjectSettings.globalize_path(res_path)
	var text := FileAccess.get_file_as_string(abs_path)
	if text == "":
		return "读不到文件"
	var eol := "\r\n" if text.contains("\r\n") else "\n"
	## 先把 \r\n 统一成 \n 再切分 —— 否则「行尾还留着 \r」+「join 又拼一个 \r\n」会写出 \r\r\n
	var lines := text.replace("\r\n", "\n").split("\n")
	var line := "\tsave_key = \"%s\"" % save_key

	## 1. 已经有一行 save_key = ... —— 整行替换，缩进照原样保留
	for i in lines.size():
		var body: String = lines[i]
		if not body.strip_edges().begins_with("save_key"):
			continue
		var k := 0
		while k < body.length() and (body.substr(k, 1) == "\t" or body.substr(k, 1) == " "):
			k += 1
		lines[i] = body.substr(0, k) + "save_key = \"%s\"" % save_key
		return _flush(abs_path, eol, lines)

	## 2. 有 _init() 但没写 save_key —— 插在声明行之后
	for i in lines.size():
		if lines[i].strip_edges().begins_with("func _init"):
			lines.insert(i + 1, line)
			return _flush(abs_path, eol, lines)

	## 3. 连 _init() 都没有 —— 在第一个函数（一般是 run_flow）之前新建一个
	##    ⚠️ 要**跨过紧邻的 @注解**（`@warning_ignore("unused_parameter")` 之类）再插：
	##    注解只修饰紧跟它的那一个声明，插在注解与 func 之间，等于把注解抢给了新建的 _init()，
	##    原来的那个函数反而丢了注解（survival_flag_01_day.gd 就是这么中招的）
	for i in lines.size():
		if not lines[i].strip_edges().begins_with("func "):
			continue
		var at := i
		while at > 0 and lines[at - 1].strip_edges().begins_with("@"):
			at -= 1
		lines = lines.slice(0, at) \
			+ PackedStringArray(["func _init() -> void:", line, ""]) \
			+ lines.slice(at)
		return _flush(abs_path, eol, lines)

	return "找不到 _init() 也没有任何 func"


func _flush(abs_path: String, eol: String, lines: PackedStringArray) -> String:
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		return "写文件失败 err=%d" % FileAccess.get_open_error()
	f.store_string(eol.join(lines))
	f.close()
	return ""


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
