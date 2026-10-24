extends ChooseLevel
## 自制关卡的选关界面 —— **属于自制关卡模组**（入口 `custom_level_mod.gd`）
##
## 本体不引用本文件：`MainSceneRegistry.get_scene_path(ChooseLevelCustom)` 的场景路径
## 由模组在 `install()` 时注入，模组没启用就进不来这里（本体零分支、零节点）。

const CHOOSE_LEVEL_BUTTON_CUSTOMIZE = preload("choose_level_button_customize.tscn")

## 玩家自制关卡目录（相对基路径 `user://`，基路径见 get_base_path()）
##
## 实际落点（Windows）：`C:/Users/<用户名>/AppData/Roaming/Godot/app_userdata/PVZ-Dream-Edit/custom_level`
## —— 编辑器里跑与导出后跑是**同一个**目录，玩家往这里丢关卡文件即可。
## 模组自带的关卡放**每个模组自己目录下的 `levels/`**（见 MOD_LEVEL_DIR / get_mod_level_dirs()），
## 所有目录一起扫，同 id 时玩家目录优先（见 scan_custom_levels）。
##
## 目录里两种摆法都认（**关卡一律是 `.gd` 关卡脚本**，见 LevelScriptBase）：
##   1）关卡包（推荐）：`custom_level/<关卡名>/` —— 一个子目录 = 一个关卡，目录名就是关卡 id。
##      目录里的**关卡脚本**当关卡，目录里**其余的文件**全是这个脚本的依赖
##      （辅助脚本 / 数据 / 场景，只加载进引擎缓存，不进选关列表）。
##   2）散装文件：`custom_level/xxx.gd` —— 文件名 basename 就是关卡 id。
##      「是不是关卡」只认继承链（LevelScriptBase / ResourceLevelData），
##      认不出来的 `.gd` 与所有 `.tres` 都只当依赖，不会在选关列表里冒出假关卡。
const CUSTOM_LEVEL_DIR := "custom_level"

## 模组自带关卡的目录名：**每个模组**都可以在自己目录下放一个 `levels/` 放关卡
##（摆法与玩家目录完全一样：关卡包优先、散装 `.gd` 亦可，关卡 id 同样是目录名 / 文件名 basename）。
##
## 扫描时由本选关界面把**所有模组**的这个目录一起扫掉（见 get_mod_level_dirs()）——
## 目录随各模组的加载根走（`user://mods/<id>/levels` 优先、`res://mods_builtin/<id>/levels` 兜底），
## 玩家把整个模组目录拷到 `user://mods/` 时自带关卡跟着走（自包含，同 模组机制.md §2.2 素材口径）。
## 自制关卡模组（custom_level）自己的关卡也放这里。**同 id 时玩家目录优先**（见 scan_custom_levels）。
const MOD_LEVEL_DIR := "levels"

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
		var chooes_level_button = CHOOSE_LEVEL_BUTTON_CUSTOMIZE.instantiate()
		chooes_level_button.init_choose_level_button_customize(all_game_paras[i][0], all_game_paras[i][1])
		curr_grid_container.add_child(chooes_level_button)

		chooes_level_button.signal_choose_level_button.connect(_on_choose_level_button)
		chooes_level_button.curr_level_data_game_para.set_choose_level(game_mode, page_i, all_game_paras[i][1])
		chooes_level_button.update_curr_level_button_state(Global.global_game_state.curr_all_level_state_data.get(chooes_level_button.curr_level_data_game_para.save_game_name, {}))

	grid_container.queue_free()

	_ready_update_page()


## 自制关卡的基路径：Godot 的 user:// 目录（编辑器与导出后同址）
static func get_base_path() -> String:
	return ProjectSettings.globalize_path("user://").trim_suffix("/")


## 某个模组的自带关卡目录（`<模组目录>/levels/`）：`user://mods/` 优先、内置源兜底，
## 根目录取 `ModManager.get_mod_root()`，不在这里抄第二份 —— 抄成 `user://mods` 的话，
## 这份跑的是内置源时就会指到一个空目录（两个源不互相复制，见 模组机制.md §二；
## 与 `custom_level_mod.gd:_choose_level_scene_path()` 同款口径）。
static func get_mod_level_dir(mod_id: StringName) -> String:
	var rel_dir := String(ModManager.MOD_SCRIPT_PATHS[mod_id]).get_base_dir()
	return ModManager.get_mod_root(mod_id).path_join(rel_dir).path_join(MOD_LEVEL_DIR)


## 所有模组的自带关卡目录（`<模组目录>/levels/`），按模组 id 排序保证顺序确定
##
## 「所有模组」= `ModManager` 登记表（`MOD_SCRIPT_PATHS`）里的全部模组 —— **不论启用与否**
## （目录里放了关卡就该被识别；选关界面本身只有 custom_level 模组启用时才进得来），
## 外加 `user://mods/` 下**未登记**的模组目录兜底（玩家自己放的模组也认）。
## 目录不存在无所谓，扫的时候自然跳过（大多数模组没有 levels/ 目录）。
static func get_mod_level_dirs() -> Array[String]:
	var dirs: Array[String] = []
	var seen: Dictionary = {}
	var ids: Array = ModManager.MOD_SCRIPT_PATHS.keys()
	ids.sort()
	for mod_id in ids:
		var dir := get_mod_level_dir(mod_id)
		if not seen.has(dir):
			seen[dir] = true
			dirs.append(dir)
	## 兜底：`user://mods/` 下未登记的模组（没有入口脚本，ModManager 不管它们）
	var user_root := DirAccess.open(ModManager.MODS_ROOT)
	if user_root == null:
		return dirs
	user_root.list_dir_begin()
	var entry_name := user_root.get_next()
	while entry_name != "":
		if not entry_name.begins_with(".") and user_root.current_is_dir():
			var dir := ModManager.MODS_ROOT.path_join(entry_name).path_join(MOD_LEVEL_DIR)
			if not seen.has(dir):
				seen[dir] = true
				dirs.append(dir)
		entry_name = user_root.get_next()
	user_root.list_dir_end()
	return dirs


## [folder_path] 相对基路径（user://）的玩家自制关卡目录
## 返回 [[关卡实例, 关卡id], ...]
##
## 扫**两类目录**：玩家目录（本参数）+ 所有模组的自带关卡目录（get_mod_level_dirs()）。
## **同 id 时玩家目录优先**，模组目录之间先到先得（按模组 id 排序，顺序确定）——
## 玩家拷过去改过的那份盖住模组自带那份（与「两个加载源玩家优先」同口径）。
## 列表顺序 = 先玩家目录、后各模组目录，每类内部顺序 = 先散装文件、后关卡包（均按名字排序）。
func scan_custom_levels(folder_path: String = CUSTOM_LEVEL_DIR) -> Array:
	var levels: Array = []
	var index_by_id: Dictionary = {}
	## 玩家目录：第一次进来时还没有就建一个，玩家才知道该往哪放关卡
	for one in _scan_root(get_base_path() + "/" + folder_path, true):
		_add_level(levels, index_by_id, one)
	for dir in get_mod_level_dirs():
		for one in _scan_root(dir):
			_add_level(levels, index_by_id, one)
	return levels


## 合并一个扫描结果进列表：同 id **先出现的赢**（调用顺序即优先级）
static func _add_level(levels: Array, index_by_id: Dictionary, one: Array) -> void:
	var level_id := str(one[1])
	if index_by_id.has(level_id):
		return
	index_by_id[level_id] = levels.size()
	levels.append(one)


## 扫**一个**关卡目录：返回 [[关卡实例, 关卡id], ...]，顺序 = 先散装文件、后关卡包（均按名字排序）
## [auto_create] 目录不存在时是否顺手建一个（只对玩家目录开：让玩家知道该往哪放关卡；
## 模组自带目录没有就是没有，不建）
func _scan_root(root: String, auto_create := false) -> Array:
	var dir = DirAccess.open(root)
	if dir == null:
		## 玩家第一次进来时目录还不存在：建一个，他才知道该往哪放关卡
		if auto_create and DirAccess.make_dir_recursive_absolute(root) == OK:
			dir = DirAccess.open(root)
	if dir == null:
		return []

	## 先分门别类，再统一加载：依赖要先于关卡脚本进缓存
	var loose_files: Array[String] = []
	var package_dirs: Array[String] = []
	dir.list_dir_begin()
	## 局部变量不叫 name：本类继承 Node，`name` 是 Node 的属性，同名会触发 SHADOWED_VARIABLE_BASE_CLASS
	var entry_name := dir.get_next()
	while entry_name != "":
		if entry_name.begins_with("."):
			entry_name = dir.get_next()
			continue
		if dir.current_is_dir():
			package_dirs.append(entry_name)
		else:
			loose_files.append(entry_name)
		entry_name = dir.get_next()
	dir.list_dir_end()
	loose_files.sort()
	package_dirs.sort()

	var levels: Array[String] = []
	## 散装文件：是关卡的进列表，其余的当依赖先加载
	var loose_deps: Array[String] = []
	for file_name in loose_files:
		var file_path = root + "/" + file_name
		if is_level_file(file_path):
			levels.append(file_path)
		else:
			loose_deps.append(file_path)
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
		for fallback_file in files:
			if SCRIPT_EXT.has(fallback_file.get_extension().to_lower()):
				scripts.append(fallback_file)
		if scripts.size() == 1:
			return scripts[0]
		return ""
	for f in candidates:
		if ENTRY_SCRIPT_NAMES.has(f.get_file().get_basename().to_lower()):
			return f
	return candidates[0]


## 加载单个关卡文件；返回 [关卡实例, 关卡id]，加载失败 / 不是关卡返回空数组
func load_level_file(full_path: String, level_id: String) -> Array:
	var res = ResourceLoader.load(full_path)
	if res == null:
		return []
	## 关卡脚本（.gd）：load 出来的是 GDScript，new() 才是关卡实例
	if res is Script:
		res = (res as Script).new()
	if not (res is ResourceLevelData):
		return []
	return [res, level_id]


## 加载依赖文件：只 load 进引擎缓存，不 new、不进选关列表
## [except_path] 关卡脚本自己，它走 load_level_file()
func load_dependencies(files: Array, except_path: String = "") -> void:
	for f in files:
		if f == except_path:
			continue
		if not DEP_EXT.has((f as String).get_extension().to_lower()):
			continue


## 目录里的直接子文件（绝对路径，不含子目录、不含点开头的隐藏文件）
func list_files(dir_path: String) -> Array[String]:
	var files: Array[String] = []
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return files
	dir.list_dir_begin()
	## 同上：不叫 name，避免遮蔽 Node.name
	var entry_name := dir.get_next()
	while entry_name != "":
		if not entry_name.begins_with(".") and not dir.current_is_dir():
			files.append(dir_path + "/" + entry_name)
		entry_name = dir.get_next()
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
