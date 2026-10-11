extends ChooseLevel
class_name CustomChooseLevel
## 自制关卡的选关界面 —— **属于自制关卡模组**（入口 `res://src/mods/custom_level/custom_level_mod.gd`）
##
## 本体不引用本文件：`MainSceneRegistry.get_scene_path(ChooseLevelCustom)` 的场景路径
## 由模组在 `install()` 时注入，模组没启用就进不来这里（本体零分支、零节点）。

const CHOOSE_LEVEL_BUTTON_CUSTOMIZE = preload("res://src/mods/custom_level/choose_level_button_customize.tscn")

## 玩家自制关卡目录（相对基路径 `user://`，基路径见 get_base_path()）
##
## 实际落点（Windows）：`C:/Users/<用户名>/AppData/Roaming/Godot/app_userdata/PVZ-Dream-Edit/custom_level`
## —— 编辑器里跑与导出后跑是**同一个**目录，玩家往这里丢关卡文件即可。
##
## 目录里两种摆法都认（**关卡一律是 `.gd` 关卡脚本**，见 LevelScriptBase）：
##   1）关卡包（推荐）：`custom_level/<关卡名>/` —— 一个子目录 = 一个关卡，目录名就是关卡 id。
##      目录里的**关卡脚本**当关卡，目录里**其余的文件**全是这个脚本的依赖
##      （辅助脚本 / 数据 / 场景，只加载进引擎缓存，不进选关列表）。
##   2）散装文件：`custom_level/xxx.gd` —— 文件名 basename 就是关卡 id。
##      「是不是关卡」只认继承链（LevelScriptBase / ResourceLevelData），
##      认不出来的 `.gd` 与所有 `.tres` 都只当依赖，不会在选关列表里冒出假关卡。
const CUSTOM_LEVEL_DIR := "custom_level"

## 关卡脚本后缀（关卡只有这一种形态：一个 .gd = 属性 + 流程）
const SCRIPT_EXT := ["gd"]
## 依赖文件后缀：只加载、不进选关列表
const DEP_EXT := ["gd", "tres", "res", "scn"]
## 关卡包里的入口脚本名约定：优先取它，其次取目录里唯一的关卡脚本
const ENTRY_SCRIPT_NAMES := ["level", "main"]

@onready var panel_help: Panel = $PanelHelp
@onready var grid_container: GridContainer = $AllPage/GridContainer

## 每一页的关卡数量
var num_level_button_every_page:=20

func _ready() -> void:
	## 获取游戏参数文件
	var all_game_paras:Array = scan_custom_levels(CUSTOM_LEVEL_DIR)
	## 初始化页面数据
	all_pages_array.clear()
	all_page.remove_child(grid_container)
	var curr_num_page:int = -1
	for i in range(all_game_paras.size()):
		var page_i:int = int(float(i) / num_level_button_every_page)
		if curr_num_page < page_i:
			curr_num_page += 1
			var new_grid_container = grid_container.duplicate()
			all_page.add_child(new_grid_container)
			all_pages_array.append(new_grid_container)
		## 当前页面
		var curr_grid_container = all_page.get_child(page_i)

		## 关卡按钮
		var chooes_level_button:ChooseLevelButtonCustomize = CHOOSE_LEVEL_BUTTON_CUSTOMIZE.instantiate()
		chooes_level_button.init_choose_level_button_customize(all_game_paras[i][0], all_game_paras[i][1])
		curr_grid_container.add_child(chooes_level_button)

		chooes_level_button.signal_choose_level_button.connect(_on_choose_level_button)
		chooes_level_button.curr_level_data_game_para.set_choose_level(game_mode, page_i, all_game_paras[i][1])
		chooes_level_button.update_curr_level_button_state(Global.global_game_state.curr_all_level_state_data.get(chooes_level_button.curr_level_data_game_para.save_game_name, {}))

	grid_container.queue_free()
	Log.debug(str("当前模式关卡数量:") + str(all_game_paras.size()))

	_ready_update_page()


## 自制关卡的基路径：Godot 的 user:// 目录（编辑器与导出后同址）
static func get_base_path() -> String:
	return ProjectSettings.globalize_path("user://").trim_suffix("/")


## [folder_path] 相对基路径的自制关卡目录
## 返回 [[关卡实例, 关卡id], ...]，顺序 = 先散装文件、后关卡包（均按名字排序）
func scan_custom_levels(folder_path: String = CUSTOM_LEVEL_DIR) -> Array:
	var root = get_base_path() + "/" + folder_path
	var dir = DirAccess.open(root)
	if dir == null:
		## 玩家第一次进来时目录还不存在：建一个，他才知道该往哪放关卡
		if DirAccess.make_dir_recursive_absolute(root) == OK:
			dir = DirAccess.open(root)
	if dir == null:
		Log.debug(str("目录不存在:") + str(root))
		return []

	## 先分门别类，再统一加载：依赖要先于关卡脚本进缓存
	var loose_files: Array[String] = []
	var package_dirs: Array[String] = []
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		if dir.current_is_dir():
			package_dirs.append(name)
		else:
			loose_files.append(name)
		name = dir.get_next()
	dir.list_dir_end()
	loose_files.sort()
	package_dirs.sort()

	var levels: Array[String] = []
	## 散装文件：是关卡的进列表，其余的当依赖先加载
	var loose_deps: Array[String] = []
	for file_name in loose_files:
		var full_path = root + "/" + file_name
		if is_level_file(full_path):
			levels.append(full_path)
		else:
			loose_deps.append(full_path)
	load_dependencies(loose_deps)

	var loose_levels: Array = []
	for full_path in levels:
		var one := load_level_file(full_path, full_path.get_file().get_basename())
		if not one.is_empty():
			loose_levels.append(one)

	## 关卡包：一个子目录 = 一个关卡
	for dir_name in package_dirs:
		var one := load_level_package(root + "/" + dir_name, dir_name)
		if not one.is_empty():
			loose_levels.append(one)

	return loose_levels


## 一个关卡包目录 = 一个关卡：目录里挑出关卡脚本，其余文件都是它的依赖
## 返回 [关卡实例, 关卡id]，目录里没有关卡脚本时返回空数组
func load_level_package(dir_path: String, dir_name: String) -> Array:
	var files := list_files(dir_path)
	var level_path := pick_level_script(files)
	if level_path == "":
		Log.debug(str("关卡包里没有关卡脚本, 跳过:") + str(dir_path))
		return []
	load_dependencies(files, level_path)
	return load_level_file(level_path, dir_name)


## 从一堆文件里挑出关卡脚本：
## 先在「继承链上是关卡」的 .gd 里按约定名（level.gd / main.gd）取，
## 取不到就取唯一的那一个；一个都没有时，目录里只有单个 .gd 就退而求其次认它。
func pick_level_script(files: Array[String]) -> String:
	var candidates: Array[String] = []
	for f in files:
		if SCRIPT_EXT.has(f.get_extension().to_lower()) and LevelRegistry.is_level_script(f):
			candidates.append(f)
	if candidates.is_empty():
		## 外部 .gd 认不出继承链时（比如导出模板下拿不到全局类）的兜底：只有单个脚本就当它是
		var scripts: Array[String] = []
		for f in files:
			if SCRIPT_EXT.has(f.get_extension().to_lower()):
				scripts.append(f)
		if scripts.size() == 1:
			Log.debug(str("认不出继承链, 取目录里唯一的脚本当关卡:") + str(scripts[0]))
			return scripts[0]
		return ""
	if candidates.size() > 1:
		Log.debug(str("关卡包里有多个关卡脚本:") + str(candidates))
	for f in candidates:
		if ENTRY_SCRIPT_NAMES.has(f.get_file().get_basename().to_lower()):
			return f
	return candidates[0]


## 加载单个关卡文件；返回 [关卡实例, 关卡id]，加载失败 / 不是关卡返回空数组
func load_level_file(full_path: String, level_id: String) -> Array:
	var res = ResourceLoader.load(full_path)
	if res == null:
		Log.debug(str("资源加载失败:") + str(full_path))
		return []
	## 关卡脚本（.gd）：load 出来的是 GDScript，new() 才是关卡实例
	if res is Script:
		res = (res as Script).new()
	if not (res is ResourceLevelData):
		Log.debug(str("不是关卡资源:") + str(full_path))
		return []
	Log.debug("加载游戏参数资源文件：" + level_id + " <- " + full_path)
	return [res, level_id]


## 加载依赖文件：只 load 进引擎缓存，不 new、不进选关列表
## [except_path] 关卡脚本自己，它走 load_level_file()
func load_dependencies(files: Array, except_path: String = "") -> void:
	for f in files:
		if f == except_path:
			continue
		if not DEP_EXT.has((f as String).get_extension().to_lower()):
			continue
		if ResourceLoader.load(f) == null:
			Log.debug(str("依赖加载失败:") + str(f))
		else:
			Log.debug("加载关卡依赖：" + (f as String).get_file())


## 目录里的直接子文件（绝对路径，不含子目录、不含点开头的隐藏文件）
func list_files(dir_path: String) -> Array[String]:
	var files: Array[String] = []
	var dir = DirAccess.open(dir_path)
	if dir == null:
		Log.debug(str("目录不存在:") + str(dir_path))
		return files
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not name.begins_with(".") and not dir.current_is_dir():
			files.append(dir_path + "/" + name)
		name = dir.get_next()
	dir.list_dir_end()
	files.sort()
	return files


## 这个文件是不是一个关卡：只看 .gd，且只认继承链上的关卡脚本
## （.tres 老格式关卡入口已删除，.tres 现在只当依赖）
func is_level_file(full_path: String) -> bool:
	if not SCRIPT_EXT.has(full_path.get_extension().to_lower()):
		return false
	return LevelRegistry.is_level_script(full_path)


func _on_help_pressed() -> void:
	panel_help.visible = true

func _on_button_ok_pressed() -> void:
	panel_help.visible = false
